extends CanvasLayer
## All menu and HUD screens built with native Godot controls.
const MAP_SCRIPT = preload("res://scripts/minimap.gd")
const VERSION_INFO = preload("res://scripts/version_info.gd")
var game
var outer: Control
var menu_panel: PanelContainer
var pause_panel: PanelContainer
var hud: Control
var mission_label: Label
var stat_label: Label
var hint_label: Label
var toast_label: Label
var update_label: Label
var map_small: Control
var map_large: Control
var map_open = false
var toast_left = 0.0
var menu_visible = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	outer = Control.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(outer)
	build_menu()
	build_hud()

func _style(color: Color, border: Color = Color.TRANSPARENT, corners = 12) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(corners)
	s.border_color = border
	s.set_border_width_all(1 if border.a > 0 else 0)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s

func _label(s: String, font_size = 20, color = Color.WHITE) -> Label:
	var l = Label.new()
	l.text = s
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_color",color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _button(s: String, callback: Callable, row: VBoxContainer) -> Button:
	var b = Button.new()
	b.text = s
	b.custom_minimum_size = Vector2(345,46)
	b.add_theme_font_size_override("font_size",19)
	b.add_theme_color_override("font_color",Color("#e1e9ed"))
	b.add_theme_stylebox_override("normal",_style(Color("#1b2b33"),Color("#36515c"),7))
	b.add_theme_stylebox_override("hover",_style(Color("#385660"),Color("#e5bc6f"),7))
	b.add_theme_stylebox_override("pressed",_style(Color("#526c70"),Color("#e5bc6f"),7))
	b.pressed.connect(callback)
	row.add_child(b)
	return b

func _panel_at(left: float,top: float,right: float,bottom: float) -> PanelContainer:
	var p = PanelContainer.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.anchor_left = left
	p.anchor_top = top
	p.anchor_right = right
	p.anchor_bottom = bottom
	p.add_theme_stylebox_override("panel",_style(Color("#0d1820e8"),Color("#435460"),13))
	outer.add_child(p)
	return p

func build_menu() -> void:
	menu_panel = _panel_at(0.16,0.06,0.84,0.94)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left",34)
	margin.add_theme_constant_override("margin_top",26)
	margin.add_theme_constant_override("margin_right",34)
	margin.add_theme_constant_override("margin_bottom",24)
	menu_panel.add_child(margin)
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation",13)
	margin.add_child(content)
	content.add_child(_label("K  /  E  /  U",22,Color("#f2ba59")))
	content.add_child(_label("GTK: VI",62,Color("#f2efdf")))
	content.add_child(_label("GRAND THEFT KARTON  |  INDUSTRIE. CHAOS. KARTON.",14,Color("#b1c6c9")))
	content.add_child(HSeparator.new())
	var buttons = VBoxContainer.new()
	buttons.add_theme_constant_override("separation",6)
	content.add_child(buttons)
	_button("STORY MODE     /     NEUES SPIEL",func(): game.begin("story"),buttons)
	_button("FREE MODE      /     FREIE FAHRT",func(): game.begin("free"),buttons)
	_button("SPIELSTAND LADEN",func(): game.load_game(),buttons)
	_button("EINSTELLUNGEN",func(): show_submenu("settings"),buttons)
	_button("STEUERUNG",func(): show_submenu("controls"),buttons)
	_button("CREDITS",func(): show_submenu("credits"),buttons)
	_button("UPDATES PRÜFEN",func(): game.updater.check_now(),buttons)
	_button("SPIEL BEENDEN",func(): game.quit_game(),buttons)
	update_label = _label("VERSION %s" % VERSION_INFO.display_with_name(),13,Color("#86a9ae"))
	content.add_child(update_label)

func show_submenu(section: String) -> void:
	if not menu_visible:
		return
	for old in menu_panel.get_children():
		if old is VBoxContainer:
			old.queue_free()
		else:
			old.hide()
	var box = VBoxContainer.new()
	box.name = "TemporarySubmenu"
	box.add_theme_constant_override("separation",15)
	menu_panel.add_child(box)
	var back = func():
		box.queue_free()
		for child in menu_panel.get_children():
			if child != box:
				child.show()
	if section == "settings":
		box.add_child(_label("EINSTELLUNGEN",37,Color("#e3bf74")))
		_button("GRAFIKQUALITÄT: " + game.graphics_quality.to_upper() + "  [WECHSELN]",func(): game.switch_quality(); show_submenu("settings"),box)
		_button("MAUS-EMPFINDLICHKEIT:  "+str(snapped(game.mouse_sensitivity*1000,0.5)),func(): game.mouse_sensitivity = 0.002 if game.mouse_sensitivity > 0.003 else 0.004; game.save_options(); show_submenu("settings"),box)
		_button("AUTO-UPDATES: "+("AN" if game.updater.auto_update else "AUS"),func(): game.updater.auto_update = not game.updater.auto_update; game.save_options(); show_submenu("settings"),box)
	elif section == "controls":
		box.add_child(_label("STEUERUNG",37,Color("#e3bf74")))
		box.add_child(_label("WASD  Bewegen / Fahren\nMAUS  Kamera\nSHIFT  Sprinten\nSTRG  Schleichen\nLEERTASTE  Springen / Handbremse\nE  Interaktion / Fahrzeug betreten und verlassen\nR  Gabelstaplerpalette aufnehmen / absetzen\nF  Taschenlampe\nM  Karte\n~ oder F1  Cheat-Konsole\nESC  Pausemenü",22))
	else:
		box.add_child(_label("CREDITS",37,Color("#e3bf74")))
		box.add_child(_label("GTK: VI\nGRAND THEFT KARTON\nEin eigenständiges 3D-Fabrik-Sandbox-Spiel.\nGodot 4.4 • GDScript • prozedurale 3D-Assets\nMusik und Industrieklänge synthetisch erzeugt.\nKeine fremden GTA-Assets.",21))
	_button("< ZURÜCK",back,box)

