extends Node
## Seven linked missions. Advancement depends on real world actions or volumes.

const TITLES = [
	"DER ERSTE ARBEITSTAG", "STAPLERSCHEIN? WELCHER STAPLERSCHEIN?",
	"DIE VERSCHWUNDENE PALETTE", "SCHICHTWECHSEL", "PRODUKTIONSCHAOS",
	"DER GROSSE KARTON-COUP", "KARTON EU IV"
]
const OBJECTIVES = [
	["Erreiche die Anmeldung in der Verwaltung.", "Sprich mit Vorarbeiter Rüdiger in Halle A.", "Stemple dich am Terminal ein."],
	["Steig in den markierten Gabelstapler.", "Fahre ins Hochregallager.", "Nimm die Expresspalette mit R auf.", "Fahre die Palette zur Versandausfahrt.", "Stelle die Palette mit R ab."],
	["Finde den Paletten-Barcode im Hochregallager.", "Prüfe die Lieferdaten in der Verwaltung.", "Frag die Disposition nach der Lieferung."],
	["Schleiche in Halle B. Meide den Werkschutz!", "Betätige den gesperrten Sicherheitsschalter.", "Verlasse den gesperrten Bereich unentdeckt."],
	["Betätige Nothalt A in Halle A.", "Betätige Nothalt B in Halle B.", "Betätige Nothalt C in Halle B."],
	["Sprich mit Mechanikerin Toni in der Werkstatt.", "Besorge die blaue Akte aus dem Lager.", "Steig in den Flucht-LKW.", "Erreiche mit dem LKW die Hafenausfahrt."],
	["Aktiviere den Zentralrechner der Verwaltung.", "Entkomme dem Werkschutz. Wähle deinen Ausgang!", "Entscheide dich für einen der beiden Ausgänge."]
]
const TARGETS = [
	[Vector3(-92,0,45),Vector3(-85,0,-29),Vector3(-110,0,55)],
	[Vector3(-70,0,12),Vector3(62,0,-10),Vector3(77,0,-47),Vector3(93,0,78),Vector3(93,0,78)],
	[Vector3(82,0,-63),Vector3(-83,0,39),Vector3(81,0,22)],
	[Vector3(-12,0,-51),Vector3(1,0,-42),Vector3(-15,0,12)],
	[Vector3(-66,0,-55),Vector3(-13,0,-53),Vector3(16,0,-37)],
	[Vector3(12,0,46),Vector3(50,0,-39),Vector3(90,0,98),Vector3(137,0,100)],
	[Vector3(-97,0,54),Vector3(-137,0,27),Vector3(10,0,106)]
]
var game
var index = 0
var stage = 0
var active = false
var timer = -1.0
var completed = false
var ending = ""
var stage_started = 0.0

func start(new_game = true) -> void:
	active = true
	completed = false
	if new_game:
		index = 0
		stage = 0
		timer = -1
	_show_stage()

func _process(delta: float) -> void:
	if not active or completed or game == null:
		return
	if timer > 0:
		timer -= delta
		if timer <= 0:
			fail("Zu spät! Die Produktion ist bereits explodiert.")
			return
	var at: Vector3 = game.player.global_position
	match index:
		0:
			if stage == 0 and at.distance_to(TARGETS[0][0]) < 12:
				advance("Anmeldung erreicht. Rüdiger wartet auf dich.")
		1:
			if stage == 0 and game.current_vehicle != null and game.current_vehicle.kind == "forklift":
				advance("Ich hoffe, die Versicherung ist informiert.")
			elif stage == 1 and game.current_vehicle != null and game.current_vehicle.global_position.distance_to(TARGETS[1][1]) < 20:
				advance("Drück R neben der Expresspalette.")
			elif stage == 3 and game.current_vehicle != null and game.current_vehicle.global_position.distance_to(TARGETS[1][3]) < 19:
				advance("Lass die Palette an der Rampe ab (R).")
		3:
			if stage == 0 and at.distance_to(TARGETS[3][0]) < 12:
				advance("Jetzt den Schalter bedienen, aber nicht entdeckt werden!")
			elif stage == 2 and at.distance_to(TARGETS[3][2]) < 13:
				game.wanted = maxi(0, game.wanted - 2)
				complete()
		5:
			if stage == 2 and game.current_vehicle != null and game.current_vehicle.kind == "truck":
				advance("Bring den LKW zur Hafenausfahrt.")
			elif stage == 3 and game.current_vehicle != null and game.current_vehicle.global_position.distance_to(TARGETS[5][3]) < 15:
				complete()
		6:
			if stage == 1 and at.distance_to(TARGETS[6][0]) > 48:
				advance("Du hast die Verwaltung verlassen. Jetzt entscheide dich!")

