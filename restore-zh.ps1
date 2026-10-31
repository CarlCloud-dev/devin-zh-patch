# 还原:把 .zhorig 备份盖回原文件并删除 zh chunk
param([string]$AssetsDir = "")
try{[Console]::OutputEncoding=[Text.Encoding]::UTF8}catch{}
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Find-Assets {
    if ($AssetsDir -and (Test-Path $AssetsDir)) { return (Resolve-Path $AssetsDir).Path }
    foreach ($c in @(
        'E:\Devin\resources\app\out\vs\workbench\devin-webapp-host\assets',
        "$env:LOCALAPPDATA\Programs\Devin\resources\app\out\vs\workbench\devin-webapp-host\assets",
        "$env:ProgramFiles\Devin\resources\app\out\vs\workbench\devin-webapp-host\assets",
        'D:\Devin\resources\app\out\vs\workbench\devin-webapp-host\assets'
        'C:\Devin\resources\app\out\vs\workbench\devin-webapp-host\assets'
    )) { if (Test-Path $c) { return $c } }
    $proc = Get-CimInstance Win32_Process -Filter "Name='Devin.exe'" -ErrorAction SilentlyContinue |
            Where-Object { $_.ExecutablePath -like '*\Devin.exe' } | Select-Object -First 1
    if ($proc) {
        $cand = Join-Path (Split-Path $proc.ExecutablePath) 'resources\app\out\vs\workbench\devin-webapp-host\assets'
        if (Test-Path $cand) { return $cand }
    }
    foreach ($rk in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
                    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*') {
        foreach ($h in (Get-ItemProperty $rk -ErrorAction SilentlyContinue |
                 Where-Object { $_.DisplayName -match 'Devin' })) {
            $base = $h.InstallLocation
            if (-not $base -and $h.DisplayIcon) { $base = Split-Path ($h.DisplayIcon -replace '"','') }
            if ($base) {
                $cand = Join-Path $base 'resources\app\out\vs\workbench\devin-webapp-host\assets'
                if (Test-Path $cand) { return $cand }
            }
        }
    }
    throw '找不到 Devin assets 目录'
}

$assets = Find-Assets
$bak = Get-ChildItem (Join-Path $assets '*.zhorig')
if (-not $bak) { Write-Host '没有找到 .zhorig 备份文件'; exit }
foreach ($f in $bak) {
    $orig = $f.FullName -replace '\.zhorig$', ''
    Copy-Item $f.FullName $orig -Force
    Write-Host "已还原 $($f.BaseName)"
}
Remove-Item (Join-Path $assets 'zh-CN-translation.js'), (Join-Path $assets 'zh-CN-review.js') -ErrorAction SilentlyContinue
Write-Host '已删除 zh-CN-*.js,重启 Devin 生效'
