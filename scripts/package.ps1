param([switch]$Source)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$pluginRoot = Join-Path $projectRoot 'addons/mesh_texture_painter'
$config = [IO.File]::ReadAllText((Join-Path $pluginRoot 'plugin.cfg'))
$version = [regex]::Match($config, '(?m)^version="([0-9]+\.[0-9]+(?:\.[0-9]+)?)"').Groups[1].Value
if (-not $version) { throw 'No numeric release version found in plugin.cfg.' }

$dist = Join-Path $projectRoot 'dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression

function Get-PackageFiles([string[]]$Directories) {
    $allowed = @('.gd', '.gdshader', '.uid', '.cfg', '.godot', '.tscn', '.tres', '.svg', '.import', '.md', '.ps1')
    foreach ($directory in $Directories) {
        Get-ChildItem -LiteralPath (Join-Path $projectRoot $directory) -Recurse -File | Where-Object {
            $relative = $_.FullName.Substring($projectRoot.Length + 1).Replace('\', '/')
            $allowed -contains $_.Extension.ToLowerInvariant() -and
                $relative -notmatch '(^|/)(\.godot|\.git|output|dist)(/|$)'
        }
    }
}

function Write-Package([string]$Name, [IO.FileInfo[]]$Files) {
    $destination = Join-Path $dist $Name
    $stream = [IO.File]::Create($destination)
    $archive = New-Object System.IO.Compression.ZipArchive($stream, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($file in ($Files | Sort-Object FullName -Unique)) {
            $relative = $file.FullName.Substring($projectRoot.Length + 1).Replace('\', '/')
            [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $file.FullName, $relative, [IO.Compression.CompressionLevel]::Optimal) | Out-Null
        }
    } finally {
        $archive.Dispose()
        $stream.Dispose()
    }
    Write-Output $destination
}

Write-Package "mesh_texture_painter-$version.zip" @(Get-PackageFiles @('addons/mesh_texture_painter'))
if ($Source) {
    $files = @(Get-PackageFiles @('addons/mesh_texture_painter', 'docs', 'tests', 'scripts'))
    foreach ($name in @('README.md', 'README.fr.md', 'CHANGELOG.md', '.gitignore', '.gitattributes', '.editorconfig', 'project.godot', 'LICENSE', 'LICENSE.md')) {
        $path = Join-Path $projectRoot $name
        if (Test-Path -LiteralPath $path -PathType Leaf) { $files += Get-Item -LiteralPath $path -Force }
    }
    Write-Package "mesh_texture_painter-source-$version.zip" $files
}
