# Tools

## build_art.ps1: rebuild the game art

Regenerates the GameMaker sprites from LimeZu's asset packs. Nothing is extracted by hand; the script reads the zips directly.

### Requirements

- Windows PowerShell 5.1 (uses .NET `System.Drawing`).
- The purchased packs anywhere under `content/downloaded/`, including subfolders such as `content/downloaded/LimeZu/` (gitignored, since the licenses forbid redistributing them):
  - `modernexteriors-win.zip` (Modern Exteriors)
  - `moderninteriors-win.zip` (Modern Interiors, full version)
  - `Fantasy Battlers - Complete.zip`

### Run

Close the project in the GameMaker IDE first. If it stays open, the IDE can overwrite the project files.

```powershell
powershell -ExecutionPolicy Bypass -File tools\build_art.ps1
```

This writes `source/apocalypse101/scripts/scr_atlas/scr_atlas.gml` and copies the new images into `spr_atlas`, `spr_ch_*` and `spr_en_*`. Add `-NoInstall` to only write the intermediate files in `source/apocalypse101/_art/` (gitignored).

### Changing art

- **Tiles, props and battlers:** edit `$Parts`. Each entry is a name, a zip, the path inside the zip, and an optional `x,y,w,h` crop. The game looks up art by name through `global.ATLAS`.
- **Characters:** edit `$Cast`. Each character is a stack of Modern Interiors Character Generator layers, in LimeZu's order: body, eyes, outfit, hairstyle, accessory (for example `Body_01`, `Outfit_01_09`, `Accessory_12_Mustache_01`). The generator's `*_LIST.png` sheets show the options. The script takes the idle row (y=32) and walk row (y=64): 24 frames of 16x32 (right, up, left, down, 6 each).
- **Overworld enemies:** edit `$Enemies` (single premade sheets in the same layout).
- **New sprites:** a new `spr_*` asset has to exist in the project before the script can install into it.
- **Atlas size:** if it grows past 1024x512, the script warns. Update `width`/`height` in `sprites/spr_atlas/spr_atlas.yy` to match.

### Licensing

All three packs allow commercial use with credit to LimeZu (limezu.itch.io). The game shows this credit on the party screen. Don't commit the zips or the raw pack files.
