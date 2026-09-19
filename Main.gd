extends Node3D

@onready var http_request: HTTPRequest = $HTTPRequest
@onready var room_light: DirectionalLight3D = $DirectionalLight3D
@onready var floor_node: CSGBox3D = $Floor
@onready var player_node: CharacterBody3D = $Player
@onready var spawned_objects_container: Node3D = $SpawnedObjects
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var aura_light: OmniLight3D = $SectorAlphaTrigger/AuraLight
@onready var aura_pillar: CSGCylinder3D = $SectorAlphaTrigger/PillarOfLight
@onready var aura_ring: CSGCylinder3D = $SectorAlphaTrigger/SanctifiedRing

@onready var wall_north: CSGBox3D = $WallNorth
@onready var wall_south: CSGBox3D = $WallSouth
@onready var wall_east: CSGBox3D = $WallEast
@onready var wall_west: CSGBox3D = $WallWest

@onready var scripture_banner: PanelContainer = $GenesisHUD/HUDContainer/ScriptureBanner
@onready var day_title_label: Label = $GenesisHUD/HUDContainer/ScriptureBanner/Margin/VBox/DayTitle
@onready var verse_label: Label = $GenesisHUD/HUDContainer/ScriptureBanner/Margin/VBox/VerseText
@onready var voice_label: Label = $GenesisHUD/HUDContainer/ScriptureBanner/Margin/VBox/VoiceText

const OVERSEER_URL = "http://127.0.0.1:8000/event"

var is_in_sanctuary: bool = false
var sanctuary_cooldown: bool = false
var sanctuary_visit_count: int = 0
var world_created: bool = false
var genesis_in_progress: bool = false

# Cached Procedural Materials
var trunk_material: StandardMaterial3D
var foliage_material: StandardMaterial3D
var foliage_gold_material: StandardMaterial3D
var gold_fruit_material: StandardMaterial3D
var water_material: StandardMaterial3D
var marble_pillar_material: StandardMaterial3D
var gold_emissive_material: StandardMaterial3D

func _ready() -> void:
	http_request.request_completed.connect(_on_overseer_response)
	start_holy_aura_animation()
	_init_genesis_materials()
	
	# Initial welcome banner
	display_scripture(
		"✧ THE BOOK OF GENESIS ✧",
		"Step into the Holy Pillar of Light to awaken creation.",
		"\"The earth was without form, and void; and darkness was upon the face of the deep.\""
	)

func _init_genesis_materials() -> void:
	trunk_material = StandardMaterial3D.new()
	trunk_material.albedo_color = Color(0.38, 0.24, 0.14)
	trunk_material.roughness = 0.9

	foliage_material = StandardMaterial3D.new()
	foliage_material.albedo_color = Color(0.18, 0.52, 0.22)
	foliage_material.roughness = 0.8

	foliage_gold_material = StandardMaterial3D.new()
	foliage_gold_material.albedo_color = Color(0.32, 0.65, 0.28)
	foliage_gold_material.roughness = 0.75

	gold_fruit_material = StandardMaterial3D.new()
	gold_fruit_material.albedo_color = Color(1.0, 0.85, 0.2)
	gold_fruit_material.metallic = 0.6
	gold_fruit_material.roughness = 0.3
	gold_fruit_material.emission_enabled = true
	gold_fruit_material.emission = Color(0.9, 0.75, 0.1)
	gold_fruit_material.emission_energy_multiplier = 0.8

	water_material = StandardMaterial3D.new()
	water_material.albedo_color = Color(0.15, 0.58, 0.85, 0.82)
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_material.roughness = 0.08
	water_material.metallic = 0.2

	marble_pillar_material = StandardMaterial3D.new()
	marble_pillar_material.albedo_color = Color(0.94, 0.93, 0.9)
	marble_pillar_material.roughness = 0.3
	marble_pillar_material.metallic = 0.1

	gold_emissive_material = StandardMaterial3D.new()
	gold_emissive_material.albedo_color = Color(1.0, 0.85, 0.3)
	gold_emissive_material.emission_enabled = true
	gold_emissive_material.emission = Color(1.0, 0.85, 0.3)
	gold_emissive_material.emission_energy_multiplier = 1.5

