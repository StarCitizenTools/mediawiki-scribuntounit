# mediawiki-scribuntounit

Run your MediaWiki [ScribuntoUnit](https://www.mediawiki.org/wiki/Module:ScribuntoUnit) suites headless, in CI — no wiki, no PHP, no LuaSandbox.

- Fetches the real Scribunto library for your MediaWiki release
- Resolves `require('Module:X')` to your repo's files
- Auto-discovers every `**/testcases.lua`

## Install

1. **Install a system `lua5.1`** — `apt-get install lua5.1` (Debian/Ubuntu) or `brew install lua@5.1` (macOS). Don't use mise's `lua` plugin; it builds from source and fails on stock CI runners.

2. **Add the runner to your `.mise.toml`** (via [mise](https://mise.jdx.dev/)):

   ```toml
   [tools]
   "github:StarCitizenTools/mediawiki-scribuntounit" = { version = "0.2.0", bin_path = "bin" }

   [tasks.fetch]
   run = "scribuntounit-fetch"   # downloads the Scribunto library (not bundled)

   [tasks.test]
   depends = ["fetch"]
   run = "scribuntounit"
   ```

3. **Run `mise install`** — puts `scribuntounit` and `scribuntounit-fetch` on your `PATH`.

4. **Gitignore the cache** — the fetched library lands in `.scribuntounit/`; add it to `.gitignore`.

## Configuration

Drop a **`scribuntounit.config.lua`** at your repo root:

```lua
return {
  -- Where Module:X resolves and where **/testcases.lua are discovered.
  moduleRoot = 'pages/module',

  -- Which MediaWiki release's Scribunto library to fetch.
  scribunto = { ref = 'REL1_43' },

  -- Render primitives with no headless build: inert stubs (every method returns '').
  stubs = { 'ProgressBar', 'Chart' },

  -- Optional: suites to skip, with a reason.
  skip = { ['Module:Legacy/testcases'] = 'needs a live-parser fixture' },

  -- Optional: extend the environment.
  setup = function(api)
    -- api.mw                -> the mw table (add mw.site overrides, …)
    -- api.stub(name, value) -> register Module:<name> with a custom value
    -- api.preload(name, fn) -> register a bare require() (e.g. an mw.ext.* module)
    api.preload('mw.ext.myextension', function()
      return { doThing = function() return '' end }
    end)
  end,
}
```

Your `Module:ScribuntoUnit` (the assertion framework) lives under `moduleRoot` like any other module.

### Extension libraries (`mw.ext.*`)

If your modules call an extension's Scribunto library, declare it under `libraries` to load the **real** upstream Lua. Its PHP leaves (`render`, `thumb`, …) default to a benign `''`, so `interface` is optional:

```lua
libraries = {
  -- fetched from the extension's repo:
  ['mw.ext.aggrid'] = {
    repo = 'StarCitizenTools/mediawiki-extensions-AGGrid',
    ref  = 'v0.4.0',
    path = 'includes/Scribunto/mw.ext.aggrid.lua',
  },
  -- or a .lua already on disk:
  ['mw.ext.tabber'] = { path = 'path/to/mw.ext.tabber.lua' },
}
```

## Run

```sh
scribuntounit                  # all suites
scribuntounit Foo              # only Module: paths containing "Foo"
REPO_ROOT=/path scribuntounit  # run from any cwd
```

## CI

A GitHub Actions job — install `lua5.1`, then run via mise:

```yaml
- uses: actions/checkout@v6
- run: sudo apt-get update && sudo apt-get install -y lua5.1
- uses: jdx/mise-action@v4
- run: mise run test
```

## License

**MIT.** See [LICENSE](LICENSE).

## See also

- [Module:ScribuntoUnit](https://www.mediawiki.org/wiki/Module:ScribuntoUnit) — the assertion framework this runs.
- [Extension:Scribunto](https://www.mediawiki.org/wiki/Extension:Scribunto) — upstream of the fetched library.
