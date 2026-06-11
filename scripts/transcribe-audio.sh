#!/usr/bin/env bash
# transcribe-audio — turn one or more audio files into an AI-readable transcript,
# optionally with speaker labels. General-purpose; knows nothing about content.
#
# Pipeline: ffmpeg (concat + 16 kHz mono) -> whisper.cpp (Vulkan GPU) for ASR,
# and (optional) sherpa-onnx on CPU for speaker diarization, merged by timestamp.
# Defaults favour accuracy over speed.
#
# Usage:
#   transcribe-audio [options] [PATH ...]
#
#   PATH   A directory (all audio inside is concatenated in sorted order) or
#          one/more audio files. Defaults to the current directory.
#
# Options:
#   --diarize        Add speaker labels (SPEAKER_01, ...) via sherpa-onnx, then
#                    merge them into the transcript -> <name>.speakers.txt.
#   --speakers N     Exact number of distinct speakers (more reliable than
#                    auto-detect). 0 = auto-detect.
#   --no-vad         Disable Voice Activity Detection (on by default; VAD trims
#                    silence and reduces hallucinations).
#   --no-clean       Disable audio cleanup (on by default: high-pass + denoise +
#                    dynamic normalisation to lift quiet/distant speakers).
#   --prompt TEXT    Initial prompt to seed proper nouns (names, places, jargon).
#                    Carried into every chunk; greatly improves spelling.
#   --max-context N  Previous-text context tokens per window (default: 0). 0
#                    prevents whisper's runaway repetition loops on long audio;
#                    -1 = unlimited (more coherent but loop-prone).
#   --model NAME     Whisper model (default: large-v3 = most accurate).
#                    Faster alternative: large-v3-turbo.
#   --lang CODE      Language (default: it). Use "auto" to detect.
#   --gpu N          Vulkan device index (default: 1 = discrete GPU; 0 = iGPU).
#   --name STEM      Output basename (default: derived from input).
#   -o, --out DIR    Output directory (default: alongside the input).
#   -h, --help       Show this help.
#
# Env overrides: WHISPER_MODEL, WHISPER_LANG, WHISPER_GPU, WHISPER_MODEL_DIR,
#                WHISPER_VAD_URL, DIAR_MODEL_DIR, DIAR_SEG_URL, DIAR_EMB_URL.
#
# Requires on PATH (NixOS installs these via transcription.nix; other systems
# must provide them): ffmpeg, whisper-cli (whisper.cpp, built with a GPU
# backend), sherpa-onnx-offline-speaker-diarization (only for --diarize),
# python3, curl, tar, bzip2, coreutils, findutils. The default --gpu 1 targets
# the second Vulkan device (this machine's AMD eGPU); set --gpu 0 elsewhere.
set -euo pipefail

MODEL="${WHISPER_MODEL:-large-v3}"
LANG_CODE="${WHISPER_LANG:-it}"
GPU="${WHISPER_GPU:-1}"
MODEL_DIR="${WHISPER_MODEL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/whisper-models}"
VAD_URL="${WHISPER_VAD_URL:-https://huggingface.co/ggml-org/whisper-vad/resolve/main/ggml-silero-v5.1.2.bin}"
DIAR_MODEL_DIR="${DIAR_MODEL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/sherpa-diarization}"
DIAR_REL="https://github.com/k2-fsa/sherpa-onnx/releases/download"
DIAR_SEG_URL="${DIAR_SEG_URL:-$DIAR_REL/speaker-segmentation-models/sherpa-onnx-pyannote-segmentation-3-0.tar.bz2}"
DIAR_EMB_URL="${DIAR_EMB_URL:-$DIAR_REL/speaker-recongition-models/3dspeaker_speech_campplus_sv_zh_en_16k-common_advanced.onnx}"
# Audio-cleanup filter chain (see --clean): kill sub-80Hz rumble, gently denoise
# below the speech floor, then dynamic-normalise to lift quiet/distant speakers.
# NB: afftdn was A/B-tested both ways. On a short clip it looked harmful, but on
# the FULL 11k-word transcript (the reliable sample) it scored marginally better
# (LanguageTool 0.94 vs 1.11 grammar errors/100w), so it stays. The effect is
# small — essentially a wash.
CLEAN_FILTER="${CLEAN_FILTER:-highpass=f=80,afftdn=nr=10:nf=-45,dynaudnorm=f=200:g=15}"
VAD=1
CLEAN=1
PROMPT="${WHISPER_PROMPT:-}"
# Tokens of previous-text context carried into each window. Default 0: whisper
# otherwise conditions on its own output and, over a long recording, can snowball
# a single repeat into a transcript-destroying loop. 0 prevents that; raise it
# (e.g. -1 for unlimited) only for clean short audio where coherence matters more.
MAX_CONTEXT="${WHISPER_MAX_CONTEXT:-0}"
DIARIZE=0
SPEAKERS=0
OUT=""
STEM=""
declare -a INPUTS=()

