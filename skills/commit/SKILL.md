---
name: commit
description: Prepares a commit of the staged changes with a message that follows the repository's convention, after scanning for secrets. Use only when the user asks to commit (/commit).
argument-hint: "[optional hint for the message]"
allowed-tools: Bash(git status *) Bash(git diff *) Bash(git log *) Bash(gitleaks *)
disable-model-invocation: true
---

# /commit

User hint for the message (may be empty): $ARGUMENTS

1. Run `git status --short` and `git diff --staged --stat`.
   - If nothing is staged, show the unstaged changes and **ask** what to
     include. Never run `git add -A` on your own.
2. Run `gitleaks git --staged --redact --no-banner`. If it finds anything,
   **stop** and show the finding; do not commit.
3. Read the staged diff (`git diff --staged`) and the repository's message
   convention (`git log -15 --oneline`).
   - If the history uses Conventional Commits (`feat:`, `fix:`…), follow it.
   - With no clear convention: Conventional Commits in English.
   - Subject up to 72 characters, imperative mood; a short body explaining
     the why when it is not obvious.
4. Show the proposed message and the files included, and **ask for
   confirmation**.
5. Only after a "yes": `git commit -m ...` (lefthook hooks run normally; if
   they fail, show the error and fix it or ask).
6. **Never** run `git push`, `--amend` or `--no-verify` unless explicitly asked.