func start_holy_aura_animation() -> void:
	if aura_light != null:
		var pulse := create_tween().set_loops()
		pulse.tween_property(aura_light, "light_energy", 4.8, 2.0).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(aura_light, "light_energy", 2.2, 2.0).set_trans(Tween.TRANS_SINE)
	if aura_ring != null:
		var rot := create_tween().set_loops()
		rot.tween_property(aura_ring, "rotation_degrees:y", 360.0, 16.0).as_relative()

func display_scripture(day_text: String, verse_text: String, voice_text: String = "") -> void:
	if scripture_banner == null:
		return
	if day_title_label:
		day_title_label.text = day_text
	if verse_label:
		verse_label.text = verse_text
	if voice_label:
		voice_label.text = voice_text
	
	var tween := create_tween()
	scripture_banner.modulate = Color(1.3, 1.3, 1.1, 0.5)
	tween.tween_property(scripture_banner, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.5).set_trans(Tween.TRANS_SINE)

func trigger_genesis_world_creation() -> void:
	if genesis_in_progress:
		return
	genesis_in_progress = true
	world_created = true

	print("\n=======================================================")
	print("✧ IN THE BEGINNING: THE GENESIS WORLD CREATION COMMENCES ✧")
	print("=======================================================\n")

	# ==========================================
	# DAY 1: FIAT LUX (Let There Be Light) (t = 0.0s)
	# ==========================================
	display_scripture(
		"✧ GENESIS • DAY 1 ✧",
		"\"And God said, 'Let there be light': and there was light.\"",
		"\"And God saw the light, that it was good: and God divided the light from the darkness.\""
	)
	
	# Holy Pillar Super-Flare
	if aura_light:
		var flare := create_tween()
		flare.tween_property(aura_light, "light_energy", 12.0, 0.3).set_trans(Tween.TRANS_EXPO)
		flare.tween_property(aura_light, "light_energy", 4.5, 2.0).set_trans(Tween.TRANS_SINE)

	# Ignite the Directional Sun
	if room_light:
		room_light.shadow_enabled = true
		var sun_tween := create_tween().set_parallel(true)
		sun_tween.tween_property(room_light, "light_color", Color(1.0, 0.96, 0.88), 2.5)
		sun_tween.tween_property(room_light, "light_energy", 2.0, 2.0).set_trans(Tween.TRANS_EXPO)
		var dawn_rot := Vector3(deg_to_rad(-35), deg_to_rad(30), 0)
		sun_tween.tween_property(room_light, "rotation", dawn_rot, 2.5)

	# ==========================================
	# DAY 2: THE FIRMAMENT (Heavens & Atmosphere) (t = 3.2s)
	# ==========================================
	get_tree().create_timer(3.2).timeout.connect(func():
		display_scripture(
			"✧ GENESIS • DAY 2 ✧",
			"\"And God said, 'Let there be a firmament in the midst of the waters.'\"",
			"\"And God called the firmament Heaven. And the evening and the morning were the second day.\""
		)
		if world_env and world_env.environment and world_env.environment.sky:
			var sky_mat = world_env.environment.sky.sky_material
			if sky_mat is ProceduralSkyMaterial:
				var sky_tween := create_tween().set_parallel(true)
				sky_tween.tween_property(sky_mat, "sky_top_color", Color(0.1, 0.36, 0.84), 2.8)
				sky_tween.tween_property(sky_mat, "sky_horizon_color", Color(0.96, 0.76, 0.46), 2.8)
				sky_tween.tween_property(sky_mat, "ground_bottom_color", Color(0.14, 0.22, 0.16), 2.8)
				sky_tween.tween_property(sky_mat, "ground_horizon_color", Color(0.42, 0.55, 0.44), 2.8)
		print("[GENESIS - DAY 2]: The heavens divided and the firmament fashioned.")
	)

	# ==========================================
	# DAY 3: THE DRY LAND, GRASS & TREES OF LIFE (t = 6.4s)
	# ==========================================
	get_tree().create_timer(6.4).timeout.connect(func():
		display_scripture(
			"✧ GENESIS • DAY 3 ✧",
			"\"And God said, 'Let the dry land appear': and it was so.\"",
			"\"And the earth brought forth grass, and the fruit tree yielding fruit after his kind.\""
		)

		# 1. Sinking the 4 enclosing chamber walls into the deep
		var wall_tween := create_tween().set_parallel(true)
		if wall_north: wall_tween.tween_property(wall_north, "position:y", -14.0, 3.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		if wall_south: wall_tween.tween_property(wall_south, "position:y", -14.0, 3.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		if wall_east: wall_tween.tween_property(wall_east, "position:y", -14.0, 3.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		if wall_west: wall_tween.tween_property(wall_west, "position:y", -14.0, 3.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		wall_tween.chain().tween_callback(func():
			if wall_north: wall_north.use_collision = false
			if wall_south: wall_south.use_collision = false
			if wall_east: wall_east.use_collision = false
			if wall_west: wall_west.use_collision = false
		)

		# 2. Expanding the Floor to vast 160x160 Eden terrain
		if floor_node:
			var floor_tween := create_tween().set_parallel(true)
			floor_tween.tween_property(floor_node, "size", Vector3(160, 0.5, 160), 3.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			
			var floor_mat: StandardMaterial3D = floor_node.material_override as StandardMaterial3D
			if floor_mat == null:
				floor_mat = floor_node.material as StandardMaterial3D
			if floor_mat == null:
				floor_mat = StandardMaterial3D.new()
				floor_node.material_override = floor_mat
			floor_mat.roughness = 0.85
			floor_tween.tween_property(floor_mat, "albedo_color", Color(0.2, 0.58, 0.22), 2.8)

		# 3. Sprout Trees of Life and Eden vegetation across the land
		spawn_eden_vegetation()

		# 4. Sprout the River of Eden
		spawn_river_of_eden()

		print("[GENESIS - DAY 3]: The prison chamber dissolved; 160m Eden pastures and groves brought forth.")
	)

	# ==========================================
	# DAY 4: THE SUN & CELESTIAL LIGHTS (t = 10.2s)
	# ==========================================
	get_tree().create_timer(10.2).timeout.connect(func():
		display_scripture(
			"✧ GENESIS • DAY 4 ✧",
			"\"And God said, 'Let there be lights in the firmament of the heaven.'\"",
			"\"The greater light to rule the day, and the lesser light to rule the night: He made the stars also.\""
		)
		if room_light:
			var celestial_tween := create_tween().set_parallel(true)
			var noon_rot := Vector3(deg_to_rad(-52), deg_to_rad(65), deg_to_rad(10))
			celestial_tween.tween_property(room_light, "rotation", noon_rot, 3.2).set_trans(Tween.TRANS_SINE)
			celestial_tween.tween_property(room_light, "light_energy", 2.2, 3.0)

		# Spawning the 4 Cardinal Monoliths of Creation at the world bounds
		spawn_cardinal_creation_pillars()

		print("[GENESIS - DAY 4]: The solar orb completed its sweeping path and cardinal pillars arose.")
	)

	# ==========================================
	# DAY 5 & 6: THE SANCTUARY ALTAR & MAN CREATED (t = 13.8s)
	# ==========================================
	get_tree().create_timer(13.8).timeout.connect(func():
		display_scripture(
			"✧ GENESIS • DAY 5 & 6 ✧",
			"\"And God created man in His own image, in the image of God created He him.\"",
			"\"Be fruitful, and multiply, and replenish the earth, and subdue it.\""
		)

		# Spawning the Eden Sanctuary Altar of the Covenant
		spawn_eden_sanctuary_altar()

		print("[GENESIS - DAY 5 & 6]: The living covenant established at the heart of the garden.")
	)

	# ==========================================
	# DAY 7: THE SABBATH REST & DIVINE BLESSING (t = 17.2s)
	# ==========================================
	get_tree().create_timer(17.2).timeout.connect(func():
		display_scripture(
			"✧ GENESIS • DAY 7 ✧",
			"\"And God saw everything that He had made, and, behold, it was very good.\"",
			"\"And God blessed the seventh day, and sanctified it: because that in it He had rested from all His work.\""
		)

		# Celestial grace bestowed upon mortal Adam
		if player_node:
			player_node.gravity = 3.2 # Low celestial gravity for paradise soaring
			player_node.speed = 7.0
			player_node.sprint_speed = 12.0
			print("[GENESIS - DAY 7]: Sabbath grace bestowed. Gravity reduced to 3.2 m/s²; mortal strides quickened.")

		if room_light:
			var rest_tween := create_tween()
			rest_tween.tween_property(room_light, "light_energy", 1.8, 2.5).set_trans(Tween.TRANS_SINE)

		genesis_in_progress = false
		print("=======================================================")
		print("✧ CREATION FULFILLED: EDEN IS SPOKEN INTO BEING ✧")
		print("=======================================================\n")
	)

func spawn_eden_vegetation() -> void:
	if spawned_objects_container == null:
		return

	# Coordinates for groves across the 160m world
	var tree_coords := [
		Vector3(-14, 0, -22), Vector3(14, 0, -25), Vector3(-8, 0, -36), Vector3(20, 0, -38), Vector3(0, 0, -48),
		Vector3(-18, 0, 18), Vector3(16, 0, 22), Vector3(-12, 0, 36), Vector3(24, 0, 34), Vector3(6, 0, 48),
		Vector3(-26, 0, -8), Vector3(-35, 0, 12), Vector3(-44, 0, -18), Vector3(-42, 0, 24), Vector3(-54, 0, 2),
		Vector3(12, 0, -10), Vector3(36, 0, -18), Vector3(38, 0, 16), Vector3(48, 0, -6), Vector3(52, 0, 26)
	]

	for i in range(tree_coords.size()):
		var coord = tree_coords[i]
		var tree_root := Node3D.new()
		tree_root.name = "TreeOfLife_" + str(i)
		
		# Trunk
		var trunk := CSGCylinder3D.new()
		trunk.radius = 0.38
		trunk.height = 4.2
		trunk.position = Vector3(0, 2.1, 0)
		trunk.use_collision = true
		trunk.material = trunk_material
		tree_root.add_child(trunk)

		# Canopy
		var canopy := CSGSphere3D.new()
		canopy.radius = 1.9
		canopy.position = Vector3(0, 4.4, 0)
		canopy.material = foliage_material if (i % 3 != 0) else foliage_gold_material
		tree_root.add_child(canopy)

		# Golden Fruit on alternating trees
		if i % 2 == 0:
			var fruit := CSGSphere3D.new()
			fruit.radius = 0.32
			fruit.position = Vector3(0.8, 4.1, 0.6)
			fruit.material = gold_fruit_material
			tree_root.add_child(fruit)

		spawned_objects_container.add_child(tree_root)

		# Emerge dynamically from beneath the soil
		tree_root.position = Vector3(coord.x, coord.y - 8.0, coord.z)
		var delay: float = float(i) * 0.08
		var tween := create_tween()
		tween.tween_interval(delay)
		tween.tween_property(tree_root, "position:y", coord.y, 1.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func spawn_river_of_eden() -> void:
	if spawned_objects_container == null:
		return

	# Main River Expanse
	var river := CSGBox3D.new()
	river.name = "RiverOfEden_Main"
	river.size = Vector3(10.0, 0.35, 145.0)
	river.position = Vector3(28.0, -3.0, 0.0)
	river.material = water_material
	river.use_collision = false
	spawned_objects_container.add_child(river)

	# Tributary Stream
	var stream := CSGBox3D.new()
	stream.name = "RiverOfEden_Tributary"
	stream.size = Vector3(38.0, 0.32, 8.0)
	stream.position = Vector3(10.0, -3.0, -20.0)
	stream.material = water_material
	stream.use_collision = false
	spawned_objects_container.add_child(stream)

	# Emerge softly to ground level
	var tween := create_tween().set_parallel(true)
	tween.tween_property(river, "position:y", -0.05, 2.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(stream, "position:y", -0.05, 2.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func spawn_cardinal_creation_pillars() -> void:
	if spawned_objects_container == null:
		return

	var positions := [
		Vector3(0, 0, -68), # North
		Vector3(0, 0, 68),  # South
		Vector3(68, 0, 0),  # East
		Vector3(-68, 0, 0)  # West
	]
	var names := ["NorthPillar", "SouthPillar", "EastPillar", "WestPillar"]

	for i in range(positions.size()):
		var root := Node3D.new()
		root.name = "Cardinal_" + names[i]

		# Marble Shaft
		var shaft := CSGCylinder3D.new()
		shaft.radius = 1.3
		shaft.height = 13.0
		shaft.position = Vector3(0, 6.5, 0)
		shaft.use_collision = true
		shaft.material = marble_pillar_material
		root.add_child(shaft)

		# Glowing Golden Capital
		var cap := CSGCylinder3D.new()
		cap.radius = 1.8
		cap.height = 0.8
		cap.position = Vector3(0, 13.2, 0)
		cap.material = gold_emissive_material
		root.add_child(cap)

		spawned_objects_container.add_child(root)

		# Emerge from the depths
		var target_pos = positions[i]
		root.position = Vector3(target_pos.x, target_pos.y - 16.0, target_pos.z)
		var tween := create_tween()
		tween.tween_property(root, "position:y", target_pos.y, 2.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func spawn_eden_sanctuary_altar() -> void:
	if spawned_objects_container == null:
		return

	var altar_root := Node3D.new()
	altar_root.name = "AltarOfTheCovenant"

	# Stepped Dais
	var dais := CSGBox3D.new()
	dais.size = Vector3(7.0, 0.6, 7.0)
	dais.position = Vector3(0, 0.3, 0)
	dais.use_collision = true
	dais.material = marble_pillar_material
	altar_root.add_child(dais)

	# Golden Core Platform
	var gold_plat := CSGCylinder3D.new()
	gold_plat.radius = 2.0
	gold_plat.height = 0.4
	gold_plat.position = Vector3(0, 0.8, 0)
	gold_plat.material = gold_emissive_material
	altar_root.add_child(gold_plat)

	# Central Tree of Life Trunk
	var gold_trunk := CSGCylinder3D.new()
	gold_trunk.radius = 0.45
	gold_trunk.height = 5.5
	gold_trunk.position = Vector3(0, 3.5, 0)
	gold_trunk.use_collision = true
	gold_trunk.material = gold_emissive_material
	altar_root.add_child(gold_trunk)

	# Radiant Golden Canopy
	var gold_canopy := CSGSphere3D.new()
	gold_canopy.radius = 2.4
	gold_canopy.position = Vector3(0, 6.2, 0)
	gold_canopy.material = gold_emissive_material
	altar_root.add_child(gold_canopy)

	# Golden Light Beacon
	var beacon := OmniLight3D.new()
	beacon.light_color = Color(1.0, 0.9, 0.5)
	beacon.light_energy = 3.5
	beacon.omni_range = 14.0
	beacon.position = Vector3(0, 6.0, 0)
	altar_root.add_child(beacon)

	spawned_objects_container.add_child(altar_root)

	# Emerge at (0, 0, -10)
	var target_pos := Vector3(0, 0, -10)
	altar_root.position = Vector3(target_pos.x, target_pos.y - 12.0, target_pos.z)
	var tween := create_tween()
	tween.tween_property(altar_root, "position:y", target_pos.y, 2.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func send_event_to_overseer(event_name: String, details: Dictionary) -> void:
	if http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
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
		if response_data.has("message") and response_data["message"] != null:
			var msg: String = str(response_data["message"])
			print("\n=======================================================")
			print("👑 [VOICE OF THE CREATOR]: ", msg)
			print("=======================================================\n")
			if voice_label:
				voice_label.text = "👑 " + msg
		execute_genesis_decree(response_data)

func execute_genesis_decree(data: Dictionary) -> void:
	# 1. Day 1 & 4: Celestial Sun
	if data.has("sun") and data["sun"] is Dictionary and not data["sun"].is_empty():
		command_sun(data["sun"])

	# 2. Day 2: The Firmament
	if data.has("firmament") and data["firmament"] is Dictionary and not data["firmament"].is_empty():
		shape_firmament(data["firmament"])

	# 3. Day 3: Dry Land and the Earth
	if data.has("terrain") and data["terrain"] is Dictionary and not data["terrain"].is_empty():
		command_earth(data["terrain"])

	# 4. Dissolve / Unmake Creations Back to Dust
	if data.get("clear_structures", false) == true:
		unmake_creations()

	# 5. Day 5 & 6: Pillars, Monuments, Altars, and Creations
	if data.has("structures") and data["structures"] is Array:
		for struct_data in data["structures"]:
			if struct_data is Dictionary:
				summon_creation(struct_data)

	# 6. Day 7 & Divine Sovereignty (Gravity, Kinetic Smite, Mortal Speed)
	if data.has("physics") and data["physics"] is Dictionary and not data["physics"].is_empty():
		divine_intervention(data["physics"])

func command_sun(sun_data: Dictionary) -> void:
	if sun_data.is_empty() or room_light == null:
		return
	var tween: Tween = null
	
	if sun_data.has("color"):
		if tween == null: tween = create_tween().set_parallel(true)
		var col: Array = parse_to_array(sun_data["color"], [1.0, 0.95, 0.8])
		var target_col := Color(safe_float(col[0], 1.0), safe_float(col[1], 0.95), safe_float(col[2], 0.8))
		tween.tween_property(room_light, "light_color", target_col, 2.0).set_trans(Tween.TRANS_SINE)
		
	if sun_data.has("energy"):
		if tween == null: tween = create_tween().set_parallel(true)
		var energy: float = safe_float(sun_data["energy"], 1.0)
		tween.tween_property(room_light, "light_energy", energy, 1.5)

	if sun_data.has("rotation"):
		if tween == null: tween = create_tween().set_parallel(true)
		var rot: Array = parse_to_array(sun_data["rotation"], [-45.0, 45.0, 0.0])
		var rot_rad := Vector3(
			deg_to_rad(safe_float(rot[0], -45.0)),
			deg_to_rad(safe_float(rot[1], 45.0)),
			deg_to_rad(safe_float(rot[2], 0.0) if rot.size() > 2 else 0.0)
		)
		tween.tween_property(room_light, "rotation", rot_rad, 3.0).set_trans(Tween.TRANS_CUBIC)

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

func command_earth(terrain: Dictionary) -> void:
	if terrain.is_empty() or floor_node == null:
		return
	var tween: Tween = null
	
	if terrain.has("floor_y"):
		if tween == null: tween = create_tween().set_parallel(true)
		var target_y: float = safe_float(terrain["floor_y"], -0.25)
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
		tween.tween_property(floor_node, "size", target_size, 2.0).set_trans(Tween.TRANS_CUBIC)

	if terrain.has("color"):
		if tween == null: tween = create_tween().set_parallel(true)
		var col_arr: Array = parse_to_array(terrain["color"], [0.3, 0.6, 0.2])
		var floor_mat: StandardMaterial3D = floor_node.material_override as StandardMaterial3D
		if floor_mat == null:
			floor_mat = floor_node.material as StandardMaterial3D
		if floor_mat == null:
			floor_mat = StandardMaterial3D.new()
			floor_node.material_override = floor_mat
		var target_col := Color(safe_float(col_arr[0], 0.3), safe_float(col_arr[1], 0.6), safe_float(col_arr[2], 0.2))
		tween.tween_property(floor_mat, "albedo_color", target_col, 2.0)

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

	var target_pos := Vector3(safe_float(pos_arr[0], 0.0), safe_float(pos_arr[1], 1.0), safe_float(pos_arr[2], 0.0))
	var height: float = safe_float(size_arr[1], 2.0) if size_arr.size() > 1 else 2.0
	node.position = Vector3(target_pos.x, target_pos.y - height - 2.0, target_pos.z)

	var tween := create_tween()
	tween.tween_property(node, "position", target_pos, 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	print("[GENESIS - DAY 5 & 6]: Behold! Monument '", struct_name, "' brought forth at ", target_pos)

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
		print("[GENESIS - DIVINE WILL]: World gravity ordained to ", g, " m/s²")
		
	if physics.has("player_speed"):
		var s: float = safe_float(physics["player_speed"], 5.0)
		player_node.speed = s
		print("[GENESIS - DIVINE WILL]: Mortal gait decreed to ", s)
		
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
	if not (body.is_in_group("Player") or body.name == "Player"):
		return
	if is_in_sanctuary or sanctuary_cooldown:
		return

	is_in_sanctuary = true
	sanctuary_cooldown = true
	sanctuary_visit_count += 1
	
	if not world_created:
		trigger_genesis_world_creation()
	else:
		print("The mortal returns to the sacred sanctuary (Communion #", sanctuary_visit_count, ")...")
		if aura_light != null:
			var flare := create_tween()
			flare.tween_property(aura_light, "light_energy", 8.0, 0.25).set_trans(Tween.TRANS_EXPO)
			flare.tween_property(aura_light, "light_energy", 3.5, 1.2).set_trans(Tween.TRANS_SINE)

	send_event_to_overseer("mortal_enters_sanctuary", {
		"location": "Eden Sanctuary (Sector Alpha)",
		"subject": "Mortal Adam",
		"visit_count": sanctuary_visit_count,
		"world_created": world_created,
		"observation": "Communion #" + str(sanctuary_visit_count) + ". The mortal activates the holy altar of creation."
	})

	# Cooldown timer to prevent repetitive re-triggering
	get_tree().create_timer(6.0).timeout.connect(func(): sanctuary_cooldown = false)

func _on_sector_alpha_trigger_body_exited(body: Node3D) -> void:
	if body.is_in_group("Player") or body.name == "Player":
		is_in_sanctuary = false
		print("The mortal departs from the holy altar.")
