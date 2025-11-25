# scaffold_docs.ps1

$folders = @(
  "docs/architecture",
  "docs/domain",
  "docs/guides",
  "docs/project",
  "docs/agents",
  "docs/workflows"
)

foreach ($folder in $folders) {
  if (-not (Test-Path $folder)) {
    New-Item -Path $folder -ItemType Directory
  }
}

# Add Domain Map placeholder if missing
if (-not (Test-Path "docs/domain/domain_map.md")) {
    Set-Content "docs/domain/domain_map.md" "# Domain Map`n`n_(To be filled)_"
}

Write-Host "✅ Docs scaffold complete. Files organized under /docs/"
