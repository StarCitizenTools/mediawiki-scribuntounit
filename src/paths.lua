-- SPDX-License-Identifier: MIT
--- Resolved filesystem roots, populated by run.lua before bootstrap loads anything
--- (a mutable singleton so the lazily-required modules below read the final values).
---   libRoot  — installed library root (contains src/ and vendor/)
---   repoRoot — consumer repo root: where the modules-under-test, their testcases,
---              and scribuntounit.config.lua live. Defaults to $REPO_ROOT or cwd.
---   lualibRoot — resolved Scribunto lualib dir (env SCRIBUNTO_LUALIB / config
---                scribunto.lualib / <repoRoot>/.scribuntounit/lualib); set by
---                bootstrap.lua before mwenv loads.
local M = {
	libRoot = '.',
	repoRoot = os.getenv('REPO_ROOT') or '.',
}
return M