usage() { sed -n '2,44p' "$0" | sed 's/^# \{0,1\}//'; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --vad) VAD=1; shift ;;
    --no-vad) VAD=0; shift ;;
    --clean) CLEAN=1; shift ;;
    --no-clean) CLEAN=0; shift ;;
    --prompt) PROMPT="$2"; shift 2 ;;
    --max-context) MAX_CONTEXT="$2"; shift 2 ;;
    --diarize) DIARIZE=1; shift ;;
    --speakers) SPEAKERS="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --lang) LANG_CODE="$2"; shift 2 ;;
    --gpu) GPU="$2"; shift 2 ;;
    --name) STEM="$2"; shift 2 ;;
    -o|--out) OUT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    --) shift; while [ "$#" -gt 0 ]; do INPUTS+=("$1"); shift; done ;;
    -*) echo "Unknown option: $1" >&2; exit 2 ;;
    *) INPUTS+=("$1"); shift ;;
  esac
done

if [ "${#INPUTS[@]}" -eq 0 ]; then INPUTS=("."); fi

# Collect audio files in order. Directories expand to their (sorted) audio.
declare -a FILES=()
audio_glob='.*\.\(wav\|mp3\|m4a\|flac\|ogg\|opus\|aac\)$'
for item in "${INPUTS[@]}"; do
  if [ -d "$item" ]; then
    while IFS= read -r f; do FILES+=("$f"); done < <(
      find "$item" -maxdepth 1 -type f -iregex "$audio_glob" \
        -not -iname '*.16k.wav' | sort
    )
  elif [ -f "$item" ]; then
    FILES+=("$item")
  else
    echo "Not found: $item" >&2; exit 1
  fi
done

if [ "${#FILES[@]}" -eq 0 ]; then
  echo "No audio files found." >&2; exit 1
fi

# Decide output location and basename.
first="${FILES[0]}"
if [ -z "$OUT" ]; then
  if [ -d "${INPUTS[0]}" ]; then OUT="${INPUTS[0]}"; else OUT="$(dirname -- "$first")"; fi
fi
if [ -z "$STEM" ]; then
  if [ "${#FILES[@]}" -gt 1 ]; then
    STEM="session"
  else
    base="$(basename -- "$first")"; STEM="${base%.*}"
  fi
fi
mkdir -p "$OUT"
wav="$OUT/$STEM.16k.wav"

echo ">> Inputs (${#FILES[@]}):"
printf '   %s\n' "${FILES[@]}"
echo ">> Output base: $OUT/$STEM"

# 1) Prepare a single 16 kHz mono WAV (whisper's expected format).
declare -a AF=()
if [ "$CLEAN" -eq 1 ]; then
  AF=(-af "$CLEAN_FILTER")
  echo ">> Audio cleanup ON: $CLEAN_FILTER"
fi
if [ "${#FILES[@]}" -gt 1 ]; then
  list="$(mktemp)"
  trap 'rm -f "$list"' EXIT
  for f in "${FILES[@]}"; do
    printf "file '%s'\n" "$(realpath -- "$f")" >>"$list"
  done
  echo ">> Concatenating + resampling to 16 kHz mono ..."
  ffmpeg -y -hide_banner -loglevel warning -f concat -safe 0 -i "$list" \
    "${AF[@]}" -ar 16000 -ac 1 -c:a pcm_s16le "$wav"
else
  echo ">> Resampling to 16 kHz mono ..."
  ffmpeg -y -hide_banner -loglevel warning -i "$first" \
    "${AF[@]}" -ar 16000 -ac 1 -c:a pcm_s16le "$wav"
fi

# 2) Ensure the Whisper model is present.
mkdir -p "$MODEL_DIR"
model_path="$MODEL_DIR/ggml-$MODEL.bin"
if [ ! -f "$model_path" ]; then
  echo ">> Downloading model '$MODEL' ..."
  whisper-cpp-download-ggml-model "$MODEL" "$MODEL_DIR"
fi

# 3) Build whisper-cli arguments. -fa (flash attention) is a big speed-up on RADV.
declare -a WARGS=(
  -m "$model_path"
  -l "$LANG_CODE"
  -fa
  -mc "$MAX_CONTEXT"
  -pp
  -otxt -osrt -oj
  -of "$OUT/$STEM"
  -f "$wav"
)

# Seed proper nouns (names/places). --carry-initial-prompt re-injects it into
# every chunk so the priming lasts the whole session, not just the first window.
if [ -n "$PROMPT" ]; then
  WARGS+=(--prompt "$PROMPT" --carry-initial-prompt)
fi

if [ "$VAD" -eq 1 ]; then
  vad_model="$MODEL_DIR/ggml-silero-v5.1.2.bin"
  if [ ! -f "$vad_model" ]; then
    echo ">> Downloading VAD model ..."
    curl -L --fail -o "$vad_model" "$VAD_URL"
  fi
  WARGS+=(--vad -vm "$vad_model")
fi

echo ">> Transcribing on Vulkan device $GPU ..."
GGML_VK_VISIBLE_DEVICES="$GPU" whisper-cli "${WARGS[@]}"

