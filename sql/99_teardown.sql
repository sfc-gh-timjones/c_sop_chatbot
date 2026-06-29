USE ROLE ACCOUNTADMIN;

-- Remove agent from Snowflake Intelligence before dropping schema.
-- Wrapped in BEGIN/EXCEPTION because DROP AGENT has no IF EXISTS syntax —
-- this silently no-ops if the agent isn't registered yet (e.g. first-run teardown).
BEGIN
  ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT
    DROP AGENT CUSTOMER_DEMOS.ARC.ARC_AGENT;
EXCEPTION
  WHEN OTHER THEN
    NULL; -- agent not registered, nothing to remove
END;

DROP SCHEMA IF EXISTS CUSTOMER_DEMOS.ARC CASCADE;
DROP WAREHOUSE IF EXISTS ARC_WH;
DROP ROLE IF EXISTS ARC_USER;
