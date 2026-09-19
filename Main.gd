extends Node3D

@onready var http_request: HTTPRequest = $HTTPRequest
@onready var room_light: DirectionalLight3D = $DirectionalLight3D
@onready var floor_node: CSGBox3D = $Floor
@onready var player_node: CharacterBody3D = $Player
@onready var spawned_objects_container: Node3D = $SpawnedObjects
@onready var world_env: WorldEnvironment = $WorldEnvironment

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
		print("Divine communion severed (code: ", response_code, ")")
		return
		
	var response_text := body.get_string_from_utf8()
	var response_data = JSON.parse_string(response_text)
	
	if response_data and response_data is Dictionary:
		execute_genesis_decree(response_data)

func execute_genesis_decree(data: Dictionary) -> void:
	# 1. Voice of the Creator
	if data.has("message") and data["message"] != null:
		print("\n=======================================================")
		print("👑 [VOICE OF THE CREATOR]: ", data["message"])
		print("=======================================================\n")

	# 2. Day 1 & 4: Fiat Lux / Celestial Lights & Sun
	if data.has("sun") and data["sun"] is Dictionary and not data["sun"].is_empty():
		command_sun(data["sun"])
	elif data.has("light_color"):
		var col_arr: Array = parse_to_array(data["light_color"], [1.0, 0.95, 0.8])
		var energy: float = safe_float(data.get("light_energy"), 1.0)
		command_sun({"color": col_arr, "energy": energy})

	# 3. Day 2: The Firmament (Heavens & Atmosphere)
	if data.has("firmament") and data["firmament"] is Dictionary and not data["firmament"].is_empty():
		shape_firmament(data["firmament"])

	# 4. Day 3: Dry Land and the Earth
	if data.has("terrain") and data["terrain"] is Dictionary and not data["terrain"].is_empty():
		command_earth(data["terrain"])

	# 5. Dissolve / Unmake Creations Back to Dust
	if data.get("clear_structures", false) == true:
		unmake_creations()

	# 6. Day 5 & 6: Pillars, Monuments, Altars, and Creations
	if data.has("structures") and data["structures"] is Array:
		for struct_data in data["structures"]:
			if struct_data is Dictionary:
				summon_creation(struct_data)

	# 7. Day 7 & Divine Sovereignty (Gravity, Kinetic Smite, Mortal Speed)
	if data.has("physics") and data["physics"] is Dictionary and not data["physics"].is_empty():
		divine_intervention(data["physics"])

func command_sun(sun_data: Dictionary) -> void:
	if sun_data.is_empty():
		return
	var tween: Tween = null
	
	if sun_data.has("color"):
		if tween == null: tween = create_tween().set_parallel(true)
		var col: Array = parse_to_array(sun_data["color"], [1.0, 0.95, 0.8])
		var target_col := Color(safe_float(col[0], 1.0), safe_float(col[1], 0.95), safe_float(col[2], 0.8))
		tween.tween_property(room_light, "light_color", target_col, 2.0).set_trans(Tween.TRANS_SINE)
		print("[GENESIS - DAY 1 & 4]: Light ordained -> Color: ", target_col)
		
	if sun_data.has("energy"):
		if tween == null: tween = create_tween().set_parallel(true)
		var energy: float = safe_float(sun_data["energy"], 1.0)
		tween.tween_property(room_light, "light_energy", energy, 1.5)
		print("[GENESIS - DAY 1]: Light radiance set to ", energy)

	if sun_data.has("rotation"):
		if tween == null: tween = create_tween().set_parallel(true)
		var rot: Array = parse_to_array(sun_data["rotation"], [-45.0, 45.0, 0.0])
		var rot_rad := Vector3(
			deg_to_rad(safe_float(rot[0], -45.0)),
			deg_to_rad(safe_float(rot[1], 45.0)),
			deg_to_rad(safe_float(rot[2], 0.0) if rot.size() > 2 else 0.0)
		)
		tween.tween_property(room_light, "rotation", rot_rad, 3.0).set_trans(Tween.TRANS_CUBIC)
		print("[GENESIS - DAY 4]: The Sun and celestial path rotated to ", rot)

