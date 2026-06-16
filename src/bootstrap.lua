-- SPDX-License-Identifier: MIT
--- Wires the off-wiki environment: loads the consumer config, configures the
--- resolver, installs the strict shim + consumer stubs + the Module: loader,
--- builds the mw global, then runs the consumer's setup hook. Returns the loaded
--- config (so run.lua can read moduleRoot for discovery).
local config = require('config').load()
local resolver = require('resolver')
local shims = require('shims')

resolver.configure(config.moduleRoot)

shims.installStrict()
shims.installStubs(config.stubs)
resolver.install()

local mwenv = require('mwenv')
_G.mw = mwenv.mw
_G.__MW_LUALIB_STATUS = mwenv.lualibStatus

if type(config.setup) == 'function' then
	config.setup({
		mw = mwenv.mw,
		stub = shims.registerStub,
		preload = shims.preload,
		lualibStatus = mwenv.lualibStatus,
	})
end

return config
