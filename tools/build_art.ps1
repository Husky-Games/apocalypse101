<#
.SYNOPSIS
  Rebuilds the game's sprite art from the LimeZu asset-pack zips.

.DESCRIPTION
  Reads straight from the purchased packs in content/downloaded (gitignored, not redistributable):
    modernexteriors-win.zip          Modern Exteriors (full)
    moderninteriors-win.zip          Modern Interiors (full)
    Fantasy Battlers - Complete.zip  Fantasy Battlers (complete)

  Writes:
    source/apocalypse101/_art/atlas.png         every tile/prop/battler, shelf-packed (gitignored)
    source/apocalypse101/_art/ch_*.png, en_*.png  384x64 character strips (gitignored)
    source/apocalypse101/scripts/scr_atlas/scr_atlas.gml   name -> [x, y, w, h] lookup table
  and, unless -NoInstall, copies the images into the matching GameMaker sprite folders
  (spr_atlas, spr_ch_*, spr_en_*), whose sizes must stay 1024x512 / 384x64.

  Character strips: row 0 = idle animation, row 1 = walk; 24 frames of 16x32 each,
  6 per direction in LimeZu order (right, up, left, down).

  All art is drawn at 16 px per world unit (the game scales it 3x). To add or swap art,
  edit $Parts / $Cast below, re-run, then rebuild the game. Close the project in the
  GameMaker IDE first, or it may overwrite the project files.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\build_art.ps1
#>
param([switch]$NoInstall)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression.FileSystem

$Repo    = Split-Path -Parent $PSScriptRoot
$Packs   = Join-Path $Repo "content\downloaded"
$Project = Join-Path $Repo "source\apocalypse101"
$OutDir  = Join-Path $Project "_art"
$GmlOut  = Join-Path $Project "scripts\scr_atlas\scr_atlas.gml"

$EXT = "modernexteriors-win.zip"
$INT = "moderninteriors-win.zip"
$FB  = "Fantasy Battlers - Complete.zip"
$exS = "Modern_Exteriors_16x16/ME_Theme_Sorter_16x16"
$cls = "1_Interiors/16x16/Theme_Sorter_Singles/5_Classroom_and_Library_Singles/Classroom_and_Library_Singles"

# name, zip, entry path, rect ("" = whole image)
$Parts = @(
  # Modern Exteriors
  @("grass",      $EXT, "$exS/1_Terrains_and_Fences_16x16.png", "48,96,16,16"),
  @("grass2",     $EXT, "$exS/1_Terrains_and_Fences_16x16.png", "16,112,16,16"),
  @("fence",      $EXT, "$exS/1_Terrains_and_Fences_16x16.png", "314,258,11,28"),
  @("asphalt",    $EXT, "$exS/2_City_Terrains_Singles_16x16/ME_Singles_City_Terrains_16x16_Asphalt_1_Variation_24.png", ""),
  @("pave",       $EXT, "$exS/2_City_Terrains_Singles_16x16/ME_Singles_City_Terrains_16x16_Sidewalk_1_10.png", ""),
  @("school",     $EXT, "$exS/13_School_Singles_16x16/ME_Singles_School_16x16_School_1.png", ""),
  @("tower",      $EXT, "$exS/13_School_Singles_16x16/ME_Singles_School_16x16_Clock_Tower_1.png", ""),
  @("car1",       $EXT, "$exS/3_City_Props_Singles_16x16/ME_Singles_City_Props_16x16_Car_Wreck_2.png", ""),
  @("car2",       $EXT, "$exS/3_City_Props_Singles_16x16/ME_Singles_City_Props_16x16_Car_Wreck_3.png", ""),
  @("container",  $EXT, "$exS/3_City_Props_Singles_16x16/ME_Singles_City_Props_16x16_Container_2.png", ""),
  @("tree_dead1", $EXT, "$exS/19_Graveyard_Singles_16x16/ME_Singles_Graveyard_16x16_Medium_Tree_1.png", ""),
  @("tree_dead2", $EXT, "$exS/19_Graveyard_Singles_16x16/ME_Singles_Graveyard_16x16_Medium_Tree_2.png", ""),
  @("tree_big",   $EXT, "$exS/19_Graveyard_Singles_16x16/ME_Singles_Graveyard_16x16_Big_Tree_.png", ""),
  @("tree_leaf1", $EXT, "$exS/3_City_Props_Singles_16x16/ME_Singles_City_Props_16x16_Tree_1.png", ""),
  @("tree_leaf2", $EXT, "$exS/3_City_Props_Singles_16x16/ME_Singles_City_Props_16x16_Tree_11.png", ""),
  @("sign",       $EXT, "$exS/3_City_Props_Singles_16x16/ME_Singles_City_Props_16x16_Danger_Sign_1.png", ""),
  @("junk",       $EXT, "$exS/3_City_Props_Singles_16x16/ME_Singles_City_Props_16x16_Junk_6.png", ""),
  @("bench",      $EXT, "$exS/13_School_Singles_16x16/ME_Singles_School_16x16_Bench_1.png", ""),
  # Modern Interiors (full)
  @("floor",      $INT, "1_Interiors/16x16/Room_Builder_16x16.png", "672,304,48,32"),
  @("wall",       $INT, "1_Interiors/16x16/Room_Builder_16x16.png", "192,176,16,32"),
  @("workbench",  $INT, "1_Interiors/16x16/Interiors_16x16.png", "16,5329,64,23"),
  @("desk1",      $INT, "${cls}_14.png", ""),
  @("desk2",      $INT, "${cls}_16.png", ""),
  @("desk3",      $INT, "${cls}_18.png", ""),
  @("desk4",      $INT, "${cls}_20.png", ""),
  @("desk5",      $INT, "${cls}_22.png", ""),
  @("desk6",      $INT, "${cls}_24.png", ""),
  @("tdesk",      $INT, "${cls}_25.png", ""),
  @("board",      $INT, "${cls}_36.png", ""),
  @("map",        $INT, "${cls}_31.png", ""),
  @("cork",       $INT, "${cls}_33.png", ""),
  @("globe",      $INT, "${cls}_34.png", ""),
  @("locker",     $INT, "${cls}_40.png", ""),
  # Fantasy Battlers (front-facing combat enemies)
  @("bt_shade",   $FB, "Fantasy Battlers - Complete/Original size/14.png", ""),
  @("bt_hollow",  $FB, "Fantasy Battlers - Complete/Original size/17.png", "")
)

