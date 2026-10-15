#!/bin/bash
# Maakt testgesprek.wav (16 kHz mono) uit dialoog.json met twee Nederlandse
# macOS-stemmen, met een halve seconde stilte tussen de beurten.
set -euo pipefail
DIALOOG="$1"
UIT="$2"
WERK="$(mktemp -d)"

echo "Beschikbare Nederlandse stemmen:"
say -v '?' | grep -E 'nl_(NL|BE)' || true
# (macOS heeft bash 3.2, dus geen mapfile.) Liefst stemmen van verschillende sprekers.
STEMMEN=()
while IFS= read -r naam; do STEMMEN+=("$naam"); done < <(say -v '?' | grep -E 'nl_(NL|BE)' | sed -E 's/ +nl_(NL|BE).*//; s/ +$//')
if [ "${#STEMMEN[@]}" -lt 2 ]; then
  echo "Minder dan twee Nederlandse stemmen gevonden; alle stemmen:"
  say -v '?'
  exit 1
fi
STEM_A="${STEMMEN[0]}"
STEM_B="${STEMMEN[1]}"
echo "Spreker A: $STEM_A, spreker B: $STEM_B"

python3 - "$DIALOOG" "$WERK" "$STEM_A" "$STEM_B" <<'PY'
import json, subprocess, sys
dialoog, werk, stem_a, stem_b = sys.argv[1:]
for i, regel in enumerate(json.load(open(dialoog))):
    stem = stem_a if regel["voice"] == "A" else stem_b
    aiff = f"{werk}/{i:02d}.aiff"
    subprocess.run(["say", "-v", stem, "-o", aiff, regel["text"]], check=True)
    subprocess.run(["afconvert", "-f", "WAVE", "-d", "LEI16@16000", "-c", "1", aiff, f"{werk}/{i:02d}.wav"], check=True)
PY

python3 - "$WERK" "$UIT" <<'PY'
import glob, sys, wave
werk, uit = sys.argv[1:]
stilte = b"\x00\x00" * 8000
with wave.open(uit, "wb") as out:
    out.setnchannels(1); out.setsampwidth(2); out.setframerate(16000)
    out.writeframes(stilte)
    for pad in sorted(glob.glob(f"{werk}/*.wav")):
        with wave.open(pad) as w:
            out.writeframes(w.readframes(w.getnframes()))
        out.writeframes(stilte)
PY
echo "Gemaakt: $UIT"
afinfo "$UIT" | grep -E 'duration|format' || true
