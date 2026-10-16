[CmdletBinding()]
param (
    [string]$Name,

    [string]$Text,
    [string]$Top,
    [string]$Bottom,
    [string]$TextColor,

    [int]$Size = 256,

    [switch]$Quiet,

    [switch]$ListPairs,

    [switch]$Letters,

    [switch]$What,

    [string]$Out = "terminal-icon.png"
)

$Palette = @(
    @{ Name = "orange";   Top = "#CF7040"; Bottom = "#B95E30"; Text = "#FFFFFF" },
    @{ Name = "blue";     Top = "#3B82F6"; Bottom = "#2563EB"; Text = "#FFFFFF" },
    @{ Name = "green";    Top = "#2E8B57"; Bottom = "#1F5C3E"; Text = "#FFFFFF" },
    @{ Name = "purple";   Top = "#7C5CBF"; Bottom = "#5B3F9E"; Text = "#FFFFFF" },
    @{ Name = "red";      Top = "#C0453B"; Bottom = "#93291F"; Text = "#FFFFFF" },
    @{ Name = "teal";     Top = "#148F8A"; Bottom = "#0E6B67"; Text = "#FFFFFF" },
    @{ Name = "graphite"; Top = "#4B5563"; Bottom = "#374151"; Text = "#FFFFFF" },
    @{ Name = "sand";     Top = "#E3C567"; Bottom = "#C9A73F"; Text = "#2A2410" }
)

function Get-Letters {
    param([string]$Instance)

    $Pieces = @($Instance -split '[-_.]' | Where-Object { $_ -match '^[A-Za-z]' })
    if ($Pieces.Count -ge 2) {
        return ($Pieces[0].Substring(0, 1) + $Pieces[1].Substring(0, 1)).ToUpper()
    }

    $Word = @($Instance -split '[-_.]' | Where-Object { $_ })[0]
    if (-not $Word) { return "?" }
    if ($Word.Length -ge 2) { return $Word.Substring(0, 2).ToUpper() }
    return $Word.ToUpper()
}

function Get-PaletteIndex {
    param([string]$Instance)

    $Hash = [long]0
    foreach ($Character in $Instance.ToLowerInvariant().ToCharArray()) {
        $Hash = ($Hash * 31 + [int]$Character) % 1000003
    }
    return [int]($Hash % $Palette.Count)
}

if ($ListPairs) {
    foreach ($Row in $Palette) {
        "{0}`t{1}`t{2}`t{3}" -f $Row.Name, $Row.Top, $Row.Bottom, $Row.Text
    }
    return
}

if ($Letters) {
    if (-not $Name) { throw "The letters are read from a name: give a -Name." }
    Get-Letters $Name
    return
}

if (-not $Name -and -not $Text) {
    throw "Nothing to draw: give a -Name (the letters and the colours come from it) or a -Text."
}

$Row = $Palette[0]
if ($Name) {
    $Row = $Palette[(Get-PaletteIndex $Name)]
    if (-not $Text) { $Text = Get-Letters $Name }
}
if (-not $Top) { $Top = $Row.Top }
if (-not $Bottom) { $Bottom = $Row.Bottom }
if (-not $TextColor) { $TextColor = $Row.Text }

Add-Type -AssemblyName System.Drawing

$family = $null
foreach ($name in @("Cascadia Mono", "Cascadia Code", "Consolas", "Segoe UI")) {
    try { $family = New-Object System.Drawing.FontFamily($name); break } catch { }
}
if (-not $family) { throw "No usable font family found on this machine." }

function Get-Monogram([single]$PixelSize) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.FillMode = [System.Drawing.Drawing2D.FillMode]::Winding
    $path.AddString($Text, $family, [int][System.Drawing.FontStyle]::Bold, $PixelSize,
                     (New-Object System.Drawing.PointF(0, 0)),
                     [System.Drawing.StringFormat]::GenericTypographic)
    return $path
}

function ConvertTo-Color([string]$Html) {
    return [System.Drawing.ColorTranslator]::FromHtml($Html)
}

$bitmap = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$canvas = [System.Drawing.Graphics]::FromImage($bitmap)
$canvas.SmoothingMode = 'AntiAlias'
$canvas.Clear([System.Drawing.Color]::Transparent)

$margin = [single][Math]::Round($Size * 0.023)
$rect = New-Object System.Drawing.RectangleF($margin, $margin,
            [single]($Size - 2 * $margin), [single]($Size - 2 * $margin))

$radius = [single]($rect.Width * 0.22)
$diameter = [single]($radius * 2)
$tile = New-Object System.Drawing.Drawing2D.GraphicsPath
$tile.AddArc($rect.X, $rect.Y, $diameter, $diameter, [single]180, [single]90)
$tile.AddArc(($rect.Right - $diameter), $rect.Y, $diameter, $diameter, [single]270, [single]90)
$tile.AddArc(($rect.Right - $diameter), ($rect.Bottom - $diameter), $diameter, $diameter, [single]0, [single]90)
$tile.AddArc($rect.X, ($rect.Bottom - $diameter), $diameter, $diameter, [single]90, [single]90)
$tile.CloseFigure()

$gradient = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $rect, (ConvertTo-Color $Top), (ConvertTo-Color $Bottom), 90)
$canvas.FillPath($gradient, $tile)

$probe = Get-Monogram 100
$probeBounds = $probe.GetBounds()
$probe.Dispose()
$scale = [Math]::Min(($rect.Width * 0.74) / $probeBounds.Width,
                     ($rect.Height * 0.74) / $probeBounds.Height)

$monogram = Get-Monogram ([single](100 * $scale))
$bounds = $monogram.GetBounds()
$shift = New-Object System.Drawing.Drawing2D.Matrix
$shift.Translate([single]($rect.X + ($rect.Width - $bounds.Width) / 2 - $bounds.X),
                 [single]($rect.Y + ($rect.Height - $bounds.Height) / 2 - $bounds.Y))
$monogram.Transform($shift)
$canvas.FillPath((New-Object System.Drawing.SolidBrush((ConvertTo-Color $TextColor))), $monogram)

$target = [System.IO.Path]::GetFullPath($Out)
$bitmap.Save($target, [System.Drawing.Imaging.ImageFormat]::Png)
$canvas.Dispose()
$bitmap.Dispose()

if ($What) {
    [PSCustomObject]@{
        Text      = $Text
        Top       = $Top
        Bottom    = $Bottom
        TextColor = $TextColor
    } | ConvertTo-Json -Compress
}

if (-not $Quiet -and -not $What) {
    Write-Host ("Wrote {0}" -f $target)
    Write-Host ("  {0}x{0} px, monogram '{1}', {2} -> {3}" -f $Size, $Text, $Top, $Bottom)
}
