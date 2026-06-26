USE ROLE ACCOUNTADMIN;
USE DATABASE CUSTOMER_DEMOS;
USE SCHEMA ARC;
USE WAREHOUSE ARC_WH;

-- =============================================================================
-- STAGE: single stage for all 20 customer SOP PDFs
-- =============================================================================

CREATE OR REPLACE STAGE ARC_DOCS_STAGE
  DIRECTORY = (ENABLE = TRUE)
  ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');

-- Copy PDFs from Git repo (runs automatically after GitHub push)
COPY FILES
INTO @CUSTOMER_DEMOS.ARC.ARC_DOCS_STAGE/
FROM @ARC_DEPLOY.GIT.C_SOP_CHATBOT_REPO/branches/main/pdfs/
PATTERN='.*[.]pdf$';

ALTER STAGE ARC_DOCS_STAGE REFRESH;

-- =============================================================================
-- PARSE, CHUNK, AND ANNOTATE: Customer Contract SOPs
--
-- Pattern: metadata lookup CTE maps filename prefix (CST0001) to customer
-- name and type, which is then stamped on every chunk row. This guarantees
-- each chunk carries customer identity as structured metadata — no inference
-- required from the agent at query time.
-- =============================================================================

CREATE OR REPLACE TABLE ARC_CONTRACT_DOCS AS
WITH customer_meta AS (
  SELECT * FROM VALUES
    ('CST0001', 'CST-0001', 'Safeway Stores Inc.',                      'Grocery Chain'),
    ('CST0002', 'CST-0002', 'Pacific Foods Distribution LLC',            'Food Distribution / Cold Storage'),
    ('CST0003', 'CST-0003', 'Sprouts Farmers Market - Region 7',         'Grocery Chain'),
    ('CST0004', 'CST-0004', 'Golden State Foods - Livermore DC',         'Food Distribution / Cold Storage'),
    ('CST0005', 'CST-0005', 'WS Operations LLC (Wingstop Franchisee)',   'Restaurant / QSR'),
    ('CST0006', 'CST-0006', 'Stater Bros. Markets',                      'Grocery Chain'),
    ('CST0007', 'CST-0007', 'ALDI Inc. - Southwest Division',            'Grocery Chain'),
    ('CST0008', 'CST-0008', 'Raley''s Family of Stores',                 'Grocery Chain'),
    ('CST0009', 'CST-0009', 'Trader Joe''s Company - Western Service Area', 'Grocery Chain'),
    ('CST0010', 'CST-0010', 'Sysco Los Angeles LLC',                     'Food Distribution / Cold Storage'),
    ('CST0011', 'CST-0011', 'Food 4 Less - TAG Service Division',        'Grocery Chain'),
    ('CST0012', 'CST-0012', 'Smart & Final Stores LLC',                  'Grocery Chain'),
    ('CST0013', 'CST-0013', 'Cold Star Logistics Inc.',                  '3PL Cold Storage / Logistics'),
    ('CST0014', 'CST-0014', 'PBI Group LLC (Panera Bread Franchisee)',   'Restaurant / Bakery-Cafe'),
    ('CST0015', 'CST-0015', 'Whole Foods Market - NorCal Region',        'Grocery Chain - Natural/Organic'),
    ('CST0016', 'CST-0016', 'Casey''s General Stores - Pacific Division', 'Convenience Store / Fuel Retail'),
    ('CST0017', 'CST-0017', 'Costco Wholesale - Business Center Refrigeration', 'Warehouse Retail'),
    ('CST0018', 'CST-0018', 'Nugget Markets Inc.',                       'Grocery Chain - Independent'),
    ('CST0019', 'CST-0019', 'BJ''s Wholesale Club - Western Expansion Sites', 'Warehouse Retail'),
    ('CST0020', 'CST-0020', 'Albertsons Companies - Division 13 (SoCal)', 'Grocery Chain')
  AS t(file_prefix, sop_id, customer_name, customer_type)
),
parsed AS (
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
    f.index      AS chunk_index,
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
  m.sop_id,
  m.customer_name,
  m.customer_type,
  c.file_name,
  c.chunk_index,
  c.chunk_text
FROM chunked c
JOIN customer_meta m ON m.file_prefix = c.file_prefix
WHERE LENGTH(c.chunk_text) > 50;

-- =============================================================================
-- CORTEX SEARCH SERVICE
-- =============================================================================

CREATE OR REPLACE CORTEX SEARCH SERVICE ARC_CONTRACT_SEARCH
  ON chunk_text
  ATTRIBUTES customer_name, customer_type, sop_id, file_name
  WAREHOUSE = ARC_WH
  TARGET_LAG = '1 hour'
AS (
  SELECT doc_id, sop_id, customer_name, customer_type, file_name, chunk_text
  FROM ARC_CONTRACT_DOCS
);
