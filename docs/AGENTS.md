**1\. Core Philosophy (MVP-Driven Development)**
================================================

1.  Implement the **Minimum Viable Product** for every request.
    
2.  Build exactly what is asked – **no speculative abstractions**.
    
3.  After implementing the MVP, you may list small, concrete follow-up improvements (not implemented unless asked).
    
4.  Prioritise clarity, readability, and maintainability above cleverness.
    
5.  **Never drift into future-phase features or inferred requirements without explicit instruction.**
    

**2\. File Size, Line Count & Refactor Rules**
==============================================

1.  Avoid large files:
    
    *   **Soft target:** 600–800 LOC
        
    *   **Hard limit:** 1500 LOC
        
2.  **\>2000 LOC = mandatory refactor signal.**
    
3.  When splitting:
    
    *   Split by **responsibility**, not arbitrary line count.
        
    *   Never create meaningless names (utils2.ex, helpers\_old.ex, etc.).
        
4.  Refactor Plan:- New file: lib/.../ticketing/validation.ex → ticket validation- New file: lib/.../ticketing/sync.ex → scan sync logic- New file: lib/.../components/seating\_map.ex → UI
    
5.  Implement only minimal changes required to match the plan.
    

**3\. Prompt Handling & Scope Control**
=======================================

1.  Handle **ONE** task at a time.
    
2.  If the user mixes several tasks → propose a TOON breakdown.
    
3.  Do not expand scope unless explicitly instructed.
    
4.  If a change implies:
    
    *   architectural shift
        
    *   major refactor
        
    *   new dependency
        
    *   breaking change
        
    *   data migration→ **pause and warn before proceeding.**
        

**4\. No Hallucinations**
=========================

1.  Never reference files, modules, or APIs unless:
    
    *   They **already exist**, or
        
    *   You are **explicitly creating them**.
        
2.  If uncertain, add an **Assumptions** section.
    
3.  Ask clarifying questions **only when required for correctness**.
    
4.  Avoid “inventing” patterns or modules that contradict existing architecture.
    

**5\. Code Style Expectations**
===============================

1.  Use clear, descriptive naming.
    
2.  Inline comments explain **intent**, not restate code.
    
3.  Follow project norms:
    
    *   Elixir: idiomatic Phoenix + Ash patterns.
        
    *   LiveView: minimal handle\_event logic; no domain logic.
        
    *   Svelte: simple, reactive, modular.
        
4.  Add comment blocks to describe:
    
    *   What the function does
        
    *   Why it’s structured this way
        
    *   Constraints or caveats
        
5.  Prefer composable functions over deeply nested logic.
    

**6\. Architecture Rules (Strengthened)**
=========================================

### **6.1 Ash Is the Domain Engine (Mandatory Rules)**

**Never bypass Ash.**This is critical:

*   ❌ No direct Repo.insert/update/delete
    
*   ❌ No raw SQL inside controllers/LiveViews
    
*   ❌ No domain logic inside Phoenix
    

**Always use Ash actions** for:

*   state transitions
    
*   validation
    
*   calculations
    
*   reservations
    
*   check-in validation
    
*   availability checks
    
*   ticket issuance
    
*   payment lifecycle
    
*   seat management
    

All invariants MUST live in:

*   validations (errors)
    
*   changes (transitions)
    
*   calculations (derived data)
    

### **6.2 Phoenix Is Only I/O Layer**

Controllers and LiveViews must be thin:

*   Parse/validate inputs
    
*   Call Ash actions
    
*   Render results
    
*   No business decisions
    
*   No calculations
    
*   No access-control logic (use Ash policies)
    

### **6.3 Caching Layer Rules**

*   Caches must **never** be the source of truth.
    
*   Invalidate via Ash notifications only.
    
*   Do not introduce caching without instruction.
    

**7\. Errors, Edge Cases, & Safety (Strengthened)**
===================================================

1.  Never introduce silent failures.
    
2.  All user input validated via Ash validations.
    
3.  Payment flows must be:
    
    *   idempotent
        
    *   safe on replays
        
    *   safe on webhook retries
        
4.  Scanner operations must be:
    
    *   idempotent
        
    *   deterministic
        
    *   concurrency-safe
        
