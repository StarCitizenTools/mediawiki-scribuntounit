-- SPDX-License-Identifier: MIT
--- Maps MediaWiki `Module:` names to on-disk files under <repoRoot>/<moduleRoot>/
--- and installs a package loader so `require('Module:Foo')` works off-wiki.
---
--- Two-candidate rule (flat first, then dir-module), mirroring MediaWiki's
--- filesystem-mirror convention:
---   Module:Foo      -> <root>/Foo.lua          (flat)
---   Module:Foo      -> <root>/Foo/Foo.lua      (dir-module)
---   Module:Foo/Sub  -> <root>/Foo/Sub.lua      (flat subpage)
local paths = require('paths')

local M = { moduleRoot = 'pages/module' }

--- @param moduleRoot string  path under repoRoot where modules live
function M.configure(moduleRoot)
	M.moduleRoot = moduleRoot or M.moduleRoot
end

--- Candidate on-disk paths for a `Module:`-prefixed name (flat, then dir-module).
--- @param name string  e.g. 'Module:Foo/Sub'
--- @return string[]
function M.candidates(name)
	local rel = name:gsub('^Module:', '')
	local base = paths.repoRoot .. '/' .. M.moduleRoot .. '/' .. rel
	local last = rel:match('([^/]+)$')
	return { base .. '.lua', base .. '/' .. last .. '.lua' }
end

--- package.loaders entry: turn a `Module:` name into a loaded chunk.
--- Returns a string (diagnostic) when it cannot load, per the loader protocol.
--- @param name string
--- @return function|string|nil
function M.loader(name)
	if not name:match('^Module:') then
		return nil
	end
	for _, path in ipairs(M.candidates(name)) do
		local f = io.open(path, 'r')
		if f then
			local src = f:read('*a')
			f:close()
			-- Load under the `Module:` name (not the filesystem path) so runtime
			-- error locations read `Module:X:line:` exactly as on-wiki. Scribunto-
			-- Unit's assertThrows strips that prefix (pattern `Module:[^:]*:[0-9]*: `);
			-- the absolute path loadfile() would embed does not match it.
			local chunk, err = loadstring(src, '@' .. name)
			if not chunk then
				return '\n\t[resolver] load error in ' .. path .. ': ' .. tostring(err)
			end
			return chunk
		end
	end
	return '\n\t[resolver] no file for ' .. name .. ' (tried: ' .. table.concat(M.candidates(name), ', ') .. ')'
end

--- Install the loader (idempotent).
function M.install()
	for _, l in ipairs(package.loaders) do
		if l == M.loader then
			return
		end
	end
	table.insert(package.loaders, M.loader)
end

return M
