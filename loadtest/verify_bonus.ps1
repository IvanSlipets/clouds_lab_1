<#
  Lab 2 / tasks 6 + 7: End-to-end test in AWS (Windows PowerShell 5.1 or later).
  Set $env:API_URL, $env:API_USER, $env:API_PASSWORD before running.
  Creates one UNIQUE sport, checks replay and resulting database record.
#>
param(
    [string]$ApiUrl = $env:API_URL,
    [string]$ApiUser = $env:API_USER,
    [string]$ApiPassword = $env:API_PASSWORD,
    [int]$WaitSeconds = 180
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

if ([string]::IsNullOrWhiteSpace($ApiUrl)) {
    throw 'Set $env:API_URL using terraform output -raw api_url'
}
if ([string]::IsNullOrWhiteSpace($ApiUser)) { $ApiUser = 'admin' }
if ([string]::IsNullOrWhiteSpace($ApiPassword)) {
    throw 'Set $env:API_PASSWORD (admin password) in this PowerShell session'
}
if ($WaitSeconds -lt 10) { throw 'WaitSeconds must be >= 10' }

$base = $ApiUrl.TrimEnd('/')
Write-Host '1/6 - JWT login...'
$loginBody = @{ username = $ApiUser; password = $ApiPassword } |
    ConvertTo-Json -Compress
$login = Invoke-RestMethod -Method Post `
    -Uri "$base/api/auth/login" `
    -ContentType 'application/json' -Body $loginBody
if (-not $login.access_token) { throw 'No access_token in login response' }

$key = [guid]::NewGuid().ToString()
$name = 'Lab2-Async-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' +
    ([guid]::NewGuid().ToString('N').Substring(0, 8))
$payload = @{ name = $name; description = 'End-to-end queue and idempotency check' } |
    ConvertTo-Json -Compress
$headers = @{
    Authorization     = "Bearer $($login.access_token)"
    'Idempotency-Key' = $key
}

Write-Host "2/6 - First POST /api/jobs/sports, sport name = $name"
$first = Invoke-WebRequest -UseBasicParsing -Method Post `
    -Uri "$base/api/jobs/sports" -Headers $headers `
    -ContentType 'application/json' -Body $payload
if ([int]$first.StatusCode -ne 202) {
    throw "First POST must return 202, received $($first.StatusCode)"
}
$firstJson = $first.Content | ConvertFrom-Json
if (-not $firstJson.job_id) { throw 'First response has no job_id' }

Write-Host '3/6 - EXACT same POST with EXACT same Idempotency-Key...'
$second = Invoke-WebRequest -UseBasicParsing -Method Post `
    -Uri "$base/api/jobs/sports" -Headers $headers `
    -ContentType 'application/json' -Body $payload
if ([int]$second.StatusCode -ne 202) {
    throw "Replay must return 202, received $($second.StatusCode)"
}
$secondJson = $second.Content | ConvertFrom-Json
if ($firstJson.job_id -ne $secondJson.job_id) {
    throw 'FAIL: replay created a different job_id'
}
if ($first.Content.Trim() -ne $second.Content.Trim()) {
    throw 'FAIL: same request returned different JSON response body'
}
if ([string]$first.Headers['Location'] -ne [string]$second.Headers['Location']) {
    throw 'FAIL: Location headers differ'
}
if ([string]$first.Headers['Idempotency-Replayed'] -ne 'false') {
    throw 'FAIL: first Idempotency-Replayed should be false'
}
if ([string]$second.Headers['Idempotency-Replayed'] -ne 'true') {
    throw 'FAIL: repeat Idempotency-Replayed should be true'
}
Write-Host "PASS - 202 / 202, same job_id: $($firstJson.job_id), response body and Location identical"

Write-Host '4/6 - Reusing key with DIFFERENT JSON must return 409...'
$changedPayload = @{ name = "${name}-changed"; description = 'Different body' } |
    ConvertTo-Json -Compress
$conflictCode = 0
try {
    $unexpected = Invoke-WebRequest -UseBasicParsing -Method Post `
        -Uri "$base/api/jobs/sports" -Headers $headers `
        -ContentType 'application/json' -Body $changedPayload
    $conflictCode = [int]$unexpected.StatusCode
}
catch [System.Net.WebException] {
    if ($null -ne $_.Exception.Response) {
        $conflictCode = [int]$_.Exception.Response.StatusCode
    }
    else { throw }
}
if ($conflictCode -ne 409) {
    throw "Expected HTTP 409 for changed payload; got $conflictCode"
}
Write-Host 'PASS - same key + different request body => 409'

Write-Host '5/6 - Poll job status until completed...'
$deadline = (Get-Date).AddSeconds($WaitSeconds)
$jobId = $firstJson.job_id
$job = $null
while ((Get-Date) -lt $deadline) {
    $job = Invoke-RestMethod -Method Get -Uri "$base/api/jobs/$jobId"
    if ($job.status -eq 'completed') { break }
    if ($job.status -eq 'failed') {
        throw ('Job failed: ' + ($job.result | ConvertTo-Json -Compress))
    }
    Start-Sleep -Seconds 3
}
if ($null -eq $job -or $job.status -ne 'completed') {
    throw "Job did not complete within $WaitSeconds seconds; check ECS Worker/SQS/CloudWatch"
}
if (-not $job.result.sport_id) { throw 'Job result has no sport_id' }
$sportId = $job.result.sport_id
$sport = Invoke-RestMethod -Method Get -Uri "$base/api/sports/$sportId"
if ($sport.name -ne $name) { throw 'Sport detail does not match submitted data' }
Write-Host "PASS - Worker completed job; GET sport_id=$sportId found sport $name"

Write-Host '6/6 - Verify only ONE matching Sport in the list (allow local cache to expire)...'
$matchesCount = 0
$listDeadline = (Get-Date).AddSeconds(75)
while ((Get-Date) -lt $listDeadline) {
    $sports = @(Invoke-RestMethod -Method Get -Uri "$base/api/sports/")
    $matchesCount = @($sports | Where-Object { $_.name -eq $name }).Count
    if ($matchesCount -eq 1) { break }
    if ($matchesCount -gt 1) { break }
    Start-Sleep -Seconds 5
}
if ($matchesCount -ne 1) {
    throw "Expected exactly 1 sport in GET list, found $matchesCount"
}
Write-Host "PASS - exactly one Sport with name '$name'"
Write-Host 'ALL FUNCTIONAL CHECKS PASSED (lab 2, tasks 6 and 7).'
