-- SPDX-License-Identifier: MIT
--- Example module: exercises mw.text (decode/trim), mw.ustring (UTF-8 char via
--- numeric-entity decode), mw.language (grouped formatNum), and an error path
--- (for assertThrows + the Module:-name chunk loading).
require('strict')

local p = {}

--- Decode HTML entities and trim. `&#160;` → the UTF-8 no-break space.
--- @param s any
--- @return string
function p.clean(s)
	return mw.text.trim(mw.text.decode(tostring(s)))
end

--- Format a number with thousands grouping.
--- @param n number
--- @return string
function p.number(n)
	return mw.getContentLanguage():formatNum(n)
end

--- Greet by name; errors when the name is empty.
--- @param name string
--- @return string
function p.greet(name)
	if not name or name == '' then
		error('name is required')
	end
	return 'Hello, ' .. name
end

return p
