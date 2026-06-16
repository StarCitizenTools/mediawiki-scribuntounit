-- SPDX-License-Identifier: MIT
require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Card = require('Module:Card')
local suite = ScribuntoUnit:new()

function suite:testRenderIsString()
	self:assertEquals('string', type(Card.render('Hi')))
end

function suite:testRenderUsesRealMwHtml()
	local out = Card.render('Hi')
	self:assertTrue(out:find('class="card"', 1, true) ~= nil, 'mw.html should emit the class attribute')
	self:assertTrue(out:find('Hi', 1, true) ~= nil, 'should contain the title')
end

-- The custom setup-hook stub (Badge) and the mw.ext stand-in both contribute.
function suite:testRenderUsesSetupHookStubs()
	local out = Card.render('Hi')
	self:assertTrue(out:find('BADGE:Hi', 1, true) ~= nil, 'custom Badge stub should echo')
	self:assertTrue(out:find('WIDGET:Hi', 1, true) ~= nil, 'mw.ext.examplewidget should contribute')
end

return suite
