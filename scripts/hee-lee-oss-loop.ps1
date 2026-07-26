<#
.SYNOPSIS
  Hee-Lee Oss donated-lane loop: pull the next good-deed task, build it with any registry agent,
  and open a PR. A thin wrapper over the installed `hee-lee-oss` CLI — it never hardcodes a vendor
  binary. `--agent <registry-id>` selects ANY agent listed in adapters/registry.json (claude-code,
  aider, codex, gemini-cli, cursor-agent, ...); the CLI's `dispatch` command resolves that agent's
  real command, model, and permission flags for you. See the "Registry-driven agents" section in
  README.md next to this script for how to add or pick an agent.

  This script never authenticates or installs a coding agent for you — that's on you, same as
  running it yourself. It only shells out to whatever agent CLI the registry says to run, on your
  own subscription/account (the donated compute lane). Every dispatch resolves the supervised
  (ask-before-edit) permission fragment for the chosen agent — this loop never escalates to an
  unattended/auto-approve mode.

.PARAMETER Count
  How many deed slots to attempt before stopping.
.PARAMETER Agent
  Registry agent id to build with (default: claude-code). Run `hee-lee-oss agents` to list what's
  installed/registered. Examples: claude-code, gemini-cli, codex, aider, cursor-agent.
.PARAMETER Project
  Pin to one project repo slug (Hee-Lee-Oss-Projects/<slug>) instead of auto-rotating.
.PARAMETER NoFork
  Clone the target repo directly instead of forking (only if you have push access).
.PARAMETER DryRun
  Show what would run for each deed slot without actually building or submitting anything.

.EXAMPLE
  ./hee-lee-oss-loop.ps1 -Count 5
.EXAMPLE
  ./hee-lee-oss-loop.ps1 -Count 5 -Agent gemini-cli
.EXAMPLE
  ./hee-lee-oss-loop.ps1 -Count 5 -Agent codex -Project tool-atlas
#>
[CmdletBinding()]
param(
    [int]$Count = 10,
    [string]$Agent = 'claude-code',
    [string]$Project,
    [string]$Lane = 'donated',
    [switch]$NoFork,
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'

# --- Resolve the CLI: prefer the globally installed binary; fall back to a local checkout next to
#     this script (useful when this repo is vendored inside a larger workspace). Never assume a
#     vendor agent binary is installed here -- only the neutral `hee-lee-oss` CLI.
$onPath = [bool](Get-Command hee-lee-oss -ErrorAction SilentlyContinue)
$localBin = Join-Path $PSScriptRoot 'node_modules/.bin/hee-lee-oss'
if (-not $onPath -and -not (Test-Path $localBin)) {
    Write-Error "hee-lee-oss CLI not found on PATH or at $localBin. Install it first: npm install -g @hee-lee-oss/cli (see README.md)."
    exit 1
}
function Invoke-HeeLeeOss {
    param([Parameter(ValueFromRemainingArguments = $true)] $RestArgs)
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
        if ($onPath) { & hee-lee-oss @RestArgs } else { & $localBin @RestArgs }
    } finally { $ErrorActionPreference = $old }
}

$BuildPrompt = 'Read .hee-lee-oss/TASK.md and .hee-lee-oss/CONTEXT.md, then produce the deliverable at the task output path. Work through EVERY acceptance criterion explicitly and satisfy each one - do not stop until all are met. Honor the refusal guardrails in CONTEXT.md - if the task would cause harm, mislead, give unqualified high-stakes advice without review, primarily benefit a for-profit, or violate a license or privacy, STOP and write nothing.'

# --- Generic agent runner: works for ANY registry entry, never hardcodes a vendor binary. The
#     dispatch plan (from `hee-lee-oss dispatch`) carries the resolved command/args/promptChannel
#     plus auth.scrubEnv -- the env vars that must be unset so the call bills to this agent's own
#     subscription/account rather than silently picking up a stray API key. This mirrors (in
#     simplified form) Invoke-Agent in scripts/ignite/HeeLeeOssIgnite.psm1 in the main repo.
function Invoke-RegistryAgent {
    param([pscustomobject]$Dispatch, [string]$Prompt, [string]$WorkingDir)
    $inv = $Dispatch.invocation
    if (-not $inv -or -not $inv.command) {
        throw "agent '$($Dispatch.agentId)' has no CLI invocation (kind: $($Dispatch.kind))"
    }
    $scrub = @()
    if ($Dispatch.auth -and $Dispatch.auth.scrubEnv) { $scrub = @($Dispatch.auth.scrubEnv) }
    $keyEnv = $null
    if ($Dispatch.auth -and $Dispatch.auth.keyEnv) { $keyEnv = "$($Dispatch.auth.keyEnv)" }
    $had = @{}; $saved = @{}
    foreach ($e in $scrub) {
        $had[$e] = Test-Path "Env:$e"
        if ($had[$e]) { $saved[$e] = (Get-Item "Env:$e").Value; Remove-Item "Env:$e" -ErrorAction SilentlyContinue }
    }
    # Never echo the key itself -- just note (once, non-secret) that a scrub happened, so a human
    # watching the loop knows a stray env var would otherwise have flipped billing to API.
    if ($keyEnv -and ($scrub -contains $keyEnv) -and $had[$keyEnv]) {
        Write-Host "loop: scrubbed $keyEnv from the environment for this call ($($Dispatch.agentId) stays on your subscription, not billed to API)" -ForegroundColor Yellow
    }
    Push-Location $WorkingDir
    $prevOut = [Console]::OutputEncoding
    try {
        try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }
        $agentArgs = @($inv.args)
        if ($inv.promptChannel -eq 'arg') {
            return (& $inv.command @agentArgs $Prompt 2>&1 | Out-String)
        }
        return ($Prompt | & $inv.command @agentArgs 2>&1 | Out-String)
    } finally {
        try { [Console]::OutputEncoding = $prevOut } catch { }
        Pop-Location
        foreach ($e in $scrub) { if ($had[$e]) { Set-Item "Env:$e" $saved[$e] } }
    }
}

