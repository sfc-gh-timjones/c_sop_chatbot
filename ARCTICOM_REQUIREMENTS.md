# Arcticom PDF Chatbot — Requirements

Source: Gong call transcript "2026_06_10_Snowflake & Arcticom"  
Attendees: Tim Jones (SE), Chelsea Sears (AE), Geoff Brougham (VP IT), Omar Rahman (VP Rev Ops)

---

## The Problem

Arcticom has MSAs (Master Service Agreements) and office SOPs for ~40 customers. Each agreement has different terms — what services can be charged, what's covered under the contract, etc. Currently it's a manual pain to look up what's covered for any given customer.

**Omar's exact words:**
> "You do that with unstructured data as well? Yes, all of it. Okay. So that's the exact test that I wanted to do because I wanted to take all of our MSAs with our customers. Each one is different, right? Like in terms of terms, if we can charge this or that, what's covered under the contract, we've got all these customers that we have agreements with. And right now, it's a bit of a pain to figure out what's covered and what's not. I was like, oh, I wonder if I can make an agent that would be able to just go through that data and be like, 'Safeway — you can charge for this trip, and here's what's covered: coils are covered, cleanings are covered.' That's all in contracts in PDFs and Word documents right now. So that's something I wanted to do."

---

## What They Want to Build

A PDF chatbot / Snowflake agent that:
- Ingests their customer SOPs and/or MSAs
- Allows natural language queries like: *"For Safeway, what services can we charge for?"*
- Returns answers grounded in the actual contract language

---

## Data Details

| Detail | Info |
|--------|------|
| Document types | MSAs (large, several pages) + Office SOPs (distilled, 5 pages or less) |
| Starting point | Office SOPs first — preferred over full MSAs |
| # of customers | ~40 |
| Format | PDFs and Word documents |
| Content | Primarily text-based (no mention of heavy images or charts) |
| Sensitivity | Proprietary / internal — must stay within Snowflake security boundary |

---

## Tim's Proposed Approach (from call)

- Create a git repo seeded with sample/public-facing PDFs as a template
- Arcticom replaces sample PDFs with their actual SOPs
- Run it → agent is live — target: **up and running in ~1 hour** during a working session
- Stack: **CoCo (Cortex Code) desktop** + Snowflake (Cortex Search + Cortex Agent)
- Everything stays within Snowflake's security/governance boundary

---

## Agreed Next Steps (from call)

1. Omar connects CoCo desktop to their Snowflake account (was having login issues — needs follow-up)
2. Schedule a **1-hour workshop** with Omar + Tim to build it live
3. Omar to share an example SOP so Tim can understand the document structure (text density, length, format)
4. Tim to send documentation/guidance in the meantime

---

## Notes / Context

- Arcticom has a Claude Enterprise agreement — same Anthropic models are available natively in Snowflake
- They're also using Claude Cowork heavily; Geoff wants a framework document explaining when to use Snowflake agent vs. Claude+MCP pointing at Snowflake
- Seven Rivers is their SI partner and built the existing Arcticom agent; they have a semantic view in progress
- This PDF chatbot use case is separate from and simpler than the broader semantic/analytics work
