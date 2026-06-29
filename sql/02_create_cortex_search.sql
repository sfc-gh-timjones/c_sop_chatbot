USE ROLE ACCOUNTADMIN;
USE DATABASE CUSTOMER_DEMOS;
USE SCHEMA ARC;
USE WAREHOUSE ARC_WH;

-- =============================================================================
-- CUSTOMER REGISTRY TABLE
-- Single source of truth for customer metadata. The aliases column stores
-- pipe-separated informal names (e.g. "Wingstop|WS Ops") so the agent can
-- resolve what users actually type to the exact customer_name used for filtering.
-- =============================================================================

CREATE OR REPLACE TABLE ARC_CUSTOMER_REGISTRY (
  file_prefix    VARCHAR,   -- matches REGEXP_SUBSTR(filename, 'CST[0-9]+')
  sop_id         VARCHAR,
  customer_name  VARCHAR,
  customer_type  VARCHAR,
  aliases        VARCHAR    -- pipe-separated informal names and abbreviations
);

INSERT INTO ARC_CUSTOMER_REGISTRY VALUES
  ('CST0001', 'CST-0001', 'Safeway Stores Inc.',                             'Grocery Chain',                      'Safeway|Safeway Stores'),
  ('CST0002', 'CST-0002', 'Pacific Foods Distribution LLC',                  'Food Distribution / Cold Storage',   'Pacific Foods|Pacific Foods Dist|Pacific Foods Distribution'),
  ('CST0003', 'CST-0003', 'Sprouts Farmers Market - Region 7',               'Grocery Chain',                      'Sprouts|Sprouts Farmers Market|Sprouts Region 7'),
  ('CST0004', 'CST-0004', 'Golden State Foods - Livermore DC',               'Food Distribution / Cold Storage',   'Golden State Foods|GSF|Golden State'),
  ('CST0005', 'CST-0005', 'WS Operations LLC (Wingstop Franchisee)',         'Restaurant / QSR',                   'Wingstop|WS Ops|WS Operations|Wing Stop'),
  ('CST0006', 'CST-0006', 'Stater Bros. Markets',                            'Grocery Chain',                      'Stater Bros|Stater Brothers|Stater'),
  ('CST0007', 'CST-0007', 'ALDI Inc. - Southwest Division',                  'Grocery Chain',                      'ALDI|Aldi|ALDI Southwest'),
  ('CST0008', 'CST-0008', 'Raley''s Family of Stores',                       'Grocery Chain',                      'Raley''s|Raleys|Raley'),
  ('CST0009', 'CST-0009', 'Trader Joe''s Company - Western Service Area',    'Grocery Chain',                      'Trader Joe''s|Trader Joes|TJ''s|TJs'),
  ('CST0010', 'CST-0010', 'Sysco Los Angeles LLC',                           'Food Distribution / Cold Storage',   'Sysco|Sysco LA|Sysco Los Angeles'),
  ('CST0011', 'CST-0011', 'Food 4 Less - TAG Service Division',              'Grocery Chain',                      'Food 4 Less|Food for Less|Food4Less|F4L'),
  ('CST0012', 'CST-0012', 'Smart & Final Stores LLC',                        'Grocery Chain',                      'Smart and Final|Smart & Final|Smart Final'),
  ('CST0013', 'CST-0013', 'Cold Star Logistics Inc.',                        '3PL Cold Storage / Logistics',       'Cold Star|Cold Star Logistics'),
  ('CST0014', 'CST-0014', 'PBI Group LLC (Panera Bread Franchisee)',         'Restaurant / Bakery-Cafe',           'Panera|Panera Bread|PBI|PBI Group'),
  ('CST0015', 'CST-0015', 'Whole Foods Market - NorCal Region',              'Grocery Chain - Natural/Organic',    'Whole Foods|Whole Foods NorCal|Whole Foods Market'),
  ('CST0016', 'CST-0016', 'Casey''s General Stores - Pacific Division',      'Convenience Store / Fuel Retail',    'Casey''s|Casey|Casey General|Casey''s Pacific'),
  ('CST0017', 'CST-0017', 'Costco Wholesale - Business Center Refrigeration','Warehouse Retail',                   'Costco|Costco Business Center|Costco Wholesale'),
  ('CST0018', 'CST-0018', 'Nugget Markets Inc.',                             'Grocery Chain - Independent',        'Nugget|Nugget Markets'),
  ('CST0019', 'CST-0019', 'BJ''s Wholesale Club - Western Expansion Sites',  'Warehouse Retail',                   'BJ''s|BJs|BJ''s Wholesale|BJ''s West'),
  ('CST0020', 'CST-0020', 'Albertsons Companies - Division 13 (SoCal)',      'Grocery Chain',                      'Albertsons|Albertson''s|Albertsons Div 13|Albertsons Division 13');

