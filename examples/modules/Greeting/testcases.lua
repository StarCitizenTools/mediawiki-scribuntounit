-- SPDX-License-Identifier: MIT
require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Greeting = require('Module:Greeting')
local suite = ScribuntoUnit:new()

-- mw.text.decode → mw.ustring.char: &#160; becomes the UTF-8 no-break space (\194\160).
function suite:testCleanDecodesNbsp()
	self:assertEquals('a\194\160b', Greeting.clean('  a&#160;b  '))
end

-- mw.language:formatNum grouping.
function suite:testNumberGroups()
	self:assertEquals('1,234,567', Greeting.number(1234567))
end

function suite:testGreet()
	self:assertEquals('Hello, World', Greeting.greet('World'))
end

-- assertThrows + the chunk-name fix: the error location must read Module:Greeting:line:
-- so the location prefix strips cleanly to the bare message.
function suite:testGreetRequiresName()
	self:assertThrows(function()
		Greeting.greet('')
	end, 'name is required')
end

return suite
