#!/usr/bin/env bash
# Copyright 2026 Google LLC.
# SPDX-License-Identifier: Apache-2.0
#
# Deterministic helpers for the per-user EGM home (default ~/.egm, override with EGM_HOME).
# The model reads and writes the knowledge files; this script owns the layout, the repo list
# and the freshness check, so those never depend on model judgment.
#
#   egm_home.sh home                 print the resolved home directory
#   egm_home.sh init                 create the layout (idempotent, never overwrites)
#   egm_home.sh repos                list registered repos: name<TAB>path<TAB>role
#   egm_home.sh meta <name>          record the repo's current commit in knowledge/<name>/meta.json
#   egm_home.sh stale [<name>]       freshness per repo: fresh | stale (<n> commits) | unbuilt | missing
#   egm_home.sh run-dir <KEY>        print (and create) the run directory for a ticket
#   egm_home.sh idea-key             mint a run key for an idea run (IDEA-<yyyymmddHHMM>) and
#                                    create its run directory
#   egm_home.sh resolve <name|path>  resolve a --repos entry (registry name, or a path to any
#                                    git checkout) to name<TAB>path<TAB>role
#   egm_home.sh activate <session>   mark an autopilot run active for the guard hook
#   egm_home.sh deactivate <session> clear that mark
set -euo pipefail

HOME_DIR="${EGM_HOME:-$HOME/.egm}"
REGISTRY="$HOME_DIR/workspace.yaml"

die() { echo "egm_home: $*" >&2; exit 1; }
need_registry() { [ -f "$REGISTRY" ] || die "not initialised: $REGISTRY not found (run /egm-pilot:egm-init)"; }

# Read the registry (flat format written by egm-init): one repo per block, one key per line.
repos() {
  need_registry
  awk -v home="$HOME" '
    function flush() { if (name != "") { sub(/^~/, home, path); printf "%s\t%s\t%s\n", name, path, role } }
    /^repos:[[:space:]]*(\{\})?[[:space:]]*$/ { inrepos = 1; next }
    /^[^[:space:]#]/ { if (inrepos) { flush(); name = ""; inrepos = 0 } }
    inrepos && /^  [^[:space:]#][^:]*:[[:space:]]*$/ { flush(); name = $1; sub(/:$/, "", name); path = ""; role = "other"; next }
    inrepos && /^    path:/ { v = $0; sub(/^    path:[[:space:]]*/, "", v); gsub(/^["\047]|["\047]$/, "", v); path = v }
    inrepos && /^    role:/ { v = $0; sub(/^    role:[[:space:]]*/, "", v); gsub(/^["\047]|["\047]$/, "", v); role = v }
    END { if (inrepos) flush() }
  ' "$REGISTRY"
}

cmd="${1:-}"; shift || true
case "$cmd" in
  home) echo "$HOME_DIR" ;;

  init)
    mkdir -p "$HOME_DIR/knowledge" "$HOME_DIR/runs"
    [ -f "$REGISTRY" ] || cat > "$REGISTRY" <<'EOF'
