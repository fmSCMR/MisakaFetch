# Convert the supplied artwork into platform icon resources; no runtime dependency.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$projectRoot = Split-Path -Parent $PSScriptRoot
$square = [Drawing.Image]::FromFile((Join-Path $projectRoot 'branding/icon-square.jpg'))
$rounded = [Drawing.Image]::FromFile((Join-Path $projectRoot 'branding/icon-rounded.jpg'))
function Get-IconPng([Drawing.Image]$image, [int]$size, [int]$inset = 0) {
    $bitmap = [Drawing.Bitmap]::new($size, $size)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $stream = [IO.MemoryStream]::new()
    try {
        $graphics.Clear([Drawing.Color]::White)
        $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.DrawImage($image, [Drawing.Rectangle]::new($inset, $inset, $size - 2*$inset, $size - 2*$inset))
        $bitmap.Save($stream, [Drawing.Imaging.ImageFormat]::Png)
        return ,$stream.ToArray()
    } finally { $stream.Dispose(); $graphics.Dispose(); $bitmap.Dispose() }
}
try {
    $icoSizes = @(16,24,32,48,64,128,256)
    $frames = @($icoSizes | ForEach-Object { ,(Get-IconPng $rounded $_) })
    $icoPath = Join-Path $projectRoot 'windows/runner/resources/app_icon.ico'
    $file = [IO.File]::Create($icoPath)
    $writer = [IO.BinaryWriter]::new($file)
    try {
        $writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]$icoSizes.Count)
        $offset = 6 + 16*$icoSizes.Count
        for ($i=0; $i -lt $icoSizes.Count; $i++) {
            $dimension = if ($icoSizes[$i] -eq 256) {0} else {$icoSizes[$i]}
            $writer.Write([byte]$dimension); $writer.Write([byte]$dimension)
            $writer.Write([byte]0); $writer.Write([byte]0)
            $writer.Write([uint16]1); $writer.Write([uint16]32)
            $writer.Write([uint32]$frames[$i].Length); $writer.Write([uint32]$offset)
            $offset += $frames[$i].Length
        }
        foreach ($frame in $frames) { $writer.Write([byte[]]$frame) }
    } finally { $writer.Dispose(); $file.Dispose() }
    $androidRes = Join-Path $projectRoot 'android/app/src/main/res'
    $densities = @{mdpi=48; hdpi=72; xhdpi=96; xxhdpi=144; xxxhdpi=192}
    foreach ($entry in $densities.GetEnumerator()) {
        $directory = Join-Path $androidRes ('mipmap-'+$entry.Key)
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
        [IO.File]::WriteAllBytes((Join-Path $directory 'ic_launcher.png'), (Get-IconPng $square $entry.Value))
    }
    New-Item -ItemType Directory -Path (Join-Path $androidRes 'drawable-nodpi'),(Join-Path $androidRes 'mipmap-anydpi-v26') -Force | Out-Null
    # 108dp layer at 4x density, original square fitted into the central 72dp.
    [IO.File]::WriteAllBytes((Join-Path $androidRes 'drawable-nodpi/misakafetch_icon_foreground.png'), (Get-IconPng $square 432 72))
    [IO.File]::WriteAllBytes((Join-Path $projectRoot 'branding/icon-preview.png'), (Get-IconPng $rounded 256))
    Write-Output '已生成 Windows 多尺寸 ICO、Android 各密度 PNG 与自适应图标前景。'
} finally { $square.Dispose(); $rounded.Dispose() }
