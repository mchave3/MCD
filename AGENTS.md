# Agent Notes for This Repo (MCD)

This repository is a PowerShell module using the DSC Community "Sampler" pipeline:
Invoke-Build + ModuleBuilder + Pester + PSScriptAnalyzer.

No Cursor rules found (`.cursor/rules/`, `.cursorrules`).
No Copilot rules found (`.github/copilot-instructions.md`).

## Repo Layout
- Entry point: `build.ps1`
- Build config: `build.yaml`
- Source: `source/` (Public/Private/Classes/en-US/...)
- Tests: `tests/` (Unit + QA)
- Build output (ignored): `output/`

## Build / Lint / Test
Run with either:
- PowerShell 7+: `pwsh -NoProfile -File ./build.ps1 ...`
- Windows PowerShell 5.1: `powershell -NoProfile -ExecutionPolicy Bypass -File .\\build.ps1 ...`

Bootstrap deps:
- Restore required modules only (no build): `./build.ps1 -ResolveDependency -Tasks noop`
- Dependency defaults: `Resolve-Dependency.psd1` (PSResourceGet enabled by default)
- Required module list: `RequiredModules.psd1`

Common workflows (from `build.yaml`):
- Default (build + test): `./build.ps1` or `./build.ps1 -Tasks .`
- Build: `./build.ps1 -Tasks build` (`Clean`, `Build_Module_ModuleBuilder`, `Generate_Repo_Docs`)
- Test: `./build.ps1 -Tasks test` (`Pester_Tests_Stop_On_Fail`, `Pester_if_Code_Coverage_Under_Threshold`)
- Docs: `./build.ps1 -Tasks docs`
- Pack: `./build.ps1 -Tasks pack`
- Publish: `./build.ps1 -Tasks publish`

Notes:
- Pester output format defaults to `NUnitXML` (`build.yaml`).
- Code coverage threshold defaults to 85% (`build.yaml:Pester:CodeCoverageThreshold`).
- VS Code task `test` uses auto-restore: `./build.ps1 -AutoRestore -Tasks test`
- `build.ps1` auto-detects config files named `build.y*ml`, `build.psd1`, `build.json*`.
- You can override the coverage threshold: `./build.ps1 -Tasks test -CodeCoverageThreshold 0`

Run a single Invoke-Build task (any task name from `build.yaml`):
- `./build.ps1 -Tasks Clean`
- `./build.ps1 -Tasks Build_Module_ModuleBuilder`
- `./build.ps1 -Tasks Generate_Repo_Docs` (local task in `.build/GenerateDocs.build.ps1`)

## Running Tests (Pester)
Recommended: `./build.ps1 -Tasks test`

Run a single test file/folder via `build.ps1`:
- Uses `-PesterScript` (alias `-PesterPath`).
- Single file: `./build.ps1 -Tasks test -PesterPath tests/Unit/Public/Get-Something.tests.ps1`
- Folder: `./build.ps1 -Tasks test -PesterPath tests/Unit`

Run a subset by tag via `build.ps1`:
- Only a tag: `./build.ps1 -Tasks test -PesterTag FunctionalQuality`
- Exclude a tag: `./build.ps1 -Tasks test -PesterExcludeTag helpQuality`
- Tags used here: `FunctionalQuality`, `TestQuality`, `helpQuality` (`tests/QA/module.tests.ps1`).

Run QA-only tests (no build wrapper filtering):
- `pwsh -NoProfile -Command "Invoke-Pester -Path 'tests/QA'"`

Direct Pester (advanced filters):
- `pwsh -NoProfile -Command "Invoke-Pester -Path 'tests/Unit'"`
- `pwsh -NoProfile -Command "Invoke-Pester -Path 'tests/QA' -TagFilter 'FunctionalQuality'"`
- Filter by full test name (Describe/It): `pwsh -NoProfile -Command "Invoke-Pester -Path 'tests/Unit' -FullNameFilter '*Get-Something*'"`
- Inspect available params: `pwsh -NoProfile -Command "Get-Help Invoke-Pester -Full"`