# Merge sherpa-onnx speaker turns into the whisper transcript (inline python3).
# Labels each transcript segment with the speaker who talks most during it,
# groups consecutive same-speaker segments, and writes "[hh:mm:ss] SPEAKER_NN:".
merge_speakers() {
  python3 - "$1" "$2" "$3" <<'PYEOF'
import json, re, sys

json_path, diar_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
diar_re = re.compile(r"([0-9.]+)\s*--\s*([0-9.]+)\s+(speaker_\d+)")

turns = []
with open(diar_path) as f:
    for line in f:
        m = diar_re.search(line)
        if m:
            turns.append((float(m.group(1)), float(m.group(2)), m.group(3)))

with open(json_path) as f:
    data = json.load(f)
segs = []
for t in data.get("transcription", []):
    off = t.get("offsets", {})
    text = (t.get("text") or "").strip()
    if text:
        segs.append((off.get("from", 0) / 1000.0, off.get("to", 0) / 1000.0, text))


def speaker_for(s0, s1):
    totals = {}
    for t0, t1, spk in turns:
        ov = min(s1, t1) - max(s0, t0)
        if ov > 0:
            totals[spk] = totals.get(spk, 0.0) + ov
    return max(totals, key=totals.get) if totals else None


def hhmmss(sec):
    sec = int(sec)
    return "%02d:%02d:%02d" % (sec // 3600, (sec % 3600) // 60, sec % 60)


mapping = {}


def friendly(spk):
    if spk is None:
        return "SPEAKER_?"
    mapping.setdefault(spk, "SPEAKER_%02d" % (len(mapping) + 1))
    return mapping[spk]


blocks, cur, buf, start0 = [], object(), [], 0.0
for s0, s1, text in segs:
    spk = speaker_for(s0, s1)
    if spk != cur:
        if buf:
            blocks.append((start0, cur, " ".join(buf)))
        cur, start0, buf = spk, s0, [text]
    else:
        buf.append(text)
if buf:
    blocks.append((start0, cur, " ".join(buf)))

lines = ["[%s] %s: %s" % (hhmmss(s), friendly(spk), txt) for s, spk, txt in blocks]
with open(out_path, "w") as f:
    f.write("\n\n".join(lines) + "\n")
print("Wrote %s: %d turns, %d speakers" % (out_path, len(lines), len(mapping)))
PYEOF
}

# 4) Optional speaker diarization (CPU, sherpa-onnx) merged into the transcript.
if [ "$DIARIZE" -eq 1 ]; then
  seg_model="$DIAR_MODEL_DIR/sherpa-onnx-pyannote-segmentation-3-0/model.onnx"
  emb_model="$DIAR_MODEL_DIR/$(basename "$DIAR_EMB_URL")"
  mkdir -p "$DIAR_MODEL_DIR"
  if [ ! -f "$seg_model" ]; then
    echo ">> Downloading diarization segmentation model ..."
    curl -L --fail -o "$DIAR_MODEL_DIR/seg.tar.bz2" "$DIAR_SEG_URL"
    tar xjf "$DIAR_MODEL_DIR/seg.tar.bz2" -C "$DIAR_MODEL_DIR"
  fi
  if [ ! -f "$emb_model" ]; then
    echo ">> Downloading speaker embedding model ..."
    curl -L --fail -o "$emb_model" "$DIAR_EMB_URL"
  fi

  nthreads="$(nproc)"
  declare -a DARGS=(
    --segmentation.num-threads="$nthreads"
    --embedding.num-threads="$nthreads"
    --segmentation.pyannote-model="$seg_model"
    --embedding.model="$emb_model"
  )
  if [ "$SPEAKERS" -gt 0 ]; then
    DARGS+=(--clustering.num-clusters="$SPEAKERS")
  else
    DARGS+=(--clustering.cluster-threshold=0.5)
  fi

  echo ">> Diarizing on CPU (continues after transcription) ..."
  # Speaker turns go to stdout; progress/errors to stderr.
  if sherpa-onnx-offline-speaker-diarization "${DARGS[@]}" "$wav" \
       >"$OUT/$STEM.diar.txt" 2>"$OUT/$STEM.diar.log"; then
    echo ">> Merging speaker turns into the transcript ..."
    merge_speakers "$OUT/$STEM.json" "$OUT/$STEM.diar.txt" "$OUT/$STEM.speakers.txt"
  else
    echo "!! Diarization failed (see $STEM.diar.log); transcript saved without labels." >&2
  fi
fi

echo
echo ">> Done. Transcripts:"
echo "   $OUT/$STEM.txt   (plain text)"
echo "   $OUT/$STEM.srt   (timestamped — feed this to the LLM)"
echo "   $OUT/$STEM.json  (segment structure)"
if [ "$DIARIZE" -eq 1 ]; then
  echo "   $OUT/$STEM.speakers.txt  (speaker-labeled — feed THIS to the LLM)"
fi
