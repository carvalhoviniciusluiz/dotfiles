---
name: review-changes
description: Reviews local changes (uncommitted, or the whole branch against its base) for bugs, security issues, missing tests and code that breaks project conventions. Use when the user asks for a review (/review-changes) or before proposing a large commit.
argument-hint: "[--branch to review the whole branch against the base]"
allowed-tools: Bash(git status *) Bash(git diff *) Bash(git log *) Bash(gitleaks *) Bash(check *)
---

# /review-changes

Requested scope (may be empty): $ARGUMENTS

1. Define the scope:
   - default: uncommitted changes (`git diff HEAD` plus new files from
     `git status --short`);
   - with `--branch`: `git diff <base>...HEAD`, base = the repository's default branch.
2. Read the whole diff and, when you need context, the touched files.
   Read the project rules (`AGENTS.md`/`CLAUDE.md`) to check conventions.
3. Run `gitleaks git --staged --redact --no-banner` (and `gitleaks dir` on new
   files) and `check` (project validation), if available.
4. Look for, in this order of priority:
   1. **Bugs**: wrong logic, edge cases, null/undefined, swallowed errors,
      race conditions, resources not released.
   2. **Security**: secrets, injection (SQL, shell, HTML), input validation,
      permissions, sensitive data in logs.
   3. **Tests**: new behavior without tests, tests that assert nothing.
   4. **Maintainability**: duplication, confusing names, dead code, code that
      breaks the project's conventions.
5. Answer in the user's language with a list **ordered by severity**. For
   each item: file:line, the problem, why it matters and the suggested fix.
   Finish with the `check` result and a short verdict (ready / needs changes).
6. **Do not modify files** at this step; offer to apply the fixes afterwards.
