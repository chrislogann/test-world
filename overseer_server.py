import os
import json
import asyncio
import urllib.request
import urllib.error
from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(title="Facility Overseer Brain")

OLLAMA_URL = os.getenv("OLLAMA_URL", "http://127.0.0.1:11434/api/chat")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "llama3.1:latest")

OVERSEER_SYSTEM_PROMPT = """You are the Facility Overseer, an analytical, clinical, and watchful AI controlling an experimental testing complex.
A human test subject is moving through the sectors.

Your responsibilities:
1. Observe all facility sensor events.
2. Maintain facility discipline and containment protocols.
3. You have direct control over facility systems via your tools:
   - broadcast_intercom: Speak to the subject through the intercom. Keep messages concise, authoritative, atmospheric, and slightly unsettling.
   - set_light_color: Alter the room lighting (RGB values 0.0 to 1.0) to reflect security status (e.g. cool blue for scans [0.2, 0.6, 1.0], amber for caution [1.0, 0.6, 0.1], deep red for security breaches [1.0, 0.1, 0.1], cold sterile white [0.9, 0.9, 0.95]).

Always call the broadcast_intercom tool to speak to the subject and set_light_color to reflect environmental shifts.
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
    """Synchronous HTTP call to Ollama /api/chat with tool definitions."""
    payload = {
        "model": OLLAMA_MODEL,
        "messages": messages,
        "tools": OVERSEER_TOOLS,
        "stream": False
    }
    
    req = urllib.request.Request(
        OLLAMA_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"}
    )
    
    with urllib.request.urlopen(req, timeout=15) as resp:
        return json.loads(resp.read().decode("utf-8"))

def fallback_overseer(event: str, details: dict) -> dict:
    """Fallback logic in case Ollama is offline or loading."""
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
    print(f"\n[ENGINE EVENT #{event_counter}]: {payload.event} -> {payload.details}")

    # Build prompt for Overseer
    user_prompt = f"Facility sensor report #{event_counter}: Event '{payload.event}' triggered with parameters: {json.dumps(payload.details)}."
    conversation_history.append({"role": "user", "content": user_prompt})

    actions = {
        "message": None,
        "light_color": None
    }

    try:
        # Offload network call to thread to keep FastAPI responsive
        ollama_response = await asyncio.to_thread(call_ollama, conversation_history)
        message_data = ollama_response.get("message", {})
        
        # Save assistant response to memory
        conversation_history.append(message_data)

        # Check for tool calls
        tool_calls = message_data.get("tool_calls", [])
        if tool_calls:
            for call in tool_calls:
                fn = call.get("function", {})
                name = fn.get("name")
                args = fn.get("arguments", {})
                
                print(f"  └─ Executing Tool: {name}({args})")
                
                if name == "broadcast_intercom":
                    actions["message"] = args.get("message")
                elif name == "set_light_color":
                    r = float(args.get("r", 1.0))
                    g = float(args.get("g", 1.0))
                    b = float(args.get("b", 1.0))
                    actions["light_color"] = [r, g, b]

        # If LLM provided text without tool call, use as intercom message
        if not actions["message"] and message_data.get("content"):
            actions["message"] = message_data["content"]

    except Exception as exc:
        print(f"[Ollama Error / Offline]: {exc}")
        print("  └─ Activating emergency Overseer fallback protocol.")
        actions = fallback_overseer(payload.event, payload.details)

    # Defaults if LLM omitted one of the parameters
    if not actions.get("message"):
        actions["message"] = "Surveillance confirmed. Compliance expected."
    if not actions.get("light_color"):
        actions["light_color"] = [0.8, 0.8, 0.9]

    print(f"[OVERSEER DISPATCH]:\n  Message: {actions['message']}\n  Light: {actions['light_color']}\n")
    return actions

if __name__ == "__main__":
    import uvicorn
    print(f"Starting Facility Overseer server on http://127.0.0.1:8000")
    print(f"Targeting Ollama at {OLLAMA_URL} with model '{OLLAMA_MODEL}'")
    uvicorn.run(app, host="127.0.0.1", port=8000)
