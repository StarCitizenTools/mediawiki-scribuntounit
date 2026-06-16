-- SPDX-License-Identifier: MIT
--- Assembles a headless `mw` global sufficient to load and run ScribuntoUnit
--- suites off-wiki. Built in two layers:
---   1. A minimal core (loadData/loadJsonData, getCurrentFrame stub, ustring
---      find/format/sub + UTF-8 char/codepoint, dumpObject, title/site stubs).
---   2. The vendored pure-Lua lualib (mw.text, mw.uri, mw.html) headless-
---      initialised on top, so format-touching suites have a real surface, plus
---      a shim for the PHP-coupled mw.language. Failures here are isolated and
---      reported via mwenv.lualibStatus rather than breaking the minimal core.
---
--- Consumer-specific surface (mw.ext.*, extra stubs) is added by the consumer's
--- scribuntounit.config.lua `setup` hook, NOT here. Returns the assembled mw
--- table; bootstrap.lua sets _G.mw.
local paths = require('paths')
local shims = require('shims')

local function vendorDir()
	return paths.libRoot .. '/vendor/mw'
end

local M = {}

-- ── Minimal core ─────────────────────────────────────────────────────────────

--- A benign frame object. Pure-logic suites never call its methods, but
--- ScribuntoUnit:init stores `mw.getCurrentFrame()` as self.frame.
local function makeFrame()
	local frame = {}
	frame.args = {}
	function frame:preprocess(text)
		return text
	end
	function frame:getParent()
		return nil
	end
	function frame:expandTemplate()
		return ''
	end
	function frame:callParserFunction()
		return ''
	end
	-- templatestyles injection: render facets call frame:extensionTag{...}; the
	-- strip marker is not needed off-wiki.
	function frame:extensionTag()
		return ''
	end
	function frame:newChild()
		return makeFrame()
	end
	return frame
end

local currentFrame = makeFrame()

local mw = {}

mw.loadData = shims.loadData
mw.loadJsonData = shims.loadJsonData

function mw.getCurrentFrame()
	return currentFrame
end

--- mw.log / mw.logObject: no-op sinks off-wiki (only used by display paths).
function mw.log() end
function mw.logObject() end