func action(id: String) -> bool:
	if not active:
		return false
	match index:
		0:
			if stage == 1 and id == "boss":
				advance("Der Chef hat dir den ersten Arbeitstag erklärt.")
				return true
			if stage == 2 and id == "timeclock":
				complete()
				return true
		1:
			if stage == 2 and id == "pallet_picked":
				advance("Die Palette liegt auf der Gabel. Vorsichtig!")
				return true
			if stage == 4 and id == "pallet_dropped":
				complete()
				return true
		2:
			if stage == 0 and id == "barcode":
				advance("Scan: Artikel 'HYPERKARTON', Standort unbekannt.")
				return true
			if stage == 1 and id == "terminal":
				advance("Die Lieferung wurde absichtlich umgebucht. Frag die Disposition.")
				return true
			if stage == 2 and id == "dispatcher":
				complete()
				return true
		3:
			if stage == 1 and id == "override":
				advance("Türentriegelung läuft. Raus, bevor der Werkschutz kommt!")
				return true
		4:
			if stage == 0 and id == "line_a":
				advance("Nothalt A aktiv. Zwei Linien verbleiben.")
				return true
			if stage == 1 and id == "line_b":
				advance("Nothalt B aktiv. Letzte Linie!")
				return true
			if stage == 2 and id == "line_c":
				game.world.machine_running = false
				complete()
				return true
		5:
			if stage == 0 and id == "mechanic":
				advance("Toni hat dir ihren Werkstattschlüssel gegeben.")
				return true
			if stage == 1 and id == "blueprint":
				advance("Die Akte ist gesichert. Jetzt zum Flucht-LKW.")
				return true
		6:
			if stage == 0 and id == "final_terminal":
				game.raise_wanted(3)
				advance("ALARM! Werkschutz mobilisiert. Flüchte aus der Verwaltung!")
				return true
			if stage == 2 and id in ["ending_a","ending_b"]:
				ending = "GUTE KARTON-KARRIERE: Du wirst neuer Schichtleiter." if id == "ending_a" else "DIE GROSSE FLUCHT: Die Akte gehört dir. Niemand fragt nach dem LKW."
				complete()
				return true
	return false

func advance(message: String = "") -> void:
	if message != "":
		game.notify(message,5.0)
	stage += 1
	if stage >= OBJECTIVES[index].size():
		complete()
	else:
		_show_stage()

func _show_stage() -> void:
	if index >= TITLES.size():
		return
	game.notify("KAPITEL %d: %s\n%s" % [index+1,TITLES[index],OBJECTIVES[index][stage]], 6.0)
	if index == 4 and stage == 0:
		timer = 155.0

func complete() -> void:
	game.player.money += 350 + index * 150
	game.notify("MISSION ABGESCHLOSSEN  +%d €\n%s" % [350+index*150,TITLES[index]],7.0)
	if index == 6:
		completed = true
		active = false
		game.wanted = 0
		game.notify("KARTON EU IV ABGESCHLOSSEN\n"+ending+"\nFree Mode bleibt verfügbar!",17.0)
		game.save_game()
		return
	index += 1
	stage = 0
	timer = -1.0
	game.save_game()
	_show_stage()

func fail(reason: String) -> void:
	if not active:
		return
	game.notify("MISSION GESCHEITERT\n"+reason+"\nVersuche es erneut!",6.0)
	if index == 3:
		game.player.global_position = Vector3(-15,1,14)
		game.wanted = 0
	elif index == 4:
		timer = 155.0
	game.player.hurt(0.0)
	if index == 3:
		stage = 0
	_show_stage()

func objective() -> String:
	if not active or index >= TITLES.size():
		return "FREIES SPIEL  |  Die Fabrik gehört dir."
	return "%02d  %s\n%s" % [index+1,TITLES[index],OBJECTIVES[index][stage]]

func target() -> Vector3:
	if not active or index >= TARGETS.size():
		return Vector3.ZERO
	return TARGETS[index][mini(stage,TARGETS[index].size()-1)]

func stage_count() -> int:
	return OBJECTIVES[index].size()
