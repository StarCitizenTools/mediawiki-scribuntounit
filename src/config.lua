-- SPDX-License-Identifier: MIT
--- Loads the consumer's scribuntounit.config.lua and applies defaults.
--- Search order: $SCRIBUNTOUNIT_CONFIG, then <repoRoot>/scribuntounit.config.lua.
--- A missing config is fine — the defaults run the bare runner against
--- pages/module/ with no consumer stubs.
local paths = require('paths')

local M = {}

local DEFAULTS = {
	-- Where Module:X resolves and where **/testcases.lua are discovered,
	-- relative to repoRoot.
	moduleRoot = 'pages/module',
	-- Module names to install as inert render-primitive stubs (each method → '').
	stubs = {},
	-- Suites to skip, keyed by suite path: { ['Module:X/testcases'] = 'reason' }.
	skip = {},
	-- Optional function(api) to extend the env: api.mw (the assembled mw table),
	-- api.stub(name, value), api.preload(name, fn).
	setup = nil,
	-- Core Scribunto lualib ref to fetch (overridable via SCRIBUNTO_REF env).
	scribunto = { ref = 'REL1_43' },
}

--- @return table config  fields: moduleRoot, stubs, skip, setup, scribunto
function M.load()
	local path = os.getenv('SCRIBUNTOUNIT_CONFIG') or (paths.repoRoot .. '/scribuntounit.config.lua')
	local cfg = {}
	local f = io.open(path, 'r')
	if f then
		f:close()
		local user = assert(loadfile(path))()
		assert(type(user) == 'table', 'scribuntounit.config.lua must return a table, got ' .. type(user))
		cfg = user
	end
	if cfg.moduleRoot == nil then
		cfg.moduleRoot = DEFAULTS.moduleRoot
	end
	if cfg.stubs == nil then
		cfg.stubs = DEFAULTS.stubs
	end
	if cfg.skip == nil then
		cfg.skip = DEFAULTS.skip
	end
	if cfg.scribunto == nil then
		cfg.scribunto = {}
	end
	if cfg.scribunto.ref == nil then
		cfg.scribunto.ref = DEFAULTS.scribunto.ref
	end
	return cfg
end

return M
