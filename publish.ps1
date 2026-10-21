# KARTON EU IV: Push full project to the existing repository, then release.
# Prerequisites: Git + GitHub CLI, authenticated using gh auth login.
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$repo = 'dmdelia/gtk-vi'
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'Git fehlt.' }
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw 'GitHub CLI fehlt: https://cli.github.com/' }
gh auth status
if ($LASTEXITCODE -ne 0) { throw 'gh auth login ausfuehren.' }
gh repo view $repo
if ($LASTEXITCODE -ne 0) { throw "Repository $repo nicht gefunden." }
if (-not (Test-Path '.git')) { git init }
git config user.name 'KARTON EU IV'
git config user.email 'kartoneu-iv@users.noreply.github.com'
git add .
git -c user.name='KARTON EU IV' -c user.email='kartoneu-iv@users.noreply.github.com' commit -m 'Add complete KARTON EU IV v0.1.0 Godot source'
if ($LASTEXITCODE -ne 0) { throw 'Commit fehlgeschlagen.' }
git branch -M main
$remote = git remote get-url origin 2>$null
if ($LASTEXITCODE -ne 0) { git remote add origin "https://github.com/$repo.git" }
else { git remote set-url origin "https://github.com/$repo.git" }
# The repository already contains a GitHub Actions workflow. Preserve its history.
git fetch origin main
if ($LASTEXITCODE -ne 0) { throw 'Fetch fehlgeschlagen.' }
git merge --allow-unrelated-histories -X ours --no-edit origin/main
if ($LASTEXITCODE -ne 0) { throw 'Merge-Konflikt. Nicht automatisch ueberschreiben.' }
git push -u origin main
if ($LASTEXITCODE -ne 0) { throw 'Push fehlgeschlagen.' }
git tag v0.1.0
if ($LASTEXITCODE -ne 0) { throw 'Tagging fehlgeschlagen.' }
git push origin v0.1.0
if ($LASTEXITCODE -ne 0) { throw 'Tag-Push fehlgeschlagen.' }
Write-Host 'Code gepusht. Release-Workflow unter https://github.com/dmdelia/gtk-vi/actions pruefen.' -ForegroundColor Green
Start-Process 'https://github.com/dmdelia/gtk-vi/actions'
