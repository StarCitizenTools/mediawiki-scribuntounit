-- SPDX-License-Identifier: MIT
require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Catalog = require('Module:Catalog')
local suite = ScribuntoUnit:new()

function suite:testNames()
	self:assertEquals('Alpha, Beta', Catalog.names())
end

function suite:testNotEmpty()
	self:assertFalse(Catalog.isEmpty())
end

return suite
