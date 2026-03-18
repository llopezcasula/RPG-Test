Please note that due to asset pack licence and resulting limitations to redistribute assets. This project only contains the assets that are distrubited in the CC0 flagged folder. Other assets will have to be downloaded and added manually from https://pixelfrog-assets.itch.io/tiny-swords

That includes: 
Bushe1
Bushe2
Bushe3
Tree3
Tree4
Water Foam
Clouds_01
Clouds_02
Clouds_03
Clouds_04
Clouds_05
Clouds_06
Clouds_07
Clouds_08
Shadow
Tilemap_color1
Tilemap_color3
Water Background color

## Godot 4 map depth-layering template

A reusable map scene template now lives at `scenes/maps/map.tscn` with a helper script at `scenes/maps/map_depth_layers.gd`.

Layering layout:
- `Water`
- `FoamRocks`
- `Ground`
- `Shadows`
- `Plateau`
- `Props`
- `Trees`
- `Sortables`
  - `Player`
  - `Enemies`
  - `NPCs`

Notes:
- Do **not** enable Y Sort on the `Map` root.
- Only `Sortables` should have `y_sort_enabled = true`.
- Keep static terrain in the TileMapLayer nodes.
- Move tall tree/canopy tiles out of `Props` and into `Trees` in the Godot editor if they are already painted into a single layer.
- If an older map scene still has `Player` directly under `Map`, the helper script reparents it into `Sortables/Player` while preserving transform.
