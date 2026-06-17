-- SPDX-License-Identifier: MIT
local suite = require('Module:ScribuntoUnit'):new()
local Tabber = require('Module:Tabber')

-- mw.ext.tabber is the REAL upstream lib (fetched per the manifest). Its render is
-- a php leaf, so headless — with no interface override — it returns the benign ''.
function suite:testFetchedExtensionRenderIsBenign()
	self:assertEquals('', Tabber.render())
end

return suite
