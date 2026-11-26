# Reading CI

**Read CI only at the step that needs its result, and never poll it when the host watches it.**

Read it once, for the commit that step is about (`sha`):

```bash
gh pr checks <pr>
gh pr view <pr> --json headRefOid -q .headRefOid
```

If `headRefOid` is not `sha`, the checks are for a newer commit: the step's own head-moved rule applies. Otherwise:

- **Green:** every check passed, was skipped or is neutral, or there are none ("no checks reported"). Go on.
- **Red:** a check failed or was cancelled. The step says what red means for it.
- **Pending:** a check is still running.
  - **The host watches CI** (it has told you so, for example the Claude desktop app with Auto-fix on): never use `--watch` or poll. Say the step is held until CI finishes, end your turn, and resume when the host reports CI done. The host also handles CI failures; leave them to it.
  - **Otherwise:** run `gh pr checks <pr> --watch` once, then read again.
