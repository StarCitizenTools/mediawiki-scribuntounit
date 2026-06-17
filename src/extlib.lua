-- SPDX-License-Identifier: MIT
--- Loads consumer-declared extension Scribunto libraries (mw.ext.*) from their
--- real upstream Lua, using the same setupInterface contract as the lualib: the
--- library captures `mw_interface` as its private `php` table and registers
--- itself under `mw.ext.<x>` + package.loaded[name]. Unstubbed PHP leaves default
--- to a benign `function() return '' end`; the consumer's optional `interface`
--- table overrides specific leaves. Sources are fetched (repo@ref, cached under
--- .scribuntounit/ext) or local (an on-disk path).
local paths = require('paths')

local M = {}

--- On-disk location of a library's real .lua.
--- fetched (`spec.repo`): <extRoot>/<name>/<basename(path)>, extRoot =
---   SCRIBUNTO_EXT_ROOT env / <repoRoot>/.scribuntounit/ext.
--- local: <repoRoot>/<path> (an absolute path is used as-is).
--- @param name string
--- @param spec table
--- @return string
local function resolvePath(name, spec)
	local p = spec.path or ''
	if spec.repo then
		local extRoot = os.getenv('SCRIBUNTO_EXT_ROOT') or (paths.repoRoot .. '/.scribuntounit/ext')
		local basename = p:match('([^/]+)$') or p
		return extRoot .. '/' .. name .. '/' .. basename
	end
	if p:sub(1, 1) == '/' then
		return p
	end
	return paths.repoRoot .. '/' .. p
end

--- mw_interface table: the consumer's overrides over a benign `() -> ''` default,
--- so any unstubbed PHP leaf is still callable and returns ''.
--- @param interface table|nil
--- @return table
local function benignInterface(interface)
	return setmetatable({}, {
		__index = function(_, k)
			if interface and interface[k] ~= nil then
				return interface[k]
			end
			return function()
				return ''
			end
		end,
	})
end

--- Load one extension library and register it into `mw`. Fails fast (stderr +
--- exit 1) on a missing file, a load error, a missing setupInterface, or a
--- setupInterface that throws.
--- @param name string  require-name, e.g. 'mw.ext.aggrid'
--- @param spec table  { repo?, ref?, path, interface? }
--- @param mw table  the assembled mw global
--- @param status table  name -> 'extlib' | 'error: ...' diagnostics sink
function M.load(name, spec, mw, status)
	if spec.repo and (not spec.path or spec.path == '') then
		io.stderr:write('ERROR: extension lib "' .. name .. '" declares `repo` but no `path`\n')
		os.exit(1)
	end
	local path = resolvePath(name, spec)
	local f = io.open(path, 'r')
	if not f then
		local hint = spec.repo
				and ('run `mise run fetch` (or `scribuntounit-fetch`) to download ' .. tostring(spec.repo))
			or ('check `path` in scribuntounit.config.lua libraries["' .. name .. '"]')
		io.stderr:write('ERROR: extension lib "' .. name .. '" not found at ' .. path .. '\n  ' .. hint .. '\n')
		os.exit(1)
	end
	local src = f:read('*a')
	f:close()

	-- Load under the `@<name>` chunk name so the library's own runtime errors read
	-- `mw.ext.x:line:` (mirrors on-wiki), consistent with the resolver invariant.
	local chunk, lerr = loadstring(src, '@' .. name)
	if not chunk then
		status[name] = 'error: ' .. tostring(lerr)
		io.stderr:write('ERROR: extension lib "' .. name .. '" failed to load: ' .. tostring(lerr) .. '\n')
		os.exit(1)
	end
	local ran, mod = pcall(chunk)
	if not ran then
		status[name] = 'error: ' .. tostring(mod)
		io.stderr:write('ERROR: extension lib "' .. name .. '" failed to execute: ' .. tostring(mod) .. '\n')
		os.exit(1)
	end
	if type(mod) ~= 'table' or type(mod.setupInterface) ~= 'function' then
		status[name] = 'error: no setupInterface'
		io.stderr:write('ERROR: extension lib "' .. name .. '" did not return a table with setupInterface\n')
		os.exit(1)
	end

	local prevMw, prevIface = _G.mw, _G.mw_interface
	_G.mw = mw
	_G.mw_interface = benignInterface(spec.interface)
	local ok, perr = pcall(mod.setupInterface, {})
	_G.mw = prevMw
	_G.mw_interface = prevIface
	if not ok then
		status[name] = 'error: ' .. tostring(perr)
		io.stderr:write('ERROR: extension lib "' .. name .. '" setupInterface failed: ' .. tostring(perr) .. '\n')
		os.exit(1)
	end
	status[name] = 'extlib'
end

return M