# Characters, built from Modern Interiors Character Generator layers, stacked in LimeZu's order:
# body, eyes, outfit, hairstyle, accessory. Designs follow content/characters.md and the reference art.
$Cast = [ordered]@{
  ch_teacher  = @("Body_01", "Eyes_01", "Outfit_01_09", "Hairstyle_16_04", "Accessory_12_Mustache_01")  # Mr. Ramirez
  ch_pritya   = @("Body_04", "Eyes_01", "Outfit_01_10", "Hairstyle_26_03")                             # Pritya Nair
  ch_maya     = @("Body_03", "Eyes_01", "Outfit_33_01", "Hairstyle_15_07")                             # Maya Chen
  ch_jake     = @("Body_07", "Eyes_01", "Outfit_09_01", "Hairstyle_03_02", "Accessory_18_Chef_01")     # Jake Torres
  ch_axel     = @("Body_02", "Eyes_03", "Outfit_06_03", "Hairstyle_09_07")                             # Axel Thompson
  ch_viola    = @("Body_02", "Eyes_04", "Outfit_01_05", "Hairstyle_20_01")                             # Viola Abelard
  ch_jorge    = @("Body_04", "Eyes_01", "Outfit_09_03", "Hairstyle_02_04", "Accessory_15_Glasses_01")  # Jorge Gutierrez
  ch_scarlett = @("Body_03", "Eyes_02", "Outfit_01_06", "Hairstyle_29_01")                             # Scarlett Andersen
  ch_zuri     = @("Body_01", "Eyes_01", "Outfit_17_03", "Hairstyle_23_04", "Accessory_17_Medical_Mask_01") # Zuri Williams
}
$LayerDirs = @{ Body = "Bodies"; Eyes = "Eyes"; Outfit = "Outfits"; Hairstyle = "Hairstyles"; Accessory = "Accessories" }

# Overworld enemies: single premade sheets. sprite name -> zip, entry
$zom = "Modern_Exteriors_16x16/Character_Generator_Addons_16x16/Characters_16x16/Modern_Exteriors_Characters"
$Enemies = [ordered]@{
  en_shade  = @($EXT, "${zom}_Zombie_1_16x16.png")
  en_hollow = @($EXT, "${zom}_Zombie_2_16x16.png")
}

# ---------------------------------------------------------------- zip access
$zips = @{}
function Open-Pack($name) {
  if (-not $zips.ContainsKey($name)) {
    # packs may sit directly in content/downloaded or in a subfolder (e.g. content/downloaded/LimeZu)
    $found = Get-ChildItem $Packs -Recurse -File -Filter $name -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $found) { throw "Missing asset pack '$name' under $Packs" }
    $path = $found.FullName
    $zips[$name] = [System.IO.Compression.ZipFile]::OpenRead($path)
  }
  $zips[$name]
}
$imgCache = @{}
function Get-Image($zip, $entry) {
  $key = "$zip|$entry"
  if (-not $imgCache.ContainsKey($key)) {
    $e = (Open-Pack $zip).GetEntry($entry)
    if (-not $e) { throw "Missing entry in ${zip}: $entry" }
    $s = $e.Open(); $ms = New-Object System.IO.MemoryStream; $s.CopyTo($ms); $s.Dispose()
    $ms.Position = 0
    $tmp = [System.Drawing.Image]::FromStream($ms)
    $imgCache[$key] = New-Object System.Drawing.Bitmap $tmp   # detach from the stream
    $tmp.Dispose(); $ms.Dispose()
  }
  $imgCache[$key]
}
function Copy-Rect($img, $r, $w, $h) {
  $bm = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bm)
  $g.DrawImage($img, (New-Object System.Drawing.Rectangle 0, 0, $w, $h), $r, [System.Drawing.GraphicsUnit]::Pixel)
  $g.Dispose(); $bm
}

