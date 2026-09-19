extends CharacterBody3D

@export var max_speed: float = 6.5
@export var acceleration: float = 3.5
@export var generation: int = 1

@onready var left_wing: CSGBox3D = $Visuals/Connectome/LeftWing
@onready var right_wing: CSGBox3D = $Visuals/Connectome/RightWing
@onready var holo_node: Node3D = $Visuals/HoloProjector
@onready var holo_quad: MeshInstance3D = $Visuals/HoloProjector/HoloQuad
@onready var synaptic_light: OmniLight3D = $Visuals/SynapticLight
@onready var thought_label: Label3D = $Visuals/ThoughtLabel
@onready var central_brain: CSGSphere3D = $Visuals/Connectome/CentralBrain
@onready var left_optic: CSGSphere3D = $Visuals/Connectome/LeftOpticLobe
@onready var right_optic: CSGSphere3D = $Visuals/Connectome/RightOpticLobe
@onready var http_connectome: HTTPRequest = $ConnectomeHTTP

const CONNECTOME_URL: String = "http://127.0.0.1:8000/connectome/step"

# Sanctuary Waypoints around the Altar & Tree of Life
var sanctuary_waypoints: Array[Vector3] = [
	Vector3(0.0, 4.5, -10.0),    # Tree of Life branch (zenith)
	Vector3(1.4, 5.2, -9.6),     # East golden branch
	Vector3(-1.3, 4.8, -10.4),   # West sacred canopy
	Vector3(0.0, 1.4, -8.5),     # Altar of the Covenant dais
	Vector3(0.8, 2.5, -9.0),     # Golden core pedestal
	Vector3(4.0, 1.8, -11.0),    # Nectar flowers by the brook
	Vector3(-3.5, 2.0, -9.5),    # Shaded grove resting spot
	Vector3(0.0, 3.2, -11.2)     # Rear sanctuary foliage
]

var current_waypoint_index: int = 0
var target_position: Vector3 = Vector3(0, 3.5, -10.0)
var time_alive: float = 0.0
var waypoint_switch_timer: float = 0.0
var next_connectome_query: float = 0.0

# Biophysical state actively watched by God
var nourishment: float = 80.0
var vitality: float = 90.0
var is_basking: bool = false
var is_reproducing: bool = false

# Live Neuprint Telemetry
var live_v_membrane: float = -70.0
var live_spike_rate: float = 38.0
var live_wing_freq: float = 38.0
var neuprint_dataset_name: String = "male-cns:v1.0"

signal reproduced(parent_fly: Node3D, spawn_pos: Vector3)

func _ready() -> void:
	add_to_group("FruitFlies")
	if http_connectome:
		http_connectome.request_completed.connect(_on_connectome_response)
	
	setup_wing_materials()
	current_waypoint_index = randi() % sanctuary_waypoints.size()
	target_position = sanctuary_waypoints[current_waypoint_index]
	
	update_billboard_label()

func setup_wing_materials() -> void:
	var wing_mat: StandardMaterial3D = StandardMaterial3D.new()
	wing_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wing_mat.albedo_color = Color(0.85, 0.95, 1.0, 0.42)
	wing_mat.roughness = 0.1
	wing_mat.metallic = 0.5
	wing_mat.rim_enabled = true
	wing_mat.rim = 0.8
	wing_mat.rim_tint = 0.5
	
	if left_wing: left_wing.material = wing_mat
	if right_wing: right_wing.material = wing_mat

func _physics_process(delta: float) -> void:
	time_alive += delta
	waypoint_switch_timer += delta

	# Natural slow metabolism (God provides sustenance to replenish)
	nourishment = maxf(10.0, nourishment - (delta * 0.4))
	
	# Switch waypoints periodically unless basking or reproducing
	if not is_basking and not is_reproducing:
		if waypoint_switch_timer >= 6.0 or global_position.distance_to(target_position) < 0.6:
			waypoint_switch_timer = 0.0
			current_waypoint_index = (current_waypoint_index + 1) % sanctuary_waypoints.size()
			var base_wp: Vector3 = sanctuary_waypoints[current_waypoint_index]
			# Subtle random offset within the sacred grove
			var jitter := Vector3(randf_range(-0.5, 0.5), randf_range(-0.2, 0.3), randf_range(-0.5, 0.5))
			target_position = base_wp + jitter

	# Flight steering toward sanctuary target
	var hover_bob: float = sin(time_alive * 2.8) * 0.18
	var destination: Vector3 = target_position + Vector3(0, hover_bob, 0)
	var to_dest: Vector3 = destination - global_position
	
	var desired_vel: Vector3 = to_dest.normalized() * minf(to_dest.length() * 2.5, max_speed)
	velocity = velocity.lerp(desired_vel, acceleration * delta)
	move_and_slide()

	# Smooth orientation toward flight direction
	if velocity.length() > 0.4:
		var look_target: Vector3 = global_position + velocity
		var cur_pos: Vector3 = global_position
		if cur_pos.distance_squared_to(look_target) > 0.01:
			var target_basis: Basis = Transform3D().looking_at(look_target - cur_pos, Vector3.UP).basis
			basis = basis.slerp(target_basis, 5.0 * delta)

	# Wing flutter driven by connectome frequency
	animate_wings(delta)

	# Synaptic bioluminescence & hologram
	animate_neural_synapses(delta)

	# Stream sensory telemetry to Neuprint connectome server
	if time_alive >= next_connectome_query:
		next_connectome_query = time_alive + 0.35 # ~3 Hz stream
		stream_sensory_to_connectome()

