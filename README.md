# ARC Assistant — Arcticom PDF Chatbot

A Cortex Agent demo for **The Arcticom Group** that answers questions about customer service agreements using 20 synthetic customer SOPs indexed in Cortex Search.

Field technicians, dispatch, and billing staff can ask natural language questions about trip charges, refrigerant allowances, PM scope, and any other contract terms — and get accurate, customer-specific answers grounded in the actual SOP documents.

---

## What It Does

- Parses 20 customer SOP PDFs using `AI_PARSE_DOCUMENT`
- Chunks each document and attaches customer metadata (`customer_name`, `customer_type`, `sop_id`, `aliases`) to every chunk
- Indexes everything in a single Cortex Search service (`ARC_CONTRACT_SEARCH`)
- Exposes a Cortex Agent (`ARC_AGENT`) in Snowflake Intelligence that answers questions by searching the indexed contracts

---

## Customers Covered

| SOP ID | Customer | Type |
|--------|----------|------|
| CST-0001 | Safeway Stores Inc. | Grocery Chain |
| CST-0002 | Pacific Foods Distribution LLC | Food Distribution / Cold Storage |
| CST-0003 | Sprouts Farmers Market - Region 7 | Grocery Chain |
| CST-0004 | Golden State Foods - Livermore DC | Food Distribution / Cold Storage |
| CST-0005 | WS Operations LLC (Wingstop Franchisee) | Restaurant / QSR |
| CST-0006 | Stater Bros. Markets | Grocery Chain |
| CST-0007 | ALDI Inc. - Southwest Division | Grocery Chain |
| CST-0008 | Raley's Family of Stores | Grocery Chain |
| CST-0009 | Trader Joe's Company - Western Service Area | Grocery Chain |
| CST-0010 | Sysco Los Angeles LLC | Food Distribution / Cold Storage |
| CST-0011 | Food 4 Less - TAG Service Division | Grocery Chain |
| CST-0012 | Smart & Final Stores LLC | Grocery Chain |
| CST-0013 | Cold Star Logistics Inc. | 3PL Cold Storage / Logistics |
| CST-0014 | PBI Group LLC (Panera Bread Franchisee) | Restaurant / Bakery-Cafe |
| CST-0015 | Whole Foods Market - NorCal Region | Grocery Chain - Natural/Organic |
| CST-0016 | Casey's General Stores - Pacific Division | Convenience Store / Fuel Retail |
| CST-0017 | Costco Wholesale - Business Center Refrigeration | Warehouse Retail |
| CST-0018 | Nugget Markets Inc. | Grocery Chain - Independent |
| CST-0019 | BJ's Wholesale Club - Western Expansion Sites | Warehouse Retail |
| CST-0020 | Albertsons Companies - Division 13 (SoCal) | Grocery Chain |

---

## Quick Start

> **One deploy path:** Use `sql/TEARDOWN_AND_REBUILD.sql`. This is the only supported
> automated path. Script `02_create_cortex_search.sql` contains a `COPY FILES FROM @ARC_DEPLOY.GIT...`
> reference that only resolves while the rebuild is in progress — running that script
> standalone (e.g. from a Workspace) will fail. If you need to run scripts individually,
> upload PDFs manually via PUT first (see the commented PUT block at the top of `sql/02_create_cortex_search.sql`).

### Step 1: Create a Git API Integration

Open a blank SQL file in Snowsight and run as `ACCOUNTADMIN`:

```sql
USE ROLE ACCOUNTADMIN;

CREATE API INTEGRATION IF NOT EXISTS GIT_HUB_INTEGRATION
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/')
  ENABLED = TRUE;
```

> Skip this step if `GIT_HUB_INTEGRATION` already exists in your account.

### Step 2: Deploy

Open a new SQL worksheet in Snowsight, paste the contents of `sql/TEARDOWN_AND_REBUILD.sql`,
and run it as `ACCOUNTADMIN`. The script will:

1. Create a temporary Git repository object pointing to this repo
2. Tear down any existing ARC objects (safe on first run)
3. Run scripts 01 → 04 via `EXECUTE IMMEDIATE FROM` — including PDF copy, parse, chunk, and index
4. Clean up the temporary deploy objects

Once complete, open **Snowflake Intelligence** and find the **ARC Assistant** agent card.

---

## Sample Demo Questions

### Trip Charges
- "Can I charge Safeway a trip fee?"
- "Does Raley's get charged for emergency calls?"
- "What is the after-hours trip charge for Stater Bros.?"
- "Which customers have all dispatches covered with no trip charge?"

### Refrigerant Policy
- "What refrigerant top-off is included for Whole Foods NorCal?"
- "Can I top off R-404A on an ALDI unit?"
- "How much R-448A is included per visit for Albertsons Division 13?"
- "Which customers prohibit R-404A top-off entirely?"

### PM Scope
- "How often does Safeway get PM visits?"
- "Is coil cleaning included for Costco Business Centers?"
- "Are door gaskets covered under the Trader Joe's contract?"
- "What defrost heater work is included vs. billable for Smart & Final?"

### Special Requirements & Dispatch
- "Which customers require special dispatch approval before I can be sent out?"
- "What are the access requirements for Sysco LA?"
- "Does ALDI require anything special before I dispatch a tech?"
- "What is the emergency response SLA for Cold Star Logistics?"

### Cross-Customer Comparisons
- "Which grocery chain customers include door gaskets in the contract?"
- "Which accounts have unlimited emergency call waivers?"
- "Compare the PM frequency for Safeway vs. Sprouts vs. ALDI."
- "Which restaurant customers are in the contract?"
