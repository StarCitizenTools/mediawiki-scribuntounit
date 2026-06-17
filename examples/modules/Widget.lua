-- SPDX-License-Identifier: MIT
require('strict')
local example = require('mw.ext.example')

local Widget = {}

--- @param label string
--- @return table  { badge = string, rendered = string }
function Widget.build(label)
	return {
		badge = example.badge(label),
		rendered = example.render({ label = label }),
	}
end

return Widget