## Lint (PSScriptAnalyzer)
Linting is enforced by QA tests (`tests/QA/module.tests.ps1`).
- Full pipeline: `./build.ps1 -Tasks test`
- Direct: `pwsh -NoProfile -Command "Invoke-ScriptAnalyzer -Path 'source' -Recurse -Settings '.vscode/analyzersettings.psd1'"`

Key rules enabled in this repo (see `.vscode/analyzersettings.psd1`):
- `PSUseApprovedVerbs`, `PSAvoidUsingCmdletAliases`, `PSAvoidUsingPositionalParameters`
- `PSAvoidUsingWriteHost`, `PSAvoidUsingInvokeExpression`, `PSAvoidUsingEmptyCatchBlock`
- `PSShouldProcess`, `PSProvideCommentHelp`, `PSUsePSCredentialType`

## Docs
- Docs are generated from comment-based help.
- Generator: `Generate_Repo_Docs` in `.build/GenerateDocs.build.ps1`
- Output: `docs/Public/*.md`, `docs/Private/*.md` (generated; do not edit by hand)

## Code Style (PowerShell)
Source of truth: `.vscode/settings.json` (formatting) + `.vscode/analyzersettings.psd1` (rules) + https://dsccommunity.org/styleguidelines

Formatting:
- Allman braces; 4-space indent; no tabs.
- Pipeline indentation: IncreaseIndentationAfterEveryPipeline.
- Trim trailing whitespace; ensure final newline.

Naming:
- Functions: `Verb-Noun` with approved verbs (`PSUseApprovedVerbs`).
- Avoid aliases and positional parameters (`PSAvoidUsingCmdletAliases`, `PSAvoidUsingPositionalParameters`).

Module layout:
- Do not edit `source/MCD.psm1` (intentionally empty; recreated during build).
- Public: `source/Public/*.ps1`; Private: `source/Private/*.ps1`; Classes: `source/Classes/*.ps1`.

Types / outputs:
- Prefer explicit parameter types (example: `source/Public/Get-Something.ps1`).
- Add `[OutputType([Type])]` when reasonable (example: `source/Private/Get-PrivateFunction.ps1`).
- Avoid `Write-Host` (`PSAvoidUsingWriteHost`).

Common function shape:
- Use `[CmdletBinding()]` (advanced function) + `param (...)` on its own lines.
- Use `process { }` when accepting pipeline input.
- Prefer `Write-Verbose -Message ...` for optional output; return data via `Write-Output`/implicit output.

ShouldProcess:
- If a function changes state, implement `SupportsShouldProcess = $true` and guard with `$PSCmdlet.ShouldProcess(...)` (`PSShouldProcess`).

Error handling / security:
- No empty `catch` blocks (`PSAvoidUsingEmptyCatchBlock`); use `-ErrorAction Stop` where you intend to catch.
- Avoid `Invoke-Expression` (`PSAvoidUsingInvokeExpression`).
- No plaintext passwords; use `[PSCredential]` params (`PSAvoidUsingPlainTextForPassword`, `PSUsePSCredentialType`).

## Quality Gates
- QA asserts every exported function has a unit test file (`tests/QA/module.tests.ps1`).
- QA enforces comment-based help: `.SYNOPSIS`, `.DESCRIPTION` (>40 chars), >=1 example, and per-parameter descriptions.

Comment-based help expectations (enforced in `tests/QA/module.tests.ps1`):
- `.DESCRIPTION` must be descriptive (length > 40 characters).
- At least one example.
- Every parameter must have a description (and be reasonably descriptive).

When adding a new function:
- Public functions go in `source/Public/<Verb-Noun>.ps1` with comment-based help.
- Add a matching unit test under `tests/Unit/Public/<Verb-Noun>.tests.ps1`.
- If you add state-changing behavior, add `SupportsShouldProcess = $true` and tests for `-WhatIf`.

## Repo Hygiene
- Line endings: `.gitattributes` (`* text eol=autocrlf`).
- Ignore patterns: `.gitignore` (includes `output/`, `node_modules`, `package-lock.json`).
- VS Code tasks: `.vscode/tasks.json` (`build`, `test`).
- Local-only scripts live in `source/Examples/` (ignored by git).

## PR Expectations
- Keep PRs atomic; follow checklist in `.github/PULL_REQUEST_TEMPLATE.md`.
- Run a clean local build/test before asking for review.
