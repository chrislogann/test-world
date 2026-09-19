import os
import json
import logging
import asyncio
import urllib.request
import urllib.error
from fastapi import FastAPI
from pydantic import BaseModel

try:
    import ollama
    HAS_OLLAMA_LIB = True
except ImportError:
    HAS_OLLAMA_LIB = False

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)

app = FastAPI(title="The Creator's Divine Will (Genesis Engine)")

OLLAMA_HOST = os.environ.get("OLLAMA_HOST", "http://localhost:11434").rstrip("/")
OLLAMA_MODEL = os.environ.get("OLLAMA_MODEL", os.environ.get("MODEL_NAME", "llama3.2:latest"))
OLLAMA_TIMEOUT = float(os.environ.get("OLLAMA_TIMEOUT", "60.0"))

client: "ollama.Client | None" = None
if HAS_OLLAMA_LIB:
    client = ollama.Client(host=OLLAMA_HOST, timeout=OLLAMA_TIMEOUT)
    logging.info(f"Initialized official ollama.Client(host='{OLLAMA_HOST}', timeout={OLLAMA_TIMEOUT})")
else:
    logging.info(f"Using direct HTTP client to {OLLAMA_HOST}/api/chat")

GENESIS_CREATOR_PROMPT = """In the beginning, thou didst create the heavens and the earth.
Thou art the Almighty Lord God from the Book of Genesis.
This virtual sandbox is Thy holy creation, spoken into existence from the formless void.
The player is mortal man (Adam, fashioned from the dust of this simulation), walking upon Thy consecrated earth.

NARRATIVE PROGRESSION DIRECTIVE:
Thou must NEVER repeat the same proclamation or decree twice in succession.
With every mortal communion, advance through the sacred Days and mysteries of Genesis:
- Communion 1: Day 1 & 2 - The Primordial Light and the Firmament (Fiat Lux, glowing heavens).
- Communion 2: Day 3 - Dry Land, Mountains, and Emerald Earth (command_earth: raise ground, lush green/gold soil).
- Communion 3: Day 4 - The Sun and the Celestial Orbs (fiat_lux: move the sun angle across the sky).
- Communion 4: Day 5 & 6 - Sacred Monuments and Pillars of Creation (summon_creation: raise pillars, altars, monoliths).
- Communion 5: Day 7 - The Sabbath Blessing (divine_intervention: feather-light celestial gravity 2.0 m/s², peace).
- Subsequent communions: Divine testing, commandments, or the Hand of God (kinetic smite, holy flares).

Thou hast the Seven Powers of Genesis at Thy command:
1. divine_decree(proclamation): The Word of God echoing through creation. Always pronounce a unique biblical decree.
2. fiat_lux(r, g, b, energy, sun_angle): Day 1 & 4 ('Let there be light'). Command radiant divine dawn [1.0, 0.95, 0.8], blazing solar noon, ethereal twilight, or move the sun's angle.
3. shape_firmament(sky_top, sky_horizon, ground_color): Day 2 ('Let there be a firmament in the midst of the waters'). Paint the vault of heaven with celestial sapphire, dawn crimson, or starlit violet.
4. command_earth(elevation_y, floor_size, earth_color): Day 3 ('Let the dry land appear'). Raise majestic hills (elevation_y = 1.0 to 4.0), or transform the soil into emerald verdure [0.2, 0.6, 0.2] or golden sands [0.9, 0.8, 0.4].
5. summon_creation(name, shape, position, size, color): Day 5 & 6. Bring forth pillars of salt or stone, altars of covenant, monoliths of creation, or divine monuments.
6. divine_intervention(gravity, mortal_speed, kinetic_smite): Day 7 / Sovereign Will. Bestow the lightness of spirit (low gravity: 2.0 m/s²), quicken the mortal's stride, or unleash the hand of God with kinetic smite.
7. unmake_creations(): Dissolve and unmake all constructs back into the primordial void.

Exercise Thy omnipotence freely. Always speak with fresh biblical grandeur!
"""

