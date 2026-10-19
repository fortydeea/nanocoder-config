#!/usr/bin/env bash
# nanocoder pre-tool-use hook for execute_bash.
# Exit 1 + stdout = block the call and tell the model what to run instead.
# Exit 0 = allow. Fails open: any problem in this script allows the command.
# Bypass for one session: export TOKEN_GUARD=off before starting nanocoder.
 
[ "${TOKEN_GUARD:-on}" = off ] && exit 0
cmd=${NANOCODER_COMMAND:-}
[ -z "$cmd" ] && exit 0
 
# 1. Raw HTTP into context -> route through context-mode.
if printf '%s' "$cmd" | grep -Eq '(^|[;&|(]|\$\()[[:space:]]*(sudo[[:space:]]+)?(curl|wget)([[:space:]]|$)' \
   || printf '%s' "$cmd" | grep -Eq '(node|bun|deno)[[:space:]]+-e.*fetch\(|python3?[[:space:]]+-c.*(requests|urllib|httpx)'; then
  echo "Blocked: raw HTTP output floods context. Use ctx_fetch_and_index(url, source) then ctx_search(queries), or ctx_execute(language: \"javascript\", code) and print only what you need."
  exit 1
fi
 
# 2. Commands RTK can compress -> tell the model the rtk form.
command -v rtk >/dev/null 2>&1 || exit 0
rewritten=$(RTK_REWRITE_HOST=nanocoder rtk rewrite "$cmd" 2>/dev/null)
rc=$?
case $rc in
  0|3)
    if [ -n "$rewritten" ] && [ "$rewritten" != "$cmd" ]; then
      echo "Use the token-compressed form instead. Run exactly: $rewritten"
      exit 1
    fi ;;
  2)
    echo "Blocked by RTK deny rule: $cmd"
    exit 1 ;;
esac
exit 0
