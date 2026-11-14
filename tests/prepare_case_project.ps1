# Prepare an isolated project whose plugin lives under capitalized Addons.
# Run Godot --headless --editor --path tests/output/case_project --quit-after 120.
param([switch]$MismatchedActivation)
$projectRoot = Split-Path $PSScriptRoot -Parent
$caseRoot = Join-Path $projectRoot 'tests/output/case_project'
$utf8 = New-Object System.Text.UTF8Encoding($false)
New-Item -ItemType Directory -Force "$caseRoot/Addons", "$caseRoot/tests" | Out-Null
Copy-Item -LiteralPath "$projectRoot/addons/mesh_texture_painter" -Destination "$caseRoot/Addons" -Recurse -Force
New-Item -ItemType Directory -Force "$caseRoot/tests/output" | Out-Null
Copy-Item -LiteralPath "$projectRoot/tests/output/fixtures" -Destination "$caseRoot/tests/output" -Recurse -Force
Copy-Item -LiteralPath "$projectRoot/tests/editor_probe" -Destination "$caseRoot/tests" -Recurse -Force
$probeFile = Join-Path $caseRoot 'tests/editor_probe/probe.gd'
$probe = [IO.File]::ReadAllText($probeFile).Replace('res://addons/mesh_texture_painter/', 'res://Addons/mesh_texture_painter/')
[IO.File]::WriteAllText($probeFile, $probe, $utf8)
$config = [IO.File]::ReadAllText((Join-Path $projectRoot 'project.godot'))
$config = $config.Replace('"res://addons/mesh_texture_painter/plugin.cfg")', '"res://Addons/mesh_texture_painter/plugin.cfg", "res://tests/editor_probe/plugin.cfg")')
if ($MismatchedActivation) {
    $config = $config.Replace('res://Addons/mesh_texture_painter/plugin.cfg', 'res://addons/mesh_texture_painter/plugin.cfg')
    $probe = $probe.Replace('res://Addons/mesh_texture_painter/plugin.gd', 'res://addons/mesh_texture_painter/plugin.gd')
    [IO.File]::WriteAllText($probeFile, $probe, $utf8)
}
[IO.File]::WriteAllText((Join-Path $caseRoot 'project.godot'), $config, $utf8)
