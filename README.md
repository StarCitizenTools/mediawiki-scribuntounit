# mediawiki-scribuntounit

**Run your MediaWiki [ScribuntoUnit](https://www.mediawiki.org/wiki/Module:ScribuntoUnit) suites headless, in CI — no wiki, no PHP, no LuaSandbox.**

A general-purpose off-wiki runner for [Scribunto](https://www.mediawiki.org/wiki/Extension:Scribunto) (Lua 5.1) module tests. It fetches the **real** Scribunto Lua library (`mw.html` / `mw.text` / `mw.uri`) for your chosen MediaWiki ref, shims the PHP-coupled surface, resolves `require('Module:X')` to your repo's files, auto-discovers `**/testcases.lua`, and exits non-zero on failure — so a plain `lua5.1` on a GitHub Actions runner gates your modules before they ship.

## Why

If you keep your wiki's Lua modules in git and want pre-deploy CI, your options today are thin: the canonical ScribuntoUnit runs only *on-wiki* (deploy first, then read the result), and the off-wiki mocks are partial hand-written stand-ins with no test discovery and no CI story. This runner is different on three axes at once:

1. **Fidelity** — it loads the *actual* fetched lualib, not a re-implementation, so `mw.html`/`mw.text`/`mw.uri` behave as they do on the wiki (matching the Scribunto ref you choose).
2. **Headless CI** — pure `lua5.1`, red/green exit code, a drop-in GitHub Actions workflow.
3. **Zero-config discovery** — it finds every `Module:X/testcases.lua` you already have.

## Scope — read this

This runner gates **logic**, not rendering or live wiki I/O. It is honest about its boundary:

| Surface | Status |
|---|---|
| `mw.html`, `mw.text`, `mw.uri` | **Real** (fetched Scribunto lualib at your chosen ref) |
| `mw.ustring` | Shim — byte-wise via Lua `string.*`, plus real UTF-8 `char`/`codepoint`. No full Unicode case/normalisation. |
| `mw.language` | Shim — grouped `formatNum`, `lc`/`uc`/`ucfirst`/`lcfirst`. No locale data, no `formatDate`. |
| `mw.title`, `mw.site` | Benign stubs |
| `mw.ext.*`, your render primitives | You provide them (see Configuration) |
| Live parser, `mw.smw`, Apiunto, the DB | Not available — out of scope |

If a module leans on real multibyte `ustring`, `formatDate`, or the live parser/DB, it will diverge from the wiki — test those on-wiki. Everything else (type resolution, data transformation, row/section building, pure helpers) gates cleanly here.

**One known fidelity gap (Lua version):** on-wiki, the `#` length operator returns `0` on `mw.loadJsonData` tables (a real quirk that has caused production bugs). Under the Lua 5.1 target this cannot be reproduced — 5.1 ignores `__len` on tables — so `#` returns the true length here. **Never use `#` on a `loadJsonData` result; guard arrays with `next()` / `t[1]`.** That is the correct, portable check on-wiki anyway; a module relying on `#frozen` will pass here but may break on-wiki.

## Install

**Prerequisite:** a system **`lua5.1`** interpreter on `PATH` — `apt-get install lua5.1` (Debian/Ubuntu) or `brew install lua@5.1` (macOS). Do **not** use mise's `lua` plugin: it builds the interpreter from source and fails on stock CI runners.

### Via [mise](https://mise.jdx.dev/) (recommended)

In your repo's `.mise.toml`:

```toml
[tools]
"github:StarCitizenTools/mediawiki-scribuntounit" = { version = "0.1.0", bin_path = "bin" }
# Requires a system lua5.1 (see above). Do NOT add mise's lua plugin.
```

`mise install` puts a `scribuntounit` command on your `PATH`.

After install, fetch the Scribunto lualib once (it is not bundled):

```sh
scribuntounit-fetch                 # reads scribunto.ref from your config
```

The lualib lands in a local cache at `.scribuntounit/` — add it to `.gitignore`. A
`mise` task that fetches then tests:

```toml
[tasks.fetch]
run = "scribuntounit-fetch"

[tasks.test]
depends = ["fetch"]
run = "scribuntounit"
```

### Manual (git submodule / vendored copy)

Clone or submodule the repo and call the entry point directly:

```sh
lua5.1 path/to/mediawiki-scribuntounit/src/run.lua
```

## Configuration

Drop a **`scribuntounit.config.lua`** at your repo root:

```lua
return {
  -- Where Module:X resolves and where **/testcases.lua are discovered.
  moduleRoot = 'pages/module',

  -- Scribunto lualib ref to fetch (overridable via SCRIBUNTO_REF). The chosen
  -- ref is the fidelity guarantee — pick the MediaWiki release your wiki runs.
  scribunto = { ref = 'REL1_43' },

  -- Render primitives with no headless-safe build: installed as inert stubs
  -- (every method returns ''), so suites that only need a string back load fine.
  stubs = { 'ProgressBar', 'Chart' },

  -- Optional: suites to skip, keyed by suite path, each with a reason.
  skip = { ['Module:Legacy/testcases'] = 'needs a live-parser fixture' },

  -- Optional: extend the environment.
  setup = function(api)
    -- api.mw                  -> the assembled mw table (add mw.site overrides, …)
    -- api.stub(name, value)   -> register Module:<name> with a custom table/function
    -- api.preload(name, fn)   -> register a bare require() (e.g. an mw.ext.* module)
    api.preload('mw.ext.myextension', function()
      return { doThing = function() return '' end }
    end)
  end,
}
```

The config is looked up at `<repoRoot>/scribuntounit.config.lua`, or at the path in the `$SCRIBUNTOUNIT_CONFIG` environment variable. A missing config is fine — the defaults run against `pages/module/` with no stubs.

Your `Module:ScribuntoUnit` (the canonical on-wiki assertion framework) must live under `moduleRoot` like any other module — the runner loads *your* copy.

## Extension libraries (`mw.ext.*`)

If your modules call an extension's Scribunto library, declare it under `libraries`
to load the **real** upstream Lua (its pure-Lua helpers run for real and track the
extension version). Only the PHP leaves (`render`, `thumb`, …) are stubbed — and
they default to a benign `''`, so `interface` is optional:

```lua
libraries = {
  -- fetched: scribuntounit-fetch downloads it (repo@ref) into .scribuntounit/ext/
  ['mw.ext.aggrid'] = {
    repo = 'StarCitizenTools/mediawiki-extensions-AGGrid',
    ref  = 'v0.4.0',
    path = 'includes/Scribunto/mw.ext.aggrid.lua',
    -- interface OPTIONAL; override a leaf only if a test asserts on it:
    -- interface = { thumb = function() return nil end },
  },
  -- local: a .lua already on disk (e.g. a checked-out extension), no fetch:
  ['mw.ext.tabber'] = { path = 'path/to/mw.ext.tabber.lua' },
}
```

Thin libraries that are just a single PHP passthrough gain nothing from this — keep
stubbing them with `api.preload` in `setup`.

**Caveat — `mw.*` beyond the leaves.** A real helper may call `mw.*` methods the
runner doesn't shim (e.g. AGGrid's `link` calls `mw.title.new(t):localUrl()`, and
the `mw.title` stub has no `localUrl`). Add what it needs in your `setup` hook
(override `mw.title`); the runner stays extension-agnostic.

## Run

```sh
scribuntounit                 # all suites
scribuntounit Foo             # only Module: paths containing "Foo" ("Module:Foo" also works)
REPO_ROOT=/path scribuntounit # run from any cwd
```

A module that ships its own `testcases.lua` is treated as a unit-under-test and loaded for real **for the entire run** — even if it is also listed in `stubs`, its real implementation wins (it is *not* also served as a stub to other suites).

## CI

A copy-paste GitHub Actions job (system lua5.1, then the runner):

```yaml
- uses: actions/checkout@v6
- run: sudo apt-get update && sudo apt-get install -y lua5.1
- uses: jdx/mise-action@v4          # if consuming via mise
- run: mise run test                # or: lua5.1 path/to/src/run.lua
```

## Lualib source (fetched, not vendored)

The Scribunto lualib is **not bundled**. `scribuntounit-fetch` downloads it for the
ref in `scribunto.ref` (or the `SCRIBUNTO_REF` env var) into a local, gitignored
cache at `.scribuntounit/lualib/`; the runner reads it from there and never
redistributes it. The chosen ref *is* the fidelity guarantee. To track a different
MediaWiki release, change `scribunto.ref` (or set `SCRIBUNTO_REF`) and re-run
`scribuntounit-fetch`. Only `vendor/dkjson.lua` (MIT) stays vendored.

## License

**MIT.** Only `vendor/dkjson.lua` (MIT) is vendored. See [LICENSE](LICENSE).

## See also

- [Module:ScribuntoUnit](https://www.mediawiki.org/wiki/Module:ScribuntoUnit) — the on-wiki assertion framework this runs.
- [Extension:Scribunto](https://www.mediawiki.org/wiki/Extension:Scribunto) — the upstream of the fetched lualib.
