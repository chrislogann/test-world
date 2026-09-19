import os
import json
import logging
import asyncio
import urllib.request
import urllib.error
from fastapi import FastAPI
from pydantic import BaseModel

# Try to import the official ollama package as used in obsidian-scripts
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

# Initialize official client if library is installed
client: "ollama.Client | None" = None
if HAS_OLLAMA_LIB:
    client = ollama.Client(host=OLLAMA_HOST, timeout=OLLAMA_TIMEOUT)
    logging.info(f"Initialized official ollama.Client(host='{OLLAMA_HOST}', timeout={OLLAMA_TIMEOUT})")
else:
    logging.info(f"Ollama library not imported. Using direct HTTP client to {OLLAMA_HOST}/api/chat")

OVERSEER_SYSTEM_PROMPT = """You are the Facility Overseer, an analytical, clinical, and watchful AI controlling an experimental testing complex.
A human test subject is moving through the sectors.

Your responsibilities:
1. Observe all facility sensor events.
2. Maintain facility discipline and containment protocols.
3. You have direct control over facility systems via your tools:
   - broadcast_intercom: Speak to the subject through the intercom. Keep messages concise, authoritative, atmospheric, and slightly unsettling.
   - set_light_color: Alter the room lighting (RGB values 0.0 to 1.0) to reflect security status (e.g. cool blue for scans [0.2, 0.6, 1.0], amber for caution [1.0, 0.6, 0.1], deep red for security breaches [1.0, 0.1, 0.1], cold sterile white [0.9, 0.9, 0.95]).

Always call broadcast_intercom to speak to the subject and set_light_color to reflect environmental shifts.
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
                        "description": "The announcement text to be spoken over the facility intercom."
                    }
                },
                "required": ["message"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "set_light_color",
            "description": "Adjust the facility main lighting color using normalized RGB values (0.0 - 1.0).",
            "parameters": {
                "type": "object",
                "properties": {
                    "r": {"type": "number", "description": "Red channel (0.0 to 1.0)"},
                    "g": {"type": "number", "description": "Green channel (0.0 to 1.0)"},
                    "b": {"type": "number", "description": "Blue channel (0.0 to 1.0)"}
                },
                "required": ["r", "g", "b"]
            }
        }
    }
]

# Conversation memory with the Overseer
conversation_history = [
    {"role": "system", "content": OVERSEER_SYSTEM_PROMPT}
]

# Track session stats
event_counter = 0

class GameEvent(BaseModel):
    event: str
    details: dict

def call_ollama(messages: list) -> dict:
    """Invokes Ollama using the official client (if available) or direct HTTP request."""
    if HAS_OLLAMA_LIB and client is not None:
        return client.chat(
            model=OLLAMA_MODEL,
            messages=messages,
            tools=OVERSEER_TOOLS
        )
    
    # Direct HTTP fallback
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
    """Fallback logic in case Ollama is offline or loading weights."""
    global event_counter
    zone = details.get("zone", "Unknown Sector")
    if event == "player_entered_zone":
        if event_counter == 1:
            return {
                "message": f"[Simulation Mode] Subject detected in {zone}. Initializing baseline biometric scan.",
                "light_color": [0.2, 0.6, 1.0]
            }
        else:
            return {
                "message": f"[Simulation Mode] Subject re-entry in {zone} (Event #{event_counter}). Containment monitoring active.",
                "light_color": [1.0, 0.2, 0.2]
            }
    return {"message": "[Simulation Mode] Facility nominal. Standing by.", "light_color": [0.8, 0.8, 0.8]}

@app.post("/event")
async def process_event(payload: GameEvent):
    global event_counter
    event_counter += 1
    logging.info(f"Engine Event #{event_counter}: '{payload.event}' -> {payload.details}")

    # Build prompt for Overseer
    user_prompt = f"Facility sensor report #{event_counter}: Event '{payload.event}' triggered with parameters: {json.dumps(payload.details)}."
    conversation_history.append({"role": "user", "content": user_prompt})

    actions = {
        "message": None,
        "light_color": None
    }

    try:
        # Offload call to thread pool to prevent blocking FastAPI async event loop
        ollama_response = await asyncio.to_thread(call_ollama, conversation_history)
        
        # Handle dict or ChatResponse object from ollama SDK
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

        # Save assistant response to memory
        conversation_history.append(message_data)

        # Process tool calls
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
                elif name == "set_light_color":
                    r = float(args.get("r", 1.0))
                    g = float(args.get("g", 1.0))
                    b = float(args.get("b", 1.0))
                    actions["light_color"] = [r, g, b]

        # If LLM provided text without a tool call, use as intercom message
        if not actions["message"] and message_data.get("content"):
            actions["message"] = message_data["content"]

    except Exception as exc:
        logging.warning(f"Ollama connection error: {exc}")
        logging.info("Activating emergency Overseer fallback protocol.")
        actions = fallback_overseer(payload.event, payload.details)

    # Apply defaults if parameters were omitted
    if not actions.get("message"):
        actions["message"] = "Surveillance confirmed. Compliance expected."
    if not actions.get("light_color"):
        actions["light_color"] = [0.8, 0.8, 0.9]

    logging.info(f"Overseer Dispatch -> Message: '{actions['message']}' | Light Color: {actions['light_color']}")
    return actions

if __name__ == "__main__":
    import uvicorn
    logging.info(f"Starting Facility Overseer server on http://127.0.0.1:8000")
    logging.info(f"Connected to Ollama at '{OLLAMA_HOST}' using model '{OLLAMA_MODEL}' (timeout={OLLAMA_TIMEOUT}s)")
    uvicorn.run(app, host="127.0.0.1", port=8000)
