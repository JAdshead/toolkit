# Category Checklists

One checklist per category. Adapt each to the stack detected in Step 3: the examples below cover several ecosystems, so use the ones that apply and translate the rest. Every category returns findings in the JSON format from `SKILL.md`.

When in doubt, leave it out.

---

## Dead Code (`dead-code`)

Look for:

1. **Unused imports / requires / `use` statements** with no usage in the file (P3).
2. **Unreferenced functions or methods**: defined, never called anywhere in the codebase (P2).
3. **Dead branches**: conditionals that always evaluate the same way (P2).
4. **Orphan files**: source files nothing imports, requires or registers (P2).
5. **Unreachable code** after an unconditional `return`, `raise`, `throw`, `panic` or `exit` (P1).

Before calling something unused, search for indirect references:

- **Framework lifecycle and hooks**: callbacks and validators (`before_*`, `after_*`, `around_*`, `validate*`), `included`/`inherited`, migration `up`/`down`, React lifecycle methods and hooks, Django signals, Spring `@PostConstruct`, test fixtures and setup hooks.
- **Convention and reflection**: controller actions reached by routes, template helpers called from views (ERB, Jinja, Blade, JSX), front-end controllers or handlers referenced from markup attributes (for example `data-action`, `x-on`, `v-on`), dependency-injection registrations, plugin or entry-point registries, `getattr`/`send`/dynamic dispatch, string-based lookups.
- **Entry points**: `main.*`, `index.*`, `application.*`, `config.ru`, `Rakefile`, `manage.py`, `bin/*`, `cmd/*`, CLI scripts, serverless handlers, files named in `package.json` / `pyproject.toml` / build configs.
- **Public API**: exported symbols of a published library, items marked public (`@api public`, `__all__`, `pub` in a library crate). These may have callers outside the repo.
- **Skip entirely**: fixtures, factories, seeds, generated code, vendored code.

---

## Duplication (`duplication`)

Look for:

1. **Exact duplicates**: identical blocks over 5 lines in more than one place (P2).
2. **Near duplicates**: the same code with only names or literals changed (P2).
3. **Repeated patterns**: the same logic sequence in 3 or more places (P3).

Approach: compare function bodies and blocks, flag copy-paste where only names differ, and group every location of one duplication into a single finding (all locations in `location`).

Skip framework boilerplate, generated code, and test setup that is repeated on purpose for readability.

---

## Architecture (`architecture`)

Look for:

1. **God classes or modules** (P1):
   - over 500 lines, OR
   - over 20 public methods (excluding generated accessors, framework callbacks and declarations), OR
   - for controllers / route handlers: over 300 lines or over 12 actions.
   Suggest concrete split points from method groupings (for example "move the authentication methods into an `Authentication` module").
2. **Circular dependencies**: modules that import each other, directly or through a short cycle (P1).
3. **High coupling**: a file importing more than 10 other project files (P2).
4. **Long functions**: over 50 lines (P2).
5. **Deep nesting**: over 4 levels of indentation that is visibly hard to follow (P3).

Include the metrics in the description ("567 lines, 23 public methods").

---

## Deferred Work (`deferred-work`)

Look for:

1. **TODO / FIXME / HACK / XXX** comments (P3; P4 if they reference a ticket).
2. **Commented-out code**: more than 3 consecutive lines of code syntax in comments (P3).
3. **Deprecation notices**: `@deprecated`, `deprecated: true`, `DEPRECATED`, `#[deprecated]`, `warnings.warn(..., DeprecationWarning)` (P2).
4. **Temporary markers**: "temp", "temporary", "remove later", "remove after", "workaround", "quick fix" (P2).

Ticket references that downgrade a TODO to P4: `TODO(#12)`, `FIXME(#34)`, `TODO: PROJ-123`, `FIXME: GH-456`, `TODO: see issue #56`, or any TODO followed by a ticket-like identifier. Check whether that ticket is still open; a TODO pointing at a closed ticket is P3.

---

## Pattern Violations (`patterns`)

Flag clear violations of the detected framework's conventions, not style preferences. Examples by stack (use the ones that apply):

**Any web framework**
- Missing authorization check when loading a resource by id from the request (P1, security).
- Business logic in controllers / route handlers that belongs in a model, service or domain module (P2).
- Unvalidated request input passed straight to persistence (P2).

**ORM-backed apps (Rails, Django, Laravel, Hibernate, Prisma, SQLAlchemy, ...)**
- N+1 query risk: an association accessed inside a loop without eager loading (`includes`/`preload`, `select_related`/`prefetch_related`, `with`, `JOIN FETCH`, `include`) (P2).
- Heavy model callbacks or signals: over 10 lines, or calling external services (P2).
- Mass assignment without an allow-list (strong parameters, serializer fields, `$fillable`) (P2).

**JS/TS front ends**
- Effects with missing or over-broad dependencies, state derived in effects instead of computed, direct DOM manipulation inside a component framework (P2).

**Go / Rust / JVM**
- Ignored errors (`_ = err`, `.unwrap()` in non-test library code, swallowed exceptions) (P2).

**Generic**
- Deprecated APIs or outdated syntax in recently changed code (P3).
- Naming that is inconsistent with the rest of the codebase (P3).

Anything the repo's linter config or contributor docs explicitly allows is not a violation.

---

## Test Quality (`tests`)

Focus on the detected test directories. Translate the patterns to the detected runner (RSpec, Minitest, pytest, Jest, Vitest, Go `testing`, JUnit, ...).

**P0: tests that hide security issues**
- A test that disables or stubs out authentication / authorization and then asserts the protected behavior works.

**P1: false confidence**
1. **Mock-only tests**: the test mocks the thing it is testing, then asserts on the mock.
   Example shape: stub `Service.call` to return X, then assert `Service.call == X`.
2. **Stubbing the subject**: stubbing a method on the object under test, then asserting on that object.
3. **Tautological tests**: the mock returns X and the test asserts the result is X, with no real logic in between.
4. **No real assertions**: only `assert true`, `expect(true).toBe(true)`, or no expectation at all.
5. **Empty test bodies**: a named test with no body that is not marked skip / pending / todo.
6. **Excessive mocking**: over half of the test's lines are mock or stub setup.
7. **Stubbing every instance of a class** (`allow_any_instance_of`, prototype patching, `mock.patch.object(Class, ...)` across all instances): hides which instance is called.
8. **Shared mutable state**: records or globals created once per suite and mutated across tests (`before(:all)`, `setUpClass`, module-level fixtures with side effects, `beforeAll` writes).

**P2**
1. **Implementation coupling**: calling private methods (`send(:private)`, `_private()`), asserting on instance variables or internal state instead of behavior.
2. **Only "does not raise"**: proves the code runs, not what it does (`not_to raise_error`, `assert_nothing_raised`, `expect(fn).not.toThrow()` as the only assertion).
3. **Happy path only**: a unit with branching logic and no visible failure-case tests.

**P3**
1. **Brittle assertions**: exact full-string or full-snapshot matching where a pattern or a targeted assertion would do.

Skip intentional skips (`skip`, `pending`, `xit`, `xdescribe`, `it.todo`, `@pytest.mark.skip`, `t.Skip`), test helpers, shared examples and shared fixtures.