-- =============================================================================
-- STAGE: single stage for all customer SOP PDFs
-- =============================================================================

CREATE OR REPLACE STAGE ARC_DOCS_STAGE
  DIRECTORY = (ENABLE = TRUE)
  ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');

-- Copy PDFs from Git repo (runs automatically via TEARDOWN_AND_REBUILD)
COPY FILES
INTO @CUSTOMER_DEMOS.ARC.ARC_DOCS_STAGE/
FROM @ARC_DEPLOY.GIT.C_SOP_CHATBOT_REPO/branches/main/pdfs/
PATTERN='.*[.]pdf$';

ALTER STAGE ARC_DOCS_STAGE REFRESH;

-- =============================================================================
-- PARSE, CHUNK, AND ANNOTATE: Customer Contract SOPs
--
-- Each PDF is parsed into text, chunked, then joined against ARC_CUSTOMER_REGISTRY
-- so every chunk row carries structured customer metadata. This ensures the agent
-- can filter by customer_name at query time rather than inferring it from text.
-- The aliases column is included so the agent can resolve informal names to the
-- correct legal customer_name before applying @eq filters.
-- =============================================================================

CREATE OR REPLACE TABLE ARC_CONTRACT_DOCS AS
WITH parsed AS (
  SELECT
    RELATIVE_PATH                                  AS file_name,
    REGEXP_SUBSTR(RELATIVE_PATH, 'CST[0-9]+')      AS file_prefix,
    AI_PARSE_DOCUMENT(
      TO_FILE('@ARC_DOCS_STAGE', RELATIVE_PATH),
      {'mode': 'LAYOUT', 'page_split': FALSE}
    ):content::STRING                              AS doc_text
  FROM DIRECTORY(@ARC_DOCS_STAGE)
  WHERE RELATIVE_PATH ILIKE 'CST%.pdf'
),
chunked AS (
  SELECT
    p.file_name,
    p.file_prefix,
    f.index         AS chunk_index,
    f.value::STRING AS chunk_text
  FROM parsed p,
  LATERAL FLATTEN(
    INPUT => SNOWFLAKE.CORTEX.SPLIT_TEXT_RECURSIVE_CHARACTER(
      p.doc_text, 'markdown', 1600, 300
    )
  ) f
)
SELECT
  ROW_NUMBER() OVER (ORDER BY c.file_name, c.chunk_index)  AS doc_id,
  r.sop_id,
  r.customer_name,
  r.customer_type,
  r.aliases,
  c.file_name,
  c.chunk_index,
  c.chunk_text
FROM chunked c
JOIN ARC_CUSTOMER_REGISTRY r ON r.file_prefix = c.file_prefix
WHERE LENGTH(c.chunk_text) > 50;

-- =============================================================================
-- INGEST VALIDATION
-- Fail fast if any PDFs on stage have no matching registry entry, or if the
-- expected customer count doesn't match.
-- =============================================================================

-- Files on stage with no registry match (should return 0 rows)
SELECT
  RELATIVE_PATH AS unmatched_file
FROM DIRECTORY(@ARC_DOCS_STAGE)
WHERE RELATIVE_PATH ILIKE 'CST%.pdf'
  AND REGEXP_SUBSTR(RELATIVE_PATH, 'CST[0-9]+') NOT IN (
    SELECT file_prefix FROM ARC_CUSTOMER_REGISTRY
  );

-- Customer count check (should be 20)
SELECT
  COUNT(DISTINCT sop_id)  AS customers_indexed,
  COUNT(*)                AS total_chunks
FROM ARC_CONTRACT_DOCS;

-- =============================================================================
-- CORTEX SEARCH SERVICE
-- =============================================================================

CREATE OR REPLACE CORTEX SEARCH SERVICE ARC_CONTRACT_SEARCH
  ON chunk_text
  ATTRIBUTES customer_name, customer_type, sop_id, aliases, file_name
  WAREHOUSE = ARC_WH
  TARGET_LAG = '1 hour'
AS (
  SELECT doc_id, sop_id, customer_name, customer_type, aliases, file_name, chunk_text
  FROM ARC_CONTRACT_DOCS
);
