extends CanvasLayer

const ROOM_LABELS: Dictionary = {
	"ENEMY": "Enemy",
	"ELITE": "Elite",
	"REST": "Rest",
	"EVENT": "Unknown",
	"TREASURE": "Treasure",
	"MERCHANT": "Merchant",
	"BOSS": "Boss",
}

const ROOM_COLORS: Dictionary = {
	"ENEMY": Color(0.18, 0.2, 0.25, 0.96),
	"ELITE": Color(0.35, 0.16, 0.18, 0.96),
	"REST": Color(0.14, 0.24, 0.19, 0.96),
	"EVENT": Color(0.24, 0.22, 0.16, 0.96),
	"TREASURE": Color(0.28, 0.23, 0.12, 0.96),
	"MERCHANT": Color(0.12, 0.22, 0.25, 0.96),
	"BOSS": Color(0.33, 0.1, 0.1, 0.96),
}

@onready var title_label: Label = $Root/Main/Margin/Content/Top/Title
@onready var floor_label: Label = $Root/Main/Margin/Content/Top/SubTitle
@onready var map_canvas: Control = $Root/Main/Margin/Content/MapSplit/MapPane/MapCanvas
@onready var lines_layer: Control = $Root/Main/Margin/Content/MapSplit/MapPane/MapCanvas/LinesLayer
@onready var nodes_layer: Control = $Root/Main/Margin/Content/MapSplit/MapPane/MapCanvas/NodesLayer
@onready var legend: VBoxContainer = $Root/Main/Margin/Content/MapSplit/LegendPane/LegendMargin/LegendRows

var _node_positions: Dictionary = {}


func _ready() -> void:
	await get_tree().process_frame
	_build_legend()
	_build_map()


func _build_map() -> void:
	for child in lines_layer.get_children():
		child.queue_free()
	for child in nodes_layer.get_children():
		child.queue_free()
	_node_positions.clear()

	var start_floor: int = RunManager.current_floor + 1
	if start_floor > RunManager.boss_floor:
		start_floor = RunManager.boss_floor
	title_label.text = "Act %d Map" % int(RunManager.current_act)
	floor_label.text = "Current floor: %d  ->  choose floor %d" % [RunManager.current_floor, start_floor]

	var lanes: int = max(3, RunManager.map_lane_count)
	var rows: int = max(1, RunManager.boss_floor - start_floor + 1)
	var canvas_size: Vector2 = map_canvas.size
	var x_margin: float = 80.0
	var y_margin: float = 42.0
	var usable_w: float = maxf(40.0, canvas_size.x - (x_margin * 2.0))
	var usable_h: float = maxf(40.0, canvas_size.y - (y_margin * 2.0))

	var reachable: PackedInt32Array = RunManager.get_reachable_lanes_for_floor(start_floor)

	for floor in range(start_floor, RunManager.boss_floor + 1):
		var nodes: Array[Dictionary] = RunManager.build_floor_map_nodes(floor)
		var row_i: int = floor - start_floor
		for node in nodes:
			var lane: int = int(node.get("lane", 0))
			var room_type: String = str(node.get("room_type", "ENEMY"))
			var x: float = x_margin + (usable_w * (float(lane) / float(max(1, lanes - 1))))
			var y: float = y_margin + (usable_h * (float(row_i) / float(max(1, rows - 1))))
			var key: String = _node_key(floor, lane)
			_node_positions[key] = Vector2(x, y)

			var btn: Button = Button.new()
			btn.custom_minimum_size = Vector2(108.0, 42.0)
			btn.size = Vector2(108.0, 42.0)
			btn.position = Vector2(x - 54.0, y - 21.0)
			btn.text = ROOM_LABELS.get(room_type, room_type)
			btn.tooltip_text = "Floor %d - %s" % [floor, btn.text]
			btn.focus_mode = Control.FOCUS_NONE
			btn.add_theme_stylebox_override("normal", _make_node_style(room_type, false))
			btn.add_theme_stylebox_override("hover", _make_node_style(room_type, true))
			btn.add_theme_stylebox_override("pressed", _make_node_style(room_type, true))

			var clickable: bool = floor == start_floor and reachable.has(lane)
			btn.disabled = not clickable
			if clickable:
				btn.pressed.connect(_on_node_pressed.bind(floor, lane, room_type))
			nodes_layer.add_child(btn)

	_draw_edges(start_floor)


func _draw_edges(start_floor: int) -> void:
	var edges: Array[Dictionary] = RunManager.get_map_edges()
	for edge in edges:
		var from_floor: int = int(edge.get("from_floor", -1))
		var to_floor: int = int(edge.get("to_floor", -1))
		if to_floor < start_floor:
			continue
		var from_key: String = _node_key(from_floor, int(edge.get("from_lane", -1)))
		var to_key: String = _node_key(to_floor, int(edge.get("to_lane", -1)))
		if not _node_positions.has(from_key) or not _node_positions.has(to_key):
			continue

		var line: Line2D = Line2D.new()
		line.width = 2.0
		line.default_color = Color(0.78, 0.78, 0.82, 0.42)
		line.add_point(_node_positions[from_key])
		line.add_point(_node_positions[to_key])
		lines_layer.add_child(line)


func _node_key(floor: int, lane: int) -> String:
	return "%d:%d" % [floor, lane]


func _build_legend() -> void:
	for child in legend.get_children():
		child.queue_free()
	var keys: PackedStringArray = PackedStringArray([
		"EVENT", "MERCHANT", "TREASURE", "REST", "ENEMY", "ELITE", "BOSS",
	])
	for key in keys:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var dot: ColorRect = ColorRect.new()
		dot.custom_minimum_size = Vector2(16.0, 16.0)
		dot.color = ROOM_COLORS.get(key, Color(0.3, 0.3, 0.3, 1.0))
		row.add_child(dot)
		var label: Label = Label.new()
		label.text = ROOM_LABELS.get(key, key)
		row.add_child(label)
		legend.add_child(row)


func _on_node_pressed(floor: int, lane: int, room_type: String) -> void:
	RunManager.travel_to_room(floor, lane, room_type)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://level.tscn")


func _make_node_style(room_type: String, hover: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = ROOM_COLORS.get(room_type, Color(0.2, 0.2, 0.2, 0.95))
	if hover:
		style.bg_color = style.bg_color.lightened(0.15)
	style.border_color = Color(0.78, 0.78, 0.78, 0.75)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	return style
