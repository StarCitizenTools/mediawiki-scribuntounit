-- SPDX-License-Identifier: MIT
--- Minimal ScribuntoUnit-compatible harness for THIS library's self-test only.
--- Real wikis use the canonical Module:ScribuntoUnit (in their own moduleRoot);
--- this implements just the subset the runner contract needs — `:new()`, a few
--- asserts, and `:runSuite()` returning {successCount, failureCount, skipCount,
--- results} — and mirrors canonical ScribuntoUnit's assertThrows location-stripping
--- so the chunk-name fidelity behaviour is exercised.
require('strict')

local ScribuntoUnit = {}
ScribuntoUnit.__index = ScribuntoUnit

function ScribuntoUnit:new()
	return setmetatable({}, ScribuntoUnit)
end

--- Raise a structured assertion failure (level 0 → no location prefix added).
local function fail(message)
	error({ __scribuntoUnit = true, message = message }, 0)
end

function ScribuntoUnit:assertEquals(expected, actual, message)
	if expected ~= actual then
		fail(string.format('%s expected %s, got %s', message or 'assertEquals:', tostring(expected), tostring(actual)))
	end
end

function ScribuntoUnit:assertTrue(value, message)
	if value ~= true then
		fail((message or 'assertTrue') .. ': expected true, got ' .. tostring(value))
	end
end

function ScribuntoUnit:assertFalse(value, message)
	if value ~= false then
		fail((message or 'assertFalse') .. ': expected false, got ' .. tostring(value))
	end
end

function ScribuntoUnit:assertThrows(fn, expectedMessage, message)
	local ok, err = pcall(fn)
	if ok then
		fail((message or 'assertThrows') .. ': expected an error but none was thrown')
	end
	-- Strip the `Module:X:line:` location prefix, exactly like canonical ScribuntoUnit.
	local actual = type(err) == 'string' and string.match(err, 'Module:[^:]*:[0-9]*: (.*)') or err
	if expectedMessage ~= nil and actual ~= expectedMessage then
		fail(
			string.format(
				'%s expected error %q, got %q',
				message or 'assertThrows:',
				tostring(expectedMessage),
				tostring(actual)
			)
		)
	end
end

--- Run every `test*` method on the instance; return the ScribuntoUnit result shape.
function ScribuntoUnit:runSuite()
	local results, successCount, failureCount = {}, 0, 0
	local names = {}
	for k in pairs(self) do
		if type(k) == 'string' and k:match('^test') and type(self[k]) == 'function' then
			names[#names + 1] = k
		end
	end
	table.sort(names)
	for _, name in ipairs(names) do
		local ok, err = pcall(self[name], self)
		if ok then
			successCount = successCount + 1
			results[#results + 1] = { name = name }
		else
			failureCount = failureCount + 1
			local msg = (type(err) == 'table' and err.message) or tostring(err)
			results[#results + 1] = { name = name, error = true, message = msg }
		end
	end
	return { successCount = successCount, failureCount = failureCount, skipCount = 0, results = results }
end

return ScribuntoUnit