try {
  New-Item -ItemType Directory -Force $OutDir | Out-Null

  # ---------------------------------------------------------------- atlas
  $items = @()
  foreach ($p in $Parts) {
    $img = Get-Image $p[1] $p[2]
    if ($p[3] -eq "") { $r = New-Object System.Drawing.Rectangle 0, 0, $img.Width, $img.Height }
    else { $v = $p[3].Split(",") | ForEach-Object { [int]$_ }; $r = New-Object System.Drawing.Rectangle $v[0], $v[1], $v[2], $v[3] }
    $items += ,@($p[0], (Copy-Rect $img $r $r.Width $r.Height))
  }
  # Shelf pack, tallest first, 2 px padding
  $W = 1024; $pad = 2
  $x = $pad; $y = $pad; $shelf = 0; $place = @{}
  foreach ($it in ($items | Sort-Object { -$_[1].Height })) {
    $bw = $it[1].Width; $bh = $it[1].Height
    if ($x + $bw + $pad -gt $W) { $x = $pad; $y += $shelf + $pad; $shelf = 0 }
    $place[$it[0]] = @($x, $y, $bw, $bh)
    $x += $bw + $pad; $shelf = [Math]::Max($shelf, $bh)
  }
  $H = 1; while ($H -lt $y + $shelf + $pad) { $H *= 2 }
  if ($W -ne 1024 -or $H -ne 512) { Write-Warning "Atlas is ${W}x$H; update spr_atlas.yy width/height to match." }
  $atlas = New-Object System.Drawing.Bitmap $W, $H, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($atlas)
  $g.Clear([System.Drawing.Color]::FromArgb(0, 0, 0, 0))
  foreach ($it in $items) { $pl = $place[$it[0]]; $g.DrawImageUnscaled($it[1], $pl[0], $pl[1]) }
  $g.Dispose()
  $atlas.Save((Join-Path $OutDir "atlas.png"), [System.Drawing.Imaging.ImageFormat]::Png)

  $lines = @("// GENERATED by tools/build_art.ps1 from LimeZu's Modern Exteriors, Modern Interiors (full) and Fantasy Battlers packs.",
             "// Region of each tile/prop inside spr_atlas: [x, y, w, h] in art pixels (16 px = 1 world unit).",
             "function atlas_init() {", "    global.ATLAS = {")
  foreach ($p in $Parts) { $pl = $place[$p[0]]; $lines += "        $($p[0]): [$($pl[0]), $($pl[1]), $($pl[2]), $($pl[3])]," }
  $lines += @("    };", "}")
  Set-Content -Path $GmlOut -Encoding utf8 -Value ($lines -join "`r`n")

  # ---------------------------------------------------------------- character strips
  # Each strip copies the sheet's idle row (y=32) and walk row (y=64), compositing layers in order.
  function Save-Strip($name, $images) {
    $bm = New-Object System.Drawing.Bitmap 384, 64, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bm)
    foreach ($img in $images) {
      $g.DrawImage($img, (New-Object System.Drawing.Rectangle 0, 0, 384, 32), (New-Object System.Drawing.Rectangle 0, 32, 384, 32), [System.Drawing.GraphicsUnit]::Pixel)
      $g.DrawImage($img, (New-Object System.Drawing.Rectangle 0, 32, 384, 32), (New-Object System.Drawing.Rectangle 0, 64, 384, 32), [System.Drawing.GraphicsUnit]::Pixel)
    }
    $g.Dispose()
    $bm.Save((Join-Path $OutDir "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
  }
  foreach ($name in $Cast.Keys) {
    $images = foreach ($layer in $Cast[$name]) {
      $dir = $LayerDirs[$layer.Split("_")[0]]
      Get-Image $INT "2_Characters/Character_Generator/$dir/16x16/$layer.png"
    }
    Save-Strip $name $images
  }
  foreach ($name in $Enemies.Keys) { Save-Strip $name @(Get-Image $Enemies[$name][0] $Enemies[$name][1]) }

  # ---------------------------------------------------------------- install into sprites
  if (-not $NoInstall) {
    $map = @{ spr_atlas = "atlas" }
    foreach ($name in @($Cast.Keys) + @($Enemies.Keys)) { $map["spr_$name"] = $name }
    foreach ($spr in $map.Keys) {
      $dir = Join-Path $Project "sprites\$spr"
      if (-not (Test-Path $dir)) { Write-Warning "Sprite folder missing: $spr (create it in GameMaker first)"; continue }
      Get-ChildItem $dir -Recurse -Filter *.png | ForEach-Object { Copy-Item (Join-Path $OutDir "$($map[$spr]).png") $_.FullName -Force }
    }
  }
  "Built atlas ${W}x$H ($($Parts.Count) parts), $($Cast.Count) character and $($Enemies.Count) enemy strips."
}
finally {
  foreach ($z in $zips.Values) { $z.Dispose() }
}
