-- SPDX-License-Identifier: MIT
--- Off-wiki ScribuntoUnit runner entry point. Discovers every
--- <repoRoot>/<moduleRoot>/**/testcases.lua, runs each via suite:runSuite() (the
--- display-free path), prints per-suite counts, and exits non-zero on any failure.
---
--- Usage (from the consumer repo root):
---   lua5.1 /path/to/mediawiki-scribuntounit/src/run.lua [filter]
---   <filter> is an optional substring of the Module: path (e.g. "Foo", "Foo/Bar").
--- Set REPO_ROOT to run from any cwd; otherwise the consumer repo is the cwd.

-- Resolve our own location so sibling modules load regardless of cwd, and so the
-- vendored lualib (../vendor) is found via paths.libRoot.
local selfPath = (arg and arg[0]) or ''
local libSrc = selfPath:match('^(.*)[/\\][^/\\]+$') or '.'
package.path = libSrc .. '/?.lua;' .. package.path

local paths = require('paths')
paths.libRoot = libSrc .. '/..'
paths.repoRoot = os.getenv('REPO_ROOT') or '.'

-- Optional substring filter on the Module: path; a leading "Module:" is accepted
-- (e.g. "Foo", "Foo/Bar", or "Module:Foo" all work).
local FILTER = arg and arg[1]
if FILTER then
	FILTER = FILTER:gsub('^Module:', '')
end

local config = require('bootstrap')

-- Suites the consumer marks unrunnable here (config.skip: { ['Module:X/testcases'] = 'reason' }).
local SKIP = config.skip or {}

--- Single-quote a path for safe shell interpolation (handles spaces/metachars).
local function shellQuote(s)
	return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

--- Discover Module:**/testcases suites under <repoRoot>/<moduleRoot> via `find`.
local function discoverSuites()
	-- Normalise trailing slashes so the strip offset below stays exact (find
	-- collapses `<root>//<rel>` to a single slash, which would otherwise be off-by-one).
	local root = ((paths.repoRoot .. '/' .. config.moduleRoot):gsub('/+$', ''))
	local handle = assert(
		io.popen('find ' .. shellQuote(root) .. ' -name testcases.lua -type f 2>/dev/null | sort'),
		'suite discovery failed (could not run find)'
	)
	local strip = #root + 2 -- drop "<root>/" prefix
	local suites = {}
	for line in handle:lines() do
		local rel = line:sub(strip):gsub('%.lua$', '') -- e.g. Foo/testcases
		if rel ~= '' and (not FILTER or rel:find(FILTER, 1, true)) then
			suites[#suites + 1] = 'Module:' .. rel
		end
	end
	handle:close()
	return suites
end

local suites = discoverSuites()
if #suites == 0 then
	io.stderr:write(
		string.format(
			'ERROR: no testcases.lua discovered under %s/%s%s — check cwd / REPO_ROOT / config.\n',
			paths.repoRoot,
			config.moduleRoot,
			FILTER and (' matching "' .. FILTER .. '"') or ''
		)
	)
	os.exit(1)
end

-- A module that ships its own testcases.lua is a unit-under-test, never a stub.
-- bootstrap installs inert stubs for the consumer's render primitives (for OTHER
-- suites that only need a string back); clear any such stub for a module we are
-- about to test so the resolver loads its real implementation.
for _, path in ipairs(suites) do
	local unit = path:gsub('/testcases$', '')
	package.preload[unit] = nil
	package.loaded[unit] = nil
end

local totalFail = 0
local ran = 0
for _, path in ipairs(suites) do
	if SKIP[path] then
		print(string.format('%s: SKIPPED (%s)', path, SKIP[path]))
	else
		ran = ran + 1
		local suite = require(path)
		local data = suite:runSuite()
		print(
			string.format(
				'%s: %d ok, %d failed, %d skipped',
				path,
				data.successCount,
				data.failureCount,
				data.skipCount
			)
		)
		for _, r in ipairs(data.results) do
			if r.error then
				totalFail = totalFail + 1
				io.stderr:write(
					string.format('FAIL %s :: %s\n  %s\n', path, r.name, tostring(r.message or ''):gsub('\n', '\n  '))
				)
			end
		end
	end
end

if totalFail > 0 then
	os.exit(1)
end

print(string.format('unit: all %d suites passed', ran))
