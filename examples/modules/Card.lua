-- SPDX-License-Identifier: MIT
--- Example module: exercises mw.html (real vendored builder), an INERT stub
--- dependency (Module:Icon, listed in config.stubs), a CUSTOM stub registered by
--- the config setup hook (Module:Badge, echoes its text), and a require-able
--- mw.ext.* stand-in (also from the setup hook).
require('strict')

local icon = require('Module:Icon') -- inert stub: every method returns ''
local badge = require('Module:Badge') -- custom stub: render{text=…} → 'BADGE:…'
local widget = require('mw.ext.examplewidget') -- mw.ext stand-in: label(t) → 'WIDGET:…'

local p = {}

--- @param title string
--- @return string
function p.render(title)
	local html = tostring(mw.html.create('div'):addClass('card'):wikitext(title))
	return html .. icon.render() .. badge.render({ text = title }) .. widget.label(title)
end

return p
