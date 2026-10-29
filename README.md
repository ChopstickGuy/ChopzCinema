# 🎬 ChopzCinema Shaders

**Cineastischer Shader für Minecraft 1.20.1, gemacht für Oculus/Iris und Distant Horizons.**

ChopzCinema soll Minecraft wie einen Kinofilm aussehen lassen: starkes Licht- und Schattenspiel, ein Film-Look mit tintenschwarzen Schatten und satten Farben wie in modernen Blockbustern, volumetrische Wolken, Nebel, Lichtstrahlen, ein echter Sternenhimmel mit Polarlichtern und Regen, der sich nach Film anfühlt.

> **Status:** v0.6, Entwicklungsversion. Im Spiel getestet mit Forge 47.4.20, Oculus 1.8.0, Embeddium 0.3.31 und Distant Horizons 3.2.0 in einer generierten Welt. Alle Screenshots unten stammen direkt aus diesem Test.

---

## Screenshots

*Alle Bilder sind echte Ingame-Screenshots (F2) mit dem Standardprofil, Distant Horizons ist aktiv.*

![Sonnenuntergang über dem Tal](docs/screenshots/sunset.jpg)
*Sonnenuntergang: Nebel im Tal, angestrahlte Wolken, Filmkurve „Brand New Day“*

| | |
|---|---|
| ![Tag](docs/screenshots/day.jpg) | ![Fernsicht mit Distant Horizons](docs/screenshots/dh_far.jpg) |
| **Tag**: harte Sonne, tiefe Schatten | **Fernsicht mit Distant Horizons**: LODs bis zum Horizont |
| ![Wald](docs/screenshots/forest.jpg) | ![Gewitter](docs/screenshots/storm.jpg) |
| **Wald am Morgen**: Schärfentiefe, Lens Flare | **Gewitter**: Regenschlieren, Regenschleier, Filmstimmung |
| ![Polarlichter](docs/screenshots/aurora.jpg) | ![Nachthimmel](docs/screenshots/night_sky.jpg) |
| **Polarlichter** (in manchen Nächten) | **Nachthimmel**: runder Mond mit Phasen, Sterne, Polarlichter |
| ![Unter Wasser](docs/screenshots/underwater.jpg) | ![Nether](docs/screenshots/nether.jpg) |
| **Unter Wasser**: Lichtstrahlen durch die Wellen | **Nether**: Lavasee, aufsteigender Rauch, tintenschwarze Schatten |
| ![Sonne](docs/screenshots/sun.jpg) | |
| **Runde Sonne** mit weicher Korona | |

---

## Features

### 🎥 Kamera & Film
- **Filmkurve** zur Auswahl: AgX Punchy (Standard), ACES oder Uchimura
- **Color Grading „Brand New Day“** (Standard), inspiriert vom Look von *Spider-Man: Brand New Day*: klassische Filmkopie-Kurve, **tintenschwarze Schatten**, satte Rot- und Blautöne, zurückhaltendes Grün, kühle Schatten und warme Lichter
- Weitere Gradings: *Blockbuster* (Teal & Orange), *Düster*, *Goldene Stunde*, *Neutral*
- **Schärfentiefe** wie bei einer Kinokamera (Fokus auf die Bildmitte, nahe Objekte oder der Hintergrund werden weich)
- Bloom mit rötlichem Film-Glühen (Halation), **anamorphotischer Lens Flare** mit Sonnen-Verdeckungstest
- Vignette, Filmkorn, leichte chromatische Aberration, optionale **Kinobalken** (2.39:1 / 1.85:1)
- **TAA** mit Nachschärfen und **automatische Belichtung**, die Nächte bewusst dunkel lässt

### ☀️ Licht & Schatten
- Weiche Schatten, die mit dem Abstand zum Schattenwerfer weicher werden (Vogel-PCF)
- **Farbige Schatten** durch Buntglas
- Durchscheinende Blätter und Gras im Gegenlicht (Subsurface Scattering)
- Warmes Fackellicht, die Farbtemperatur ist in Kelvin einstellbar
- Glanzlichter auf Metall und polierten Blöcken

### 🌅 Himmel & Atmosphäre
- **Physikalischer Himmel** (Rayleigh, Mie und Ozon) mit echten Sonnenauf- und -untergängen
- **Volumetrische Wolken** mit Silberrändern, bei Regen dichter und dunkler
- **Höhennebel**, Dunst in der Ferne und **Morgen- und Abendnebel** über dem Boden
- **Lichtstrahlen (God Rays)** im Nebel mit echten Schatten

### 🌌 Nachthimmel
- Dunkler Sternenhimmel mit drei Sternebenen, unterschiedlichen Farbtemperaturen und Funkeln
- **Milchstraße** mit Staubbändern und Nebelflecken
- Die Sterne drehen sich mit dem Himmel
- **Runde Sonne** mit Randverdunklung und Korona, **runder Mond** mit Kratern und den echten Mondphasen (statt der eckigen Vanilla-Texturen)
- **Sternschnuppen**
- **Polarlichter** in etwa 30 % der Nächte (einstellbar), sie spiegeln sich auch im Wasser

### 🌧️ Regen
- Dünne, fast durchsichtige Regenschlieren, die im Gegenlicht leuchten und an Fackeln warm werden
- **Nasse Oberflächen und Pfützen** mit Spiegelungen
- **Regentropfen-Ringe** auf Pfützen und Wasser
- **Regenschleier**, die in der Ferne vorbeiziehen
- **Blitze** erhellen Himmel, Wolken und Landschaft
- Automatische **Regen-Filmstimmung**: kühler, entsättigter, etwas mehr Kontrast

