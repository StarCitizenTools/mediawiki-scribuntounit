-- SPDX-License-Identifier: MIT
--- Wires the off-wiki environment: loads the consumer config, configures the
--- resolver, installs the strict shim + consumer stubs + the Module: loader,
--- builds the mw global, then runs the consumer's setup hook. Returns the loaded
--- config (so run.lua can read moduleRoot for discovery).
local config = require('config').load()
local resolver = require('resolver')
local shims = require('shims')
local paths = require('paths')

resolver.configure(config.moduleRoot)

shims.installStrict()
shims.installStubs(config.stubs)
resolver.install()

-- Resolve the Scribunto lualib root BEFORE mwenv loads (mwenv reads it at require
-- time). Priority: SCRIBUNTO_LUALIB env, config.scribunto.lualib, then the
-- conventional fetch cache <repoRoot>/.scribuntounit/lualib.
local scribunto = config.scribunto or {}
paths.lualibRoot = os.getenv('SCRIBUNTO_LUALIB') or scribunto.lualib or (paths.repoRoot .. '/.scribuntounit/lualib')

-- Fail fast with an actionable message if the lualib has not been fetched.
local probe = io.open(paths.lualibRoot .. '/mw.text.lua', 'r')
if probe then
	probe:close()
else
	io.stderr:write(
		'ERROR: Scribunto lualib not found at '
			.. paths.lualibRoot
			.. '\n  Run `mise run fetch` (or `scribuntounit-fetch`), or set SCRIBUNTO_LUALIB to a lualib dir.\n'
	)
	os.exit(1)
end

local mwenv = require('mwenv')
_G.mw = mwenv.mw
_G.__MW_LUALIB_STATUS = mwenv.lualibStatus

-- Load consumer-declared extension libraries (real upstream Lua + benign-default
-- interface) into mw.ext.*, before setup so a setup hook can still override them.
-- Load order is undefined (pairs); inter-library setupInterface dependencies are unsupported.
local extlib = require('extlib')
for name, spec in pairs(config.libraries or {}) do
	extlib.load(name, spec, mwenv.mw, mwenv.lualibStatus)
end

if type(config.setup) == 'function' then
	config.setup({
		mw = mwenv.mw,
		stub = shims.registerStub,
		preload = shims.preload,
		lualibStatus = mwenv.lualibStatus,
	})
end

return config
