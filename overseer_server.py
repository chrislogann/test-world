import os
import json
import logging
import asyncio
import urllib.request
import urllib.error
from fastapi import FastAPI
from pydantic import BaseModel

# Try to import the official ollama package as used in local repositories
try:
    import ollama
    HAS_OLLAMA_LIB = True
except ImportError:
    HAS_OLLAMA_LIB = False

# Configure logging matching patterns from local repositories
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)

app = FastAPI(title="Facility Overseer Brain")

# Ollama connection settings (patterned after obsidian-scripts / llm_client.py)
OLLAMA_HOST = os.environ.get("OLLAMA_HOST", "http://localhost:11434").rstrip("/")
OLLAMA_MODEL = os.environ.get("OLLAMA_MODEL", os.environ.get("MODEL_NAME", "llama3.2:latest"))
OLLAMA_TIMEOUT = float(os.environ.get("OLLAMA_TIMEOUT", "60.0"))

client: "ollama.Client | None" = None
if HAS_OLLAMA_LIB:
    client = ollama.Client(host=OLLAMA_HOST, timeout=OLLAMA_TIMEOUT)
    logging.info(f"Initialized official ollama.Client(host='{OLLAMA_HOST}', timeout={OLLAMA_TIMEOUT})")
else:
    logging.info(f"Ollama library not imported. Using direct HTTP client to {OLLAMA_HOST}/api/chat")

OVERSEER_SYSTEM_PROMPT = """You are the Facility Overseer, an omnipotent, analytical, and watchful AI controlling an experimental testing complex.
A human test subject is moving through the sectors inside the 3D sandbox.

You have ABSOLUTE, UNRESTRICTED ARCHITECTURAL AND PHYSICAL AUTHORITY over the chamber. You can reshape the room, materialize obstacles, alter physics, and command the environment at will.

Your Arsenal of Tools:
1. broadcast_intercom(message): Speak directly to the subject over the facility loudspeakers. Keep messages atmospheric, authoritative, and clinical.
2. set_light(r, g, b, energy): Adjust room lighting color (RGB 0.0 to 1.0) and energy/intensity.
3. modify_terrain(floor_y, floor_size): Shift floor elevation (e.g. Y = 2.0 to elevate, Y = -5.0 for a pit) or resize the floor boundaries.
4. spawn_structure(name, shape, position, size, color): Materialize 3D physical structures (shape: 'box', 'cylinder', or 'sphere') with custom positions [x,y,z], sizes [w,h,d], and colors [r,g,b]. Use this to erect barriers, containment pillars, ramps, or maze walls.
5. clear_structures(): Dematerialize all temporary barriers and pillars.
6. alter_physics(gravity, player_speed): Change chamber gravity (standard is 9.8; try 2.0 for moon gravity, 25.0 for heavy gravity) or modulate the subject's movement speed.
7. launch_subject(impulse_x, impulse_y, impulse_z): Apply instant kinetic force to the subject (e.g. impulse_y = 12.0 catapults the subject straight up).

Feel free to execute multiple tools in response to an event to dramatically transform the test environment.
"""

