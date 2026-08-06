#!/bin/bash
set -euo pipefail

SORA_CLI=${SORA_CLI:-/opt/homebrew/bin/sora}
RESULT=$(mktemp /tmp/sora-automation-check.XXXXXX)
ERROR=$(mktemp /tmp/sora-automation-error.XXXXXX)
SPACE_ID=
cleanup() {
  [[ -z $SPACE_ID ]] || "$SORA_CLI" space remove "$SPACE_ID" --force >/dev/null 2>&1 || true
  rm -f "$RESULT" "$ERROR"
}
trap cleanup EXIT

SPACE_ID=$("$SORA_CLI" space create --name "Automation Check" | cut -f1)
"$SORA_CLI" space list | grep -q "^$SPACE_ID"
"$SORA_CLI" space rename "$SPACE_ID" "Automation Check Renamed" >/dev/null
"$SORA_CLI" space select "$SPACE_ID" >/dev/null
"$SORA_CLI" run --space "$SPACE_ID" --name "Automation Check" -- \
  /bin/sh -c 'printf "%s" "$1" > "$2"' check "argument with ' quote" "$RESULT" >/dev/null
for _ in {1..100}; do
  [[ $(<"$RESULT") == "argument with ' quote" ]] && break
  sleep 0.1
done
[[ $(<"$RESULT") == "argument with ' quote" ]]

UNKNOWN=00000000-0000-0000-0000-000000000001
if "$SORA_CLI" output "$UNKNOWN" --lines 501 2>"$ERROR"; then exit 1; fi
grep -q '^sora: invalidRequest:' "$ERROR"
if "$SORA_CLI" open /definitely/not/a/sora/project 2>"$ERROR"; then exit 1; fi
grep -q '^sora: invalidPath:' "$ERROR"

"$SORA_CLI" space remove "$SPACE_ID" --force >/dev/null
SPACE_ID=
echo "Sora automation check passed"
