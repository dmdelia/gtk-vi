# Abnahmetest: KARTON EU IV

Der folgenden Tests sollten auf einem Rechner mit Godot 4.4.1 durchlaufen werden. Sie sind **noch keine bestandenen Tests**. Die Erstellungsumgebung enthält keine Godot-Engine.

1. `godot --headless --editor --path . --import --quit` muss ohne Parserfehler laufen.
2. `godot --headless --path . --quit-after 120` muss Welt, NPCs, Musik und Menüs ohne Laufzeitfehler initialisieren.
3. Story: Verwaltung betreten, Rüdiger ansprechen, einstempeln => erster Abschluss.
4. Stapler betreten, Lager anfahren, Expresspalette mit R aufnehmen, Versandrampe erreichen, mit R abstellen.
5. Barcode, Lieferdaten, Disposition ansprechen.
6. Gesperrte Halle betreten; bei Erkennung durch Werkschutz Mission zurücksetzen; im zweiten Versuch Sicherheitskonsole bedienen und fliehen.
7. Alle drei roten Nothalt-Terminals innerhalb von 155 Sekunden erreichen, Förderbandbewegung stoppt.
8. Mechanikerin finden, blaue Akte beschaffen, LKW fahren.
9. Zentralrechner auslösen, aus Verwaltung entkommen, eines der zwei Enden am Tor wählen.
10. Free Mode: Fahrzeuge, Werkstattautomat, Slalom, Easter Egg, Fahndung.
11. F1: alle Cheats einzeln testen, Toggle-Cheats durch zweite Eingabe ausschalten.
12. Optionen ändern, speichern, neu starten, laden, Zustand vergleichen.
13. Release `v0.1.1-prealpha` taggen, GitHub-Action auf erfolgreichen Windows-Export prüfen, ZIP entpacken, .exe + .pck aus gleichem Ordner starten.
14. Nach `v0.1.1-prealpha` mit angepasster CURRENT_VERSION einen Release mit ZIP + SHA256-Digest veröffentlichen; beim Start Update prüfen, heruntergeladenes Paket verifizieren und beim Beenden austauschen.

> Die Software muss vor Verteilung an Dritte real ausgeführt und getestet werden. Quellcode-Bereitstellung allein weist keine Laufzeitfunktion nach.