func shape_firmament(firmament: Dictionary) -> void:
	if world_env == null or world_env.environment == null or world_env.environment.sky == null or firmament.is_empty():
		return
	var sky_mat = world_env.environment.sky.sky_material
	if not (sky_mat is ProceduralSkyMaterial):
		return
		
	var tween: Tween = null
	if firmament.has("sky_top"):
		if tween == null: tween = create_tween().set_parallel(true)
		var st: Array = parse_to_array(firmament["sky_top"], [0.2, 0.4, 0.8])
		tween.tween_property(sky_mat, "sky_top_color", Color(safe_float(st[0]), safe_float(st[1]), safe_float(st[2])), 2.5)
	if firmament.has("sky_horizon"):
		if tween == null: tween = create_tween().set_parallel(true)
		var sh: Array = parse_to_array(firmament["sky_horizon"], [0.6, 0.7, 0.85])
		tween.tween_property(sky_mat, "sky_horizon_color", Color(safe_float(sh[0]), safe_float(sh[1]), safe_float(sh[2])), 2.5)
	if firmament.has("ground_color"):
		if tween == null: tween = create_tween().set_parallel(true)
		var gc: Array = parse_to_array(firmament["ground_color"], [0.2, 0.15, 0.1])
		tween.tween_property(sky_mat, "ground_bottom_color", Color(safe_float(gc[0]), safe_float(gc[1]), safe_float(gc[2])), 2.5)
	print("[GENESIS - DAY 2]: The Firmament divided and painted across the celestial sphere.")

func command_earth(terrain: Dictionary) -> void:
	if terrain.is_empty():
		return
	var tween: Tween = null
	
	if terrain.has("floor_y"):
		if tween == null: tween = create_tween().set_parallel(true)
		var target_y: float = safe_float(terrain["floor_y"], -0.25)
		print("[GENESIS - DAY 3]: Mountains and valleys moved. Earth elevation: Y = ", target_y)
		tween.tween_property(floor_node, "position:y", target_y, 2.0).set_trans(Tween.TRANS_CUBIC)
		
	if terrain.has("floor_size"):
		if tween == null: tween = create_tween().set_parallel(true)
		var fs = terrain["floor_size"]
		var target_size := floor_node.size
		if fs is Array and fs.size() >= 2:
			target_size = Vector3(safe_float(fs[0], 20.0), floor_node.size.y, safe_float(fs[1], 20.0))
		elif fs is float or fs is int or fs is String:
			var s_val := safe_float(fs, 20.0)
			target_size = Vector3(s_val, floor_node.size.y, s_val)
		print("[GENESIS - DAY 3]: The expanse of the dry land reshaped to ", target_size)
		tween.tween_property(floor_node, "size", target_size, 2.0).set_trans(Tween.TRANS_CUBIC)

	if terrain.has("color"):
		if tween == null: tween = create_tween().set_parallel(true)
		var col_arr: Array = parse_to_array(terrain["color"], [0.3, 0.6, 0.2])
		if floor_node.material == null or not (floor_node.material is StandardMaterial3D):
			var mat := StandardMaterial3D.new()
			mat.metallic = 0.1
			mat.roughness = 0.8
			floor_node.material = mat
		var floor_mat: StandardMaterial3D = floor_node.material
		var target_col := Color(safe_float(col_arr[0], 0.3), safe_float(col_arr[1], 0.6), safe_float(col_arr[2], 0.2))
		tween.tween_property(floor_mat, "albedo_color", target_col, 2.0)
		print("[GENESIS - DAY 3]: The surface of the earth transformed to color ", target_col)

