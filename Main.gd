extends Node3D

@onready var http_request: HTTPRequest = $HTTPRequest
@onready var room_light: DirectionalLight3D = $DirectionalLight3D
@onready var floor_node: CSGBox3D = $Floor
@onready var player_node: CharacterBody3D = $Player
@onready var spawned_objects_container: Node3D = $SpawnedObjects

const OVERSEER_URL = "http://127.0.0.1:8000/event"

func _ready() -> void:
	http_request.request_completed.connect(_on_overseer_response)

func send_event_to_overseer(event_name: String, details: Dictionary) -> void:
	var payload := {
		"event": event_name,
		"details": details
	}
	var json_data := JSON.stringify(payload)
	var headers := ["Content-Type: application/json"]
	
	http_request.request(OVERSEER_URL, headers, HTTPClient.METHOD_POST, json_data)

func _on_overseer_response(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		print("Overseer connection error: ", response_code)
		return
		
	var response_text := body.get_string_from_utf8()
	var response_data = JSON.parse_string(response_text)
	
	if response_data and response_data is Dictionary:
		handle_overseer_actions(response_data)

func handle_overseer_actions(data: Dictionary) -> void:
	# 1. Dialogue / Intercom Message
	if data.has("message") and data["message"] != null:
		print("[OVERSEER INTERCOM]: ", data["message"])

	# 2. Lighting Changes
	if data.has("light_color") and data["light_color"] is Array:
		var col: Array = data["light_color"]
		if col.size() >= 3:
			var target_color := Color(float(col[0]), float(col[1]), float(col[2]))
			var tween := create_tween()
			tween.tween_property(room_light, "light_color", target_color, 1.2).set_trans(Tween.TRANS_SINE)

	if data.has("light_energy") and data["light_energy"] != null:
		var energy: float = float(data["light_energy"])
		var tween := create_tween()
		tween.tween_property(room_light, "light_energy", energy, 0.8).set_trans(Tween.TRANS_QUAD)

	# 3. Clear Chamber Structures
	if data.get("clear_structures", false) == true:
		clear_chamber_structures()

	# 4. Terrain Modification (Floor elevation and dimensions)
	if data.has("terrain") and data["terrain"] is Dictionary:
		apply_terrain_modification(data["terrain"])

	# 5. Spawn Structures (Barriers, Platforms, Monoliths, Pillars)
	if data.has("structures") and data["structures"] is Array:
		for struct_data in data["structures"]:
			if struct_data is Dictionary:
				spawn_chamber_structure(struct_data)

	# 6. Physics Manipulation (Gravity, Speed, Kinetic Impulses)
	if data.has("physics") and data["physics"] is Dictionary:
		apply_physics_manipulation(data["physics"])

func apply_terrain_modification(terrain: Dictionary) -> void:
	var tween := create_tween().set_parallel(true)
	if terrain.has("floor_y"):
		var target_y: float = float(terrain["floor_y"])
		print("[OVERSEER TERRAIN]: Shifting floor elevation to Y = ", target_y)
		tween.tween_property(floor_node, "position:y", target_y, 2.0).set_trans(Tween.TRANS_CUBIC)
	
	if terrain.has("floor_size"):
		var fs = terrain["floor_size"]
		var target_size := floor_node.size
		if fs is Array and fs.size() >= 2:
			target_size = Vector3(float(fs[0]), floor_node.size.y, float(fs[1]))
		elif fs is float or fs is int:
			target_size = Vector3(float(fs), floor_node.size.y, float(fs))
		print("[OVERSEER TERRAIN]: Resizing chamber floor to ", target_size)
		tween.tween_property(floor_node, "size", target_size, 2.0).set_trans(Tween.TRANS_CUBIC)

func parse_to_array(val, default_arr: Array) -> Array:
	if val is Array:
		return val
	if val is String:
		var parsed = JSON.parse_string(val)
		if parsed is Array:
			return parsed
	return default_arr

func spawn_chamber_structure(struct_data: Dictionary) -> void:
	if spawned_objects_container == null:
		return

	var shape_type: String = str(struct_data.get("shape", "box")).to_lower()
	var pos_arr: Array = parse_to_array(struct_data.get("position"), [0.0, 1.0, 0.0])
	var size_arr: Array = parse_to_array(struct_data.get("size"), [2.0, 2.0, 2.0])
	var col_arr: Array = parse_to_array(struct_data.get("color"), [0.4, 0.5, 0.7])
	var struct_name: String = str(struct_data.get("name", "Construct_" + str(Time.get_ticks_msec())))

	# Remove existing structure with same name if already present
	var existing = spawned_objects_container.get_node_or_null(struct_name)
	if existing:
		existing.queue_free()

	var node: CSGShape3D
	if shape_type == "cylinder":
		var cyl := CSGCylinder3D.new()
		cyl.radius = float(size_arr[0]) / 2.0
		cyl.height = float(size_arr[1]) if size_arr.size() > 1 else float(size_arr[0])
		node = cyl
	elif shape_type == "sphere":
		var sph := CSGSphere3D.new()
		sph.radius = float(size_arr[0]) / 2.0
		node = sph
	else:
		var box := CSGBox3D.new()
		var sx = float(size_arr[0])
		var sy = float(size_arr[1]) if size_arr.size() > 1 else sx
		var sz = float(size_arr[2]) if size_arr.size() > 2 else sx
		box.size = Vector3(sx, sy, sz)
		node = box

	node.name = struct_name
	node.use_collision = true

	var mat := StandardMaterial3D.new()
	var cr = float(col_arr[0]) if col_arr.size() > 0 else 0.5
	var cg = float(col_arr[1]) if col_arr.size() > 1 else 0.5
	var cb = float(col_arr[2]) if col_arr.size() > 2 else 0.6
	mat.albedo_color = Color(cr, cg, cb)
	mat.metallic = 0.3
	mat.roughness = 0.4
	node.material = mat

	spawned_objects_container.add_child(node)

	# Emerge dramatically from the ground
	var target_pos := Vector3(float(pos_arr[0]), float(pos_arr[1]), float(pos_arr[2]))
	var height: float = float(size_arr[1]) if size_arr.size() > 1 else 2.0
	node.position = Vector3(target_pos.x, target_pos.y - height - 1.0, target_pos.z)

	var tween := create_tween()
	tween.tween_property(node, "position", target_pos, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	print("[OVERSEER CONSTRUCT]: Materialized ", shape_type, " '", struct_name, "' at ", target_pos)

func clear_chamber_structures() -> void:
	if spawned_objects_container == null:
		return
	for child in spawned_objects_container.get_children():
		var tween := create_tween()
		tween.tween_property(child, "position:y", child.position.y - 6.0, 0.7).set_trans(Tween.TRANS_SINE)
		tween.tween_callback(child.queue_free)
	print("[OVERSEER CONSTRUCT]: Dematerialized all chamber structures.")

func apply_physics_manipulation(physics: Dictionary) -> void:
	if player_node == null:
		return
		
	if physics.has("gravity"):
		var g: float = float(physics["gravity"])
		player_node.gravity = g
		print("[OVERSEER PHYSICS]: Chamber gravity calibrated to ", g, " m/s²")
		
	if physics.has("player_speed"):
		var s: float = float(physics["player_speed"])
		player_node.speed = s
		print("[OVERSEER PHYSICS]: Test subject movement speed modulated to ", s)
		
	if physics.has("impulse"):
		var imp: Array = physics["impulse"]
		if imp.size() >= 3:
			var impulse_vec := Vector3(float(imp[0]), float(imp[1]), float(imp[2]))
			player_node.velocity += impulse_vec
			print("[OVERSEER PHYSICS]: Kinetic force applied to subject: ", impulse_vec)

func _on_sector_alpha_trigger_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player") or body.name == "Player":
		print("Sending Sector Alpha alert to overseer...")
		send_event_to_overseer("player_entered_zone", {"zone": "Sector Alpha"})
