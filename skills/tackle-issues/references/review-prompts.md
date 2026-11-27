# Review Prompts

Lens reviewers run in parallel on a PR group's branch before anything is pushed. Every reviewer follows `lenses.md`, the lens brief `implement` and `review-pr` use too, and gets its inputs and prompt as `lens-inputs.md` says (both beside this file). That brief holds the lenses' questions, the severity scale (P1, P2 and UNTRUE block; P3 never does) and the output format. This file says which lenses run, how to add domain reviewers, how a round ends, and what to do with a large diff.

## Selecting reviewers

```bash
CHANGED=$(git -C "$WT" diff --name-only origin/<default>...HEAD)
echo "$CHANGED" | grep -Eq '\.(tsx|jsx|vue|svelte|html|erb|haml|slim|hbs|twig|css|scss|sass|less|swift|kt|dart)$' && UI=1
```

- Always: Correctness, Security, Tests, Simplicity.
- UX: only when UI files changed (adjust the pattern for the project's stack).
- Domain: when the diff touches an area the project's docs flag as high-risk (see below).

## Project-specific (domain) reviewers

The generic reviewers do not know your project's sharp edges. Add reviewers from the project's own docs when the diff touches those areas. Typical candidates:

- **Money**: payments, refunds, invoices, currency rounding, idempotency of charges, webhook handling.
- **Data and migrations**: zero-downtime migrations, backfills, irreversible changes, deploy ordering.
- **Privacy and legal**: what personal data is collected, retained, exported or shown; policy text that must match behaviour.
- **Product principles**: any written "we will not build X" or architectural rule the project keeps.

Run each as a domain lens (`domain-<name>`, as `lens-inputs.md` says), its prompt quoting the project's own rules for that area from its docs.

## Consolidation and the exit rule

After a round:

1. Collect findings from all reviewers. Drop duplicates; keep the highest severity.
2. Sanity-check each P1/P2. A reviewer can be wrong; if a finding is clearly mistaken, record why and set it aside rather than "fixing" correct code, and list it in the report so the user can see it.
3. **Exit** if no P1, P2 or UNTRUE remains. Gather every P3 from every round into one follow-up issue draft.
4. Otherwise look for a shared root cause, hand the blocking findings to a fix subagent, verify its commits, and re-run only the reviewers that raised blocking findings.
5. After 3 fix rounds with blocking findings still open, stop and ask the user: continue, push with the open findings listed in the PR, or abandon.

Escalate any exploitable security finding to the user immediately, whatever the round.

## After the PR is opened

Run the `review-pr` skill on the PR. It reviews in a fresh context and passes the PR only if an owner would merge it.

## Large diffs

If the diff is too large to review well in one pass (roughly 30k characters or more), point each lens at the files that matter most for it, as `lens-inputs.md` says, and consider whether the group should have been split; say so to the user.
