/***************************************************************************************************
  ARC ASSISTANT — One-Click Deployment

  This script:
    1. Creates a Git repo integration to pull scripts directly from GitHub
    2. Tears down any existing ARC demo objects (safe to run fresh)
    3. Runs all setup scripts (01 -> 04) via EXECUTE IMMEDIATE FROM

  PDFs are copied automatically from the Git repo into the internal stage in script 02.
  No manual upload step is required.
***************************************************************************************************/

USE ROLE ACCOUNTADMIN;
CREATE WAREHOUSE IF NOT EXISTS ARC_DEPLOY_WH WAREHOUSE_SIZE = 'XSMALL' AUTO_SUSPEND = 60 AUTO_RESUME = TRUE;
USE WAREHOUSE ARC_DEPLOY_WH;

/*=============================================================================
  1. GIT REPO INTEGRATION

  If you followed the README instructions, this integration already exists
  and the block below will do nothing. If you skipped that step or are unsure,
  you can safely uncomment and run it — IF NOT EXISTS means it will only
  create the integration if it isn't already there.
=============================================================================*/

-- CREATE API INTEGRATION IF NOT EXISTS GIT_HUB_INTEGRATION
--   API_PROVIDER = git_https_api
--   API_ALLOWED_PREFIXES = ('https://github.com/')
--   ENABLED = TRUE;

CREATE DATABASE IF NOT EXISTS ARC_DEPLOY;
CREATE SCHEMA IF NOT EXISTS ARC_DEPLOY.GIT;

CREATE OR REPLACE GIT REPOSITORY ARC_DEPLOY.GIT.C_SOP_CHATBOT_REPO
  API_INTEGRATION = GIT_HUB_INTEGRATION
  ORIGIN = 'https://github.com/sfc-gh-timjones/c_sop_chatbot';

ALTER GIT REPOSITORY ARC_DEPLOY.GIT.C_SOP_CHATBOT_REPO FETCH;

/*=============================================================================
  2. TEARDOWN (safe even on first run)
=============================================================================*/

EXECUTE IMMEDIATE FROM @ARC_DEPLOY.GIT.C_SOP_CHATBOT_REPO/branches/main/sql/99_teardown.sql;

/*=============================================================================
  3. REBUILD (runs in order: 01 -> 04)
=============================================================================*/

EXECUTE IMMEDIATE FROM @ARC_DEPLOY.GIT.C_SOP_CHATBOT_REPO/branches/main/sql/01_database_and_schema.sql;
EXECUTE IMMEDIATE FROM @ARC_DEPLOY.GIT.C_SOP_CHATBOT_REPO/branches/main/sql/02_create_cortex_search.sql;
EXECUTE IMMEDIATE FROM @ARC_DEPLOY.GIT.C_SOP_CHATBOT_REPO/branches/main/sql/03_create_agent.sql;
EXECUTE IMMEDIATE FROM @ARC_DEPLOY.GIT.C_SOP_CHATBOT_REPO/branches/main/sql/04_grants.sql;

/*=============================================================================
  DONE!

  The demo environment is ready. Open Snowflake Intelligence -> ARC Assistant.
  Verify objects:
    SHOW AGENTS IN SCHEMA CUSTOMER_DEMOS.ARC;
    SHOW CORTEX SEARCH SERVICES IN SCHEMA CUSTOMER_DEMOS.ARC;
    SELECT COUNT(DISTINCT sop_id) AS customers_indexed FROM CUSTOMER_DEMOS.ARC.ARC_CONTRACT_DOCS;
=============================================================================*/

DROP DATABASE IF EXISTS ARC_DEPLOY;
DROP WAREHOUSE IF EXISTS ARC_DEPLOY_WH;

SELECT 'ARC demo deployed. Open Snowflake Intelligence -> ARC Assistant.' AS status;
