-- SPDX-License-Identifier: MIT
require('strict')
local tabber = require('mw.ext.tabber')

local Tabber = {}

--- Call the fetched extension's render leaf (benign '' headless).
--- @return string
function Tabber.render()
	return tabber.render({ { label = 'A', content = 'x' } })
end

return Tabber
