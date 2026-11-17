[CmdletBinding()]
param(
  [string]$EnvFile = (Join-Path $PSScriptRoot '../../.env'),
  [string]$Model = 'gpt-6-luna',
  [string]$OutputDirectory = '.dart_tool/live-novel-roles',
  [string]$Cases = '',
  [switch]$Replay,
  [string]$FlutterCommand = 'flutter'
)
$ErrorActionPreference = 'Stop'
$values = @{}
if (!$Replay) {
foreach ($line in [IO.File]::ReadAllLines((Resolve-Path -LiteralPath $EnvFile))) {
  $entry = $line.Trim() -replace '^export\s+', ''
  if (!$entry -or $entry.StartsWith('#') -or !$entry.Contains('=')) { continue }
  $parts = $entry.Split('=', 2)
  $value = $parts[1].Trim()
  if ($value.Length -ge 2 -and (($value.StartsWith('"') -and $value.EndsWith('"')) -or
      ($value.StartsWith("'") -and $value.EndsWith("'")))) {
    $value = $value.Substring(1, $value.Length - 2)
  }
  $values[$parts[0].Trim()] = $value
}
}
$key = $values['OPENAI_TEST_API_KEY']
if (!$key) { $key = $values['OPENAI_API_KEY'] }
if (!$key) { $key = $values['OPENAI_KEY'] }
if (!$key -and !$Replay) { throw 'No supported API key variable found in the local .env.' }
$settings = @{
  OPENAI_TEST_API_KEY = $key
  NEIROHA_LIVE_ROLES = '1'
  OPENAI_ROLE_MODEL = $Model
  OPENAI_ROLE_OUT_DIR = $OutputDirectory
  OPENAI_ROLE_CASES = $Cases
  NEIROHA_ROLE_REPLAY = $(if ($Replay) { '1' } else { '0' })
}
$previous = @{}
foreach ($name in $settings.Keys) { $previous[$name] = [Environment]::GetEnvironmentVariable($name) }
try {
  foreach ($name in $settings.Keys) { [Environment]::SetEnvironmentVariable($name, $settings[$name]) }
  if ($Replay) {
    Write-Host 'Replaying captured model results offline; no inference requests.'
  } else {
    Write-Host "Running opt-in novel evaluation with $Model (global limit 72 structured calls)."
  }
  & $FlutterCommand test scripts/tests/novel_role_live_test.dart --reporter expanded 2>&1 |
    ForEach-Object {
      $safeLine = $_.ToString()
      if ($key) { $safeLine = $safeLine.Replace($key, '[REDACTED]') }
      $safeLine -replace 'sk-[A-Za-z0-9_-]+', '[REDACTED]'
    }
  $result = $LASTEXITCODE
} finally {
  foreach ($name in $settings.Keys) { [Environment]::SetEnvironmentVariable($name, $previous[$name]) }
}
exit $result
