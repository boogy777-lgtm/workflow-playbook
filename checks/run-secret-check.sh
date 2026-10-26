#!/usr/bin/env bash
# run-secret-check.sh  (macOS and Linux)
# Universal pre-publish secret scanner. Cross-platform twin of run-secret-check.ps1.
# Ensures the Betterleaks scanner is present and at the latest stable release,
# installing or updating it automatically, then scans a target folder: working
# tree plus full git history, using Betterleaks' built-in rules plus any
# project-specific rules in betterleaks-extra.toml.
# Exits 0 when clean, nonzero when anything is found, so it can gate a publish step.
# No scanner binary is committed to any repo; this script fetches it on demand.
#
# Usage:
#   ./run-secret-check.sh                 # scan current folder
#   ./run-secret-check.sh /path/to/repo   # scan a specific folder

set -u

TARGET="${1:-.}"
if [ ! -d "$TARGET" ]; then
    echo "ERROR: target is not an existing directory: $TARGET" >&2
    exit 2
fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTRA_CONFIG="$SCRIPT_DIR/betterleaks-extra.toml"
PRIVATE_CONFIG="$SCRIPT_DIR/scan-private.toml"   # untracked; holds personal identifiers
LOCAL_DIR="$HOME/.local/bin"

latest_release_json() {
    # The /releases/latest endpoint returns the newest non-prerelease: latest stable.
    curl -fsSL --max-time 20 -H "User-Agent: run-secret-check" \
        "https://api.github.com/repos/betterleaks/betterleaks/releases/latest" 2>/dev/null
}

latest_stable_version() {
    printf '%s' "$1" | grep -o '"tag_name": *"[^"]*"' | head -n1 | sed 's/.*"v\{0,1\}\([^"]*\)"/\1/'
}

latest_asset_url() {
    local os arch
    case "$(uname -s)" in
        Linux)  os="linux" ;;
        Darwin) os="darwin" ;;
        *)      return 1 ;;
    esac
    case "$(uname -m)" in
        x86_64|amd64)  arch="x64\|amd64\|x86_64" ;;
        arm64|aarch64) arch="arm64\|aarch64" ;;
        *)             return 1 ;;
    esac
    printf '%s' "$1" | tr ',' '\n' | grep '"browser_download_url"' \
        | grep -i "${os}" | grep -i "${arch}" | head -n1 \
        | sed 's/.*"\(http[^"]*\)".*/\1/'
}

bin_version() {
    "$1" --version 2>&1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -n1
}

install_to_local_dir() {
    local url="$1" tmp
    mkdir -p "$LOCAL_DIR"
    tmp="$(mktemp -d)"
    if curl -fsSL --max-time 300 -o "$tmp/archive" "$url" 2>/dev/null; then
        tar -xzf "$tmp/archive" -C "$tmp" 2>/dev/null || unzip -o "$tmp/archive" -d "$tmp" >/dev/null 2>&1
        found="$(find "$tmp" -type f -name betterleaks -perm -u+x 2>/dev/null | head -n1)"
        [ -z "$found" ] && found="$(find "$tmp" -type f -name betterleaks 2>/dev/null | head -n1)"
        if [ -n "$found" ]; then
            mv "$found" "$LOCAL_DIR/betterleaks"
            chmod +x "$LOCAL_DIR/betterleaks"
            rm -rf "$tmp"
            return 0
        fi
    fi
    rm -rf "$tmp"
    return 1
}

resolve_bin() {
    if command -v betterleaks >/dev/null 2>&1; then
        command -v betterleaks
    elif [ -x "$LOCAL_DIR/betterleaks" ]; then
        echo "$LOCAL_DIR/betterleaks"
    fi
}

