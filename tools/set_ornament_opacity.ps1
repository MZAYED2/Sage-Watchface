param(
    [int]$OpacityPercent = 16,
    [double]$Scale = 1.30
)

Add-Type -AssemblyName System.Drawing

$sourcePath = Join-Path $PSScriptRoot "ottoman_source_full.png"
$targetPath = Join-Path $PSScriptRoot "..\watchface\src\main\res\drawable\uc_0_orn_1.png"

if (-not (Test-Path $sourcePath)) {
    Write-Error "Source master ornament not found at $sourcePath"
    exit 1
}

Write-Host "Generating enlarged ornament (Scale: ${Scale}x, Opacity: ${OpacityPercent}%) from $sourcePath..."

$srcImg = [System.Drawing.Bitmap]::FromFile($sourcePath)
$canvasSize = 1254

# Ornament bounding box in original source: X=[28, 596], Y=[38, 1170]
$cropX = 28
$cropY = 38
$cropW = 596 - 28 # 568
$cropH = 1170 - 38 # 1132

$cropRect = New-Object System.Drawing.Rectangle($cropX, $cropY, $cropW, $cropH)
$ornCrop = $srcImg.Clone($cropRect, $srcImg.PixelFormat)

# Scaled dimensions
$newW = [int]($cropW * $Scale)
$newH = [int]($cropH * $Scale)

# Align right edge at the centerline (X = 627)
$centerLine = [int]($canvasSize / 2) # 627
$destX = $centerLine - $newW
$destY = [int](($canvasSize - $newH) / 2)

$dstBmp = New-Object System.Drawing.Bitmap($canvasSize, $canvasSize, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($dstBmp)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

$destRect = New-Object System.Drawing.Rectangle($destX, $destY, $newW, $newH)
$g.DrawImage($ornCrop, $destRect)
$g.Dispose()
$ornCrop.Dispose()
$srcImg.Dispose()

# Now apply opacity and strictly ensure no pixels cross into the right half (X >= centerLine)
$rect = New-Object System.Drawing.Rectangle(0, 0, $canvasSize, $canvasSize)
$bmpData = $dstBmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

$bytes = $canvasSize * $canvasSize * 4
$pixelBuffer = New-Object byte[] $bytes
[System.Runtime.InteropServices.Marshal]::Copy($bmpData.Scan0, $pixelBuffer, 0, $bytes)

$mult = $OpacityPercent / 100.0

for ($y = 0; $y -lt $canvasSize; $y++) {
    for ($x = 0; $x -lt $canvasSize; $x++) {
        $offset = ($y * $canvasSize + $x) * 4
        if ($x -gt $centerLine) {
            # Zero out anything crossing into the right half
            $pixelBuffer[$offset + 3] = 0
        } else {
            $origA = $pixelBuffer[$offset + 3]
            if ($origA -gt 0) {
                $newA = [int][Math]::Round($origA * $mult)
                if ($newA -gt 255) { $newA = 255 }
                $pixelBuffer[$offset + 3] = [byte]$newA
            }
        }
    }
}

[System.Runtime.InteropServices.Marshal]::Copy($pixelBuffer, 0, $bmpData.Scan0, $bytes)
$dstBmp.UnlockBits($bmpData)

$dstBmp.Save($targetPath, [System.Drawing.Imaging.ImageFormat]::Png)
$dstBmp.Dispose()

Write-Host "Successfully generated: $targetPath ($canvasSize x $canvasSize) covering entire left side to centerline with $OpacityPercent% opacity."
