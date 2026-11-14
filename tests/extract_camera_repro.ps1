param([Parameter(Mandatory=$true)][string]$Source)
$projectRoot=Split-Path $PSScriptRoot -Parent
$raw=[IO.File]::ReadAllText($Source)
$blocks=[regex]::Matches($raw,'(?ms)^\[(?<kind>ext_resource|sub_resource|node)[^\r\n]*\].*?(?=^\[|\z)')
$sub=@{}
foreach($block in $blocks){
    $id=[regex]::Match($block.Value.Split("`n")[0],'\bid="([^"]+)"').Groups[1].Value
    if($block.Groups['kind'].Value -eq 'sub_resource'){ $sub[$id]=$block.Value }
}
$nodes=($blocks | Where-Object { $_.Groups['kind'].Value -eq 'node' -and $_.Value -match '^\[node name="(Island_Terrain|TexturePaint)"' } | ForEach-Object {$_.Value}) -join "`n"
$needSub=@{}; $needExt=@{}; $queue=New-Object System.Collections.Generic.Queue[string]; $queue.Enqueue($nodes)
while($queue.Count -gt 0){
    $value=$queue.Dequeue()
    foreach($match in [regex]::Matches($value,'SubResource\("([^"]+)"\)')){
        $id=$match.Groups[1].Value
        if(-not $needSub.ContainsKey($id)){ $needSub[$id]=$true; $queue.Enqueue($sub[$id]) }
    }
    foreach($match in [regex]::Matches($value,'ExtResource\("([^"]+)"\)')){ $needExt[$match.Groups[1].Value]=$true }
}
$output="[gd_scene format=4]`n`n"
foreach($block in $blocks){
    $id=[regex]::Match($block.Value.Split("`n")[0],'\bid="([^"]+)"').Groups[1].Value
    if(($block.Groups['kind'].Value -eq 'ext_resource' -and $needExt.ContainsKey($id)) -or ($block.Groups['kind'].Value -eq 'sub_resource' -and $needSub.ContainsKey($id))){ $output += $block.Value+"`n" }
}
$output += "[node name=`"CameraRepro`" type=`"Node3D`"]`n`n" + $nodes
$destination=Join-Path $projectRoot 'tests/output/case_project/camera-island.tscn'
[IO.File]::WriteAllText($destination,$output,(New-Object System.Text.UTF8Encoding($false)))
