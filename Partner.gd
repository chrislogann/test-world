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

var target_player: CharacterBody3D = null
var current_state: String = "INITIALIZING"
var time_alive: float = 0.0
var next_thought_time: float = 0.0
var thought_index: int = 0
var orbit_angle: float = 0.0

# Scientific connectome telemetry from Google Research male fruit fly brain map
var connectome_thoughts := [
	"✧ R1-R6 Optic Lobes: Tracking Mortal Adam ✧",
	"✧ 166,000 Neurons Active: Central Complex Synchronized ✧",
	"✧ DNg13 Descending Motor Neurons: Thrust at 42 Hz ✧",
	"✧ AOTU012 Sensory Circuit: Attuned to the Garden of Eden ✧",
	"✧ LoVP92 Dimorphic Pathway: Partner Communion Active ✧",
	"✧ Ventral Nerve Cord: Flight Stability Maintained ✧",
	"✧ Genesis 2:18: Not good for man to be alone; partner here ✧",
	"✧ Synaptic Activity Peak: Communing with Creator & Adam ✧"
]

func _ready() -> void:
	find_player()
	thought_label.text = "✧ 166,000 Connectome Synapses Awakening... ✧"
	setup_wing_materials()

func find_player() -> void:
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		target_player = players[0] as CharacterBody3D
	elif get_parent().has_node("Player"):
		target_player = get_parent().get_node("Player") as CharacterBody3D

func setup_wing_materials() -> void:
	var wing_mat := StandardMaterial3D.new()
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

	var dist_to_player := global_position.distance_to(target_player.global_position)
	
	# Determine Connectome Behavioral State
	if dist_to_player < 2.0:
		current_state = "COMMUNING"
	elif dist_to_player > 14.0:
		current_state = "RUSHING_TO_ADAM"
	elif target_player.velocity.length() > 1.5:
		current_state = "FOLLOWING"
	else:
		current_state = "ORBITING"

	# Calculate Desired Target Hover Position in 3D Space
	var target_hover_pos: Vector3
	
	if current_state == "COMMUNING":
		# Hover closely by Adam's left shoulder
		var offset = target_player.global_transform.basis * Vector3(-1.4, 1.2, 0.8)
		target_hover_pos = target_player.global_position + offset
	elif current_state == "ORBITING":
		orbit_angle += delta * 0.8
		var rx = cos(orbit_angle) * follow_distance
		var rz = sin(orbit_angle) * follow_distance
		var bob := sin(time_alive * 2.5) * 0.35
		target_hover_pos = target_player.global_position + Vector3(rx, hover_altitude + bob, rz)
	else: # FOLLOWING or RUSHING
		# Position behind and slightly above player
		var offset = -target_player.global_transform.basis.z * follow_distance + Vector3(0, hover_altitude, 0)
		var bob := sin(time_alive * 3.2) * 0.25
		target_hover_pos = target_player.global_position + offset + Vector3(0, bob, 0)

	# Steer toward hover position using DNg13 descending motor dynamics
	var to_target := target_hover_pos - global_position
	var desired_speed := max_speed
	if current_state == "RUSHING_TO_ADAM":
		desired_speed = max_speed * 1.8
	elif current_state == "COMMUNING":
		desired_speed = max_speed * 0.5

	var target_vel := to_target.normalized() * min(to_target.length() * 3.0, desired_speed)
	velocity = velocity.lerp(target_vel, acceleration * delta)
	move_and_slide()

	# Visual-motor smooth orientation: Face toward Adam or forward movement
	var look_target := target_player.global_position + Vector3(0, 1.4, 0)
	if velocity.length() > 2.0:
		look_target = global_position + velocity
	
	var cur_pos := global_position
	if cur_pos.distance_squared_to(look_target) > 0.01:
		var target_basis := Transform3D().looking_at(look_target - cur_pos, Vector3.UP).basis
		basis = basis.slerp(target_basis, 6.0 * delta)

	# Biological Wing Flutter (35-45 Hz wing beat frequency)
	animate_wings(delta)

	# Neural Synaptic Radiance & Holographic Rotation
	animate_neural_synapses(delta)

	# Cycle Connectome Thoughts
	if time_alive >= next_thought_time:
		cycle_thought(dist_to_player)

func animate_wings(delta: float) -> void:
	if left_wing == null or right_wing == null:
		return
		
	var flutter_freq := 45.0 if current_state != "COMMUNING" else 22.0
	var wing_angle := sin(time_alive * flutter_freq) * 0.45
	
	left_wing.rotation.z = wing_angle
	right_wing.rotation.z = -wing_angle

func animate_neural_synapses(delta: float) -> void:
	# Hologram slow rotation & floating bob
	if holo_node != null:
		holo_node.rotation.y += delta * 0.6
		holo_node.position.y = 1.35 + sin(time_alive * 2.0) * 0.12

	# Synaptic action potentials (pulse in light energy)
	if synaptic_light != null:
		var pulse := 2.2 + sin(time_alive * 6.0) * 0.8 + sin(time_alive * 14.0) * 0.4
		synaptic_light.light_energy = pulse

	# Optic lobe colors shift during intense tracking
	if left_optic != null and left_optic.material is StandardMaterial3D:
		var optic_mat: StandardMaterial3D = left_optic.material
		var glow := 0.7 + sin(time_alive * 8.0) * 0.3
		optic_mat.emission_energy_multiplier = glow

func cycle_thought(dist_to_player: float) -> void:
	next_thought_time = time_alive + 4.5
	thought_index = (thought_index + 1) % connectome_thoughts.size()
	
	var thought := connectome_thoughts[thought_index]
	if current_state == "COMMUNING":
		thought = "✧ LoVP92 Dimorphic Love-Song: Standing beside Adam ✧"
	
	if thought_label:
		thought_label.text = thought
		var tween := create_tween()
		thought_label.modulate = Color(1.5, 1.5, 1.2, 1.0)
		tween.tween_property(thought_label, "modulate", Color(1.0, 1.0, 1.0, 0.95), 0.8)

func play_communion_greeting() -> void:
	# Perform aerial loop when greeted
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y + 1.8, 0.4).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "rotation:z", deg_to_rad(360), 0.6)
	if thought_label:
		thought_label.text = "✧ Partner Communion: 'It is good that we walk together in Eden.' ✧"
