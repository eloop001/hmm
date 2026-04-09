#!/usr/bin/env python3

import sys
import os
import platform
from gemini import call_gemini

# Ensure the script can find gemini.py in the same directory
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


def main(debug_input: str = None):
    prompt = ""

    if debug_input:
        prompt = debug_input.strip()
    else:
    
        # 1. Read from standard input if data is being piped (e.g., cat error.log | hmm)
        if not sys.stdin.isatty():
            prompt = sys.stdin.read().strip()
            
    # 2. Add any command-line arguments passed
    if len(sys.argv) > 1:
        arg_prompt = " ".join(sys.argv[1:]).strip()
        if prompt:
            # Combine args and piped input (e.g., `cat log | hmm "fix this error"`)
            prompt = f"{arg_prompt}\n\nContext:\n{prompt}"
        else:
            prompt = arg_prompt
            
    # 3. Interactive fallback: No args and no pipe
    if not prompt:
        # Print to stderr so it shows up even if hmm is capturing stdout for the -x flag
        print("Hmm... No question provided.", file=sys.stderr)
        print("Type your question and/or paste your error messages or other information below", file=sys.stderr)
        print("that hmm can use to help you.", file=sys.stderr)
        print("", file=sys.stderr)
        print("(Press Ctrl+D when finished to submit)\n", file=sys.stderr)
        print("---", file=sys.stderr)
        try:
            prompt = sys.stdin.read().strip()
        except KeyboardInterrupt:
            sys.exit(0)

    if not prompt:
        sys.exit(0)
        
    try:
        # Pass the plain text and OS info to your Gemini library
        result = call_gemini(prompt, get_os_info())
        
        # Force the output into a single line to keep the console clean
        single_line_result = str(result).strip()
        
        # Output directly to console
        print(single_line_result)
        
    except Exception as e:
        print(f"Hmm... Error: {e}")

if __name__ == "__main__":

    main()
    