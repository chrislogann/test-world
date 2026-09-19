extends Node3D

@onready var http_request: HTTPRequest = $HTTPRequest
@onready var room_light: DirectionalLight3D = $DirectionalLight3D

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
	if data.has("message"):
		print("[OVERSEER INTERCOM]: ", data["message"])
		
	# 2. Lighting Changes
	if data.has("light_color"):
		var col: Array = data["light_color"] # Expecting [r, g, b]
		var target_color := Color(col[0], col[1], col[2])
		var tween := create_tween()
		tween.tween_property(room_light, "light_color", target_color, 1.2).set_trans(Tween.TRANS_SINE)

func _on_sector_alpha_trigger_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player") or body.name == "Player":
		print("Sending Sector Alpha alert to overseer...")
		send_event_to_overseer("player_entered_zone", {"zone": "Sector Alpha"})
