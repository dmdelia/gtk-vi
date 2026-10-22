# GTK: VI updater. Runs outside the game so Windows can replace the executable.
# No network access or elevated privileges. Only installs previously SHA-256 checked game files.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][int]$ParentProcessId,
    [Parameter(Mandatory=$true)][string]$InstallDirectory,
    [Parameter(Mandatory=$true)][string]$StageDirectory,
    [string]$OldExecutable = '',
    [switch]$SkipLaunch
)
$ErrorActionPreference = 'Stop'
$files = @('GTK-VI.exe','GTK-VI.pck')
$logFile = Join-Path $StageDirectory 'installation.log'
$backupDirectory = Join-Path $StageDirectory 'backups'
function Write-UpdateLog([string]$Message) {
    Add-Content -LiteralPath $logFile -Value ("{0} {1}" -f (Get-Date -Format o), $Message) -Encoding UTF8
}
try {
    if (-not (Test-Path -LiteralPath $StageDirectory -PathType Container)) { throw 'Staging directory missing' }
    if (-not (Test-Path -LiteralPath $InstallDirectory -PathType Container)) { throw 'Installation directory missing' }
    foreach ($file in $files) {
        $candidate = Join-Path $StageDirectory $file
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { throw "Staged game file missing: $file" }
        if ((Get-Item -LiteralPath $candidate).Length -lt 4096) { throw "Staged game file empty or truncated: $file" }
    }
    # Wait for the Godot/Windows process to fully release its EXE and PCK.
    $end = (Get-Date).AddSeconds(90)
    while ((Get-Date) -lt $end) {
        $parent = Get-Process -Id $ParentProcessId -ErrorAction SilentlyContinue
        if ($null -eq $parent) { break }
        Start-Sleep -Milliseconds 300
    }
    if ($null -ne (Get-Process -Id $ParentProcessId -ErrorAction SilentlyContinue)) {
        throw 'Previous game process did not exit within 90 seconds'
    }
    New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
    foreach ($file in $files) {
        $target = Join-Path $InstallDirectory $file
        if (Test-Path -LiteralPath $target -PathType Leaf) {
            Copy-Item -LiteralPath $target -Destination (Join-Path $backupDirectory $file) -Force
        }
    }
    $installed = @()
    try {
        foreach ($file in $files) {
            $source = Join-Path $StageDirectory $file
            $target = Join-Path $InstallDirectory $file
            $temporary = "$target.gtk-pending"
            Copy-Item -LiteralPath $source -Destination $temporary -Force
            Move-Item -LiteralPath $temporary -Destination $target -Force
            $installed += $file
            Write-UpdateLog "Installed $file"
        }
    } catch {
        Write-UpdateLog "Installation failed: $($_.Exception.Message)"
        foreach ($file in $installed) {
            $target = Join-Path $InstallDirectory $file
            $backup = Join-Path $backupDirectory $file
            if (Test-Path -LiteralPath $backup -PathType Leaf) {
                Copy-Item -LiteralPath $backup -Destination $target -Force
            } elseif (Test-Path -LiteralPath $target -PathType Leaf) {
                Remove-Item -LiteralPath $target -Force
            }
        }
        throw
    }
    # Only clean up old-name game files after the new pair is installed.
    if ($OldExecutable -ieq 'KARTON-EU-IV.exe') {
        foreach ($oldFile in @('KARTON-EU-IV.exe','KARTON-EU-IV.pck')) {
            $oldPath = Join-Path $InstallDirectory $oldFile
            if (Test-Path -LiteralPath $oldPath -PathType Leaf) {
                Remove-Item -LiteralPath $oldPath -Force -ErrorAction SilentlyContinue
            }
        }
    }
    Write-UpdateLog 'Update complete'
    if (-not $SkipLaunch) {
        Start-Process -FilePath (Join-Path $InstallDirectory 'GTK-VI.exe') -WorkingDirectory $InstallDirectory
    }
    exit 0
} catch {
    Write-UpdateLog "ERROR: $($_.Exception.Message)"
    exit 1
}
