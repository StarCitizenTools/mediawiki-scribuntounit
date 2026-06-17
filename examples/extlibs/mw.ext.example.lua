-- SPDX-License-Identifier: MIT
-- A minimal Scribunto external library for the self-test: one pure-Lua helper
-- (example.badge) and one PHP leaf (example.render -> php.render).
local example = {}
local php

function example.setupInterface()
	example.setupInterface = nil
	php = mw_interface
	mw_interface = nil
	mw = mw or {}
	mw.ext = mw.ext or {}
	mw.ext.example = example
	package.loaded['mw.ext.example'] = example
end

--- Pure-Lua helper (real logic, no PHP): format a badge label.
--- @param text string
--- @return string
function example.badge(text)
	return 'BADGE[' .. tostring(text) .. ']'
end

--- PHP leaf: server-side render. Headless it returns the benign '' default unless
--- the consumer's interface overrides it.
--- @param opts table
--- @return string
function example.render(opts)
	return php.render(opts)
end

return example
