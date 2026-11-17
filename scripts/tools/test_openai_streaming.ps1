[CmdletBinding()]
param(
  [string]$EnvFile = (Join-Path $PSScriptRoot '../../.env'),
  [string]$OutputDirectory = '.dart_tool/live-streaming',
  [string]$FlutterCommand = 'flutter'
)
$ErrorActionPreference = 'Stop'
$values = @{}
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
$key = $values['OPENAI_TEST_API_KEY']
if (!$key) { $key = $values['OPENAI_API_KEY'] }
if (!$key) { $key = $values['OPENAI_KEY'] }
if (!$key) { throw 'No supported API key variable found in the local .env.' }
$names = @('OPENAI_TEST_API_KEY', 'NEIROHA_LIVE_STREAMING', 'OPENAI_TEST_OUT_DIR')
$previous = @{}
foreach ($name in $names) { $previous[$name] = [Environment]::GetEnvironmentVariable($name) }
try {
  [Environment]::SetEnvironmentVariable('OPENAI_TEST_API_KEY', $key)
  [Environment]::SetEnvironmentVariable('NEIROHA_LIVE_STREAMING', '1')
  [Environment]::SetEnvironmentVariable('OPENAI_TEST_OUT_DIR', $OutputDirectory)
  Write-Host 'Running 3 live streaming checks against api.openai.com; native audio will play.'
  & $FlutterCommand test scripts/tests/openai_streaming_live_test.dart --reporter expanded 2>&1 |
    ForEach-Object { $_.ToString().Replace($key, '[REDACTED]') -replace 'sk-[A-Za-z0-9_-]+', '[REDACTED]' }
  $result = $LASTEXITCODE
} finally {
  foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name, $previous[$name]) }
}
exit $result
