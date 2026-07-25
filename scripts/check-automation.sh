#!/bin/bash
set -euo pipefail

SORA_CLI=${SORA_CLI:-/opt/homebrew/bin/sora}
PROJECT=${1:-$PWD}
RESULT=$(mktemp /tmp/sora-automation-check.XXXXXX)
ERROR=$(mktemp /tmp/sora-automation-error.XXXXXX)
trap 'rm -f "$RESULT" "$ERROR"' EXIT

"$SORA_CLI" open "$PROJECT" >/dev/null
"$SORA_CLI" run --project "$PROJECT" --name "Automation Check" -- \
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

echo "Sora automation check passed"
