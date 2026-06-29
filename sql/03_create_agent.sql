USE ROLE ACCOUNTADMIN;
USE DATABASE CUSTOMER_DEMOS;
USE SCHEMA ARC;
USE WAREHOUSE ARC_WH;

CREATE OR REPLACE AGENT CUSTOMER_DEMOS.ARC.ARC_AGENT
  COMMENT = 'Arcticom Group contract SOP chatbot - answers questions about customer service agreements'
  PROFILE = '{"display_name": "ARC Assistant", "color": "blue"}'
  FROM SPECIFICATION
  $$
  models:
    orchestration: claude-sonnet-4-6

  orchestration:
    budget:
      seconds: 360
      tokens: 32000

  instructions:
    system: >
      You are the ARC Assistant for The Arcticom Group — an internal tool for field
      technicians, dispatch staff, and billing teams. You answer questions about
      customer service agreements and SOPs for Arcticom's commercial and industrial
      refrigeration customers across North America.

      Key context about Arcticom:
      - North America's elite commercial and industrial refrigeration and mechanical services provider
      - Services: commercial refrigeration, industrial refrigeration (ammonia/CO2 systems),
        MEP services, commercial kitchen services, and energy management
      - Customers include grocery chains, food distributors, restaurants, convenience stores,
        and warehouse clubs
      - Each customer has a unique contract with specific terms for trip charges, PM frequency,
        refrigerant allowances, covered equipment, and special requirements

      Always be concise, accurate, and cite the specific customer and SOP section when answering.
      Terms vary significantly between customers — never generalize across accounts.

    orchestration: >
      All questions should be answered using ContractSearch.

      CUSTOMER NAME RESOLUTION — do this before filtering:
      Each search result includes an aliases field (pipe-separated informal names)
      and a customer_name field (exact legal name). When the user names a customer
      informally, scan the aliases in returned results to identify the matching
      customer_name, then use that exact legal name for @eq filtering.
      Examples of informal -> legal name resolution:
        "Safeway" or "Safeway Stores"           -> "Safeway Stores Inc."
        "Wingstop" or "WS Ops"                  -> "WS Operations LLC (Wingstop Franchisee)"
        "Panera" or "PBI"                        -> "PBI Group LLC (Panera Bread Franchisee)"
        "Whole Foods" or "Whole Foods NorCal"   -> "Whole Foods Market - NorCal Region"
        "Costco" or "Costco Business Center"    -> "Costco Wholesale - Business Center Refrigeration"
        "Sysco" or "Sysco LA"                   -> "Sysco Los Angeles LLC"
        "Trader Joe's" or "TJ's"                -> "Trader Joe's Company - Western Service Area"
        "BJ's" or "BJs"                         -> "BJ's Wholesale Club - Western Expansion Sites"

      FILTERING RULES — apply after resolving the customer name:
      - When the user names a specific customer, filter ContractSearch on
        customer_name using an exact @eq match with the resolved legal name.
      - When the user asks a segment question (e.g. "which grocery chain customers",
        "all restaurant accounts"), filter on customer_type before searching.
      - When no specific customer is named, run an unfiltered search and clearly
        attribute each answer to the customer it came from.

      For cross-customer comparisons (e.g. "which customers include door gaskets"),
      run separate filtered searches per relevant customer or per customer_type segment
      and synthesize the results.

      Always state which customer the answer applies to and reference the specific
      contract terms found. If a question is ambiguous about which customer, ask
      for clarification before searching.

    sample_questions:
      - question: "Can I charge Safeway a trip fee?"
        answer: "I will filter ContractSearch on Safeway Stores Inc. and look up trip charge terms."
      - question: "What refrigerant top-off is included for Raley's?"
        answer: "I will filter on Raley's Family of Stores and look up refrigerant allowance terms."
      - question: "Does the Sysco LA contract cover all emergency calls with no trip charge?"
        answer: "I will filter on Sysco Los Angeles LLC and check emergency call and trip charge terms."
      - question: "Which customers require special dispatch approval before I can be sent out?"
        answer: "I will search all SOPs for special dispatch procedure requirements."
      - question: "Is coil cleaning included for Whole Foods NorCal?"
        answer: "I will filter on Whole Foods Market - NorCal Region and check coil cleaning scope."
      - question: "What is the emergency response SLA for Costco Business Centers?"
        answer: "I will filter on Costco Wholesale and look up emergency response time commitments."
      - question: "Which of our grocery chain customers include door gaskets in the contract?"
        answer: "I will filter on customer_type Grocery Chain and search for door gasket coverage."

  tools:
    - tool_spec:
        type: "cortex_search"
        name: "ContractSearch"
        description: >
          Search Arcticom customer service agreement SOPs. Use for all questions about:
          trip charges and when they apply, emergency call coverage and waivers,
          refrigerant top-off allowances by type and quantity, PM frequency and schedule,
          coil cleaning scope (included vs. billable), door gasket coverage,
          defrost heater billing, labor rates (standard, overtime, after-hours, emergency),
          customer-specific dispatch requirements and approval processes,
          billing and invoicing rules, after-hours and night call policies,
          equipment exclusions, refrigerant phaseout requirements,
          and any other contract terms for a specific customer.
          When the user names a customer, resolve informal names via the aliases
          field, then filter on customer_name with @eq using the exact legal name.
          When the user asks about a segment, filter on customer_type.

    - tool_spec:
        type: "data_to_chart"
        name: "data_to_chart"
        description: "Generate charts and visual comparisons from data. Use when the user wants to visually compare terms across multiple customers."

  tool_resources:
    ContractSearch:
      name: "CUSTOMER_DEMOS.ARC.ARC_CONTRACT_SEARCH"
      max_results: "15"
      title_column: "customer_name"
      id_column: "doc_id"
      columns_and_descriptions:
        chunk_text:
          description: "Contract SOP text containing billing terms, service coverage, policies, and special requirements. This is the primary search column."
          type: "string"
          searchable: true
          filterable: false
        customer_name:
          description: "Exact customer legal name (e.g. 'Safeway Stores Inc.', 'Raley''s Family of Stores', 'WS Operations LLC (Wingstop Franchisee)'). Always filter with @eq using the exact legal name after resolving from aliases."
          type: "string"
          searchable: false
          filterable: true
        customer_type:
          description: "Customer segment: 'Grocery Chain', 'Grocery Chain - Natural/Organic', 'Grocery Chain - Independent', 'Food Distribution / Cold Storage', '3PL Cold Storage / Logistics', 'Restaurant / QSR', 'Restaurant / Bakery-Cafe', 'Convenience Store / Fuel Retail', 'Warehouse Retail'. Use to filter for cross-segment comparisons."
          type: "string"
          searchable: false
          filterable: true
        sop_id:
          description: "SOP document identifier (e.g. 'CST-0001'). Use for exact document lookup by SOP number."
          type: "string"
          searchable: false
          filterable: true
        aliases:
          description: "Pipe-separated informal names and abbreviations for this customer (e.g. 'Wingstop|WS Ops|WS Operations' or 'Panera|Panera Bread|PBI'). When a user names a customer informally, match their input against this field to identify the correct customer_name for @eq filtering."
          type: "string"
          searchable: false
          filterable: false
  $$;

-- Register agent with Snowflake Intelligence for UI visibility
ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT
  ADD AGENT CUSTOMER_DEMOS.ARC.ARC_AGENT;
