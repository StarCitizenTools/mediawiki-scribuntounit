-- SPDX-License-Identifier: MIT
--- Example consumer config, used by this library's own self-test. A real wiki
--- drops a file like this at its repo root (see README).
return {
	-- Modules + testcases live under examples/modules/ (relative to REPO_ROOT).
	moduleRoot = 'modules',

	-- Pin the Scribunto lualib ref the self-test fetches.
	scribunto = { ref = 'REL1_43' },

	-- Extension libraries: load real .lua and stub only PHP leaves. Local fixture
	-- here; a fetched one (mw.ext.tabber) is added in Task 2.
	libraries = {
		['mw.ext.example'] = {
			path = 'extlibs/mw.ext.example.lua',
			interface = {
				render = function(opts)
					return 'RENDER:' .. tostring(opts and opts.label or '')
				end,
			},
		},
	},

	-- Render primitives with no headless-safe implementation: install as inert
	-- stubs so suites that only need a string back don't drag in the real module.
	stubs = { 'Icon' },

	-- Extend the env: register a custom stub and a mw.ext.* stand-in.
	setup = function(api)
		-- A custom stub that echoes its text (how a consumer stands in for a render
		-- module whose output a logic test still inspects).
		api.stub('Badge', {
			render = function(opts)
				return 'BADGE:' .. tostring(opts and opts.text or '')
			end,
		})
		-- A require-able mw.ext.* stand-in for an extension used at module load.
		api.preload('mw.ext.examplewidget', function()
			return {
				label = function(t)
					return 'WIDGET:' .. tostring(t)
				end,
			}
		end)
	end,
}