func build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(hud)
	var top_left = PanelContainer.new()
	top_left.anchor_left = 0.014
	top_left.anchor_right = 0.47
	top_left.anchor_top = 0.02
	top_left.anchor_bottom = 0.18
	top_left.add_theme_stylebox_override("panel",_style(Color("#111e26db"),Color("#41525b"),8))
	hud.add_child(top_left)
	mission_label = _label("",18,Color("#f2efe3"))
	top_left.add_child(mission_label)
	var top_right = PanelContainer.new()
	top_right.anchor_left = 0.73
	top_right.anchor_right = 0.986
	top_right.anchor_top = 0.02
	top_right.anchor_bottom = 0.16
	top_right.add_theme_stylebox_override("panel",_style(Color("#111e26db"),Color("#41525b"),8))
	hud.add_child(top_right)
	stat_label = _label("",19,Color("#e2cc9c"))
	stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_right.add_child(stat_label)
	var bottom = PanelContainer.new()
	bottom.anchor_left = 0.014
	bottom.anchor_right = 0.54
	bottom.anchor_top = 0.87
	bottom.anchor_bottom = 0.97
	bottom.add_theme_stylebox_override("panel",_style(Color("#121e25dd"),Color("#3e555a"),8))
	hud.add_child(bottom)
	hint_label = _label("WASD  Bewegen | E  Interagieren | ESC  Menü",17,Color("#c7dad4"))
	bottom.add_child(hint_label)
	var map_back = PanelContainer.new()
	map_back.anchor_left = 0.78
	map_back.anchor_top = 0.58
	map_back.anchor_right = 0.984
	map_back.anchor_bottom = 0.97
	map_back.add_theme_stylebox_override("panel",_style(Color("#182630"),Color("#779096"),7))
	hud.add_child(map_back)
	map_back.clip_contents = true  # Godot scissor-clips all minimap marks to the frame.
	map_small = MAP_SCRIPT.new()
	map_small.game = game
	map_small.clip_contents = true
	map_back.add_child(map_small)
	map_small.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_large = MAP_SCRIPT.new()
	map_large.game = game
	map_large.expanded = true
	map_large.clip_contents = true
	map_large.anchor_left = 0.19
	map_large.anchor_right = 0.81
	map_large.anchor_top = 0.13
	map_large.anchor_bottom = 0.86
	hud.add_child(map_large)
	map_large.hide()
	toast_label = _label("",22,Color("#f7d18b"))
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_label.anchor_left = 0.24
	toast_label.anchor_right = 0.76
	toast_label.anchor_top = 0.27
	toast_label.anchor_bottom = 0.42
	toast_label.add_theme_stylebox_override("normal",_style(Color("#14222cee"),Color("#e3af67"),9))
	hud.add_child(toast_label)
	pause_panel = _panel_at(0.33,0.17,0.67,0.85)
	var buttons = VBoxContainer.new()
	buttons.add_theme_constant_override("separation",12)
	pause_panel.add_child(buttons)
	buttons.add_child(_label("PAUSE  //  SCHICHTUNTERBRECHUNG",26,Color("#f2c17b")))
	_button("WEITERSPIELEN",func():game.toggle_pause(),buttons)
	_button("SPIEL SPEICHERN",func():game.save_game(),buttons)
	_button("UPDATES PRÜFEN",func():game.updater.check_now(),buttons)
	_button("HAUPTMENÜ",func():game.exit_to_menu(),buttons)
	_button("SPIEL BEENDEN",func():game.quit_game(),buttons)
	pause_panel.hide()
	hud.hide()

func set_menu(show: bool) -> void:
	menu_visible = show
	menu_panel.visible = show
	hud.visible = not show
	pause_panel.hide()

func show_pause(show: bool) -> void:
	pause_panel.visible = show
	hud.visible = not show
	map_large.hide()
	map_open = false

func toggle_map() -> void:
	map_open = not map_open
	map_large.visible = map_open

func notify(message: String, sec = 4.0) -> void:
	toast_label.text = message
	toast_left = sec
	toast_label.show()

func _process(delta: float) -> void:
	if toast_left > 0:
		toast_left -= delta
		if toast_left <= 0:
			toast_label.hide()
	if menu_visible or game == null or game.player == null:
		return
	mission_label.text = game.missions.objective()
	if game.missions.timer > 0:
		mission_label.text += "
ZEIT: %ds" % ceili(game.missions.timer)
	var v = ""
	if game.current_vehicle != null:
		v = "\n%d km/h  |  SCHADEN %d%%" % [absf(game.current_vehicle.speed)*3.6,game.current_vehicle.damage]
	stat_label.text = "€ %s     ♥ %d%%\n%s   %02d:00     %s%s" % [str(game.player.money),int(game.player.health),"★".repeat(game.wanted),int(game.time_of_day),"FREE" if game.mode == "free" else "STORY",v]
	hint_label.text = game.get_nearby_hint()
