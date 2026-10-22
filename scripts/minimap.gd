extends Control
## World-derived minimap; zoomed and full-scale share the same mapping.

var game
var expanded = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _process(_delta: float) -> void:
	if game != null and game.world != null:
		queue_redraw()

func _color_for(info: Dictionary) -> Color:
	if info.has("map_color"):
		return Color(str(info.map_color))
	var style = str(info.get("wall_style", "hall_grey"))
	match style:
		"hall_blue":
			return Color("#56788e")
		"warehouse_dark":
			return Color("#6f685f")
		"office_white":
			return Color("#d0d4cf")
		"office_sage":
			return Color("#92a087")
		"workshop_red":
			return Color("#9e665b")
		"shipping_grey":
			return Color("#9ca5ab")
		_:
			return Color("#7d8589")

func _draw() -> void:
	if game == null or game.world == null or game.player == null:
		return
	var ext = Vector2(size.x, size.y)
	draw_rect(Rect2(Vector2.ZERO, ext), Color(0.035, 0.055, 0.07, 0.91), true)
	var player_p = Vector2(game.player.global_position.x, game.player.global_position.z)
	var scale_factor = (minf(ext.x, ext.y) / 340.0) if expanded else (minf(ext.x, ext.y) / 165.0)
	var origin = ext * 0.5 - (Vector2.ZERO if expanded else player_p) * scale_factor
	if expanded:
		origin = ext * 0.5
	for info in game.world.get_blocks():
		var center = Vector2(float(info.x), float(info.z)) * scale_factor + origin
		var half = Vector2(float(info.w), float(info.d)) * scale_factor * 0.5
		var rect = Rect2(center - half, half * 2)
		var fill = _color_for(info)
		draw_rect(rect, fill.darkened(0.12), true)
		draw_rect(rect, Color(0.66, 0.76, 0.77, 0.4), false, 1.0)
	for z in [-105.0, 9.0, 100.0]:
		draw_line(Vector2(-155, z) * scale_factor + origin, Vector2(155, z) * scale_factor + origin, Color("#627073"), maxf(1, 7 * scale_factor))
	if game.missions != null and game.missions.active:
		var destination: Vector3 = game.missions.target()
		var spot = Vector2(destination.x, destination.z) * scale_factor + origin
		if spot.x > 0 and spot.x < ext.x and spot.y > 0 and spot.y < ext.y:
			draw_arc(spot, 7, 0, TAU, 28, Color("#f5c266"), 2.8)
			draw_line(spot + Vector2(-8, -8), spot + Vector2(8, 8), Color("#f5c266"), 1)
	for vehicle in game.vehicles:
		if is_instance_valid(vehicle):
			var at = Vector2(vehicle.global_position.x, vehicle.global_position.z) * scale_factor + origin
			if Rect2(Vector2.ZERO, ext).has_point(at):
				draw_circle(at, 3.5, Color("#ffc677") if vehicle.kind == "forklift" else Color("#91dbdf"))
	for person in game.npcs:
		if is_instance_valid(person):
			var at = Vector2(person.global_position.x, person.global_position.z) * scale_factor + origin
			if Rect2(Vector2.ZERO, ext).has_point(at):
				draw_circle(at, 1.9, Color("#d87276") if person.role == "guard" else Color("#b1c0b5"))
	var hero = player_p * scale_factor + origin
	if game.current_vehicle != null:
		hero = Vector2(game.current_vehicle.global_position.x, game.current_vehicle.global_position.z) * scale_factor + origin
	var a = game.player.rotation.y if game.current_vehicle == null else game.current_vehicle.rotation.y
	var points = PackedVector2Array([hero + Vector2(-sin(a), -cos(a)) * 9, hero + Vector2(cos(a), -sin(a)) * 5, hero - Vector2(-sin(a), -cos(a)) * 5, hero - Vector2(cos(a), -sin(a)) * 5])
	draw_colored_polygon(points, Color("#f4f6ee"))
	draw_rect(Rect2(Vector2.ZERO, ext), Color("#70969a"), false, 2)
