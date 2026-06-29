-- =============================================================================
-- ARC DEMO — Role and Grants
--
-- All demo objects are created and owned by ACCOUNTADMIN. This script creates
-- a read-only ARC_USER role that can use the agent via Snowflake Intelligence
-- without needing elevated privileges.
--
-- Grant ARC_USER to any Snowflake users who should access the ARC Assistant:
--   GRANT ROLE ARC_USER TO USER <username>;
-- =============================================================================

USE ROLE ACCOUNTADMIN;

CREATE ROLE IF NOT EXISTS ARC_USER;

-- Database and schema access
GRANT USAGE ON DATABASE CUSTOMER_DEMOS        TO ROLE ARC_USER;
GRANT USAGE ON SCHEMA   CUSTOMER_DEMOS.ARC    TO ROLE ARC_USER;

-- Warehouse access (required to run agent queries)
GRANT USAGE ON WAREHOUSE ARC_WH               TO ROLE ARC_USER;

-- Agent access (required for Snowflake Intelligence UI)
GRANT USAGE ON AGENT CUSTOMER_DEMOS.ARC.ARC_AGENT TO ROLE ARC_USER;

-- Read access to underlying tables (needed if users query directly)
GRANT SELECT ON TABLE CUSTOMER_DEMOS.ARC.ARC_CONTRACT_DOCS      TO ROLE ARC_USER;
GRANT SELECT ON TABLE CUSTOMER_DEMOS.ARC.ARC_CUSTOMER_REGISTRY  TO ROLE ARC_USER;

-- Cortex Search access (needed for direct API calls if applicable)
GRANT USAGE ON CORTEX SEARCH SERVICE CUSTOMER_DEMOS.ARC.ARC_CONTRACT_SEARCH TO ROLE ARC_USER;

-- =============================================================================
-- Assign to users
-- Uncomment and repeat for each Arcticom user who should access ARC Assistant:
-- =============================================================================
-- GRANT ROLE ARC_USER TO USER <username>;