# EGM workspace registry (per user). Managed by /egm-pilot:egm-init; safe to edit by hand.
# Keep the exact shape: one repo per block, two-space name line, four-space keys, one key per line.
# role: shared | backend | client | frontend | tests | infra | docs | other
version: 1
repos: {}
# repos:
#   my-service:
#     path: /absolute/path/to/my-service
#     role: backend
#     base: main
EOF
    [ -f "$HOME_DIR/map.md" ] || printf '# Cross-repo map\n\nWho exposes and who consumes which contract. Built by /egm-pilot:egm-init.\n' > "$HOME_DIR/map.md"
    [ -f "$HOME_DIR/learnings.md" ] || printf '# Learnings\n\nRecurring park reasons and findings, by category. No ticket text.\n' > "$HOME_DIR/learnings.md"
    echo "$HOME_DIR"
    ;;

  repos) repos ;;

  meta)
    name="${1:-}"; [ -n "$name" ] || die "usage: meta <name>"
    line="$(repos | awk -F'\t' -v n="$name" '$1==n')"; [ -n "$line" ] || die "unknown repo: $name"
    path="$(printf '%s' "$line" | cut -f2)"
    [ -d "$path/.git" ] || [ -f "$path/.git" ] || die "not a git checkout: $path"
    mkdir -p "$HOME_DIR/knowledge/$name"
    jq -n --arg sha "$(git -C "$path" rev-parse HEAD)" \
          --arg branch "$(git -C "$path" rev-parse --abbrev-ref HEAD)" \
          --arg built "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
          '{built_from_sha:$sha, built_from_branch:$branch, built_at:$built}' \
      > "$HOME_DIR/knowledge/$name/meta.json"
    cat "$HOME_DIR/knowledge/$name/meta.json"
    ;;

  stale)
    only="${1:-}"
    repos | while IFS=$'\t' read -r name path role; do
      [ -z "$only" ] || [ "$only" = "$name" ] || continue
      if [ ! -d "$path" ]; then printf '%s\tmissing\n' "$name"; continue; fi
      meta="$HOME_DIR/knowledge/$name/meta.json"
      if [ ! -f "$meta" ]; then printf '%s\tunbuilt\n' "$name"; continue; fi
      sha="$(jq -r '.built_from_sha // empty' "$meta")"
      head="$(git -C "$path" rev-parse HEAD 2>/dev/null || true)"
      if [ -z "$head" ]; then printf '%s\tmissing\n' "$name"
      elif [ "$sha" = "$head" ]; then printf '%s\tfresh\n' "$name"
      else
        n="$(git -C "$path" rev-list --count "$sha..$head" 2>/dev/null || echo '?')"
        printf '%s\tstale (%s commits)\n' "$name" "$n"
      fi
    done
    ;;

  run-dir)
    key="${1:-}"; [[ "$key" =~ ^[A-Za-z][A-Za-z0-9]*-[0-9]+$ ]] || die "bad ticket key: '$key'"
    mkdir -p "$HOME_DIR/runs/$key"; echo "$HOME_DIR/runs/$key"
    ;;

  idea-key)
    n="$(date +%Y%m%d%H%M)"
    while [ -e "$HOME_DIR/runs/IDEA-$n" ]; do n=$((n + 1)); done
    mkdir -p "$HOME_DIR/runs/IDEA-$n"; echo "IDEA-$n"
    ;;

  resolve)
    entry="${1:-}"; [ -n "$entry" ] || die "usage: resolve <name|path>"
    if [ -f "$REGISTRY" ]; then
      line="$(repos | awk -F'\t' -v n="$entry" '$1==n')"
      if [ -n "$line" ]; then printf '%s\n' "$line"; exit 0; fi
    fi
    case "$entry" in "~"|"~/"*) entry="$HOME${entry#\~}" ;; esac
    [ -d "$entry" ] || die "not a registered repo or a directory: $entry"
    top="$(git -C "$entry" rev-parse --show-toplevel 2>/dev/null)" || die "not a git checkout: $entry"
    top="$(cd "$top" && pwd -P)"
    # A registered checkout keeps its registry name and role.
    if [ -f "$REGISTRY" ]; then
      line="$(repos | while IFS=$'\t' read -r n p r; do
        [ -d "$p" ] && [ "$(cd "$p" && pwd -P)" = "$top" ] && printf '%s\t%s\t%s\n' "$n" "$top" "$r"
      done | head -n 1)"
      if [ -n "$line" ]; then printf '%s\n' "$line"; exit 0; fi
    fi
    printf '%s\t%s\t%s\n' "$(basename "$top")" "$top" other
    ;;

  activate|deactivate)
    sid="${1:-}"; [[ "$sid" =~ ^[A-Za-z0-9-]+$ ]] || die "bad session id: '$sid'"
    if [ "$cmd" = activate ]; then mkdir -p "$HOME_DIR/active"; : > "$HOME_DIR/active/$sid"
    else rm -f "$HOME_DIR/active/$sid"; fi
    ;;

  *) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
