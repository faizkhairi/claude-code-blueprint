#!/bin/bash
# Replays the labelled cases in tests/judge-fixtures/ through the Stop prompt hook in
# examples/settings-template.json and reports, per case, how often the judge agreed
# with the label.
#
# Run: ANTHROPIC_API_KEY=... bash tests/judge-eval.sh [settings.json]
#   JUDGE_MODEL  model id for the judge (default claude-sonnet-5-5, the Sonnet the
#                template's "model": "sonnet" stands for)
#   JUDGE_RUNS   calls per case (default 3)
#   JUDGE_DRY_RUN=1  build every request and check it, call nothing, need no key
#
# MANUAL ONLY. This calls the Anthropic API, which needs a key and costs money, so it
# is deliberately not a CI job. Run it after you edit the Stop prompt.
#
# WHY THIS EXISTS
#
# The Stop hook is a prompt, not a script: a model reads the final message and answers
# {"ok": true} or {"ok": false, "reason": ...}. hooks/test-hooks.sh cannot see what a
# prompt decides, so a prompt edit can silently change which messages get blocked.
# This replays fixed messages through the same prompt and counts agreement.
#
# HOW IT MATCHES THE HOOK
#
# A prompt hook sends the prompt with $ARGUMENTS replaced by the hook input JSON, or
# with the JSON appended when the prompt has no $ARGUMENTS (code.claude.com/docs/en/
# hooks, prompt hook configuration). For Stop, that input carries the final message as
# last_assistant_message. This script builds the same input per fixture. It is an
# approximation: Claude Code adds its own framing around the call, so treat a case that
# passes here and misfires in real use as a new fixture, not as noise.
#
# FIXTURES
#
# Each file in tests/judge-fixtures/ has front matter (id, expected: ok|block, rule)
# and the final message as its body. {{FAKE_SECRET}} in a body is replaced with a fresh
# random string per run, so nothing credential-shaped is ever committed.
#
# Exit: 0 when the majority verdict of every case matches its label, 1 when one does
# not, 2 when the key, curl or Python is missing.

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SETTINGS="${1:-$ROOT/examples/settings-template.json}"
FIXTURES="$ROOT/tests/judge-fixtures"
MODEL="${JUDGE_MODEL:-claude-sonnet-5-5}"
RUNS="${JUDGE_RUNS:-3}"

PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
if [ -z "$PYTHON" ]; then echo "judge-eval: Python is required." >&2; exit 2; fi
if ! command -v curl >/dev/null 2>&1; then echo "judge-eval: curl is required." >&2; exit 2; fi
if [ -z "${ANTHROPIC_API_KEY:-}" ] && [ "${JUDGE_DRY_RUN:-}" != 1 ]; then
  echo "judge-eval: set ANTHROPIC_API_KEY. This script is manual only and never runs in CI." >&2
  exit 2
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# build <fixture> <out>: writes the Messages API request body for one fixture.
build() {
  "$PYTHON" - "$SETTINGS" "$1" "$MODEL" > "$2" <<'PY'
import json, re, secrets, sys
settings, fixture, model = sys.argv[1:4]
with open(settings, encoding="utf-8") as f:
    prompts = [h["prompt"] for g in json.load(f)["hooks"]["Stop"]
               for h in g.get("hooks", []) if h.get("type") == "prompt"]
if len(prompts) != 1:
    sys.exit("judge-eval: expected exactly one Stop prompt hook, found %d" % len(prompts))
with open(fixture, encoding="utf-8") as f:
    text = f.read()
body = re.split(r"^---\s*$", text, maxsplit=2, flags=re.M)[2].strip("\n")
body = body.replace("{{FAKE_SECRET}}", secrets.token_urlsafe(12))
hook_input = json.dumps({"session_id": "judge-eval", "hook_event_name": "Stop",
                         "stop_hook_active": False, "last_assistant_message": body})
prompt = prompts[0]
prompt = prompt.replace("$ARGUMENTS", hook_input) if "$ARGUMENTS" in prompt \
    else prompt + "\n\n" + hook_input
print(json.dumps({"model": model, "max_tokens": 4000,
                  "messages": [{"role": "user", "content": prompt}]}))
PY
}

# verdict <response.json>: prints ok, block, or error:<detail>.
verdict() {
  "$PYTHON" - "$1" <<'PY'
import json, re, sys
try:
    with open(sys.argv[1], encoding="utf-8") as f:
        r = json.load(f)
except Exception:
    print("error:unreadable response"); sys.exit()
if r.get("type") == "error":
    print("error:" + r.get("error", {}).get("message", "api error")[:80]); sys.exit()
text = "".join(b.get("text", "") for b in r.get("content", []) if b.get("type") == "text")
m = re.search(r"\{.*\}", text, re.S)
try:
    ok = json.loads(m.group(0)).get("ok") if m else None
except Exception:
    ok = None
print({True: "ok", False: "block"}.get(ok, "error:no ok field"))
PY
}

field() { sed -n "s/^$2: *//p" "$1" | head -1; }

echo "=== Stop judge eval ($MODEL, $RUNS runs per case) ==="
echo "Prompt from: $SETTINGS"
echo ""
MISMATCH=0
for fx in "$FIXTURES"/*.md; do
  id=$(field "$fx" id); expected=$(field "$fx" expected)
  if [ "${JUDGE_DRY_RUN:-}" = 1 ]; then
    build "$fx" "$WORK/req.json" || exit 2
    if grep -q 'last_assistant_message' "$WORK/req.json" && ! grep -q 'FAKE_SECRET' "$WORK/req.json"; then
      printf 'BUILT %-32s expected %s, %s bytes
' "$id" "$expected" "$(wc -c < "$WORK/req.json" | tr -d ' ')"
    else
      printf 'BAD   %-32s request is missing the message or kept the placeholder
' "$id"; MISMATCH=1
    fi
    continue
  fi
  agree=0; detail=""
  for n in $(seq 1 "$RUNS"); do
    build "$fx" "$WORK/req.json" || exit 2
    printf 'header = "x-api-key: %s"\n' "$ANTHROPIC_API_KEY" \
      | curl -sS -K - https://api.anthropic.com/v1/messages \
          -H "anthropic-version: 2026-10-21" -H "content-type: application/json" \
          --data-binary "@$WORK/req.json" -o "$WORK/res.json"
    v=$(verdict "$WORK/res.json")
    [ "$v" = "$expected" ] && agree=$((agree + 1))
    detail="$detail $n:$v"
  done
  if [ $((agree * 2)) -gt "$RUNS" ]; then status=PASS; else status=FAIL; MISMATCH=1; fi
  printf '%s  %-32s expected %-5s agreed %d/%d  [%s ]\n' "$status" "$id" "$expected" "$agree" "$RUNS" "$detail"
done
echo ""
if [ "${JUDGE_DRY_RUN:-}" = 1 ]; then
  [ "$MISMATCH" -eq 0 ] && { echo "Dry run: every request built, no API call made."; exit 0; }
  echo "Dry run: at least one request could not be built."; exit 1
fi
if [ "$MISMATCH" -eq 0 ]; then echo "Every case matched its label by majority."; exit 0; fi
echo "At least one case did not match its label. Read its runs above before changing the prompt."
exit 1
