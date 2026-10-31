# Devin Agent 界面简体中文汉化补丁
# 用法:双击"一键汉化.bat",或 powershell -File apply-zh.ps1 [-AssetsDir <assets目录>]
# 幂等:已打补丁则跳过,可重复执行;Devin 更新后重跑一次即可恢复中文。
param([string]$AssetsDir = "")
try{[Console]::OutputEncoding=[Text.Encoding]::UTF8}catch{}

$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$pkg = $PSScriptRoot

function Find-Assets {
    if ($AssetsDir -and (Test-Path $AssetsDir)) { return (Resolve-Path $AssetsDir).Path }
    foreach ($c in @(
        'E:\Devin\resources\app\out\vs\workbench\devin-webapp-host\assets',
        "$env:LOCALAPPDATA\Programs\Devin\resources\app\out\vs\workbench\devin-webapp-host\assets",
        "$env:ProgramFiles\Devin\resources\app\out\vs\workbench\devin-webapp-host\assets",
        'D:\Devin\resources\app\out\vs\workbench\devin-webapp-host\assets',
        'C:\Devin\resources\app\out\vs\workbench\devin-webapp-host\assets'
    )) { if (Test-Path $c) { return $c } }
    # 兜底1:从正在运行的 Devin.exe 进程反推安装目录
    $proc = Get-CimInstance Win32_Process -Filter "Name='Devin.exe'" -ErrorAction SilentlyContinue |
            Where-Object { $_.ExecutablePath -like '*\Devin.exe' } | Select-Object -First 1
    if ($proc) {
        $cand = Join-Path (Split-Path $proc.ExecutablePath) 'resources\app\out\vs\workbench\devin-webapp-host\assets'
        if (Test-Path $cand) { return $cand }
    }
    # 兜底2:注册表卸载条目的安装位置/图标路径
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
    throw "找不到 Devin assets 目录,请用 -AssetsDir 参数指定"
}

$assets = Find-Assets
Write-Host "[*] assets 目录: $assets"

function Save-Text($path, $text) {
    try { [IO.File]::WriteAllText($path, $text, $utf8) }
    catch [IO.IOException] { throw "写入失败(文件被占用?),请先关闭 Devin 再运行: $path" }
}

# ---------- 1. 拷贝 zh 语言 chunk ----------
foreach ($f in 'zh-CN-translation.js', 'zh-CN-review.js') {
    Copy-Item (Join-Path $pkg $f) (Join-Path $assets $f) -Force
    Write-Host "[+] 已安装 $f"
}

# ---------- 1.5 workbench 内核层汉化:替换 nls.messages 消息数组 ----------
# assets 位于 out\vs\workbench\devin-webapp-host\assets,nls 文件在 out\ 下
$outDir = (Resolve-Path (Join-Path $assets '..\..\..\..')).Path
foreach ($pair in @(@('nls.messages.json','nls.messages.zh.json'),
                    @('nls.messages.js','nls.messages.zh.js'))) {
    $dst = Join-Path $outDir $pair[0]
    $src = Join-Path $pkg $pair[1]
    if (-not (Test-Path $dst)) { Write-Host "[=] 跳过 $($pair[0]) (不存在)"; continue }
    $cur = [IO.File]::ReadAllText($dst, $utf8)
    if ($cur.Contains('关闭对话框')) {
        Write-Host "[=] $($pair[0]) 已是中文,跳过"
    } else {
        if (-not (Test-Path "$dst.zhorig")) { Copy-Item $dst "$dst.zhorig" }
        Copy-Item $src $dst -Force
        Write-Host "[+] 已汉化 $($pair[0]) (workbench 内核)"
    }
}

# ---------- 2. editor-mode-menu: 注册 zh 语言项 + mapDeps ----------
$menu = Get-ChildItem (Join-Path $assets 'entry-host-editor-mode-menu-*.js') |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $menu) { throw '找不到 entry-host-editor-mode-menu-*.js' }
$s = [IO.File]::ReadAllText($menu.FullName, $utf8)

if ($s -match 'code:`zh`') {
    Write-Host "[=] 语言列表已含 zh,跳过菜单补丁"
} else {
    if (-not (Test-Path "$($menu.FullName).zhorig")) {
        Copy-Item $menu.FullName "$($menu.FullName).zhorig"
    }

    # 2a. m.f 依赖表追加两个 zh chunk,取新索引
    $mdep = [regex]::Match($s, 'm\.f=\[([^\]]*)\]')
    if (-not $mdep.Success) { throw '未找到 m.f 依赖表,版本可能已变化' }
    $depIdx = ([regex]::Matches($mdep.Groups[1].Value, '"[^"]*"')).Count
    $s = $s.Substring(0, $mdep.Index) +
         'm.f=[' + $mdep.Groups[1].Value + ',"./zh-CN-translation.js","./zh-CN-review.js"]' +
         $s.Substring($mdep.Index + $mdep.Length)

    # 2b. 克隆最后一个语言条目(en/ja/pt/es 中末尾那个),改写成 zh
    # 条目内部无花括号,用 [^{}]* 限定确保只捕获紧随 ] 的那一条
    $ment = [regex]::Match($s, ',(?<e>\{code:`[^`]+`,label:`[^`]+`,translation:[^{}]*\})\]')
    if (-not $ment.Success) { throw '未找到语言列表,版本可能已变化' }
    $entry = $ment.Groups['e'].Value
    $script:i = 0; $script:j = 0; $script:depIdx = $depIdx
    $files = './zh-CN-translation.js', './zh-CN-review.js'
    $zh = $entry -replace 'code:`[^`]+`', 'code:`zh`' -replace 'label:`[^`]+`', 'label:`中文(简体)`'
    $zh = [regex]::Replace($zh, 'import\(`\./[^`]+`\)', [System.Text.RegularExpressions.MatchEvaluator]{
        param($mm); $f = $files[$script:i]; $script:i++; 'import(`' + $f + '`)'
    })
    $zh = [regex]::Replace($zh, '__vite__mapDeps\(\[\d+', [System.Text.RegularExpressions.MatchEvaluator]{
        param($mm); $k = $script:depIdx + $script:j; $script:j++; "__vite__mapDeps([$k"
    })
    $at = $ment.Index + $ment.Length - 1   # 末尾语言条目之后、] 之前
    $s = $s.Substring(0, $at) + ',' + $zh + $s.Substring($at)
    Save-Text $menu.FullName $s
    Write-Host "[+] 语言列表已注册 zh (dep idx $depIdx,$($depIdx+1))"
}

