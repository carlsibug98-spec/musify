# Resona brand

**Name:** Resona  
**Tagline:** Daylight for your music.  
**Mark:** seven-bar resonance waveform; a five-bar compact cut is used in the app.

## Palette

| Role | Value |
| --- | --- |
| Resona green | `#22D760` |
| Deep green | `#0E9F48` |
| Icon ink | `#0B0D10` |
| Icon ink top | `#20242B` |
| Daylight light ground | `#F7F9FC` |
| Daylight dark ground | `#0B0D10` |
| Daylight cobalt accent | `#2743E8` |

Daylight's cool-grey grounds and user-selectable accent stay in place; Resona green
is reserved for the brand mark and app icon. That keeps the logo recognisable even
when the interface accent changes.

## Files

- `resona-icon-1024.png` — master app icon.
- `resona-banner.png` — README / store banner.
- `../assets/icons/resona_icon.png` — 256 px in-app tile used on About.
- `../assets/icons/ic_launcher.png` — Linux desktop icon.
- `../android/app/src/main/res/` — legacy, round, adaptive, monochrome launcher icons.
- `../windows/runner/resources/app_icon.{png,ico}` — Windows icons.
- `../fastlane/metadata/android/en-US/images/icon.png` — store icon.

Regenerate everything with:

```bash
python scripts/generate_brand_assets.py
```

The generator requires Pillow and uses the same Bricolage Grotesque and Inter fonts
that ship in `assets/fonts/daylight/`.
