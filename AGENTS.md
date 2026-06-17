# AGENTS.md

Guidance for LLM agents working in this repository.

## Project Overview

`mediawiki-scribuntounit` is a general-purpose **off-wiki runner** for MediaWiki
[Scribunto](https://www.mediawiki.org/wiki/Extension:Scribunto) (Lua 5.1) module
tests. It runs a wiki's [ScribuntoUnit](https://www.mediawiki.org/wiki/Module:ScribuntoUnit)
suites headless under a plain `lua5.1` interpreter — no wiki, no PHP, no
LuaSandbox — so modules can be gated in CI before they ship.

It does this by fetching the **real** Scribunto Lua library
(`mw.html`/`mw.text`/`mw.uri`) for a chosen MediaWiki ref into a local cache,
shimming the PHP-coupled surface, resolving `require('Module:X')` to on-disk
files, and auto-discovering `**/testcases.lua`.

## Layout

- `src/` — the runner. Authored here; MIT-licensed (per-file SPDX).
  - `run.lua` — entry point: discovers + runs suites, exit code.
  - `bootstrap.lua` — wires config → resolver → stubs → mw env → setup hook.
  - `resolver.lua` — `Module:X` → `<repoRoot>/<moduleRoot>/…` + the package loader.
  - `shims.lua` — `strict`, `loadData`/`loadJsonData` (+ frozen-table), stub mechanism.
  - `mwenv.lua` — the headless `mw.*` environment (fetched lualib + generic shims).
  - `config.lua` — loads the consumer's `scribuntounit.config.lua`.
  - `paths.lua` — resolved `libRoot` / `repoRoot` singleton.
- `vendor/` — bundled `dkjson.lua` (MIT), **verbatim**, the only committed
  third-party file. The Scribunto lualib is **fetched** (not vendored) by
  `bin/scribuntounit-fetch`; see `vendor/REVISION`.
- `examples/` — the library's own self-test: sample modules + `testcases.lua` +
  `scribuntounit.config.lua`. This is what CI runs.
- `bin/scribuntounit` — launcher for mise's `github` backend.
- `bin/scribuntounit-fetch` — downloads the Scribunto lualib for `scribunto.ref`
  into `.scribuntounit/` (the runner itself has no network code).

## Architecture

The reusable design is a **config seam**: generic runner code in `src/` knows
nothing about any particular wiki; a consumer drops a `scribuntounit.config.lua`
at its repo root declaring `{ moduleRoot, stubs, setup }`. The `setup(api)` hook
(`api.mw`, `api.stub(name, value)`, `api.preload(name, fn)`) is where a consumer
registers its render-primitive stubs and `mw.ext.*` modules. Generic `mw.*`
shims (ustring, language, title, site) live in `mwenv.lua`; wiki-specific stubs do
NOT — keep that boundary.

Runner pipeline: `run.lua` sets `paths`, requires `bootstrap` (load config →
`resolver.configure` → `installStrict` + `installStubs` → `resolver.install` →
build `mwenv` → run `config.setup`), then discovers `**/testcases.lua` under the
module root, un-stubs each unit-under-test, and runs each via `suite:runSuite()`.

## Code Conventions

- Lua 5.1. Every authored `.lua` file starts with `-- SPDX-License-Identifier: MIT`.
- Modules-under-test convention: `require('strict')` at the top (the shim makes it
  a no-op headless).
- LuaCATS annotations (`--- @param`, `--- @return`) where they add clarity.
- Formatting is `stylua` (config in `stylua.toml`: tabs, width 120, single quotes).
  Run `mise run lint` / `mise run fix`.

## Invariants — do not break these

- **Vendored files are verbatim.** Never reformat anything under `vendor/`
  (excluded via `.styluaignore` + `.gitattributes`). The only vendored file is
  `vendor/dkjson.lua`. The Scribunto lualib is fetched, not vendored: to track a
  different MediaWiki release, change `scribunto.ref` / `SCRIBUNTO_REF` and re-run
  `scribuntounit-fetch` — never commit the fetched lualib (`.scribuntounit/` is
  gitignored).
- **Load chunks under their `Module:` name.** `resolver.lua` uses
  `loadstring(src, '@'..name)` so runtime error locations read `Module:X:line:`
  exactly as on-wiki — ScribuntoUnit's `assertThrows` location-stripping depends
  on it. Don't switch to `loadfile` (it embeds the filesystem path).
- **Never use `#` on `mw.loadJsonData` results.** On-wiki, `#` returns 0 on frozen
  JSON tables — a real quirk that has caused production bugs. We CANNOT reproduce
  it under the Lua 5.1 target (5.1 ignores `__len` on tables), so here `#` returns
  the TRUE length — the opposite. Guard emptiness with `t[1] == nil` / `next(t)`,
  never `#`. A module relying on `#frozen` passes here but may break on-wiki: this
  is the one fidelity gap, forced by the Lua version, so the rule is non-negotiable.
- **A module with its own `testcases.lua` is a unit-under-test, never a stub.**
  The runner clears any stub for it so the real module loads.
- **`lua5.1` is a SYSTEM prerequisite.** Do NOT add mise's `lua` plugin — it
  builds the interpreter from source and fails on stock CI runners. Use the apt
  (`lua5.1`) / brew (`lua@5.1`) package.

## Scope

This runner gates **logic**, not rendering or live wiki I/O. `mw.html`/`text`/`uri`
are real (fetched); `mw.ustring`/`language`/`title`/`site` are shims (no full
Unicode/locale; no `formatDate`); the live parser, `mw.smw`, and the DB are out of
scope. A module leaning on those will diverge from the wiki — test it on-wiki.
Keep this boundary honest in code and docs.

## Testing

```
mise run test    # self-test: runs examples/ suites under examples/ moduleRoot
mise run lint    # stylua --check on src/ + examples/
```

Add a self-test by writing a `Module:Foo` under `examples/modules/` and a
`Module:Foo/testcases.lua` beside it (ScribuntoUnit convention:
`local suite = require('Module:ScribuntoUnit'):new()`, `function suite:testX()`,
`return suite`). `examples/modules/ScribuntoUnit.lua` is a minimal MIT
ScribuntoUnit-compatible harness for the self-test only — real consumers supply
the canonical `Module:ScribuntoUnit` in their own `moduleRoot`.

## Licensing

**MIT** (see `LICENSE`). Only `vendor/dkjson.lua` (MIT) is vendored. Keep per-file
`SPDX-License-Identifier: MIT` on new authored files.

## Delivery

Distributed via GitHub releases, consumed through mise's `github` backend
(`"github:StarCitizenTools/mediawiki-scribuntounit" = { version = "…", bin_path = "bin" }`).
A release is a tarball of `src/` + `vendor/` (dkjson only) + `bin/` (including `scribuntounit-fetch`); `bin/scribuntounit` is a
symlink-safe launcher that execs the system `lua5.1` against `src/run.lua`.
