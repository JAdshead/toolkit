---
name: glossary
description: Build and refine a project's GLOSSARY.md so people and agents use the same words for the same things. Challenges vague, overloaded or conflicting terms as they come up, proposes one canonical term with the rejected synonyms listed, checks claims against the code, and writes each settled term down at once. Also audits an existing glossary, or the code and docs, for ambiguity, drift and bloat. Use when the user is naming or defining concepts, says a word means different things to different people, asks to create, update, tighten or audit a glossary, or when a prompt and the code disagree about what a term means.
license: MIT
metadata:
  tags: glossary terminology ubiquitous-language domain naming
---

# Glossary

One word, one meaning, everywhere: in prompts, in agent output, in issues and in code. The glossary is where that is written down, so an agent reading a prompt resolves each term the way the person writing it meant.

This skill is the active discipline: it interrupts, asks which meaning is meant, and records the answer. Just reading `GLOSSARY.md` to pick up vocabulary is not this skill; any agent should do that.

## Modes

- `glossary`: work alongside the current conversation. Challenge terms as they appear (see **Live**).
- `glossary audit`: look for ambiguity in an existing glossary, or seed one from the code and docs (see **Audit**).
- `glossary <term>`: settle one term now. Ask the **Live** questions about that term until it is settled, or the user parks it under **Open**.

## Where the glossary lives

1. If `GLOSSARY-MAP.md` exists at the repo root, the repo has several contexts, each with its own `GLOSSARY.md`. Use the map to pick one; if the term could belong to more than one, ask.
2. Otherwise use `GLOSSARY.md` at the repo root.
3. If neither exists, never create one unasked. Unless the user invoked this skill or asked for a glossary, ask once when the first entry is needed (a term is settled, or parked under **Open**): `No glossary yet. Start GLOSSARY.md with **Subscription**?` On anything but a yes, use the answer for the task at hand, write nothing, and don't ask again this session. With a yes, create `GLOSSARY.md` then, not before.

Also read issues, ADRs or docs the project points to for terminology, so a naming question already settled there is not raised again.

## Live

While the user talks, prompts or describes work, watch the domain terms the work depends on. Stop and ask (one short question, then carry on) only when the meaning would change what you do, and:

- **It conflicts with the glossary.** "The glossary says a *Booking* is a confirmed reservation, but you're using it for a held slot. Which do you mean?"
- **It is an avoided synonym.** The user says *client* and the glossary lists it under *Avoid* for *Customer*. Point it out once and use the canonical term from then on. Don't nag about the same word twice in a session.
- **It is vague or overloaded.** *account*, *user*, *item*, *job*, *status*, *active*, *sync*. Propose the precise term: "By *account*, do you mean the **Customer** (who pays) or the **Login** (who signs in)?"
- **Two words seem to name one thing**, or **one word names two things.** Ask which; propose one name per concept.
- **The code says otherwise.** When the user states how something works, check the code. "You said a cancelled Order can be partially refunded, but `refund()` only takes whole Orders. Which is right?" Never silently trust either side.

Use concrete scenarios to find the edges: "A Customer with two Subscriptions cancels one. Is that Customer still *active*?" A term is settled when the user can answer every such case without hesitating.

**Write it down immediately.** When a term is settled, update the glossary in the same turn, then say so in one line (`Glossary: added **Subscription**, avoid *plan*`). Don't batch updates for the end of the session, and don't write terms the user hasn't settled. Agents must not make up definitions on the user's behalf: if the user won't decide yet, record it under **Open** instead.

## Audit

Read-only until the user confirms.

1. **Collect candidates.** From the glossary if there is one, otherwise from the code (type, model, table and route names), docs, README, agent instructions (`AGENTS.md`, `CLAUDE.md`), recent issues and PR titles.
2. **Find problems.** For each, note the evidence (file and line, or issue):
   - *Synonyms*: several words for one concept (`Client`, `Customer`, `Buyer`).
   - *Homonyms*: one word for several concepts (`status` meaning payment status in one module and shipping status in another).
   - *Drift*: the glossary says one thing, the code or docs another.
   - *Vague*: a term used often but defined nowhere, or defined by what it does rather than what it is.
   - *Bloat*: entries that are general programming terms, implementation detail, or not used anywhere.
3. **Present the list**, grouped by problem, most confusing first, each with a proposed resolution. Ask the user to accept, change or skip each one. Don't edit until they answer.
4. **Apply** the accepted changes to the glossary. Renaming code to match is separate work: offer to file it as an issue (or use `collect-feedback`), don't rename in this skill.

## Format

```markdown
# {Context name}

{One or two sentences: what this context covers and why it exists.}

## Language

**Customer**:
A person or organization that pays for at least one Subscription.
_Avoid_: client, buyer, account
_Not_: a **Login**, which is who signs in; one Customer can have many.

**Subscription**:
A Customer's agreement to pay for one Plan on a recurring schedule.
_Avoid_: plan, membership
_Code_: `Membership` (rename pending)

## Open

- **active**: does it mean "has any Subscription" or "has paid this month"? Raised in session on {date}.
```

Rules for entries:

- **Pick one word.** Every rejected synonym goes under `_Avoid_`, so the next person (or agent) who reaches for it is redirected.
- **Define what it is, not what it does,** in one or two sentences. Use other glossary terms in **bold** so definitions link up.
- **`_Not_`** only for a near neighbour people actually confuse it with.
- **`_Code_`** only when the code's name differs from the canonical term. It records drift to fix, not a mapping to keep. Otherwise no implementation detail: no fields, tables, endpoints or algorithms.
- **Only this project's terms.** Leave out general programming or industry words unless this project uses them in a narrower or different sense; then define that sense.
- **Group** under `###` subheadings when clusters appear; otherwise a flat list, alphabetical.
- **Open** holds terms with competing meanings that the user hasn't decided. Agents must ask, not guess, when they meet an Open term. Move an entry into Language once it is settled.

The glossary is a glossary and nothing else. Not a spec, not a decision log, not a design doc. Decisions and rationale go in the project's ADRs or issues.

For several contexts, `GLOSSARY-MAP.md` lists each context with a link to its glossary and a one-line description, then the relationships between contexts, including any term that means different things on each side (`**Order**: in Sales a quote the Customer accepted; in Fulfillment a shipment to send`).

## Keep it short

A glossary only works if agents read all of it. When it grows:

- Remove entries nobody uses and terms that turned out not to be project-specific.
- Tighten definitions to one sentence where one will do.
- Split by context (`GLOSSARY-MAP.md`) when there are clear clusters with their own vocabulary, not to cut length.

## Make agents use it

A glossary agents never read changes nothing. When the glossary is first created, and on every `glossary audit`, check whether the project's agent instructions (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`) mention it. If not, offer to add this, and add it only if the user agrees:

```markdown
## Terminology
Use the terms defined in GLOSSARY.md (or, where GLOSSARY-MAP.md exists, in the glossary it lists for the context you're working in), with those meanings, in code, prompts, issues and replies. Don't use a word listed under _Avoid_. If a term is under Open, or a prompt uses a word in a way the glossary doesn't cover, ask which meaning is meant before acting on it.
```