### 🌊 Wasser
- Prozedurale Wellen, Lichtbrechung und Absorption, also klares Wasser, das mit der Tiefe blaugrün wird
- Screen-Space-Reflexionen mit Himmel als Rückfall und Sonnenglitzern
- **Kaustiken**: das bewegte Lichtnetz am Grund
- **Lichtstrahlen unter Wasser**, die aus den Wellen entstehen. Boote und Terrain werfen Schatten in die Strahlen.

### 🔥 Hitze
- **Hitzeflimmern** steigt über Lava, Feuer, Magma, Lagerfeuern und Öfen auf
- **Nether-Rauch**: volumetrischer, langsam aufsteigender Rauch, von unten orange angestrahlt (ähnlich dem „Nether Storm“ in Complementary Unbound)
- **Wogende Lava**: die Lavaoberfläche bewegt sich langsam
- Im Nether flimmert die Ferne, und der Nebel über dem Lavameer glüht orange

### 🏔️ Distant Horizons
- LODs bekommen dieselbe Beleuchtung, denselben Nebel, dieselben Wolken und dasselbe TAA
- Weicher, gedithereter Übergang zwischen normalen Chunks und LODs
- Ferne Berge verschwinden im Dunst

---

## Installation

1. Die neueste `ChopzCinema-vX.Y.zip` unter [Releases](../../releases) herunterladen.
2. Die ZIP **nicht entpacken**, sondern nach `.minecraft/shaderpacks/` legen.
3. Im Spiel: *Optionen → Grafik → Shader-Pakete → ChopzCinema*.
4. Im Shader-Menü ein Profil wählen: **LOW / MEDIUM / HIGH / ULTRA** (Standard: HIGH).

### Kompatibilität
| | Version |
|---|---|
| Minecraft | 1.20.1 |
| Forge | Oculus 1.8.0+ und Embeddium |
| Fabric | Iris 1.7+ und Sodium |
| Distant Horizons | 2.2+ / 3.x (optional) |
| OptiFine | nicht unterstützt (kein DH-Support) |

### Tipps
- Für das echte Kino-Format **Kinobalken 2.39:1** unter *Kamera & Film* einschalten.
- Ist die Schärfentiefe zu stark oder zu schwach, kann sie unter *Kamera & Film → Stärke der Schärfentiefe* angepasst werden.

### Performance-Tipps
- Die größten Stellschrauben sind **Schattenauflösung**, **Wolkenqualität** und **Lichtstrahlen-Qualität**.
- Wolken und Lichtstrahlen werden ohnehin in halber Auflösung berechnet.
- Mit Distant Horizons kostet vor allem die LOD-Distanz selbst. Der Shader-Aufwand pro Pixel bleibt gleich.

---

## Einstellungen

Das Menü gibt es auf **Deutsch** und Englisch:

| Seite | Inhalt |
|---|---|
| Kamera & Film | Belichtung, Filmkurve, Grading, Bloom, Lens Flare, Schärfentiefe, Vignette, Korn, Kinobalken, TAA |
| Himmel, Wolken & Nebel | Wolken (Qualität, Höhe, Dicke, Bedeckung), Lichtstrahlen, Nebel, Morgennebel, Höhlennebel |
| Nachthimmel | runde Sonne & Mond (Größe), Sterne, Milchstraße, Sternschnuppen, Polarlichter (aus / manche Nächte / jede Nacht) |
| Beleuchtung | Sonne, Himmelslicht, Nacht, Fackellicht und Farbtemperatur |
| Schatten | Auflösung, Distanz, Weichheit, farbige Schatten, Sonnenwinkel |
| Wasser & Reflexionen | Wellen, Klarheit, Kaustiken, Unterwasser-Strahlen, Reflexionen |
| Regen | Regenschlieren, Tropfen-Ringe, Pfützen, Regenschleier, Blitze, Filmstimmung |
| Hitze | Hitzeflimmern, Nether-Flimmern, Lava-Glühen, Nether-Rauch, wogende Lava |
| Wind | wehende Pflanzen und Blätter |

---

## Technik

```
shadow      → Shadow Map (+ Wasseroberfläche für Kaustiken)
gbuffers    → G-Buffer (Albedo, Normalen, Lightmap, Material) – auch dh_terrain
deferred    → volumetrische Wolken (½ Auflösung)
deferred1   → Beleuchtung, Himmel, Sterne, Polarlichter, Wolken
forward     → Wasser, Glas, Partikel, Regen, Hand
composite   → Lichtbrechung, Wasser-Absorption, Reflexionen, Pfützen
composite1  → Lichtstrahlen / Unterwasser-Strahlen (½ Auflösung)
composite2  → Nebel, Regenschleier, Nether-Glühen
composite3  → TAA + Auto-Belichtung
final       → Hitzeflimmern, Schärfentiefe, Bloom, Lens Flare, Filmkurve, Grading, Film-Effekte
```

```
shaders/
  shaders.properties   Menü, Profile, Blend-Modi
  block.properties     Material-IDs (Blätter, Glas, Metall, Lichtquellen, Lava, …)
  lib/                 gemeinsamer Code (Himmel, Nachthimmel, Wolken, Nebel, Regen, Wasser, Licht, Post)
  program/             Programme
  world0|world-1|world1 automatisch erzeugte Wrapper je Dimension
  lang/                Deutsch / Englisch
tools_gen_wrappers.py  erzeugt die Wrapper neu
```

---

## Feedback

Probleme bitte als Issue melden und dazu anhängen:
- `.minecraft/logs/latest.log`
- Screenshot(s)
- verwendetes Profil und Grafikkarte
