$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$caseRoot = Join-Path $projectRoot 'tests/output/reopen_project'
$utf8 = New-Object System.Text.UTF8Encoding($false)
New-Item -ItemType Directory -Force "$caseRoot/Addons", "$caseRoot/tests" | Out-Null
Copy-Item -LiteralPath "$projectRoot/addons/mesh_texture_painter" -Destination "$caseRoot/Addons" -Recurse -Force
New-Item -ItemType Directory -Force "$caseRoot/tests/output" | Out-Null
Copy-Item -LiteralPath "$projectRoot/tests/output/fixtures" -Destination "$caseRoot/tests/output" -Recurse -Force
Copy-Item -LiteralPath "$projectRoot/tests/generate_reopen.gd" -Destination "$caseRoot/tests" -Force
Copy-Item -LiteralPath "$projectRoot/tests/editor_reopen" -Destination "$caseRoot/tests" -Recurse -Force
$config = [IO.File]::ReadAllText((Join-Path $projectRoot 'project.godot')).Replace('"res://addons/mesh_texture_painter/plugin.cfg")', '"res://addons/mesh_texture_painter/plugin.cfg", "res://tests/editor_reopen/plugin.cfg")')
[IO.File]::WriteAllText("$caseRoot/project.godot", $config, $utf8)
