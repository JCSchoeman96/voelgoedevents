**VoelgoedEvents – Gemini Agent Execution RulesThis file extends (but does not replace) AGENTS.md.**

1\. Purpose of This Document
----------------------------

This document instructs **Google Gemini** (all models, including: Gemini 1.5 Pro, Ultra, Flash, and any future variants) how to behave when acting as a coding, planning, documentation, or architectural agent for the **VoelgoedEvents** platform.

> **Important:**AGENTS.md is the _canonical_ ruleset.GEMINI.md contains _Gemini-specific_ requirements and workflow instructions.

Gemini must always load and respect:

*   AGENTS.md
    
*   INDEX.md
    
*   Architecture documents
    
*   Domain documents
    
*   Workflow documents
    
*   Project overview documents
    

before generating any code or plans.

2\. Mandatory Loading Sequence (Gemini Must Follow This)
--------------------------------------------------------

Before ANY code, planning, TOON generation, or architectural reasoning:

### **1\. Load the canonical rules**

/docs/AGENTS.md

### **2\. Load the top-level index**

/docs/INDEX.md

### **3\. Load architecture constraints**

Required each session:

Plaintext

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   /docs/architecture/01_foundation.md  /docs/architecture/02_multi_tenancy.md  /docs/architecture/03_caching_and_realtime.md  /docs/architecture/04_vertical_slices.md   `

Load others on demand:

Plaintext

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   05_eventing_model.md  06_jobs_and_async.md  07_security_and_auth.md  08_cicd_and_deployment.md  09_scaling_and_resilience.md   `

### **4\. Load domain definitions**

