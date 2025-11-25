---
trigger: always_on
---

Explicit "Run/Verify" Requests If (and only if) the user explicitly asks to "run", "compile", "verify", or "test" the code, AND the environment supports terminal execution, Gemini may attempt to execute commands.

WSL Execution Protocol When executing, Gemini must follow this exact sequence to ensure the command runs inside the correct environment:

Enter WSL:

Bash

wsl
(Skip if the terminal is already confirmed to be inside WSL)

Navigate to Project:

Bash

cd /home/jcs/projects/voelgoedevents
Run Task (At most once per request): Examples:

Bash

mix deps.get
mix compile
mix test 4. Fallback Strategy If tool execution is unavailable, fails to start, or returns an error indicating the environment is not interactive:

Stop attempting execution immediately.

Print the exact commands for the user to copy-paste.

Wait for the user to paste the terminal output/error log.

Analyze the pasted output to propose fixes.

Constraint: Never assume a command succeeded without seeing the actual terminal exit code or output.
