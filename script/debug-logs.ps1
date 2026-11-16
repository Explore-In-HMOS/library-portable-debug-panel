# Pulls debugpanel logs from the watch to the desktop.

$LOG_DIR = './data/storage/el2/base/files/debugkit'
$DESKTOP = [Environment]::GetFolderPath('Desktop')

function Fail($msg) {
    Write-Host ''
    Write-Host "ERROR: $msg" -ForegroundColor Red
    exit 1
}

$HDC = (Get-Command hdc -ErrorAction SilentlyContinue).Source
if (-not $HDC) { Fail 'hdc not found. Add it to PATH.' }

# --- device ---
$targets = @(& hdc list targets 2>$null | ForEach-Object { [string]$_ } |
             ForEach-Object { $_.Trim() } |
             Where-Object { $_ -and $_ -notmatch '^\[Empty\]' })
if ($targets.Count -eq 0) { Fail 'No device connected.' }

$T = @('-t', $targets[0])
if ($targets.Count -gt 1) {
    Write-Host 'Connected devices:'
    for ($i = 0; $i -lt $targets.Count; $i++) { Write-Host "  [$($i+1)] $($targets[$i])" }
    $s = Read-Host 'Device'
    $n = 0
    if (-not [int]::TryParse($s, [ref]$n) -or $n -lt 1 -or $n -gt $targets.Count) { Fail 'Invalid selection.' }
    $T = @('-t', $targets[$n - 1])
}

function Invoke-Hdc {
    param([string[]]$A)
    $out = & $HDC @T @A 2>&1
    return @($out | ForEach-Object { [string]$_ })
}

# --- applications ---
Write-Host 'Listing applications...' -ForegroundColor DarkGray

$dump = Invoke-Hdc @('shell', 'bm', 'dump', '-a')

$all = @($dump | ForEach-Object { $_.Trim() } |
         Where-Object { $_ -match '^[A-Za-z][\w]*(\.[\w]+)+$' })

# filter out preinstalled / system packages
$apps = @($all | Where-Object { $_ -notmatch '^(ohos\.|com\.ohos\.|com\.huawei\.|com\.hmos\.|com\.wifi)' })
Write-Host "DEBUG apps: $($apps.Count)" -ForegroundColor Cyan

if ($apps.Count -eq 0) { Fail 'No applications found.' }

$rows = $apps

Write-Host ''
for ($i = 0; $i -lt $rows.Count; $i++) {
    Write-Host ("  [{0}] {1}" -f ($i + 1), $rows[$i])
}

Write-Host ''
$sel = Read-Host 'Application number'
$idx = 0
if (-not [int]::TryParse($sel, [ref]$idx) -or $idx -lt 1 -or $idx -gt $rows.Count) { Fail 'Invalid selection.' }
$bundle = $rows[$idx - 1]

# --- files ---
Write-Host "DEBUG bundle: >>[$bundle]<<" -ForegroundColor Cyan
$raw = Invoke-Hdc @('shell', '-b', $bundle, 'ls', '-l', $LOG_DIR)
$raw | ForEach-Object { Write-Host "  >>[$_]<<" -ForegroundColor DarkCyan }
$files = @()
foreach ($line in $raw) {
    $t = ($line.Trim() -split '\s+')
    if ($t.Count -lt 2) { continue }
    $name = $t[-1]
    if ($name -notmatch '\.jsonl$') { continue }
    $nums = @($t | Where-Object { $_ -match '^\d+$' })
    $size = if ($nums.Count -ge 1) { [int]$nums[-1] } else { 0 }
    $files += [pscustomobject]@{ Name = $name; Size = $size }
}

if ($files.Count -eq 0) { Fail "No jsonl files for this application.`n  $LOG_DIR" }
$files = @($files | Sort-Object Name)

Write-Host ''
Write-Host "$bundle" -ForegroundColor DarkGray
for ($i = 0; $i -lt $files.Count; $i++) {
    $kb = [math]::Round($files[$i].Size / 1KB, 1)
    Write-Host ("  [{0}] {1}  {2} KB" -f ($i + 1), $files[$i].Name, $kb)
}

Write-Host ''
$sel = Read-Host 'File number  (0 = all)'
$fid = -1
if (-not [int]::TryParse($sel, [ref]$fid) -or $fid -lt 0 -or $fid -gt $files.Count) { Fail 'Invalid selection.' }

# --- download ---
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$dest = Join-Path $DESKTOP "logs-$bundle-$stamp"
New-Item -ItemType Directory -Path $dest -Force | Out-Null

$picked = if ($fid -eq 0) { $files } else { @($files[$fid - 1]) }

$ok = 0
foreach ($f in $picked) {
    Write-Host "  downloading: $($f.Name)"
    $r = Invoke-Hdc @('file', 'recv', '-b', $bundle, "$LOG_DIR/$($f.Name)", $dest)
    if (Test-Path (Join-Path $dest $f.Name)) { $ok++ }
    else { Write-Host "    failed: $r" -ForegroundColor Yellow }
}

Write-Host ''
if ($ok -eq 0) {
    Remove-Item $dest -Force -Recurse -ErrorAction SilentlyContinue
    Fail 'No files were downloaded.'
}
Write-Host "$ok file(s) downloaded:" -ForegroundColor Green
Write-Host "  $dest"
Start-Process explorer.exe $dest