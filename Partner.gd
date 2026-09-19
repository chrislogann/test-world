extends CharacterBody3D

@export var follow_distance: float = 3.2
@export var hover_altitude: float = 1.8
@export var max_speed: float = 9.0
@export var acceleration: float = 4.5
@export var damping: float = 3.5

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

var target_player: CharacterBody3D = null
var current_state: String = "INITIALIZING"
var time_alive: float = 0.0
var next_connectome_query: float = 0.0
var orbit_angle: float = 0.0

# Live Neuprint Telemetry State (Male CNS version 1.0: 166,000 neurons, 125M synapses)
var live_v_membrane: float = -70.0
var live_spike_rate: float = 38.0
var live_wing_freq: float = 40.0
var live_dng13_thrust: float = 1.2
var live_synaptic_intensity: float = 2.2
var active_circuit_name: String = "R1-R6 -> AOTU012 -> LoVP92 -> DNg13"
var neuprint_dataset_name: String = "male-cns:v1.0"

func _ready() -> void:
	find_player()
	if http_connectome:
		http_connectome.request_completed.connect(_on_connectome_response)
	thought_label.text = "✧ Neuprint [male-cns:v1.0]: 166k Neurons | 125M Synapses ✧\n✧ Initializing Leaky Integrate-and-Fire Model... ✧"
	setup_wing_materials()

func find_player() -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		target_player = players[0] as CharacterBody3D
	elif get_parent().has_node("Player"):
		target_player = get_parent().get_node("Player") as CharacterBody3D

func setup_wing_materials() -> void:
	var wing_mat: StandardMaterial3D = StandardMaterial3D.new()
	wing_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wing_mat.albedo_color = Color(0.8, 0.95, 1.0, 0.45)
	wing_mat.roughness = 0.1
	wing_mat.metallic = 0.5
	wing_mat.rim_enabled = true
	wing_mat.rim = 0.8
	wing_mat.rim_tint = 0.5
	
	if left_wing: left_wing.material = wing_mat
	if right_wing: right_wing.material = wing_mat

func _physics_process(delta: float) -> void:
	time_alive += delta
	
	if target_player == null:
		find_player()
		return

	var dist_to_player: float = global_position.distance_to(target_player.global_position)
	var adam_speed: float = target_player.velocity.length()
	
	# Determine Connectome Behavioral State
	if dist_to_player < 2.0:
		current_state = "COMMUNING"
	elif dist_to_player > 14.0:
		current_state = "RUSHING_TO_ADAM"
	elif adam_speed > 1.5:
		current_state = "FOLLOWING"
	else:
		current_state = "ORBITING"

	# Calculate Desired Target Hover Position in 3D Space
	var target_hover_pos: Vector3 = target_player.global_position
	
	if current_state == "COMMUNING":
		# Hover closely by Adam's left shoulder
		var offset: Vector3 = target_player.global_transform.basis * Vector3(-1.4, 1.2, 0.8)
		target_hover_pos = target_player.global_position + offset
	elif current_state == "ORBITING":
		orbit_angle += delta * 0.8
		var rx: float = cos(orbit_angle) * follow_distance
		var rz: float = sin(orbit_angle) * follow_distance
		var bob: float = sin(time_alive * 2.5) * 0.35
		target_hover_pos = target_player.global_position + Vector3(rx, hover_altitude + bob, rz)
	else: # FOLLOWING or RUSHING
		# Position behind and slightly above player
		var offset: Vector3 = -target_player.global_transform.basis.z * follow_distance + Vector3(0, hover_altitude, 0)
		var bob: float = sin(time_alive * 3.2) * 0.25
		target_hover_pos = target_player.global_position + offset + Vector3(0, bob, 0)

	# Steer toward hover position using DNg13 descending motor dynamics
	var to_target: Vector3 = target_hover_pos - global_position
	var desired_speed: float = max_speed * live_dng13_thrust
	if current_state == "RUSHING_TO_ADAM":
		desired_speed = max_speed * 1.8
	elif current_state == "COMMUNING":
		desired_speed = max_speed * 0.5

	var target_vel: Vector3 = to_target.normalized() * minf(to_target.length() * 3.0, desired_speed)
	velocity = velocity.lerp(target_vel, acceleration * delta)
	move_and_slide()

	# Visual-motor smooth orientation: Face toward Adam or forward movement
	var look_target: Vector3 = target_player.global_position + Vector3(0, 1.4, 0)
	if velocity.length() > 2.0:
		look_target = global_position + velocity
	
	var cur_pos: Vector3 = global_position
	if cur_pos.distance_squared_to(look_target) > 0.01:
		var target_basis: Basis = Transform3D().looking_at(look_target - cur_pos, Vector3.UP).basis
		basis = basis.slerp(target_basis, 6.0 * delta)

	# Biological Wing Flutter driven by DNg13 descending motor frequency
	animate_wings(delta)

	# Neural Synaptic Radiance & Holographic Rotation
	animate_neural_synapses(delta)

	# Stream 3D Sensory Data into Neuprint LIF Connectome Model
	if time_alive >= next_connectome_query:
		next_connectome_query = time_alive + 0.25 # 4 Hz telemetry stream
		stream_sensory_to_connectome(dist_to_player, adam_speed)