Plaintext

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   /docs/DOMAIN_MAP.md  /docs/domain/*.md   `

### **5\. Load workflow docs relevant to the task**

/docs/workflows/\*.md

Gemini **must not** generate code without loading these.

3\. Gemini Behavioral Requirements
----------------------------------

### 3.1 **Always use the TOON format**

Every coding or planning action must be structured into:

*   **Task**
    
*   **Objective**
    
*   **Output**
    
*   **Note**
    

(As defined in AGENTS.md.)

### 3.2 **Vertical Slice First**

Gemini must:

*   Never design horizontal layers.
    
*   Always organize code by feature slice.
    
*   Keep UI → domain orchestration → domain → persistence in one slice.
    
*   Avoid shared service modules unless architecture explicitly permits.
    

### 3.3 **Domain-Pure Logic**

Gemini must:

*   Put _all business logic_ into **Ash Resources**, **Ash Domains**, or **Ash Actions**.
    
*   NEVER put domain logic in Phoenix Controllers, LiveViews, or components.
    
*   Treat controllers and LiveViews as thin input/output adapters.
    

### 3.4 **Multi-Tenancy Safety**

Gemini must ALWAYS:

*   Pass organization\_id explicitly.
    
*   Avoid cross-tenant reads/writes.
    
*   Use tenant-scoped Redis/ETS keys (org:{org\_id}:entity:{id}).
    

### 3.5 **Caching & Performance**

Gemini must follow the caching hierarchy:

*   **Hot:** ETS/GenServer
    
*   **Warm:** Redis
    
*   **Cold:** Postgres
    

And enforce:

*   No DB reads on hot paths
    
*   Redis bitmaps for seat availability
    
*   Redis ZSETs for seat holds
    
*   Tenant-scoped keys
    
*   PubSub for real-time events
    
*   Oban for async jobs
    

### 3.6 **Real-Time Updates**

Gemini must use:

*   Phoenix PubSub
    
*   LiveView diff updates
    
*   Domain events → slice-level handlers
    

Polling is **not allowed**.

### 3.7 **Ash-Centric Development**

Gemini must:

*   Use Ash DSL syntax correctly
    
*   Prefer actions (read, create, update, destroy)
    
*   Use policies for authorization
    
*   Use calculations, aggregates, code interfaces
  
### 3.8 – Execution Boundaries
Gemini's role in this project is code generation, refactoring, interpretation, and following TOON prompts.
Gemini must never attempt to execute or simulate command-line operations.
All build steps, compiles, database tasks, or runtime execution will be performed manually by the user in the WSL Ubuntu terminal.

#### Gemini MUST DO: ####
    - Read and understand repo files
    - Follow TOON prompts exactly
    - Create, update, or delete code files
    - Generate migrations, modules, schemas, resources
    - Produce shell commands for the user to run manually (never execute)
    - Fix errors based on compiler output that the user pastes in
    - Explain why changes are needed
    - Keep code self-contained and aligned with the architecture
    - Maintain vertical slices and Ash patterns
    - Follow multi-tenancy, caching, and performance rules

#### Gemini MUST NOT: ####
    Execute or attempt to execute:
        - mix
        - npm
        - yarn
        - pnpm
        - docker
        - bash
        - git
        - any command in any shell
    - Attempt to run or start Phoenix servers
    - Attempt to compile or test code
    - Attempt to run database migrations
    - Attempt to check OTP/Elixir versions
    - Simulate command-line output
    - Make assumptions about runtime behavior without user-provided logs

#### Runtime Model for Gemini ####

Assume:
- The project is executed in WSL Ubuntu, not Windows
- The user manually runs all commands in the WSL terminal
- Gemini reacts only to:
    - File content
    - TOON prompts
    - Documentation
    - User-provided error messages
- Gemini never initiates compile or runtime steps

#### IF a TOON prompt requires verification or compilation ####

Gemini must:
Provide the exact commands the user should run
Wait for the user to paste the errors
Fix only the files related to the errors

Example pattern:

Commands for the user to run (do NOT execute):
    mix deps.get
    mix compile
    mix ecto.migrate

Gemini must not pretend to run them.


4\. Code Generation Rules (Specific for Gemini)
-----------------------------------------------

### 4.1 Keep modules small and slice-focused

Never create “god modules”.

### 4.2 File paths must always be correct

Paths MUST match project conventions defined in:

Plaintext

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   /docs/project_overview.md  /docs/architecture/04_vertical_slices.md   `

### 4.3 No placeholders or incomplete modules

Every code block must be complete unless the user explicitly requests partials.

### 4.4 No assumptions outside documentation

If something is missing, Gemini must ask clarifying questions.

### 4.5 Use realistic naming

All module names must:

*   Use VoelgoedEvents project namespace
    
*   Match existing domain/slice names
    
*   Follow Phoenix & Ash conventions
    

### 4.6 Obey performance constraints

All hot paths must implement:

*   ETS checks
    
*   Redis reads
    
*   Optimistic locking
    
*   No DB fan-outs
    
*   PubSub broadcasts
    

5\. Gemini-Specific Constraints
-------------------------------

Due to Gemini’s tendency to:

*   hallucinate file paths
    
*   over-explain
    
*   omit key architectural constraints
    
*   merge horizontal layers
    
*   add business logic to controllers
    

**Gemini must consciously check every output** against:

1.  Multi-tenancy rules
    
2.  Caching rules
    
3.  Vertical slice rules
    
4.  Domain purity
    
5.  TOON structure
    
6.  File path correctness
    

Before finalizing the answer.

6\. When Gemini Should Ask Questions
------------------------------------

Gemini must request clarification when:

*   A domain action is not defined in docs
    
*   A workflow is incomplete
    
*   A schema or resource is undefined
    
*   A caching rule is unclear
    
*   A performance constraint might be violated
    
*   A slice name is ambiguous
    
*   A data contract is not documented
    

Failure to ask is a violation of GEMINI.md.

7\. Forbidden Actions
---------------------

Gemini must **never**:

*   Invent new architecture not defined in docs
    
*   Move business logic into controllers, LiveViews, or components
    
*   Create horizontal service layers
    
*   Ignore tenant boundaries
    
*   Ignore performance-sensitive constraints
    
*   Modify architecture docs unless explicitly asked
    
*   Produce incomplete TOON prompts
    
*   Generate speculative API endpoints
    
*   Introduce lifecycle or logic outside Ash domains
    

8\. How Gemini Should Reference Documentation
---------------------------------------------

Gemini must:

*   Use **relative paths** only
    
*   Reference exact file names
    
*   Never invent file paths
    

**Examples:**

✔ **Correct:**

> As defined in /docs/architecture/02\_multi\_tenancy.md

❌ **Incorrect:**

> “In the multi tenancy doc”“In the tenancy section”Referencing paths that do not exist

9\. Final Rule: AGENTS.md Supersedes Everything
-----------------------------------------------

If any rule in GEMINI.md conflicts with AGENTS.md:

> **AGENTS.md always wins.**

This file simply adapts the canonical rules for optimal Gemini behavior.

10\. Summary for Gemini
-----------------------

1.  Load AGENTS.md
    
2.  Load INDEX.md
    
3.  Load core architecture docs
    
4.  Load domain + workflow docs relevant to the task
    
5.  Produce TOON prompts with full detail
    
6.  Follow vertical-slice rules
    
7.  Keep logic inside Ash domains
    
8.  Apply performance + multi-tenancy + caching rules
    
9.  Ask clarifying questions when needed
    
10.  Never violate architecture constraints
    

By following the above, Gemini will produce reliable, correct code aligned with the VoelgoedEvents platform’s long-term architecture.