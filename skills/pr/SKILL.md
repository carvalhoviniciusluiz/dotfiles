---
name: pr
description: Opens a GitHub pull request for the current branch with a title and description generated from the commits and the diff. Use only when the user asks (/pr).
argument-hint: "[base branch, default: the repository's default branch]"
allowed-tools: Bash(git status *) Bash(git log *) Bash(git diff *) Bash(git rev-parse *) Bash(gh repo view *) Bash(gh pr list *) Bash(gh pr view *)
disable-model-invocation: true
---

# /pr

Base branch given by the user (may be empty): $ARGUMENTS

1. Find the current branch (`git rev-parse --abbrev-ref HEAD`) and the base
   (the argument above or `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`).
   - If you are on the base itself (e.g. `main`), **stop** and suggest creating a branch.
   - If a PR already exists for the branch (`gh pr list --head <branch>`), show
     its link and ask whether to update the description.
2. Check for uncommitted changes (`git status --short`); if any, warn and ask
   whether they should go in first (via /commit).
3. Gather the content: `git log --oneline <base>..HEAD` and
   `git diff --stat <base>...HEAD` (plus the full diff when it is small).
4. Run `check` (project validation) if it exists and report the result.
5. Write:
   - **Title**: short, following the repository's commit convention.
   - **Description** with: Summary (what and why), Main changes (list),
     How to test, and Risks/follow-ups. Include the `check` result.
     End with the line `🤖 Generated with [Claude Code](https://claude.com/claude-code)`
     when the PR is opened by Claude Code.
6. Show the title and description and **ask for confirmation**. Also ask
   whether the branch may be pushed (`git push -u origin <branch>`) if it is
   not on the remote yet.
7. Only after a "yes": push (if authorized) and
   `gh pr create --base <base> --title ... --body-file <temp file>`.
   Show the PR link. Open it as a draft (`--draft`) if the user asks.
