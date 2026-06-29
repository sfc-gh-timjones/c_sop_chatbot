/*******************************************************************************
  ARC ASSISTANT — One-Click Deployment

  Tears down any existing ARC demo objects and rebuilds from scratch using
  scripts sourced directly from the GitHub repo.

  PDFs are copied automatically from the repo's pdfs/ folder into the internal
  stage in script 02. No manual upload step required after GitHub push.

  Prerequisites:
    - GIT_HUB_INTEGRATION API integration must exist (see README Step 1)
    - Run as ACCOUNTADMIN
*******************************************************************************/

USE ROLE ACCOUNTADMIN;
CREATE WAREHOUSE IF NOT EXISTS ARC_DEPLOY_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE;
USE WAREHOUSE ARC_DEPLOY_WH;

-- GIT_HUB_INTEGRATION is required — uncomment if it doesn't exist yet:
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

-- Teardown (safe even on first run)
EXECUTE IMMEDIATE FROM @ARC_DEPLOY.GIT.C_SOP_CHATBOT_REPO/branches/main/sql/99_teardown.sql;

-- Rebuild
EXECUTE IMMEDIATE FROM @ARC_DEPLOY.GIT.C_SOP_CHATBOT_REPO/branches/main/sql/01_database_and_schema.sql;
EXECUTE IMMEDIATE FROM @ARC_DEPLOY.GIT.C_SOP_CHATBOT_REPO/branches/main/sql/02_create_cortex_search.sql;
EXECUTE IMMEDIATE FROM @ARC_DEPLOY.GIT.C_SOP_CHATBOT_REPO/branches/main/sql/03_create_agent.sql;
EXECUTE IMMEDIATE FROM @ARC_DEPLOY.GIT.C_SOP_CHATBOT_REPO/branches/main/sql/04_grants.sql;

DROP DATABASE IF EXISTS ARC_DEPLOY;
DROP WAREHOUSE IF EXISTS ARC_DEPLOY_WH;

SELECT 'ARC demo deployed. Open Snowflake Intelligence -> ARC Assistant.' AS status;
