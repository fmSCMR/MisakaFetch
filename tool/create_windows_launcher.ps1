# Build a small launcher outside the source folder in the organized workspace.
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
if (-not (Test-Path -LiteralPath $compiler)) {
    throw '没有找到 Windows .NET Framework C# 编译器。'
}
$source = Join-Path $PSScriptRoot 'windows_launcher.cs'
$launcherRoot = $projectRoot
if ((Split-Path -Leaf $projectRoot) -in @('source', '项目源码')) {
    $launcherRoot = Split-Path -Parent $projectRoot
}
$output = Join-Path $launcherRoot 'MisakaFetch.exe'
$icon = Join-Path $projectRoot 'windows/runner/resources/app_icon.ico'
& $compiler /nologo /target:winexe /platform:anycpu /optimize+ /reference:System.Windows.Forms.dll "/win32icon:$icon" "/out:$output" $source
if ($LASTEXITCODE -ne 0) { throw 'MisakaFetch 启动器编译失败。' }
Write-Output "启动器已生成：$output"
