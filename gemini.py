#!/usr/bin/env python3

import os
import sys

from google import genai
from google.genai import types

ENV_FILE = os.path.expanduser("~/.config/hmm/.env")


class Config:
    CURRENT_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
    # Stable (non-preview) models, tried in order. If a model has been
    # retired or is unavailable for the current API key, the next one
    # in the list is tried automatically.
    MODEL_CANDIDATES = [
        "gemini-2.5-flash-lite",
        "gemini-2.5-flash",
        "gemini-flash-latest",
    ]
    TEMPERATURE = 0.05
    MAX_OUTPUT_TOKENS = 8192


# ── API key handling ─────────────────────────────────────────────────────────

def read_key_from_env_file():
    try:
        with open(ENV_FILE, "r") as f:
            for line in f:
                line = line.strip()
                if line.startswith("GOOGLE_API_KEY="):
                    return line.split("=", 1)[1].strip("\"'") or None
    except OSError:
        pass
    return None


def save_api_key(key):
    os.makedirs(os.path.dirname(ENV_FILE), exist_ok=True)
    lines = []
    try:
        with open(ENV_FILE, "r") as f:
            lines = [l for l in f.read().splitlines()
                     if not l.startswith("GOOGLE_API_KEY=")]
    except OSError:
        pass
    lines.append('GOOGLE_API_KEY="%s"' % key)
    tmp = ENV_FILE + ".tmp"
    with open(tmp, "w") as f:
        f.write("\n".join(lines) + "\n")
    os.chmod(tmp, 0o600)
    os.replace(tmp, ENV_FILE)
    os.environ["GOOGLE_API_KEY"] = key


def prompt_for_api_key(reason=None):
    """Ask for a key on the controlling terminal. Returns None if not interactive."""
    if not os.path.exists("/dev/tty"):
        return None
    import getpass
    if reason:
        print(reason, file=sys.stderr)
    try:
        key = getpass.getpass("Enter your Google Gemini API key: ")
    except (EOFError, OSError):
        return None
    except KeyboardInterrupt:
        print(file=sys.stderr)
        return None
    return key.strip() or None


def _key_is_valid(key):
    """Cheap live check of an API key. On network trouble, assume it is fine."""
    try:
        client = genai.Client(api_key=key)
        next(iter(client.models.list()), None)
        return True
    except Exception as e:
        return not _is_auth_error(e)


def update_api_key_interactive():
    """Used by 'hmm -key': prompt, validate against the API, and store the key."""
    for _ in range(3):
        key = prompt_for_api_key()
        if not key:
            print("Hmm... No key entered, nothing changed.", file=sys.stderr)
            return 1
        if _key_is_valid(key):
            save_api_key(key)
            print("API key validated and saved to %s" % ENV_FILE, file=sys.stderr)
            return 0
        print("Hmm... Google rejected that key. Try again (Ctrl+C to abort).",
              file=sys.stderr)
    print("Hmm... Too many failed attempts, nothing changed.", file=sys.stderr)
    return 1


# ── Error classification ─────────────────────────────────────────────────────

def _error_text(e):
    return ("%s: %s" % (type(e).__name__, e)).lower()


def _is_auth_error(e):
    t = _error_text(e)
    return any(s in t for s in (
        "api key not valid", "api_key_invalid", "invalid api key",
        "unauthenticated", "permission_denied", "permission denied",
        "401", "403",
    ))


def _is_model_unavailable(e):
    t = _error_text(e)
    return any(s in t for s in (
        "not_found", "not found", "404", "is not supported",
        "deprecated", "has been retired",
    ))


# ── Generation ───────────────────────────────────────────────────────────────

def _build_config(model):
    args = {
        "temperature": Config.TEMPERATURE,
        "top_p": 0.95,
        "top_k": 40,
        "max_output_tokens": Config.MAX_OUTPUT_TOKENS,
        "response_mime_type": "text/plain",
        "system_instruction": [
            types.Part(text="Follow the EXACT instructions. This is a technical critical task!")
        ],
    }
    if model.startswith("gemini-3"):
        args["thinking_config"] = types.ThinkingConfig(
            include_thoughts=False, thinking_level="LOW")
    elif model.startswith("gemini-2.5"):
        # Keep answers fast: no thinking needed for one-line shell commands.
        args["thinking_config"] = types.ThinkingConfig(thinking_budget=0)
    return types.GenerateContentConfig(**args)


def _generate(api_key, prompt):
    """Try each candidate model in order.

    Returns (result_text, None) on a final answer, or (None, "auth") when the
    key was rejected so the caller can re-prompt for a new one.
    """
    client = genai.Client(api_key=api_key)
    contents = [types.Content(role="user", parts=[types.Part(text=prompt)])]
    last_err = None
    for model in Config.MODEL_CANDIDATES:
        try:
            response = client.models.generate_content(
                model=model, contents=contents, config=_build_config(model))
            text = response.text
            return (text.strip() if text
                    else "#AI call succeeded but no answer was returned"), None
        except Exception as e:
            if _is_auth_error(e):
                return None, "auth"
            if _is_model_unavailable(e):
                last_err = e
                continue
            return "#Error: %s" % e, None
    return "#Error: no available Gemini model found (last error: %s). Run 'hmm -update' to get the latest model list." % last_err, None


def call_gemini(query: str, sysinfo: str) -> str:
    prompt_file = os.path.join(Config.CURRENT_SCRIPT_DIR, "oshelp.md")
    try:
        with open(prompt_file, "r") as f:
            prompt = f.read()
    except OSError:
        return "#Error: prompt template missing at %s. Run 'hmm -update' to reinstall." % prompt_file

    prompt = prompt.replace("$$query$$", query)
    prompt = prompt.replace("$$sysinfo$$", sysinfo)

    # Candidate keys: environment variable first, then the stored key.
    keys = []
    env_key = os.getenv("GOOGLE_API_KEY")
    if env_key:
        keys.append(env_key)
    file_key = read_key_from_env_file()
    if file_key and file_key not in keys:
        keys.append(file_key)

    newly_entered = None
    if not keys:
        key = prompt_for_api_key("No Google Gemini API key found.")
        if not key:
            return "#Error: No API key found. Run 'hmm -key' to set one, or set GOOGLE_API_KEY."
        keys.append(key)
        newly_entered = key

    try:
        prompted_after_reject = False
        i = 0
        while i < len(keys):
            key = keys[i]
            result, failure = _generate(key, prompt)
            if failure != "auth":
                if key == newly_entered:
                    save_api_key(key)
                    print("API key saved to %s" % ENV_FILE, file=sys.stderr)
                return result
            i += 1
            if i == len(keys) and not prompted_after_reject:
                prompted_after_reject = True
                new_key = prompt_for_api_key(
                    "Your Google API key was rejected. It may be invalid or expired.")
                if new_key:
                    keys.append(new_key)
                    newly_entered = new_key
        return "#Error: your Google API key was rejected. Run 'hmm -key' to set a new one."
    except Exception as e:
        return "#Error: %s" % e
