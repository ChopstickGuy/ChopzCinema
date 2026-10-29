# ChopzCinema Shaders (v0.2, Entwicklungsversion)

Ein cineastischer Shader für **Minecraft 1.20.1** mit **Oculus/Iris** und Unterstützung für **Distant Horizons**.
Ziel: Film-Look (Teal & Orange, weiches Licht, starke Licht-/Schattenkontraste), volumetrische Wolken, Nebel und Lichtstrahlen. Die Reflexionen sollen schön sein, ohne zu übertreiben.

## Voraussetzungen
- Forge 1.20.1 mit **Oculus 1.8.0** + **Embeddium** (oder Fabric mit Iris 1.7+ und Sodium)
- optional **Distant Horizons 2.2+ / 3.x**

## Installation
1. `ChopzCinema-v0.1.zip` in den Ordner `.minecraft/shaderpacks/` legen (nicht entpacken).
2. Im Spiel: Optionen → Grafik → Shader-Pakete → **ChopzCinema** auswählen.
3. Profil im Shader-Menü wählen (LOW / MEDIUM / HIGH / ULTRA). Standard ist HIGH.

## Features
| Bereich | Inhalt |
|---|---|
| Himmel | physikalischer Himmel (Rayleigh, Mie, Ozon), echte Sonnenuntergänge, „Day-for-Night“-Nächte |
| Nachthimmel | dunkler Sternenhimmel mit 3 Sternebenen (Farbtemperaturen, Funkeln), Milchstraße mit Staubbändern, Sternschnuppen, Polarlichter in manchen Nächten (auch im Wasser gespiegelt), Sterne drehen sich mit dem Himmel |
| Wolken | volumetrische Cumulus-Wolken (halbe Auflösung), Silberränder, Regen macht sie dichter |
| Nebel | Höhennebel und Dunst, Morgen-/Abendnebel, Lichtstrahlen (God Rays) mit echten Schatten, Unterwasser-Lichtstrahlen |
| Licht | weiche Schatten (Vogel-PCF), farbige Schatten durch Glas, durchscheinende Blätter, warmes Fackellicht (Kelvin einstellbar) |
| Wasser | prozedurale Wellen, Lichtbrechung, Absorption, Screen-Space-Reflexionen, Sonnenglitzern |
| Reflexionen | Metall- und polierte Blöcke, Pfützen bei Regen |
| Kamera | TAA, Auto-Belichtung, Bloom mit Halation, AgX-/ACES-Filmkurve, Color Grading, anamorphotischer Lens Flare, Vignette, Filmkorn, optionale Kinobalken |
| Distant Horizons | LODs bekommen dieselbe Beleuchtung, denselben Nebel, Wolken und TAA, mit einem nahtlosen Übergang zu den normalen Chunks |

## Projektstruktur
```
shaders/
  shaders.properties   Menü, Profile, Blend-Modi
  block.properties     Material-IDs (Blätter, Glas, Metall, Lichtquellen, …)
  lib/                 gemeinsamer Code (Himmel, Schatten, Wolken, Nebel, Licht, Post)
  program/             die eigentlichen Programme
  world0|world-1|world1 automatisch erzeugte Wrapper je Dimension
tools_gen_wrappers.py  erzeugt die Wrapper neu (nach Änderungen an der Programmliste)
```

## Render-Pipeline
1. `shadow`: Shadow Map (mit Wind-Animation)
2. `gbuffers_*` / `dh_terrain`: G-Buffer (Albedo, Normalen, Lightmap, Material)
3. `deferred`: volumetrische Wolken (halbe Auflösung)
4. `deferred1`: Beleuchtung, Himmel, Wolken einblenden
5. `gbuffers_water` / `dh_water` / Partikel / Hand: Forward-Pass in eigenen Buffer
6. `composite`: Lichtbrechung, Wasser, Glas, Reflexionen
7. `composite1`: Lichtstrahlen (halbe Auflösung)
8. `composite2`: Nebel
9. `composite3`: TAA + Belichtung
10. `final`: Bloom, Lens Flare, Filmkurve, Grading, Vignette, Korn

## Status
Version 0.2: Alle Programme kompilieren in allen Dimensionen fehlerfrei mit einem echten OpenGL-Compiler.
**Im Spiel ist sie noch ungetestet.** Bitte bei Problemen Screenshots und `.minecraft/logs/latest.log` schicken.