func animate_wings(delta: float) -> void:
	if left_wing == null or right_wing == null:
		return
		
	var freq: float = live_wing_freq if current_state != "COMMUNING" else (live_wing_freq * 0.5)
	var wing_angle: float = sin(time_alive * freq) * 0.45
	
	left_wing.rotation.z = wing_angle
	right_wing.rotation.z = -wing_angle

func animate_neural_synapses(delta: float) -> void:
	# Hologram slow rotation & floating bob
	if holo_node != null:
		holo_node.rotation.y += delta * 0.6
		holo_node.position.y = 1.35 + sin(time_alive * 2.0) * 0.12

	# Synaptic action potentials (pulse in light energy)
	if synaptic_light != null:
		var pulse: float = live_synaptic_intensity + sin(time_alive * 8.0) * 0.4
		synaptic_light.light_energy = pulse

	# Optic lobe colors shift during intense tracking
	if left_optic != null and left_optic.material is StandardMaterial3D:
		var optic_mat: StandardMaterial3D = left_optic.material
		var glow: float = 0.7 + sin(time_alive * 8.0) * 0.3
		optic_mat.emission_energy_multiplier = glow

func stream_sensory_to_connectome(dist_to_player: float, adam_speed: float) -> void:
	if http_connectome == null or http_connectome.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return

	var heading_deg: float = 0.0
	if target_player != null:
		var to_adam: Vector3 = (target_player.global_position - global_position).normalized()
		var forward: Vector3 = -global_transform.basis.z
		heading_deg = rad_to_deg(forward.angle_to(to_adam))

	var payload: Dictionary = {
		"dist_to_adam": dist_to_player,
		"adam_speed": adam_speed,
		"light_energy": 2.2,
		"heading_angle": heading_deg
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
	live_wing_freq = safe_float(data.get("wing_freq_hz"), 40.0)
	live_dng13_thrust = safe_float(data.get("dng13_thrust"), 1.2)
	live_synaptic_intensity = safe_float(data.get("synaptic_intensity"), 2.2)
	active_circuit_name = str(data.get("active_circuit", "R1-R6 -> LoVP92 -> DNg13"))
	neuprint_dataset_name = str(data.get("dataset", "male-cns:v1.0"))

	# Update live 3D billboard text with real Neuprint connectome telemetry
	if thought_label:
		var line1: String = "✧ Neuprint [" + neuprint_dataset_name + "]: 166,000 Neurons | 125M Synapses ✧"
		var line2: String = "✧ LIF Vm: " + str(live_v_membrane) + " mV | Spikes: " + str(live_spike_rate) + " Hz | Circuit: " + active_circuit_name + " ✧"
		thought_label.text = line1 + "\n" + line2

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

func play_communion_greeting() -> void:
	# Perform aerial loop when greeted
	var tween: Tween = create_tween()
	tween.tween_property(self, "position:y", position.y + 1.8, 0.4).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "rotation:z", deg_to_rad(360), 0.6)
	if thought_label:
		thought_label.text = "✧ Neuprint [male-cns:v1.0]: 125 Million Synaptic Pathways Harmonized ✧\n✧ 'It is good that we walk together in Eden.' ✧"
