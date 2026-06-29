USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS CUSTOMER_DEMOS;
CREATE SCHEMA IF NOT EXISTS CUSTOMER_DEMOS.ARC;

CREATE OR REPLACE WAREHOUSE ARC_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 30
  AUTO_RESUME = TRUE;

-- Optional: enable cross-region Cortex inference if your account region doesn't
-- have the required models available natively. This is an account-wide setting —
-- review with your Snowflake account team before enabling, especially if you have
-- data residency requirements.
-- ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';

USE DATABASE CUSTOMER_DEMOS;
USE SCHEMA ARC;
USE WAREHOUSE ARC_WH;
