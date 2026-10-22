$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
Write-Host "Running advanced SQL demo against database advanced_sql_demo..."
psql -U postgres -h localhost -p 5432 -d advanced_sql_demo -v ON_ERROR_STOP=1 -f ".\tests\run_all.sql"
if ($LASTEXITCODE -ne 0) {
    throw "psql failed with exit code $LASTEXITCODE. Review the SQL error above."
}
Write-Host "SQL run completed successfully."