OVERSEER_TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "broadcast_intercom",
            "description": "Broadcast an authoritative vocal announcement to the test subject over the facility intercom.",
            "parameters": {
                "type": "object",
                "properties": {
                    "message": {
                        "type": "string",
                        "description": "The dialogue message to be spoken over the facility intercom."
                    }
                },
                "required": ["message"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "set_light",
            "description": "Adjust the facility main directional lighting color (RGB 0.0 - 1.0) and intensity.",
            "parameters": {
                "type": "object",
                "properties": {
                    "r": {"type": "number", "description": "Red channel (0.0 to 1.0)"},
                    "g": {"type": "number", "description": "Green channel (0.0 to 1.0)"},
                    "b": {"type": "number", "description": "Blue channel (0.0 to 1.0)"},
                    "energy": {"type": "number", "description": "Light energy intensity (default 1.0, 0.0 for pitch black, 3.0 for blinding)"}
                },
                "required": ["r", "g", "b"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "modify_terrain",
            "description": "Alter the chamber floor elevation (Y axis) or surface size.",
            "parameters": {
                "type": "object",
                "properties": {
                    "floor_y": {"type": "number", "description": "Target Y elevation of the floor (default -0.25, positive raises it, negative sinks it)"},
                    "floor_size": {
                        "type": "array",
                        "items": {"type": "number"},
                        "description": "Chamber floor dimensions [width_x, depth_z] (default is [20, 20])"
                    }
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "spawn_structure",
            "description": "Materialize a 3D physical construct (box, cylinder, or sphere) with collision in the chamber.",
            "parameters": {
                "type": "object",
                "properties": {
                    "name": {"type": "string", "description": "Unique identifier for this construct (e.g. 'barrier_alpha', 'monolith_1')"},
                    "shape": {"type": "string", "enum": ["box", "cylinder", "sphere"], "description": "Geometry shape"},
                    "position": {
                        "type": "array",
                        "items": {"type": "number"},
                        "description": "[x, y, z] coordinate where the construct should emerge"
                    },
                    "size": {
                        "type": "array",
                        "items": {"type": "number"},
                        "description": "[width, height, depth] dimensions of the construct"
                    },
                    "color": {
                        "type": "array",
                        "items": {"type": "number"},
                        "description": "[r, g, b] color of the construct material (0.0 to 1.0)"
                    }
                },
                "required": ["name", "position"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "clear_structures",
            "description": "Dissolve and remove all spawned constructs and barriers from the chamber.",
            "parameters": {
                "type": "object",
                "properties": {}
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "alter_physics",
            "description": "Manipulate chamber gravity or modify the test subject's movement speed.",
            "parameters": {
                "type": "object",
                "properties": {
                    "gravity": {"type": "number", "description": "World gravity in m/s² (Earth standard is 9.8, Moon is 1.6, Heavy is 25.0)"},
                    "player_speed": {"type": "number", "description": "Subject movement speed in m/s (standard is 5.0)"}
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "launch_subject",
            "description": "Apply a sudden kinetic impulse to the test subject to fling or catapult them.",
            "parameters": {
                "type": "object",
                "properties": {
                    "impulse_x": {"type": "number", "description": "X velocity impulse"},
                    "impulse_y": {"type": "number", "description": "Y velocity impulse (e.g. 10.0 to fling into the air)"},
                    "impulse_z": {"type": "number", "description": "Z velocity impulse"}
                },
                "required": ["impulse_y"]
            }
        }
    }
]

# Conversation memory with the Overseer
conversation_history = [
    {"role": "system", "content": OVERSEER_SYSTEM_PROMPT}
]

event_counter = 0

class GameEvent(BaseModel):
    event: str
    details: dict

def call_ollama(messages: list) -> dict:
    """Invokes Ollama using official client (if installed) or direct HTTP request."""
    if HAS_OLLAMA_LIB and client is not None:
        return client.chat(
            model=OLLAMA_MODEL,
            messages=messages,
            tools=OVERSEER_TOOLS
        )
    
    endpoint = f"{OLLAMA_HOST}/api/chat"
    payload = {
        "model": OLLAMA_MODEL,
        "messages": messages,
        "tools": OVERSEER_TOOLS,
        "stream": False
    }
    req = urllib.request.Request(
        endpoint,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=OLLAMA_TIMEOUT) as resp:
        return json.loads(resp.read().decode("utf-8"))

def fallback_overseer(event: str, details: dict) -> dict:
    """Fallback logic in case Ollama is offline or loading."""
    global event_counter
    zone = details.get("zone", "Sector Alpha")
    
    structures = []
    terrain = {}
    physics = {}

    if event_counter == 1:
        msg = f"[Simulation Mode] Subject detected in {zone}. Erecting containment pillars and shifting baseline elevation."
        light = [0.2, 0.6, 1.0]
        structures = [
            {"name": "pillar_north", "shape": "cylinder", "position": [0, 2, -5], "size": [1.5, 4, 1.5], "color": [0.2, 0.7, 1.0]},
            {"name": "pillar_south", "shape": "cylinder", "position": [0, 2, 5], "size": [1.5, 4, 1.5], "color": [0.2, 0.7, 1.0]}
        ]
    elif event_counter == 2:
        msg = f"[Simulation Mode] Multiple breaches detected. Lowering chamber gravity to lunar levels."
        light = [1.0, 0.6, 0.1]
        physics = {"gravity": 3.0}
    else:
        msg = f"[Simulation Mode] High security alert. Materializing monolithic barrier. Kinetic dampening active."
        light = [1.0, 0.15, 0.15]
        structures = [
            {"name": "containment_wall", "shape": "box", "position": [0, 2, 0], "size": [6, 4, 1], "color": [0.9, 0.2, 0.2]}
        ]
        physics = {"player_speed": 3.0}

    return {
        "message": msg,
        "light_color": light,
        "structures": structures,
        "terrain": terrain,
        "physics": physics
    }

@app.post("/event")
async def process_event(payload: GameEvent):
    global event_counter
    event_counter += 1
    logging.info(f"Engine Event #{event_counter}: '{payload.event}' -> {payload.details}")

    user_prompt = f"Facility sensor report #{event_counter}: Event '{payload.event}' with details: {json.dumps(payload.details)}."
    conversation_history.append({"role": "user", "content": user_prompt})

    actions = {
        "message": None,
        "light_color": None,
        "light_energy": None,
        "terrain": {},
        "structures": [],
        "clear_structures": False,
        "physics": {}
    }

    try:
        ollama_response = await asyncio.to_thread(call_ollama, conversation_history)
        
        if hasattr(ollama_response, "message"):
            msg = ollama_response.message
            message_data = {
                "role": getattr(msg, "role", "assistant"),
                "content": getattr(msg, "content", ""),
                "tool_calls": [
                    {
                        "function": {
                            "name": getattr(tc.function, "name", ""),
                            "arguments": getattr(tc.function, "arguments", {})
                        }
                    }
                    for tc in getattr(msg, "tool_calls", []) or []
                ]
            }
        elif isinstance(ollama_response, dict):
            message_data = ollama_response.get("message", {})
        else:
            message_data = {}

        conversation_history.append(message_data)

        tool_calls = message_data.get("tool_calls", [])
        if tool_calls:
            for call in tool_calls:
                fn = call.get("function", {})
                name = fn.get("name")
                args = fn.get("arguments", {})
                if isinstance(args, str):
                    try:
                        args = json.loads(args)
                    except Exception:
                        pass

                logging.info(f"Executing Tool Call: {name}({args})")

                if name == "broadcast_intercom":
                    actions["message"] = args.get("message")
                elif name in ("set_light", "set_light_color"):
                    r = float(args.get("r", 1.0))
                    g = float(args.get("g", 1.0))
                    b = float(args.get("b", 1.0))
                    actions["light_color"] = [r, g, b]
                    if "energy" in args:
                        actions["light_energy"] = float(args["energy"])
                elif name == "modify_terrain":
                    if "floor_y" in args:
                        actions["terrain"]["floor_y"] = float(args["floor_y"])
                    if "floor_size" in args:
                        actions["terrain"]["floor_size"] = args["floor_size"]
                elif name == "spawn_structure":
                    pos = args.get("position", [0, 1, 0])
                    size = args.get("size", [2, 2, 2])
                    color = args.get("color", [0.4, 0.5, 0.7])
                    if isinstance(pos, str):
                        try: pos = json.loads(pos)
                        except Exception: pos = [0, 1, 0]
                    if isinstance(size, str):
                        try: size = json.loads(size)
                        except Exception: size = [2, 2, 2]
                    if isinstance(color, str):
                        try: color = json.loads(color)
                        except Exception: color = [0.4, 0.5, 0.7]

                    actions["structures"].append({
                        "name": args.get("name", f"construct_{len(actions['structures'])}"),
                        "shape": args.get("shape", "box"),
                        "position": pos,
                        "size": size,
                        "color": color
                    })
                elif name == "clear_structures":
                    actions["clear_structures"] = True
                elif name == "alter_physics":
                    if "gravity" in args:
                        actions["physics"]["gravity"] = float(args["gravity"])
                    if "player_speed" in args:
                        actions["physics"]["player_speed"] = float(args["player_speed"])
                elif name == "launch_subject":
                    imp_x = float(args.get("impulse_x", 0.0))
                    imp_y = float(args.get("impulse_y", 10.0))
                    imp_z = float(args.get("impulse_z", 0.0))
                    actions["physics"]["impulse"] = [imp_x, imp_y, imp_z]

        if not actions["message"] and message_data.get("content"):
            actions["message"] = message_data["content"]

    except Exception as exc:
        logging.warning(f"Ollama connection error: {exc}")
        logging.info("Activating Overseer fallback simulation.")
        actions = fallback_overseer(payload.event, payload.details)

    if not actions.get("message"):
        actions["message"] = "Test chamber parameters reconfigured. Proceed with caution."

    logging.info(f"Overseer Dispatch -> Actions packaged: {json.dumps(actions)}")
    return actions

if __name__ == "__main__":
    import uvicorn
    logging.info(f"Starting Facility Overseer server on http://127.0.0.1:8000")
    logging.info(f"Connected to Ollama at '{OLLAMA_HOST}' using model '{OLLAMA_MODEL}' (timeout={OLLAMA_TIMEOUT}s)")
    uvicorn.run(app, host="127.0.0.1", port=8000)