func animate_wings(delta: float) -> void:
	if left_wing == null or right_wing == null:
		return
		
	var is_resting: bool = velocity.length() < 0.3 and not is_basking
	var freq: float = (live_wing_freq * 0.3) if is_resting else live_wing_freq
	var wing_angle: float = sin(time_alive * freq) * 0.45
	
	left_wing.rotation.z = wing_angle
	right_wing.rotation.z = -wing_angle

func animate_neural_synapses(delta: float) -> void:
	if holo_node != null:
		holo_node.rotation.y += delta * 0.5
		holo_node.position.y = 1.35 + sin(time_alive * 2.0) * 0.12

	if synaptic_light != null:
		var bonus: float = 2.0 if is_basking else 0.0
		var pulse: float = 2.0 + bonus + sin(time_alive * 7.0) * 0.5
		synaptic_light.light_energy = pulse

func stream_sensory_to_connectome() -> void:
	if http_connectome == null or http_connectome.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return

	var altar_pos := Vector3(0, 1.2, -10.0)
	var dist_to_altar := global_position.distance_to(altar_pos)
	
	var payload: Dictionary = {
		"dist_to_adam": dist_to_altar, # Sacred center focus
		"adam_speed": velocity.length(),
		"light_energy": 3.5 if is_basking else 2.2,
		"heading_angle": 0.0
	}
	var json_data: String = JSON.stringify(payload)
	var headers: PackedStringArray = ["Content-Type: application/json"]
	http_connectome.request(CONNECTOME_URL, headers, HTTPClient.METHOD_POST, json_data)

func _on_connectome_response(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		return

	var text: String = body.get_string_from_utf8()
	var data = JSON.parse_string(text)
	if not (data is Dictionary):
		return

	live_v_membrane = safe_float(data.get("v_membrane_mv"), -70.0)
	live_spike_rate = safe_float(data.get("spike_rate_hz"), 38.0)
	live_wing_freq = safe_float(data.get("wing_freq_hz"), 38.0)
	neuprint_dataset_name = str(data.get("dataset", "male-cns:v1.0"))

	update_billboard_label()

func update_billboard_label() -> void:
	if thought_label == null:
		return
		
	var gen_str := "Gen " + str(generation)
	var care_status := "✧ Hand of God Sustaining ✧" if is_basking else ("Nourishment: " + str(int(nourishment)) + "%")
	var line1: String = "✧ " + gen_str + " Sacred Fly [" + neuprint_dataset_name + "] • " + care_status + " ✧"
	var line2: String = "✧ 166,000 Neurons | 125M Synapses | LIF Vm: " + str(live_v_membrane) + " mV ✧"
	thought_label.text = line1 + "\n" + line2

# Called when God actively pours divine light and nectar upon the fruit fly
func receive_divine_care(bless_reproduction: bool = false) -> void:
	is_basking = true
	nourishment = 100.0
	vitality = 100.0
	
	# Spiral up joyfully in the heavenly light
	var tween: Tween = create_tween()
	var original_pos: Vector3 = global_position
	tween.tween_property(self, "position:y", original_pos.y + 2.0, 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "rotation:y", rotation.y + deg_to_rad(720), 1.2)
	tween.tween_property(self, "position:y", original_pos.y, 0.8).set_trans(Tween.TRANS_SINE)
	
	if synaptic_light:
		synaptic_light.light_color = Color(1.0, 0.9, 0.4) # Divine gold
	
	get_tree().create_timer(4.0).timeout.connect(func():
		is_basking = false
		if synaptic_light:
			synaptic_light.light_color = Color(0.3, 0.85, 1.0)
	)

	# Reproduce if blessed by God (Genesis 1:22)
	if bless_reproduction or nourishment >= 95.0:
		get_tree().create_timer(1.2).timeout.connect(reproduce)

# Genesis 1:22 - Be Fruitful and Multiply
func reproduce() -> void:
	if is_reproducing:
		return
	is_reproducing = true
	
	# Lay a radiant golden chrysalis on the Tree of Life / Altar
	var egg_pos: Vector3 = global_position + Vector3(0.3, -0.4, 0.2)
	reproduced.emit(self, egg_pos)
	
	nourishment = 65.0
	get_tree().create_timer(3.0).timeout.connect(func(): is_reproducing = false)

func safe_float(val, default_val: float = 0.0) -> float:
	if val == null:
		return default_val
	if val is float or val is int:
		return float(val)
	if val is String:
		var s: String = val as String
		if s.is_valid_float():
			return s.to_float()
	return default_val