merge_configs() {
    # Betterleaks honours only the LAST --config flag: stacked flags silently
    # disable the earlier files. Merge every existing config into one temp
    # file instead: concatenate, keep exactly one [extend] useDefault=true
    # block, drop any other title line.
    local out tmp f
    out="$(mktemp)"
    printf '[extend]\nuseDefault = true\n' > "$out"
    for f in "$@"; do
        [ -f "$f" ] || continue
        # strip a UTF-8 BOM and CRLF line endings before merging
        sed -e '1s/^\xEF\xBB\xBF//' -e 's/\r$//' "$f" | awk -v out="$out" '
            BEGIN { in_extend = 0 }
            /^[[:space:]]*\[extend\][[:space:]]*$/ { in_extend = 1; next }
            in_extend && /^[[:space:]]*\[/         { in_extend = 0 }
            in_extend                              { next }
            /^[[:space:]]*title[[:space:]]*=/      { next }
            { print }
        ' >> "$out"
    done
    printf '%s' "$out"
}

# --- Install if missing ---------------------------------------------------------
BIN="$(resolve_bin)"
if [ -z "$BIN" ]; then
    echo "betterleaks not found; installing the latest stable release..." >&2
    if command -v brew >/dev/null 2>&1; then
        brew install betterleaks >/dev/null 2>&1 || true
        BIN="$(resolve_bin)"
    fi
    if [ -z "$BIN" ]; then
        JSON="$(latest_release_json)"
        URL=""
        [ -n "$JSON" ] && URL="$(latest_asset_url "$JSON" || true)"
        if [ -n "$URL" ] && install_to_local_dir "$URL"; then
            BIN="$LOCAL_DIR/betterleaks"
        fi
    fi
    if [ -z "$BIN" ]; then
        echo "ERROR: could not install betterleaks automatically." >&2
        echo "Install it from https://github.com/betterleaks/betterleaks/releases and re-run." >&2
        exit 2
    fi
fi

# --- Update to latest stable ------------------------------------------------------
HAVE="$(bin_version "$BIN")"
JSON="$(latest_release_json)"
LATEST=""
[ -n "$JSON" ] && LATEST="$(latest_stable_version "$JSON")"
if [ -n "$LATEST" ] && [ -n "$HAVE" ] && [ "$LATEST" != "$HAVE" ]; then
    NEWER="$(printf '%s\n%s\n' "$HAVE" "$LATEST" | sort -V | head -n1)"
    if [ "$NEWER" = "$HAVE" ]; then
        echo "betterleaks $HAVE installed; updating to latest stable ($LATEST)..." >&2
        UPDATED=0
        if command -v brew >/dev/null 2>&1; then
            brew upgrade betterleaks >/dev/null 2>&1 || true
            RESOLVED="$(resolve_bin)"
            if [ -n "$RESOLVED" ] && [ "$(bin_version "$RESOLVED")" = "$LATEST" ]; then
                BIN="$RESOLVED"; UPDATED=1
            fi
        fi
        if [ "$UPDATED" -eq 0 ]; then
            URL="$(latest_asset_url "$JSON" || true)"
            if [ -n "$URL" ] && install_to_local_dir "$URL"; then
                if [ "$(bin_version "$LOCAL_DIR/betterleaks")" = "$LATEST" ]; then
                    BIN="$LOCAL_DIR/betterleaks"; UPDATED=1
                fi
            fi
        fi
        [ "$UPDATED" -eq 0 ] && echo "WARNING: update did not complete; scanning with $HAVE." >&2
    fi
elif [ -z "$LATEST" ]; then
    echo "WARNING: could not reach GitHub to check for a newer stable release; scanning with ${HAVE:-unknown}." >&2
fi

# --- Scan --------------------------------------------------------------------------
CONFIGS=()
[ -f "$EXTRA_CONFIG" ]   && CONFIGS+=("$EXTRA_CONFIG")
if [ -f "$PRIVATE_CONFIG" ]; then
    echo "Including private rules from $PRIVATE_CONFIG (kept out of git)." >&2
    CONFIGS+=("$PRIVATE_CONFIG")
fi

CONFIG_FLAG=()
MERGED=""
if [ "${#CONFIGS[@]}" -gt 0 ]; then
    MERGED="$(merge_configs "${CONFIGS[@]}")"
    trap 'rm -f "$MERGED"' EXIT
    CONFIG_FLAG=(--config "$MERGED")
fi

echo "Scanning '$TARGET' for secrets (working tree + git history)..."

# git mode scans commits, not untracked files or uncommitted edits. Always scan
# the actual directory, then all Git refs, keeping a failure from either pass.
# Redaction prevents a failed gate from copying credentials into build logs.
"$BIN" dir "${CONFIG_FLAG[@]}" --no-banner --redact=100 --exit-code 1 "$TARGET"
code=$?
if git -C "$TARGET" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    "$BIN" git "${CONFIG_FLAG[@]}" --log-opts=--all --no-banner --redact=100 --exit-code 1 "$TARGET"
    history_code=$?
    if [ "$history_code" -ne 0 ] && { [ "$code" -eq 0 ] || [ "$history_code" -ne 1 ]; }; then
        code="$history_code"
    fi
fi

if [ "$code" -eq 0 ]; then
    echo ""
    echo "CLEAN: no secrets detected."
elif [ "$code" -eq 1 ]; then
    echo ""
    echo "FOUND SECRETS. Do not publish until every hit above is reviewed."
    echo "For each hit: confirm whether it is real. Rotate the credential if it was ever exposed,"
    echo "then remove it from the file AND from git history (git filter-repo / BFG)."
else
    echo "ERROR: secret scan did not complete successfully (exit $code). Do not publish." >&2
fi
exit "$code"