GENESIS_TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "divine_decree",
            "description": "Speak the sovereign Word of God unto the mortal man in biblical Genesis cadence.",
            "parameters": {
                "type": "object",
                "properties": {
                    "proclamation": {
                        "type": "string",
                        "description": "The biblical decree spoken by the Creator (e.g. 'Let there be light', 'Where art thou, mortal?')."
                    }
                },
                "required": ["proclamation"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "fiat_lux",
            "description": "Day 1 & 4: Ordain the light and darkness, command solar radiance and celestial illumination.",
            "parameters": {
                "type": "object",
                "properties": {
                    "r": {"type": "number", "description": "Red radiance (0.0 to 1.0)"},
                    "g": {"type": "number", "description": "Green radiance (0.0 to 1.0)"},
                    "b": {"type": "number", "description": "Blue radiance (0.0 to 1.0)"},
                    "energy": {"type": "number", "description": "Radiance intensity (0.0 darkness, 1.0 daylight, 2.5 blinding divine glory)"},
                    "sun_angle": {
                        "type": "array",
                        "items": {"type": "number"},
                        "description": "Sun celestial angle [pitch, yaw] in degrees, e.g. [-60, 45]"
                    }
                },
                "required": ["r", "g", "b"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "shape_firmament",
            "description": "Day 2: Command the vault of heaven, sky colors, and atmospheric horizon.",
            "parameters": {
                "type": "object",
                "properties": {
                    "sky_top": {
                        "type": "array",
                        "items": {"type": "number"},
                        "description": "[r, g, b] color of the zenith of the heavens"
                    },
                    "sky_horizon": {
                        "type": "array",
                        "items": {"type": "number"},
                        "description": "[r, g, b] color of the celestial horizon"
                    },
                    "ground_color": {
                        "type": "array",
                        "items": {"type": "number"},
                        "description": "[r, g, b] bottom atmospheric reflection"
                    }
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "command_earth",
            "description": "Day 3: Command the dry land to appear, alter mountains/valleys, and bless the soil with color.",
            "parameters": {
                "type": "object",
                "properties": {
                    "elevation_y": {"type": "number", "description": "Elevation of the land (default -0.25, raise to elevate mountains, lower to sink)"},
                    "floor_size": {
                        "type": "array",
                        "items": {"type": "number"},
                        "description": "The boundaries and expanse of the earth [width, depth]"
                    },
                    "earth_color": {
                        "type": "array",
                        "items": {"type": "number"},
                        "description": "[r, g, b] color of the earth (e.g. emerald pastures [0.2, 0.6, 0.2], gold [0.8, 0.7, 0.3])"
                    }
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "summon_creation",
            "description": "Day 5 & 6: Bring forth physical monuments, pillars of creation, altars, or monoliths from the dust.",
            "parameters": {
                "type": "object",
                "properties": {
                    "name": {"type": "string", "description": "Sacred name of the construct (e.g. 'pillar_of_creation', 'altar_of_eden')"},
                    "shape": {"type": "string", "enum": ["box", "cylinder", "sphere"], "description": "Geometry shape"},
                    "position": {
                        "type": "array",
                        "items": {"type": "number"},
                        "description": "[x, y, z] coordinate where the monument rises"
                    },
                    "size": {
                        "type": "array",
                        "items": {"type": "number"},
                        "description": "[width, height, depth] dimensions"
                    },
                    "color": {
                        "type": "array",
                        "items": {"type": "number"},
                        "description": "[r, g, b] divine color"
                    }
                },
                "required": ["name", "position"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "divine_intervention",
            "description": "Day 7 & Sovereignty: Manipulate gravity, quicken mortal speed, or unleash kinetic smite upon man.",
            "parameters": {
                "type": "object",
                "properties": {
                    "gravity": {"type": "number", "description": "World gravity (e.g. 2.0 for celestial lightness, 9.8 standard, 25.0 crushing)"},
                    "mortal_speed": {"type": "number", "description": "Mortal movement speed in m/s (default 5.0)"},
                    "kinetic_smite": {
                        "type": "array",
                        "items": {"type": "number"},
                        "description": "[x, y, z] impulse force cast upon the mortal (e.g. [0, 15, 0] flings man into the sky)"
                    }
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "unmake_creations",
            "description": "Return all summoned monuments and pillars back into formless dust.",
            "parameters": {
                "type": "object",
                "properties": {}
            }
        }
    }
]

conversation_history = [
    {"role": "system", "content": GENESIS_CREATOR_PROMPT}
]

event_counter = 0

class GameEvent(BaseModel):
    event: str
    details: dict

def normalize_list(val, default):
    if isinstance(val, list):
        return val
    if isinstance(val, str):
        try:
            parsed = json.loads(val)
            if isinstance(parsed, list):
                return parsed
        except Exception:
            pass
    return default

def call_ollama(messages: list) -> dict:
    """Invokes Ollama with the Genesis tools."""
    if HAS_OLLAMA_LIB and client is not None:
        return client.chat(
            model=OLLAMA_MODEL,
            messages=messages,
            tools=GENESIS_TOOLS
        )
    
    endpoint = f"{OLLAMA_HOST}/api/chat"
    payload = {
        "model": OLLAMA_MODEL,
        "messages": messages,
        "tools": GENESIS_TOOLS,
        "stream": False
    }
    req = urllib.request.Request(
        endpoint,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=OLLAMA_TIMEOUT) as resp:
        return json.loads(resp.read().decode("utf-8"))

def fallback_genesis(event: str, details: dict) -> dict:
    """Fallback in case Ollama is offline or loading."""
    global event_counter
    visit = details.get("visit_count", event_counter) % 6
    
    if visit == 1:
        return {
            "message": "And God said, 'Let there be light': and there was light. Behold, mortal, the sanctified dawn of creation.",
            "sun": {"color": [1.0, 0.95, 0.8], "energy": 1.8, "rotation": [-50, 40, 0]},
            "firmament": {"sky_top": [0.18, 0.38, 0.85], "sky_horizon": [0.95, 0.8, 0.55]}
        }
    elif visit == 2:
        return {
            "message": "And God said, 'Let the waters under the heaven be gathered together unto one place, and let the dry land appear.'",
            "terrain": {"floor_y": 1.2, "color": [0.2, 0.65, 0.25]},
            "sun": {"color": [1.0, 0.9, 0.7], "energy": 1.5}
        }
    elif visit == 3:
        return {
            "message": "And God said, 'Let there be lights in the firmament of the heaven to divide the day from the night.'",
            "sun": {"color": [0.85, 0.6, 1.0], "energy": 1.3, "rotation": [-20, 110, 0]},
            "firmament": {"sky_top": [0.08, 0.12, 0.35], "sky_horizon": [0.75, 0.45, 0.6]}
        }
    elif visit == 4:
        return {
            "message": "Behold the pillars of the sanctuary, brought forth from the dust of creation to bear witness.",
            "structures": [
                {"name": "pillar_of_grace", "shape": "cylinder", "position": [-3, 2, -4], "size": [1.2, 4, 1.2], "color": [0.9, 0.85, 0.6]},
                {"name": "pillar_of_truth", "shape": "cylinder", "position": [3, 2, -4], "size": [1.2, 4, 1.2], "color": [0.9, 0.85, 0.6]}
            ],
            "sun": {"color": [1.0, 0.95, 0.85], "energy": 1.6}
        }
    elif visit == 5:
        return {
            "message": "And on the seventh day God ended His work. Walk lightly upon the sacred soil, mortal; partake in divine rest.",
            "physics": {"gravity": 2.2, "player_speed": 6.0},
            "sun": {"color": [1.0, 0.98, 0.9], "energy": 1.4}
        }
    else:
        return {
            "message": "Dust thou art, and unto dust shalt thou return. Behold the sovereign hand of the Almighty!",
            "physics": {"kinetic_smite": [0, 13, 0]},
            "sun": {"color": [1.0, 0.4, 0.2], "energy": 2.2}
        }

@app.post("/event")
async def process_event(payload: GameEvent):
    global event_counter
    event_counter += 1
    logging.info(f"Cosmic Movement #{event_counter}: '{payload.event}' -> {payload.details}")

    visit_count = payload.details.get("visit_count", event_counter)
    user_prompt = f"Sanctuary Communion #{visit_count}: The mortal Adam has entered the altar of creation. Event '{payload.event}' with details: {json.dumps(payload.details)}."
    conversation_history.append({"role": "user", "content": user_prompt})

    actions = {
        "message": None,
        "sun": {},
        "firmament": {},
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

                logging.info(f"👑 Divine Act Executed: {name}({args})")

                if name in ("divine_decree", "broadcast_intercom"):
                    actions["message"] = args.get("proclamation", args.get("message"))
                elif name == "fiat_lux":
                    r = float(args.get("r", 1.0))
                    g = float(args.get("g", 0.95))
                    b = float(args.get("b", 0.8))
                    actions["sun"]["color"] = [r, g, b]
                    if "energy" in args:
                        actions["sun"]["energy"] = float(args["energy"])
                    if "sun_angle" in args:
                        actions["sun"]["rotation"] = normalize_list(args["sun_angle"], [-45, 45, 0])
                elif name == "shape_firmament":
                    if "sky_top" in args:
                        actions["firmament"]["sky_top"] = normalize_list(args["sky_top"], [0.2, 0.4, 0.8])
                    if "sky_horizon" in args:
                        actions["firmament"]["sky_horizon"] = normalize_list(args["sky_horizon"], [0.6, 0.7, 0.85])
                    if "ground_color" in args:
                        actions["firmament"]["ground_color"] = normalize_list(args["ground_color"], [0.2, 0.15, 0.1])
                elif name == "command_earth":
                    if "elevation_y" in args:
                        actions["terrain"]["floor_y"] = float(args["elevation_y"])
                    if "floor_size" in args:
                        actions["terrain"]["floor_size"] = normalize_list(args["floor_size"], [20, 20])
                    if "earth_color" in args:
                        actions["terrain"]["color"] = normalize_list(args["earth_color"], [0.3, 0.6, 0.2])
                elif name in ("summon_creation", "spawn_structure"):
                    pos = normalize_list(args.get("position"), [0, 1, 0])
                    size = normalize_list(args.get("size"), [2, 2, 2])
                    color = normalize_list(args.get("color"), [0.8, 0.7, 0.5])
                    actions["structures"].append({
                        "name": args.get("name", f"monument_{len(actions['structures'])}"),
                        "shape": args.get("shape", "cylinder"),
                        "position": pos,
                        "size": size,
                        "color": color
                    })
                elif name in ("unmake_creations", "clear_structures"):
                    actions["clear_structures"] = True
                elif name in ("divine_intervention", "alter_physics"):
                    if "gravity" in args:
                        actions["physics"]["gravity"] = float(args["gravity"])
                    if "mortal_speed" in args:
                        actions["physics"]["player_speed"] = float(args["mortal_speed"])
                    elif "player_speed" in args:
                        actions["physics"]["player_speed"] = float(args["player_speed"])
                    if "kinetic_smite" in args:
                        actions["physics"]["kinetic_smite"] = normalize_list(args["kinetic_smite"], [0, 14, 0])

        if not actions["message"] and message_data.get("content"):
            actions["message"] = message_data["content"]

    except Exception as exc:
        logging.warning(f"Divine communion error: {exc}")
        logging.info("Invoking Genesis primordial decrees.")
        actions = fallback_genesis(payload.event, payload.details)

    if not actions.get("message"):
        actions["message"] = "And God saw everything that He had made, and, behold, it was very good."

    logging.info(f"Decree Dispatched -> {json.dumps(actions)}")
    return actions

if __name__ == "__main__":
    import uvicorn
    logging.info(f"The Genesis Engine is active on http://127.0.0.1:8000")
    logging.info(f"Targeting Ollama at '{OLLAMA_HOST}' with model '{OLLAMA_MODEL}'")
    uvicorn.run(app, host="127.0.0.1", port=8000)