# ---------- 3. index bundle: zh 语言持久化(写跳过云端 + 读走 localStorage) ----------
$index = Get-ChildItem (Join-Path $assets 'entry-host-index-*.js') |
         Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $index) { throw '找不到 entry-host-index-*.js' }
$s2 = [IO.File]::ReadAllText($index.FullName, $utf8)
$dirty = $false

# 3a. 写路径: PUT users/ui-language 对 zh 跳过(服务端枚举不认 zh)
$hsPatched = ($s2 -match '===`zh`\?Promise') -or ($s2 -match 'if\(t===`zh`\)')
if (-not $hsPatched) {
    $pat = '([A-Za-z_$][\w$]*)\.put\(`users/ui-language`,\{json:\{language:([A-Za-z_$][\w$]*)\}\}\)(\.json\(\))?'
    if ($s2 -notmatch $pat) { throw '未找到 users/ui-language PUT 调用,版本可能已变化' }
    $s2 = [regex]::Replace($s2, $pat, [System.Text.RegularExpressions.MatchEvaluator]{
        param($mm)
        $c = $mm.Groups[1].Value; $v = $mm.Groups[2].Value; $j = $mm.Groups[3].Value
        "($v===``zh``?Promise.resolve({ui_language:$v}):$c.put(``users/ui-language``,{json:{language:$v}})$j)"
    })
    $dirty = $true
    Write-Host '[+] index: zh 跳过云端保存 (PUT)'
} else { Write-Host '[=] index: PUT 补丁已存在,跳过' }

# 3b. 读路径: GET users/ui-language 对 zh 返回 localStorage 值(启动时服务端 en 会覆盖 zh)
$vsPatched = ($s2 -match 'localStorage\.getItem\(`devin-language`\)===`zh`')
if (-not $vsPatched) {
    $pat = '([A-Za-z_$][\w$]*)\.get\(`users/ui-language`,\{signal:([A-Za-z_$][\w$]*)\}\)(\.json\(\))?'
    if ($s2 -notmatch $pat) { throw '未找到 users/ui-language GET 调用,版本可能已变化' }
    $s2 = [regex]::Replace($s2, $pat, [System.Text.RegularExpressions.MatchEvaluator]{
        param($mm)
        $c = $mm.Groups[1].Value; $v = $mm.Groups[2].Value; $j = $mm.Groups[3].Value
        "(()=>{try{if(localStorage.getItem(``devin-language``)===``zh``)return{ui_language:``zh``}}catch{}return $c.get(``users/ui-language``,{signal:$v})$j})()"
    })
    $dirty = $true
    Write-Host '[+] index: zh 读取走 localStorage (GET)'
} else { Write-Host '[=] index: GET 补丁已存在,跳过' }

if ($dirty) {
    if (-not (Test-Path "$($index.FullName).zhorig")) {
        Copy-Item $index.FullName "$($index.FullName).zhorig"
    }
    Save-Text $index.FullName $s2
}

# ---------- 4. 校验 ----------
$ok = $true
$s = [IO.File]::ReadAllText($menu.FullName, $utf8)
$s2 = [IO.File]::ReadAllText($index.FullName, $utf8)
if ($s -notmatch 'code:`zh`') { $ok = $false; Write-Host '[!] 校验失败: 语言列表无 zh' }
if ($s2 -notmatch '===`zh`') { $ok = $false; Write-Host '[!] 校验失败: index 无 zh PUT 补丁' }
if ($s2 -notmatch 'localStorage\.getItem\(`devin-language`\)===`zh`') { $ok = $false; Write-Host '[!] 校验失败: index 无 zh GET 补丁' }
foreach ($f in 'zh-CN-translation.js', 'zh-CN-review.js') {
    if (-not (Test-Path (Join-Path $assets $f))) { $ok = $false; Write-Host "[!] 校验失败: 缺 $f" }
}
$nlsCheck = Join-Path $outDir 'nls.messages.json'
if ((Test-Path $nlsCheck) -and (-not ([IO.File]::ReadAllText($nlsCheck, $utf8)).Contains('关闭对话框'))) { $ok = $false; Write-Host '[!] 校验失败: nls.messages.json 未汉化' }
if ($ok) {
    Write-Host ''
    Write-Host '==== 汉化完成 ===='
    Write-Host '完全退出并重启 Devin(顶部菜单栏由主进程在启动时加载,Reload Window 不会刷新),'
    Write-Host '然后在语言选项里选择 中文(简体)。'
}
