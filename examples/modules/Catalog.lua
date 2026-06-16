-- SPDX-License-Identifier: MIT
--- Example module: exercises mw.loadJsonData + the frozen-table semantics (the
--- `#` length operator is unreliable on the frozen result, so emptiness is
--- checked with `[1] == nil`, the documented guard).
require('strict')

local data = mw.loadJsonData('Module:Catalog/items.json')

local p = {}

--- @return string  comma-joined item names
function p.names()
	local out = {}
	for _, item in ipairs(data.items) do
		out[#out + 1] = item.name
	end
	return table.concat(out, ', ')
end

--- @return boolean  whether the catalog is empty (next()/[1] guard, not #)
function p.isEmpty()
	return data.items[1] == nil
end

return p
