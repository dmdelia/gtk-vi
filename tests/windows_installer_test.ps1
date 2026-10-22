$ErrorActionPreference = 'Stop'
$work = Join-Path $env:RUNNER_TEMP ('gtk_vi_updater_test_' + [guid]::NewGuid().ToString('N'))
$installation = Join-Path $work 'installation'
$stage = Join-Path $work 'staged'
New-Item -ItemType Directory -Path $installation,$stage -Force | Out-Null
$oldExe = Join-Path $installation 'KARTON-EU-IV.exe'
$oldPck = Join-Path $installation 'KARTON-EU-IV.pck'
[System.IO.File]::WriteAllBytes($oldExe, [byte[]]::new(6000))
[System.IO.File]::WriteAllBytes($oldPck, [byte[]]::new(6000))
[System.IO.File]::WriteAllBytes((Join-Path $stage 'GTK-VI.exe'), [byte[]]::new(6500))
[System.IO.File]::WriteAllBytes((Join-Path $stage 'GTK-VI.pck'), [byte[]]::new(7500))
& "$PSScriptRoot/../tools/install_update.ps1" -ParentProcessId 999999 -InstallDirectory $installation -StageDirectory $stage -OldExecutable 'KARTON-EU-IV.exe' -SkipLaunch
if ($LASTEXITCODE -ne 0) { throw 'Installer exit code was nonzero' }
if ((Get-Item (Join-Path $installation 'GTK-VI.exe')).Length -ne 6500) { throw 'New executable not installed' }
if ((Get-Item (Join-Path $installation 'GTK-VI.pck')).Length -ne 7500) { throw 'New PCK not installed' }
if (Test-Path $oldExe) { throw 'Legacy EXE was not removed' }
if (Test-Path $oldPck) { throw 'Legacy PCK was not removed' }
Write-Output 'WINDOWS INSTALLER TEST PASS'
Remove-Item -LiteralPath $work -Recurse -Force
