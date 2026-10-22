# KARTON EU IV

**3D-Industriesandbox für Windows, mit sieben Story-Missionen und Free Mode.** Eigenständiges Godot-4.4.1-Projekt aus GDScript und prozeduralen 3D-Objekten, ohne fremde GTA-Inhalte oder kostenpflichtige Assets.

> **Entwicklungsstand: 0.1.2-prealpha @ 1.102.** Gameplay-Prototyp mit erneuerten 3D-Modellen und bitmap-basierten PBR-Materialien. Windows-Build wird durch GitHub Actions importiert, getestet und exportiert; manuelle Spieltests sind trotzdem notwendig.

## Spielen

1. Godot **4.4.1 Standard** und Python 3 mit `pip install pillow numpy` installieren: https://godotengine.org/download/
2. Einmal `python tools/generate_textures.py` im Projektordner aufrufen, damit alle 36 PNG-PBR-Maps erzeugt werden. Der Windows-CI-Build macht dies automatisch.
3. In Godot **Importieren**, `project.godot` auswählen, Projekt öffnen.
4. Oben rechts **F6/F5** oder ▶ drücken. Im Menü Story Mode oder Free Mode wählen.
5. Nach einem erfolgreichen GitHub-Release kannst du alternativ `KARTON-EU-IV-windows.zip` herunterladen, entpacken und **`KARTON-EU-IV.exe`** starten. Die dazugehörige `.pck` muss im selben Ordner bleiben.

### Steuerung

| Taste | Aktion |
| --- | --- |
| WASD | Bewegen / Fahrzeuge fahren |
| Maus | Freie Third-Person-Kamera |
| Shift | Sprinten |
| Strg | Schleichen; im Flugmodus sinken |
| Leertaste | Springen; im Fahrzeug bremsen |
| E | Reden, Terminals bedienen, Fahrzeug betreten/verlassen, Kisten tragen |
| R | Palette mit Stapler/LKW aufnehmen bzw. absetzen |
| F | Taschenlampe |
| M | Große Karte |
| F1 oder `~` | Cheat-Konsole |
| ESC | Pause |

## Inhalt

- Fiktiver zusammenhängender Fabrikkomplex (vier Produktionshallen, Hochregallager, Verwaltung, Kantine, Werkstatt, Versand), Straßen, Parkplatz und Zaun, zahlreiche frei begehbare Innenräume.
- Kollisionen, Third-Person-Steuerung, springender und schleichender Spieler, Fahrphysik für Autos, LKWs und Gabelstapler, Schaden und Frachtaufnahme.
- 34 Fabrik-NPCs mit Graph-Navigation, Schicht- und Pausenrouten, Gesprächen, Panikzustand; Werkschutz verfolgt Spieler bei Fahndung.
- Sieben aufeinander folgende Story-Missionen, mit kontextgebundenen Stufen, Triggern, mindestens einer Zeitmission, Werkschutz-Stealth, Lieferfahrten und zwei Enden.
- Free Mode mit interaktiven Terminals, Automaten, Werkzeugbereich, Slalom-Nebenaufgabe und Geheimnissen.
- Tag-/Nachtlicht, Förderbandbewegung, synthetischer Industrie-Sound, Minimap/Hauptkarte, Geld, Gesundheit, Fahndung, Save/Load unter `user://`.
- Cheat-Konsole: `GODMODE`, `RICHKARTON`, `FORKLIFT`, `SUPERSPEED`, `LOWGRAVITY`, `NIGHTSHIFT`, `DAYSHIFT`, `CHAOS`, `CLEARWANTED`, `FLYKARTON`, `HEALKARTON`.

## Releases / Windows-EXE

Die Workflow-Datei `.github/workflows/windows-release.yml` baut nach Push auf `main` ein ZIP unter GitHub Actions. Bei einem Tag `v0.1.2-prealpha` erzeugt sie zusätzlich ein GitHub-Release mit dem ZIP, einschließlich `.exe` und `.pck`.

**Repository:** https://github.com/dmdelia/gtk-vi (main). Ein initialer Workflow liegt dort bereits. Das vollstaendige Spielprojekt kann mit `publish.ps1` (PowerShell, Git und angemeldete GitHub CLI erforderlich) gepusht werden. Das Skript erstellt danach `v0.1.2-prealpha` und loest dadurch den Windows-Release-Build aus. Erst wenn der Workflow erfolgreich durchlaeuft, steht die EXE unter https://github.com/dmdelia/gtk-vi/releases bereit.

