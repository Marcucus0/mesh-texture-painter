param(
    [Parameter(Mandatory=$true)][string]$Godot,
    [switch]$Render
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$utf8 = New-Object System.Text.UTF8Encoding($false)
Push-Location $projectRoot
try {
    New-Item -ItemType Directory -Force tests/output | Out-Null
    function Invoke-GodotCheck([string]$Label, [string[]]$Arguments, [string]$Expected) {
        $stdoutPath = Join-Path $projectRoot "tests/output/$Label.stdout.log"
        $stderrPath = Join-Path $projectRoot "tests/output/$Label.stderr.log"
        $process = Start-Process -FilePath $Godot -ArgumentList $Arguments -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
        $processHandle = $process.Handle
        if (-not $process.WaitForExit(60000)) {
            Stop-Process -Id $process.Id -Force
            throw "Timeout: $Label (see tests/output logs)"
        }
        $process.WaitForExit()
        $stdoutText = [IO.File]::ReadAllText($stdoutPath)
        $stderrText = [IO.File]::ReadAllText($stderrPath)
        if ($process.ExitCode -ne 0 -or $stderrText -match 'SCRIPT ERROR|Parse Error|Shader compilation failed' -or ($Expected -and $stdoutText -notmatch $Expected)) {
            Write-Host $stdoutText
            Write-Host $stderrText
            throw "Failed: $Label (exit=$($process.ExitCode))"
        }
        Write-Host "$Label passed"
        if ($Expected) { Write-Host ($stdoutText -split "`n" | Where-Object { $_ -match $Expected }) }
    }
    Invoke-GodotCheck 'import' @('--headless','--editor','--path','.','--import','--quit') ''
    Invoke-GodotCheck 'fixture' @('--headless','--path','.','--script','tests/generate_fixture.gd') 'FIXTURE RESULT: 0'
    Invoke-GodotCheck 'fixture-import' @('--headless','--editor','--path','.','--import','--quit') ''
    Invoke-GodotCheck 'painter' @('--headless','--path','.','--script','tests/test_painter.gd') 'RESULT: 52 checks, 0 failures'
    Invoke-GodotCheck 'automatic-uv' @('--headless','--path','.','--script','tests/test_missing_uv.gd') 'UV RESULT: 14 checks, 0 failures'
    Invoke-GodotCheck 'uv-seams' @('--headless','--path','.','--script','tests/test_uv_seams.gd') 'SEAM RESULT: 13 checks, 0 failures'
    Invoke-GodotCheck 'brush-cache' @('--headless','--path','.','--script','tests/test_brush_cache.gd') 'BRUSH CACHE RESULT: 13 checks, 0 failures'
    Invoke-GodotCheck 'localization' @('--headless','--path','.','--script','tests/test_localization.gd') 'LOCALIZATION RESULT: 92 messages, 0 failures'
    $projectFile = Join-Path $projectRoot 'project.godot'
    $original = [IO.File]::ReadAllText($projectFile)
    try {
        $testConfig = $original.Replace('"res://addons/mesh_texture_painter/plugin.cfg")', '"res://addons/mesh_texture_painter/plugin.cfg", "res://tests/editor_probe/plugin.cfg")')
        [IO.File]::WriteAllText($projectFile, $testConfig, $utf8)
        Invoke-GodotCheck 'editor' @('--headless','--editor','--path','.','--language','fr','--max-fps','120','--quit-after','1000') 'EDITOR RESULT: 40 checks, 0 failures'
    } finally {
        [IO.File]::WriteAllText($projectFile, $original, $utf8)
    }
    if ($env:OS -eq 'Windows_NT') {
        & "$PSScriptRoot/prepare_reopen_project.ps1"
        Invoke-GodotCheck 'reopen-import' @('--headless','--editor','--path','tests/output/reopen_project','--import','--quit') ''
        Invoke-GodotCheck 'reopen-generate' @('--headless','--path','tests/output/reopen_project','--script','tests/generate_reopen.gd') 'REOPEN FIXTURE: saved'
        Invoke-GodotCheck 'reopen-editor' @('--headless','--editor','--path','tests/output/reopen_project','--max-fps','120','--quit-after','1000') 'REOPEN RESULT: 14 checks, 0 failures'
        Copy-Item -LiteralPath "$PSScriptRoot/editor_brush_settings" -Destination 'tests/output/reopen_project/tests' -Recurse -Force
        $brushProject = Join-Path $projectRoot 'tests/output/reopen_project/project.godot'
        $brushConfig = [IO.File]::ReadAllText($brushProject).Replace('tests/editor_reopen/plugin.cfg', 'tests/editor_brush_settings/plugin.cfg')
        [IO.File]::WriteAllText($brushProject, $brushConfig, $utf8)
        Invoke-GodotCheck 'brush-write' @('--headless','--editor','--path','tests/output/reopen_project','--max-fps','120','--quit-after','1000','--','--write') 'BRUSH SETTINGS: written'
        Invoke-GodotCheck 'brush-read' @('--headless','--editor','--path','tests/output/reopen_project','--max-fps','120','--quit-after','1000') 'BRUSH SETTINGS: 6 checks, 0 failures'
        Copy-Item -LiteralPath "$PSScriptRoot/editor_layer_order" -Destination 'tests/output/reopen_project/tests' -Recurse -Force
        $orderConfig = [IO.File]::ReadAllText($brushProject).Replace('tests/editor_brush_settings/plugin.cfg', 'tests/editor_layer_order/plugin.cfg')
        [IO.File]::WriteAllText($brushProject, $orderConfig, $utf8)
        Invoke-GodotCheck 'layer-order' @('--headless','--editor','--path','tests/output/reopen_project','--max-fps','120','--quit-after','1000') 'LAYER ORDER RESULT: 16 checks, 0 failures'
        Copy-Item -LiteralPath "$PSScriptRoot/editor_localization" -Destination 'tests/output/reopen_project/tests' -Recurse -Force
        $localeConfig = [IO.File]::ReadAllText($brushProject).Replace('tests/editor_layer_order/plugin.cfg', 'tests/editor_localization/plugin.cfg')
        [IO.File]::WriteAllText($brushProject, $localeConfig, $utf8)
        foreach ($language in @('en', 'fr')) {
            Invoke-GodotCheck "locale-$language" @('--headless','--editor','--path','tests/output/reopen_project','--language',$language,'--max-fps','120','--quit-after','1000') "EDITOR LOCALIZATION RESULT: $language, 10 checks, 0 failures"
        }
    }
    if ($Render) {
        Invoke-GodotCheck 'seams-gpu' @('--path','.','--script','tests/test_render_seams.gd','--rendering-method','forward_plus','--rendering-driver','vulkan','--resolution','800x600','--quit-after','600') 'SEAM GPU RESULT: folded surface opaque across UV seam, success'
        foreach ($renderer in @('gl_compatibility', 'forward_plus')) {
            Invoke-GodotCheck $renderer @('--path','.','--script','tests/test_render.gd','--rendering-method',$renderer,'--resolution','800x600','--quit-after','300') 'RENDER RESULT: image saved'
            Copy-Item -LiteralPath tests/output/render.png -Destination "tests/output/render-$renderer.png" -Force
        }
    }
} finally {
    Pop-Location
}