func summon_creation(struct_data: Dictionary) -> void:
	if spawned_objects_container == null:
		return

	var shape_type: String = str(struct_data.get("shape", "box")).to_lower()
	var pos_arr: Array = parse_to_array(struct_data.get("position"), [0.0, 1.0, 0.0])
	var size_arr: Array = parse_to_array(struct_data.get("size"), [2.0, 2.0, 2.0])
	var col_arr: Array = parse_to_array(struct_data.get("color"), [0.8, 0.7, 0.5])
	var struct_name: String = str(struct_data.get("name", "Creation_" + str(Time.get_ticks_msec())))

	var existing = spawned_objects_container.get_node_or_null(struct_name)
	if existing:
		existing.queue_free()

	var node: CSGShape3D
	if shape_type == "cylinder":
		var cyl := CSGCylinder3D.new()
		cyl.radius = safe_float(size_arr[0], 2.0) / 2.0
		cyl.height = safe_float(size_arr[1], 4.0) if size_arr.size() > 1 else safe_float(size_arr[0], 2.0)
		node = cyl
	elif shape_type == "sphere":
		var sph := CSGSphere3D.new()
		sph.radius = safe_float(size_arr[0], 2.0) / 2.0
		node = sph
	else:
		var box := CSGBox3D.new()
		var sx = safe_float(size_arr[0], 2.0)
		var sy = safe_float(size_arr[1], 2.0) if size_arr.size() > 1 else sx
		var sz = safe_float(size_arr[2], 2.0) if size_arr.size() > 2 else sx
		box.size = Vector3(sx, sy, sz)
		node = box

	node.name = struct_name
	node.use_collision = true

	var mat := StandardMaterial3D.new()
	var cr = safe_float(col_arr[0], 0.8) if col_arr.size() > 0 else 0.8
	var cg = safe_float(col_arr[1], 0.7) if col_arr.size() > 1 else 0.7
	var cb = safe_float(col_arr[2], 0.5) if col_arr.size() > 2 else 0.5
	mat.albedo_color = Color(cr, cg, cb)
	mat.metallic = 0.2
	mat.roughness = 0.5
	node.material = mat

	spawned_objects_container.add_child(node)

	# Emerge dramatically from the deep
	var target_pos := Vector3(safe_float(pos_arr[0], 0.0), safe_float(pos_arr[1], 1.0), safe_float(pos_arr[2], 0.0))
	var height: float = safe_float(size_arr[1], 2.0) if size_arr.size() > 1 else 2.0
	node.position = Vector3(target_pos.x, target_pos.y - height - 2.0, target_pos.z)

	var tween := create_tween()
	tween.tween_property(node, "position", target_pos, 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	print("[GENESIS - DAY 5 & 6]: Behold! Monument '", struct_name, "' brought forth from the dust at ", target_pos)

func unmake_creations() -> void:
	if spawned_objects_container == null:
		return
	for child in spawned_objects_container.get_children():
		var tween := create_tween()
		tween.tween_property(child, "position:y", child.position.y - 8.0, 1.0).set_trans(Tween.TRANS_SINE)
		tween.tween_callback(child.queue_free)
	print("[GENESIS]: All creations dissolved back into primordial dust.")

func divine_intervention(physics: Dictionary) -> void:
	if player_node == null:
		return
		
	if physics.has("gravity"):
		var g: float = safe_float(physics["gravity"], 9.8)
		player_node.gravity = g
		print("[GENESIS - DIVINE WILL]: Weight of the mortal coil ordained to ", g, " m/s²")
		
	if physics.has("player_speed"):
		var s: float = safe_float(physics["player_speed"], 5.0)
		player_node.speed = s
		print("[GENESIS - DIVINE WILL]: Mortal gait and quickness decreed to ", s)
		
	if physics.has("kinetic_smite") or physics.has("impulse"):
		var imp_data = physics.get("kinetic_smite", physics.get("impulse"))
		var imp: Array = parse_to_array(imp_data, [0.0, 14.0, 0.0])
		if imp.size() >= 3:
			var impulse_vec := Vector3(safe_float(imp[0], 0.0), safe_float(imp[1], 14.0), safe_float(imp[2], 0.0))
			player_node.velocity += impulse_vec
			print("[GENESIS - DIVINE SMITE]: The hand of God casts the mortal across the heavens: ", impulse_vec)

func safe_float(val, default_val: float = 0.0) -> float:
	if val == null:
		return default_val
	if val is float or val is int:
		return float(val)
	if val is String:
		var s := val as String
		if s.is_valid_float():
			return s.to_float()
	return default_val

func parse_to_array(val, default_arr: Array) -> Array:
	if val is Array:
		return val
	if val is String:
		var parsed = JSON.parse_string(val)
		if parsed is Array:
			return parsed
	return default_arr

func _on_sector_alpha_trigger_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player") or body.name == "Player":
		print("The mortal sets foot in the sacred sanctuary...")
		send_event_to_overseer("mortal_enters_sanctuary", {
			"location": "Eden Sanctuary (Sector Alpha)",
			"subject": "Mortal Adam",
			"observation": "Mortal walks upon the dust of Creation."
		})
