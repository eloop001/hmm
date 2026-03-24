#!/usr/bin/env python3

from google import genai
from google.genai import types
import os

class Config:
    CURRENT_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
    MODEL_NAME_FLASH = "gemini-3.1-flash-lite-preview"
    TEMPERATURE = 0.05
    THINKING_LEVEL = "MINIMAL"  # Options: LOW, HIGH

model_name = Config.MODEL_NAME_FLASH

def call_gemini(query: str, sysinfo: str) -> str:
    
    api_key = os.getenv("GOOGLE_API_KEY")
    if not api_key:
        env_file = os.path.expanduser("~/.config/hmm/.env")
        if os.path.exists(env_file):
            try:
                with open(env_file, "r") as f:
                    for line in f:
                        line = line.strip()
                        if line.startswith("GOOGLE_API_KEY="):
                            api_key = line.split("=", 1)[1].strip('"\'')
                            os.environ["GOOGLE_API_KEY"] = api_key
                            break
            except Exception:
                pass
    
    if not api_key:
        return "#Error: No API key found. Set GOOGLE_API_KEY or add it to ~/.config/hmm/.env"

    prompt_file = os.path.join(Config.CURRENT_SCRIPT_DIR, "oshelp.md")
    with open(prompt_file, "r") as f:
        prompt = f.read()
    
    prompt = prompt.replace("$$query$$", query)
    prompt = prompt.replace("$$sysinfo$$", sysinfo)
    
    try:
        

        # 1. Base Configuration
        config_args = {
            "temperature": Config.TEMPERATURE,
            "top_p": 0.95,
            "top_k": 40,
            "max_output_tokens": 65000,
            "response_mime_type": "text/plain",
            "system_instruction": [
                
                types.Part(text='Follow the EXACT instructions. This is a technical critical task!')
            ]
        }


        # Gemini 3 uses 'thinking_level' (LOW, HIGH)
        config_args["thinking_config"] = types.ThinkingConfig(
            include_thoughts=False,
            thinking_level=Config.THINKING_LEVEL
        )


        generate_content_config = types.GenerateContentConfig(**config_args)

        # 3. Create Content Object
        contents = [
            types.Content(
                role="user", 
                parts=[types.Part(text=prompt)]
            )
        ]

        # 4. Initialize Client
        google_client = genai.Client(api_key=api_key)
        
        # 5. Generate Content
        response = google_client.models.generate_content(
            model=model_name,
            contents=contents,
            config=generate_content_config
        )

        # 6. Safe Result Extraction
        result = response.text.strip() if response.text else "#AI Call succeeded but no answer returned"
        
        return result

    except Exception as e:
        print(f"Error during generation or execution: {str(e)}")
        return f"#Error: {e}"
        
# Test the function with a sample query
#query = "my computer is listening on port 42235. What is that port used for?"
#print( call_gpt(query) )