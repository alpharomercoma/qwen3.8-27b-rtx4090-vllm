#!/bin/bash
# POD. Team API keys for pi, opencode and other OpenAI-compatible clients. authz.py re-reads the file on change.
# usage: keys.sh add <label>      create a key and print it once (give it to that person or group)
#        keys.sh list             labels and key fingerprints
#        keys.sh revoke <label>   remove a key; its holder is locked out on the next request
set -euo pipefail
F=/workspace/.team_api_keys
touch $F; chmod 600 $F
case "${1:-}" in
  add)
    L=${2:?label}; [[ $L =~ ^[A-Za-z0-9_.-]+$ ]] || { echo "label: letters, digits, _ . - only"; exit 2; }
    awk -v l="$L" '$1 == l {found=1} END {exit !found}' $F && { echo "label $L exists; revoke it first"; exit 1; }
    K="sk-heretic-$(python3 -c 'import secrets;print(secrets.token_urlsafe(32))')"
    tmp=$(mktemp "$F.tmp.XXXXXX"); cat $F > "$tmp"; echo "$L $K" >> "$tmp"; chmod 600 "$tmp"; mv "$tmp" $F   # same filesystem: atomic rename
    echo "$K" ;;
  list)
    while read -r l k; do [ -n "$l" ] && echo "$l $(printf %s "$k" | sha256sum | cut -c1-12)"; done < $F ;;
  revoke)
    L=${2:?label}; tmp=$(mktemp "$F.tmp.XXXXXX"); awk -v l="$L" '$1 != l' $F > "$tmp"; chmod 600 "$tmp"; mv "$tmp" $F; echo "revoked $L" ;;
  *) sed -n '2,6p' "$0"; exit 2 ;;
esac
