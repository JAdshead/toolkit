# Reading CI

**Read CI only at the step that needs its result, and never poll it.**

Read it once, for the commit that step is about (`sha`):

```bash
gh pr checks <pr>
gh pr view <pr> --json headRefOid -q .headRefOid
```

If `headRefOid` is not `sha`, the checks are for a newer commit: the step's own head-moved rule applies. Otherwise:

- **Green:** every check passed, was skipped or is neutral, or there are none ("no checks reported"). Go on.
- **Red:** a check failed or was cancelled. The step says what red means for it.
- **Pending:** a check is still running. Go on when the step says go on while CI runs; hold only the step that needs CI's result. To hold it, run `gh pr checks <pr> --watch --interval 60` once, in the background if your agent can, and read again when it exits: a single call, not a loop, never repeated reads, sleeps or scheduled wake-ups. Do this even when the host watches CI (it has told you so, for example the Claude desktop app with Auto-fix on): the host reports failures and conflicts, never success, so waiting for it to say CI passed waits forever. The host does handle CI failures; leave them to it.
