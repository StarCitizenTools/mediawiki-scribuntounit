-- SPDX-License-Identifier: MIT
--- Off-wiki implementations of the load-time primitives Scribunto modules rely on:
--- `strict`, mw.loadData, mw.loadJsonData (+ the frozen-table wrapper mirroring
--- mw.loadJsonData's read-only result on-wiki), and a stub mechanism for modules
--- that have no headless-safe implementation (render primitives, extensions).
local paths = require('paths')
local resolver = require('resolver')

local S = {}

local dkjson
local function getDkjson()
	if not dkjson then
		dkjson = dofile(paths.libRoot .. '/vendor/dkjson.lua')
	end
	return dkjson
end

--- Recursively freeze a table to approximate mw.loadJsonData's read-only result:
--- writes to new keys raise (the `__newindex` below).
---
--- FIDELITY GAP (unavoidable under Lua 5.1): on-wiki, the `#` operator returns 0
--- on these frozen JSON tables — a real quirk that has caused production bugs. We
--- CANNOT reproduce it here: Lua 5.1's `#` ignores `__len` on tables (that is a
--- 5.2+ feature; emulating it with an empty proxy would break `pairs`/`ipairs`,
--- which 5.1 also can't metamethod-override). So `#` returns the TRUE length here.
--- The `__len` below is therefore inert under the 5.1 target and only takes effect
--- if run under Lua 5.2+. Module code MUST guard arrays with `next()` / `t[1]`,
--- never `#` — that is required on-wiki regardless, and the only portable check.
--- @param t any
--- @return any
local function freeze(t)
	if type(t) ~= 'table' then
		return t
	end
	for k, v in pairs(t) do
		rawset(t, k, freeze(v))
	end
	return setmetatable(t, {
		__len = function() -- honoured only under Lua 5.2+; inert on the 5.1 target (see above)
			return 0
		end,
		__newindex = function()
			error('frozen table (mw.loadJsonData is read-only)', 2)
		end,
	})
end
S.freeze = freeze

--- mw.loadData: load a Lua data module by `Module:` name, return its table.
--- @param name string
--- @return table
function S.loadData(name)
	for _, p in ipairs(resolver.candidates(name)) do
		local f = io.open(p, 'r')
		if f then
			f:close()
			return assert(loadfile(p))()
		end
	end
	error('[shims] loadData: no file for ' .. name)
end

--- mw.loadJsonData: load a `.json` page by `Module:` name, decode + freeze.
--- JSON page names include the `.json` extension in their title.
--- @param name string
--- @return table
function S.loadJsonData(name)
	local rel = name:gsub('^Module:', '')
	local path = paths.repoRoot .. '/' .. resolver.moduleRoot .. '/' .. rel
	local f = assert(io.open(path, 'r'), '[shims] loadJsonData: no file ' .. path)
	local txt = f:read('*a')
	f:close()
	return freeze((getDkjson().decode(txt)))
end

--- Install the `strict` shim so `require('strict')` (no Module: prefix) resolves.
--- On-wiki strict only guards undeclared globals, irrelevant headless; a no-op
--- table suffices.
function S.installStrict()
	if not package.preload['strict'] then
		package.preload['strict'] = function()
			return setmetatable({}, {})
		end
	end
end

--- An inert stub whose every method returns '' (a string), so getSections-style
--- tests that only assert `type(content) == 'string'` still pass.
local function makeStub()
	local stub = {}
	setmetatable(stub, {
		__index = function()
			return function()
				return ''
			end
		end,
		__tostring = function()
			return ''
		end,
	})
	return stub
end
S.makeStub = makeStub

--- Register `Module:<name>` via package.preload (no-op if already registered).
--- With `value` (table/function), preloads it verbatim; without, the inert stub.
--- @param name string  module name WITHOUT the 'Module:' prefix
--- @param value table|function|nil
function S.registerStub(name, value)
	local full = 'Module:' .. name
	if package.preload[full] or package.loaded[full] then
		return
	end
	package.preload[full] = function()
		if value ~= nil then
			return value
		end
		return makeStub()
	end
end

--- Raw package.preload registration for a bare module name (e.g. 'mw.ext.foo'),
--- for require()s that are NOT 'Module:'-prefixed.
--- @param name string
--- @param fn function
function S.preload(name, fn)
	if not package.preload[name] and not package.loaded[name] then
		package.preload[name] = fn
	end
end

--- Install inert stubs for a list of module names (render primitives etc.).
--- @param list string[]|nil
function S.installStubs(list)
	for _, name in ipairs(list or {}) do
		S.registerStub(name)
	end
end

return S