## Integrierter Updater

Beim Start fragt das Spiel `https://api.github.com/repos/dmdelia/gtk-vi/releases?per_page=20` ab, um auch Pre-Releases zu finden. Existiert ein neueres Release mit einer `KARTON-EU-IV-windows.zip` und GitHub-SHA256-Digest, kann der Updater es laden und die beiden Dateien sicher im lokalen Benutzerdatenordner vorbereiten. Beim regulären Beenden über das Spielmenü installiert ein Windows-Batchstarter das Paket nach dem Schließen und startet das Spiel neu. Updateprüfung und Auto-Updates sind in den Einstellungen änderbar. **Bis zur Veröffentlichung des GitHub-Releases kann dies nicht funktionieren.**

## Projektaufbau

- `scripts/world.gd`: datengetriebene Gebäude, Maschinen, Lager, Terminals, AStar-Graph
- `scripts/player.gd`: Charakter, Kollisionssteuerung, Health, Kamera-Kopplung
- `scripts/vehicle.gd`: drei Fahrzeugklassen, Trägheit, Schaden, Cargo
- `scripts/npc.gd`: Arbeiter, Dialog, Routen, Panik, Werkschutz
- `scripts/missions.gd`: Story-Inhalte und Ereigniszustände
- `scripts/main.gd`: Spielzustand, Interaktionen, Cheats, Save/Load
- `scripts/hud.gd`, `scripts/minimap.gd`: Menüs, HUD, große Karte
- `scripts/audio.gd`: royalty-free procedural sounds
- `scripts/updater.gd`: SHA-256-gesicherter GitHub-Release-Updatepfad

## Bekannte Grenzen

- Spielgeometrie ist weiterhin stilisiert, aber alle Hauptmodelle verwenden überarbeitete Silhouetten und echte PBR-Texturdateien. Das Grundstück folgt einem zur Verfügung gestellten Luftbild; Innenräume sind fiktiv.
- Das KI-Routing nutzt ein vereinfachtes, kollisionsgeprüftes AStar-Raster statt einer vollständig gebackenen NavMesh.
- Fahrzeugphysik ist arcade-orientiert, nicht realistisch simuliert; keine Fahrzeug-Zerstörungsmeshes.
- Zwischensequenzen bestehen aus eingeblendeten Texten und Missionsereignissen, nicht aus vertonten Cinematics.
- Automatische Updates benötigen einen veröffentlichten passenden GitHub-Release und funktionieren nur in exportierten Windows-Builds.
- Der tatsächliche Godot-Import, die Spielbarkeit und der Windows-Build müssen mit Godot/CI überprüft und nötigenfalls korrigiert werden.

## 0.1.2-prealpha: 3D-Modell- und Textur-Overhaul

- **12 eigens erstellte Materialfamilien** (`asphalt`, `concrete`, `sheetmetal`, `roof`, `cardboard`, `wood`, `steel`, `machine`, `brick`, `rubber`, `hazard`, `fabric`) mit je separaten Bitmap-Albedo-, Normal- und Roughness-Maps.
- **36 echte PNG-Dateien** (512²) werden beim Build aus `tools/generate_textures.py` generiert und in den Windows-Export eingebettet. Alle Quellen sind original erstellt und nicht von Karten-/GTA-Spielen kopiert.
- **Neue Fahrzeugmodelle** aus eigenständigen Polygon-Wedges, Radzylindern, Achsnaben, Glas, Fugen, Stoßstangen, Spiegeln und detailliertem Stapler-Mast.
- **Neue NPC- und Spielerfiguren** mit Rundkörper-Silhouetten, Kleidung, Helmen, Gesicht und Gliedmaßen statt reiner Quader-Menschen.
- **Fabrikdetails** mit Dachventilatoren, Gerüst-Rohren, runden Förderbandrollen, Metallrohren, Palettenteilen und technischen Anbauten.
- **Map-Clipping-Fix:** Minimap und Vollbildkarte clippen alle Zeichenoperationen zuverlässig an ihren Anzeigegrenzen.
- Die bereits vorgegebene Grundstücksgeometrie ist eine spielbare Annäherung an den vom Nutzer bereitgestellten Luftbild-Auszug, kein vermessener Grundriss.
