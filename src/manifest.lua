-- SPDX-License-Identifier: MIT
--- Builds the fetch manifest: the list of upstream sources that
--- bin/scribuntounit-fetch downloads, derived from the consumer config. Each
--- entry is { repo, ref, src, dest }; rendered as TAB-separated lines so the
--- POSIX-sh helper can parse them with `while read`.
local M = {}

local SCRIBUNTO_REPO = 'wikimedia/mediawiki-extensions-Scribunto'
local LUALIB_SRC = 'includes/Engines/LuaCommon/lualib'
local LUALIB_DEST = '.scribuntounit/lualib'

-- TODO: a later change will append extension-library entries to this list.
--- @param config table  loaded consumer config (uses config.scribunto.ref)
--- @return table[]  list of { repo, ref, src, dest }
function M.build(config)
	local scribunto = config.scribunto or {}
	-- SCRIBUNTO_REF env wins (CI matrix override); else config; else REL1_43.
	local ref = os.getenv('SCRIBUNTO_REF') or scribunto.ref or 'REL1_43'
	return {
		{ repo = SCRIBUNTO_REPO, ref = ref, src = LUALIB_SRC, dest = LUALIB_DEST },
	}
end

--- Render entries as TAB-separated lines (repo, ref, src, dest), newline-terminated.
--- @param config table
--- @return string
function M.render(config)
	local out = {}
	for _, e in ipairs(M.build(config)) do
		out[#out + 1] = table.concat({ e.repo, e.ref, e.src, e.dest }, '\t')
	end
	return table.concat(out, '\n') .. '\n'
end

return M