$built = @(); $held = @(); $noChange = @()

for ($i = 1; $i -le $Count; $i++) {
    Write-Host "`n=== deed $i / $Count (agent: $Agent) ===" -ForegroundColor Cyan

    $nextArgs = @('next', '--lane', $Lane)
    if ($Project) { $nextArgs += @('--repo', "Hee-Lee-Oss-Projects/$Project") }
    if ($NoFork) { $nextArgs += '--no-fork' }
    $out = (Invoke-HeeLeeOss @nextArgs 2>&1 | Out-String)
    $m = [regex]::Match($out, 'HEE_LEE_OSS_NEXT taskId=(\S+) repo=(\S+) workspace=(.+?) output=(\S+)')
    if (-not $m.Success) {
        if ($out -match 'session cap') { Write-Warning 'Session cap reached. Stopping.'; break }
        Write-Host 'No more eligible tasks - stopping.' -ForegroundColor Yellow; break
    }
    $taskId = $m.Groups[1].Value; $repo = $m.Groups[2].Value; $ws = $m.Groups[3].Value.Trim()

    # Ask the registry how to run this task with the chosen agent -- resolved model, acceptance
    # verdict, and a ready-to-run invocation. Nothing here knows agent-specific flags; that lives
    # entirely in adapters/registry.json, published alongside this script.
    $planJson = (Invoke-HeeLeeOss dispatch --workspace $ws --agent $Agent 2>&1 | Out-String)
    $d = $null; try { $d = ($planJson | ConvertFrom-Json) } catch { }
    if (-not $d -or -not $d.agentId) {
        Write-Warning "dispatch failed for $taskId (agent '$Agent') - skipping.`n$planJson"
        Remove-Item -Recurse -Force $ws -ErrorAction SilentlyContinue; continue
    }
    if ($d.acceptance -eq 'unusable') {
        Write-Host "held: $taskId - agent '$Agent' is unusable for this deliverable" -ForegroundColor Yellow
        $held += "$taskId (unusable by $Agent)"
        Remove-Item -Recurse -Force $ws -ErrorAction SilentlyContinue; continue
    }
    if ($d.kind -ne 'cli') {
        Write-Host "held: $taskId - agent '$Agent' kind '$($d.kind)' is not a CLI this loop can drive" -ForegroundColor Yellow
        $held += "$taskId (kind $($d.kind) unsupported here)"
        Remove-Item -Recurse -Force $ws -ErrorAction SilentlyContinue; continue
    }

    if ($DryRun) {
        Write-Host "[dry run] would build $taskId with $Agent (model $($d.model), acceptance $($d.acceptance))" -ForegroundColor DarkGray
        Remove-Item -Recurse -Force $ws -ErrorAction SilentlyContinue; continue
    }

    Write-Host "-> building $taskId (agent: $Agent, model: $($d.model))" -ForegroundColor DarkGray
    Invoke-RegistryAgent -Dispatch $d -Prompt $BuildPrompt -WorkingDir $ws | Out-Null

    $submitOut = (Invoke-HeeLeeOss submit $taskId --repo $repo --agent $Agent 2>&1 | Out-String)
    $pr = [regex]::Match($submitOut, 'https://github\.com/\S+?/pull/(\d+)')
    if (-not $pr.Success) {
        Write-Host "no changes for $taskId - releasing workspace (already done, or needs a human?)." -ForegroundColor Yellow
        $noChange += $taskId
        Remove-Item -Recurse -Force $ws -ErrorAction SilentlyContinue; continue
    }
    Write-Host "PR: $($pr.Value)" -ForegroundColor Green
    $built += "$taskId -> $($pr.Value)"
    Remove-Item -Recurse -Force $ws -ErrorAction SilentlyContinue
}

Write-Host "`n=== loop finished ===" -ForegroundColor Cyan
Write-Host "PRs opened ($($built.Count)):" -ForegroundColor Green; $built | ForEach-Object { Write-Host "  $_" }
Write-Host "held - needs a human ($($held.Count)):" -ForegroundColor Yellow; $held | ForEach-Object { Write-Host "  $_" }
Write-Host "no changes ($($noChange.Count)):" -ForegroundColor DarkYellow; $noChange | ForEach-Object { Write-Host "  $_" }
Invoke-HeeLeeOss status