--- Minimal mw.dumpObject — a stable, readable serialisation for assertion
--- failure messages. Not byte-identical to the on-wiki PHP dumper, but adequate.
function mw.dumpObject(object)
	local seen = {}
	local function dump(v, indent)
		local t = type(v)
		if t == 'table' then
			if seen[v] then
				return '<recursive table>'
			end
			seen[v] = true
			local parts = {}
			local keys = {}
			for k in pairs(v) do
				keys[#keys + 1] = k
			end
			table.sort(keys, function(a, b)
				return tostring(a) < tostring(b)
			end)
			for _, k in ipairs(keys) do
				parts[#parts + 1] = indent .. '  [' .. dump(k, '') .. '] = ' .. dump(v[k], indent .. '  ')
			end
			seen[v] = nil
			if #parts == 0 then
				return 'table#1 {}'
			end
			return 'table#1 {\n' .. table.concat(parts, ',\n') .. ',\n' .. indent .. '}'
		elseif t == 'string' then
			return string.format('%q', v)
		else
			return tostring(v)
		end
	end
	return dump(object, '')
end

-- Minimal ustring — delegate to Lua string.* (ASCII-correct); the lualib layer
-- does not replace these (we do not vendor the full ustring lib).
mw.ustring = {
	format = string.format,
	sub = string.sub,
	len = string.len,
	upper = string.upper,
	lower = string.lower,
	rep = string.rep,
	gsub = string.gsub,
	gmatch = string.gmatch,
	match = string.match,
}

--- ustring.find delegating to string.find. ScribuntoUnit calls find(s, pattern,
--- nil, plain); Lua's string.find treats a nil `init` as 1, so this matches.
function mw.ustring.find(s, pattern, init, plain)
	return string.find(s, pattern, init, plain)
end

--- ustring.char(...): encode each Unicode codepoint argument to UTF-8. The
--- byte-wise shim delegates most ops to string.*, but codepoint→UTF-8 is genuinely
--- multibyte (string.char can't do it); mw.text.decode needs this to expand
--- numeric entities (&#160;). A focused encoder, not the full ustring lib.
function mw.ustring.char(...)
	local out = {}
	for _, cp in ipairs({ ... }) do
		cp = math.floor(cp)
		if cp < 0x80 then
			out[#out + 1] = string.char(cp)
		elseif cp < 0x800 then
			out[#out + 1] = string.char(0xC0 + math.floor(cp / 0x40), 0x80 + cp % 0x40)
		elseif cp < 0x10000 then
			out[#out + 1] =
				string.char(0xE0 + math.floor(cp / 0x1000), 0x80 + math.floor(cp / 0x40) % 0x40, 0x80 + cp % 0x40)
		else
			out[#out + 1] = string.char(
				0xF0 + math.floor(cp / 0x40000),
				0x80 + math.floor(cp / 0x1000) % 0x40,
				0x80 + math.floor(cp / 0x40) % 0x40,
				0x80 + cp % 0x40
			)
		end
	end
	return table.concat(out)
end

--- ustring.codepoint(s, i): the codepoint of the UTF-8 character at byte offset i
--- (default 1). Single-character form (sufficient for the decode paths here).
function mw.ustring.codepoint(s, i)
	s = tostring(s)
	i = i or 1
	local b = s:byte(i)
	if not b then
		return nil
	end
	if b < 0x80 then
		return b
	elseif b < 0xE0 then
		return (b - 0xC0) * 0x40 + (s:byte(i + 1) - 0x80)
	elseif b < 0xF0 then
		return (b - 0xE0) * 0x1000 + (s:byte(i + 1) - 0x80) * 0x40 + (s:byte(i + 2) - 0x80)
	end
	return (b - 0xF0) * 0x40000
		+ (s:byte(i + 1) - 0x80) * 0x1000
		+ (s:byte(i + 2) - 0x80) * 0x40
		+ (s:byte(i + 3) - 0x80)
end

-- Minimal mw.text — replaced by the vendored lib when it loads.
mw.text = {
	nowiki = function(s)
		return tostring(s)
	end,
	trim = function(s)
		return (tostring(s):gsub('^%s*(.-)%s*$', '%1'))
	end,
}

-- ── Title stub ───────────────────────────────────────────────────────────────
local titleStub = {
	nsText = '',
	prefixedText = 'Sandbox/Test',
	fullText = 'Sandbox/Test',
	text = 'Test',
	namespace = 0,
}
function titleStub:inNamespace(ns)
	return self.namespace == ns or self.nsText == ns
end

mw.title = {
	getCurrentTitle = function()
		return titleStub
	end,
	makeTitle = function(_, text)
		local t = {}
		for k, v in pairs(titleStub) do
			if type(v) ~= 'function' then
				t[k] = v
			end
		end
		t.text = text or t.text
		t.fullText = text or t.fullText
		t.inNamespace = titleStub.inNamespace
		return t
	end,
	new = function(text)
		return mw.title.makeTitle(0, text)
	end,
}

-- ── Site stub ────────────────────────────────────────────────────────────────
-- Minimal mw.site exposing the File namespace (id 6) that file-link helpers read.
-- name/canonicalName/aliases mirror a default MediaWiki; consumers can override
-- via the config setup hook.
mw.site = {
	namespaces = {
		[6] = { id = 6, name = 'File', canonicalName = 'File', aliases = { 'Image' } },
	},
}

-- ── Vendored lualib layer ────────────────────────────────────────────────────
-- Headless-initialise the pure-Lua libraries. Each exposes setupInterface(opts)
-- that, on-wiki, receives a PHP callback table; headless we pass minimal opts and
-- Lua stand-ins for the few PHP callbacks the pure-Lua paths invoke.

M.lualibStatus = {} -- lib name -> 'lualib' | 'shim' | 'minimal' | error string

local function fileExists(p)
	local f = io.open(p, 'r')
	if f then
		f:close()
		return true
	end
	return false
end

--- Load a vendored lualib file by basename; returns the module value or nil + err.
local function loadVendored(basename)
	local path = vendorDir() .. '/' .. basename
	if not fileExists(path) then
		return nil, 'not vendored: ' .. path
	end
	local chunk, err = loadfile(path)
	if not chunk then
		return nil, err
	end
	local ok, mod = pcall(chunk)
	if not ok then
		return nil, mod
	end
	return mod
end

-- The vendored libs require their siblings by bare/slashed names (`libraryUtil`,
-- etc.). Install one loader resolving those against vendor/mw/.
local function vendorLoader(name)
	local candidates = {
		vendorDir() .. '/' .. name .. '.lua',
		vendorDir() .. '/' .. name:gsub('%.', '/') .. '.lua',
	}
	for _, p in ipairs(candidates) do
		if fileExists(p) then
			local chunk, err = loadfile(p)
			if not chunk then
				return '\n\t[vendor] load error in ' .. p .. ': ' .. tostring(err)
			end
			return chunk
		end
	end
	return nil
end

local function installVendorLoader()
	for _, l in ipairs(package.loaders) do
		if l == vendorLoader then
			return
		end
	end
	table.insert(package.loaders, vendorLoader)
end

--- Headless-init one lualib. Reproduces the on-wiki contract: publish _G.mw, set
--- _G.mw_interface to the (possibly empty) PHP-callback stand-in, call setupInterface.
--- @param libKey string  status key, e.g. 'mw.html'
--- @param basename string  vendored file, e.g. 'mw.html.lua'
--- @param opts table  setupInterface options
--- @param iface table|nil  mw_interface stand-in (defaults to {})
--- @param onFail function|nil  fallback installer if init throws
local function initLib(libKey, basename, opts, iface, onFail)
	local mod, err = loadVendored(basename)
	if not (mod and mod.setupInterface) then
		M.lualibStatus[libKey] = 'minimal (' .. tostring(err) .. ')'
		if onFail then
			onFail(mw)
		end
		return
	end
	local prevMw = _G.mw
	_G.mw = mw
	_G.mw_interface = iface or {}
	local ok, perr = pcall(mod.setupInterface, opts)
	_G.mw = prevMw
	_G.mw_interface = nil
	if ok then
		M.lualibStatus[libKey] = 'lualib'
	else
		M.lualibStatus[libKey] = (onFail and 'shim (' or 'minimal (') .. tostring(perr) .. ')'
		if onFail then
			onFail(mw)
		end
	end
end

local function installLualib()
	installVendorLoader()

	M.lualibStatus['mw.ustring'] = 'shim (byte-wise + UTF-8 char/codepoint; not vendored)'

	-- mw.text — fast paths (trim/encode/decode/split) are pure-Lua; the few PHP
	-- paths (unstrip/killMarkers/json*) are stubbed to error only if actually hit.
	initLib('mw.text', 'mw.text.lua', {
		comma = ', ',
		['and'] = ' and ',
		ellipsis = '…',
		nowiki_protocols = {},
	}, {
		unstrip = function(s)
			return s
		end,
		unstripNoWiki = function(s)
			return s
		end,
		killMarkers = function(s)
			return s
		end,
		getEntityTable = function()
			return {}
		end,
		jsonEncode = function()
			error('[mwenv] mw.text.jsonEncode PHP path not available headless', 2)
		end,
		jsonDecode = function()
			error('[mwenv] mw.text.jsonDecode PHP path not available headless', 2)
		end,
	})
	if package.loaded['mw.text'] then
		mw.text = package.loaded['mw.text']
	end

	-- mw.uri — encode/decode helpers are pure-Lua; fall back to the focused shim
	-- if full init throws (it reads more PHP callbacks than we provide).
	initLib('mw.uri', 'mw.uri.lua', {
		defaultUrl = 'https://example.org/wiki/Main_Page',
		ALL = 'all',
	}, {}, M.installUriShim)
	if M.lualibStatus['mw.uri'] == 'lualib' and package.loaded['mw.uri'] then
		mw.uri = package.loaded['mw.uri']
	end

	-- mw.html — fully self-contained builder; needs only the uniq markers.
	initLib('mw.html', 'mw.html.lua', { uniqPrefix = '\127UNIQ', uniqSuffix = '\127' }, {})
	if package.loaded['mw.html'] then
		mw.html = package.loaded['mw.html']
	end

	-- Content language: the full mw.language lib needs deep PHP locale callbacks,
	-- so we shim the methods format-facing code uses.
	M.installLanguageShim(mw)
end

--- Minimal mw.uri shim: encode (QUERY component) + decode.
function M.installUriShim(target)
	target.uri = target.uri or {}
	function target.uri.encode(s, enctype)
		s = tostring(s)
		local space = '+'
		if enctype == 'PATH' or enctype == 'WIKI' then
			space = '%20'
		end
		s = s:gsub('([^%w%-_%.~])', function(c)
			if c == ' ' then
				return space
			end
			return string.format('%%%02X', string.byte(c))
		end)
		return s
	end
	function target.uri.decode(s)
		s = tostring(s):gsub('+', ' '):gsub('%%(%x%x)', function(h)
			return string.char(tonumber(h, 16))
		end)
		return s
	end
end

--- Minimal mw.language / getContentLanguage shim with grouped formatNum.
function M.installLanguageShim(target)
	if target.language and target.getContentLanguage then
		return
	end
	local lang = {}
	--- Group integer part with thousands separators (en grouping).
	function lang:formatNum(n)
		if type(n) ~= 'number' then
			n = tonumber(n) or 0
		end
		local neg = n < 0
		local intPart = math.modf(math.abs(n))
		local s = string.format('%d', intPart)
		local grouped = s:reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
		local out = grouped
		local fracPart = math.abs(n) - intPart
		if fracPart ~= 0 then
			out = out .. (string.format('%g', fracPart):gsub('^0', ''))
		end
		if neg then
			out = '−' .. out -- U+2212 minus, matching mw.language:formatNum on-wiki
		end
		return out
	end
	function lang:getCode()
		return 'en'
	end
	function lang:ucfirst(s)
		return (tostring(s):gsub('^%l', string.upper))
	end
	function lang:lcfirst(s)
		return (tostring(s):gsub('^%u', string.lower))
	end
	function lang:lc(s)
		return string.lower(tostring(s))
	end
	function lang:uc(s)
		return string.upper(tostring(s))
	end
	target.language = {
		new = function()
			return lang
		end,
		getContentLanguage = function()
			return lang
		end,
		fetchLanguageName = function()
			return ''
		end,
	}
	function target.getContentLanguage()
		return lang
	end
	M.lualibStatus['mw.language'] = M.lualibStatus['mw.language'] or 'shim'
end

-- Build the lualib layer; isolate any catastrophic failure so the minimal core
-- still works.
local ok, err = pcall(installLualib)
if not ok then
	M.lualibStatus['_install'] = 'failed: ' .. tostring(err)
	M.installUriShim(mw)
	M.installLanguageShim(mw)
end

M.mw = mw
return M
