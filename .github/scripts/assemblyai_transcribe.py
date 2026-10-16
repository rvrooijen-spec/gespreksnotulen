#!/usr/bin/env python3
"""Schrijft audiobestanden uit via AssemblyAI (EU-endpoint), met sprekers.

Gebruik: assemblyai_transcribe.py <uitvoermap> <audio...>
Vereist omgevingsvariabele ASSEMBLYAI_API_KEY.
Uitvoer per bestand: <naam>.txt in hetzelfde formaat als de app.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request

BASE = os.environ.get("ASSEMBLYAI_BASE_URL", "https://api.eu.assemblyai.com")
KEY = os.environ.get("ASSEMBLYAI_API_KEY", "").strip()

# Nieuwste modellen eerst; AssemblyAI valt terug op het volgende als het eerste
# geen Nederlands ondersteunt. Werkt een combinatie niet, dan proberen we de volgende.
ATTEMPTS = [
    {"speech_models": ["universal-3-5-pro", "universal-2"]},
    {"speech_models": ["universal-3-pro", "universal-2"]},
    {"speech_models": ["universal-2"]},
    {},
]


def request(method, path, body=None, raw=None):
    headers = {"authorization": KEY}
    data = None
    if raw is not None:
        data = raw
        headers["content-type"] = "application/octet-stream"
    elif body is not None:
        data = json.dumps(body).encode()
        headers["content-type"] = "application/json"
    req = urllib.request.Request(BASE + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=300) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")
        raise RuntimeError(f"HTTP {e.code} op {path}: {detail}") from None


def fmt_time(ms):
    s = int(ms // 1000)
    return f"{s // 3600}:{s % 3600 // 60:02d}:{s % 60:02d}" if s >= 3600 else f"{s // 60:02d}:{s % 60:02d}"


def transcribe(path):
    with open(path, "rb") as f:
        upload_url = request("POST", "/v2/upload", raw=f.read())["upload_url"]

    last_error = None
    for extra in ATTEMPTS:
        body = {"audio_url": upload_url, "language_code": "nl", "speaker_labels": True, **extra}
        try:
            job = request("POST", "/v2/transcript", body=body)
        except RuntimeError as e:
            print(f"  instelling {extra or 'standaard'} niet geaccepteerd: {e}")
            last_error = e
            continue
        print(f"  gestart met {extra or 'standaardmodel'} (id {job['id']})")
        while job["status"] not in ("completed", "error"):
            time.sleep(3)
            job = request("GET", f"/v2/transcript/{job['id']}")
        if job["status"] == "completed":
            return job
        print(f"  mislukt: {job.get('error')}")
        last_error = RuntimeError(job.get("error"))
    raise RuntimeError(f"Alle pogingen mislukt: {last_error}")


def to_text(title, job):
    # Sprekers A, B, ... → Persoon 1, 2, ... op volgorde van eerste keer spreken.
    numbering = {}
    lines = [title, f"{fmt_time((job.get('audio_duration') or 0) * 1000)} · model: {job.get('speech_model') or job.get('speech_model_used') or '?'}", ""]
    for u in job.get("utterances") or []:
        spk = u.get("speaker")
        if spk not in numbering:
            numbering[spk] = len(numbering) + 1
        lines.append(f"[{fmt_time(u['start'])}] Persoon {numbering[spk]}: {u['text'].strip()}")
        lines.append("")
    if not job.get("utterances"):
        lines.append(job.get("text") or "(geen spraak gevonden)")
    return "\n".join(lines)


def main():
    if not KEY:
        sys.exit("ASSEMBLYAI_API_KEY ontbreekt. Voeg hem toe als repository secret (Settings → Secrets and variables → Actions).")
    out_dir = sys.argv[1]
    os.makedirs(out_dir, exist_ok=True)
    failed = False
    for path in sys.argv[2:]:
        title = os.path.splitext(os.path.basename(path))[0]
        print(f"== {title} ==")
        start = time.time()
        try:
            job = transcribe(path)
            text = to_text(title, job)
            print(text)
            print(f"(klaar in {int(time.time() - start)} s)")
            with open(os.path.join(out_dir, title + ".txt"), "w", encoding="utf-8") as f:
                f.write(text)
        except Exception as e:  # noqa: BLE001
            print(f"Mislukt: {e}")
            failed = True
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
