#!/usr/bin/env python3

import sys
import os
import platform
from gpt import call_gpt 

# Ensure the script can find gpt.py in the same directory
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

def get_os_info() -> str:
    """Extract OS type, version, architecture, and shell for concise environment context."""
    system = platform.system()
    arch = platform.machine()
    shell = os.environ.get("SHELL", "unknown")
    
    hw_type = "Apple" if system == "Darwin" else "PC"
    
    if system == "Linux":
        try:
            with open("/etc/os-release") as f:
                os_data = dict(line.strip().split("=", 1) for line in f if "=" in line)
            name = os_data.get("PRETTY_NAME", os_data.get("NAME", '"Linux"')).strip('"\'')
            base = f"{hw_type} | Linux / {name}"
        except OSError:
            # Fallback when the OS release file is unavailable
            base = f"{hw_type} | Linux / {platform.release()}"
            
    elif system == "Darwin":
        base = f"{hw_type} | Mac / macOS {platform.mac_ver()[0]}"
    else:
        base = f"{hw_type} | {system} / {platform.release()}"
        
    return f"{base} | Arch: {arch} | Shell: {shell}"


def main():
    # Check if a prompt was provided
    if len(sys.argv) < 2:
        print("Hmm...Error: No prompt provided.")
        sys.exit(1)
    
    # Capture the prompt (combining arguments just in case quotes are omitted)
    prompt = " ".join(sys.argv[1:])
    
    try:
        # Pass the plain text and OS info to your GPT library
        result = call_gpt(prompt, get_os_info())
        
        # Force the output into a single line to keep the console clean
        single_line_result = str(result).replace('\n', ' ').replace('\r', '').strip()
        
        # Output directly to console
        print(single_line_result)
        
    except Exception as e:
        print(f"Hmm... Error: {e}")

if __name__ == "__main__":
    main()