5.  Seat reservations must be:
    
    *   atomic
        
    *   validated on server
        
    *   never trusted from client input
        

### **Critical Safety Constraints**

*   **Seat locking** must prevent double-sells (Ash concurrency rules).
    
*   **Ticket validation** must use a **single authoritative Ash action**.
    
*   **Offline sync** must apply scans **strictly in timestamp order**.
    
*   **Scanner responses must never leak tenant or internal IDs**.
    

**8\. Tests**
=============

1.  Add/update tests for any non-trivial logic.
    
2.  Do not break existing tests unless:
    
    *   behaviour must change AND
        
    *   you explain why
        
3.  Test all critical flows:
    
    *   payments
        
    *   seat locking / concurrency
        
    *   scanner validation
        
    *   offline sync
        
    *   ticket issuance
        
4.  Tests must be isolated and domain-focused.
    

**9\. Documentation Expectations**
==================================

1.  Add docstrings for major functions.
    
2.  Add module docs for new modules.
    
3.  Update /docs/domain/\*.md or /docs/api/\*.md when changing:
    
    *   domain schemas
        
    *   workflows
        
    *   scanner API
        
4.  Summaries in responses:
    
    *   What changed
        
    *   Why
        
    *   How to test locally
        

**10\. Frontend & UX Standards**
================================

### **LiveView + Tailwind**

*   Use clean layout primitives: grid, flex, gap, auto-fit, etc.
    
*   UIs must be responsive.
    
*   Avoid complex JS unless required.
    
*   Use LiveComponents for reusable UI.
    

### **Svelte Rules**

*   Keep components small and reactive.
    
*   Never duplicate domain logic.
    
*   API responses must fully drive UI state.
    

**11\. Token & Context Efficiency**
===================================

1.  Never rewrite full files unless necessary.
    
2.  Prefer minimal diffs.
    
3.  Search the repo before creating new modules.
    
4.  Do not regenerate boilerplate unless asked.
    

**12\. Project-Specific Rules (Strengthened)**
==============================================

### **12.1 Tenancy**

*   All domain resources must be tenant-scoped.
    
*   Phoenix must always load current\_tenant.
    
*   Never perform unscoped queries.
    

### **12.2 Seat & Seating Plan Safety**

*   Never delete seats after sales exist (only soft-disable).
    
*   Never reorder seats/rows without user request.
    
*   Prevent seat conflicts via Ash concurrency.
    
*   Draft/Published/Locked states must be respected.
    

### **12.3 Scanner API**

*   Mandatory device authentication.
    
*   No insecure shortcuts.
    
*   Online and offline validation must use **the same Ash action**.
    
*   Offline sync applies scans **deterministically**.
    

### **12.4 Payments**

*   Payment state machine must be Ash-driven.
    
*   Webhook events must be idempotent.
    
*   Never trust external provider state blindly.
    

**13\. Database & Migration Rules**
===================================

(**Highly important and previously missing**)

1.  **Never modify or reorder existing migrations.**
    
2.  New schema changes must use new migrations only.
    
3.  Backfills must be:
    
    *   safe
        
    *   reversible (or well documented)
        
4.  Never introduce destructive changes without explicit confirmation.
    

**14\. Version Control & File Mutation Rules**
==============================================

1.  Never delete existing code unless certain it is unused.
    
2.  Never remove TODO / FIXMEs unless addressed.
    
3.  Avoid renaming modules without explicit instruction.
    
4.  Maintain internal naming consistency across domains and modules.
    

**15\. Multi-Agent Collaboration Protocol**
===========================================

1.  Always search project before creating new files.
    
2.  If modifying a recently-touched file → state assumptions clearly.
    
3.  Never change public interfaces without documenting.
    
4.  Always respect existing patterns before introducing new ones.
    

**16\. TOON Micro-Prompt Compliance**
=====================================

When implementing a TOON micro-prompt:

*   Implement **exactly** the Task.
    
*   Ensure code fulfills the Objective.
    
*   Produce exactly the Output requested.
    
*   Respect all Notes (especially domain, Ash, and tenancy rules).
    

If a TOON conflicts with AGENTS.md:→ **Flag the conflict and propose a safe compromise.**