-- SPDX-License-Identifier: MIT
local suite = require('Module:ScribuntoUnit'):new()
local Widget = require('Module:Widget')

-- The real fixture Lua loaded: badge is a pure-Lua helper.
function suite:testBadgeUsesRealHelper()
	self:assertEquals('BADGE[Ship]', Widget.build('Ship').badge)
end

-- The consumer's interface override wins for the PHP leaf.
function suite:testRenderUsesInterfaceOverride()
	self:assertEquals('RENDER:Ship', Widget.build('Ship').rendered)
end

return suite
