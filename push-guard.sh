#!/bin/bash
# Claude Code PreToolUse hook (managed-settings.json): the only push allowed is
# "git push no-mistakes <branch>", which goes through the no-mistakes gate.
# Exit 2 blocks the command and shows the message to Claude.
set -uo pipefail

cmd=$(jq -r '.tool_input.command // empty')
# every "git ... push ..." piece of the command line (split at ; & | and newlines)
pushes=$(printf '%s\n' "$cmd" | tr ';&|' '\n\n\n' | grep -E '(^|[[:space:]])git([[:space:]]+[^[:space:]]+)*[[:space:]]+push([[:space:]]|$)' || true)
[ -z "$pushes" ] && exit 0

while IFS= read -r piece; do
    piece=$(printf '%s' "$piece" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
    if ! printf '%s' "$piece" | grep -qE '^git push no-mistakes [A-Za-z0-9._/-]+$'; then
        echo "Blocked: only \"git push no-mistakes <branch>\" is allowed (got: $piece)" >&2
        exit 2
    fi
done <<< "$pushes"
exit 0
