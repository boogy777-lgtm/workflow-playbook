#!/usr/bin/env bash
# Guards working-tree and all-ref history coverage, and redacted reports.
# Added 2026-10-27. Requires Bash, Git, and Betterleaks 1.9.0 on PATH.
# Runs on Linux/macOS; every fixture and commit is local and disposable.
# Optional argument: powershell (also requires PowerShell 7 on PATH).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-bash}"
SCANNER="$(command -v betterleaks)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/tools" "$TMP/bin"
cp "$ROOT/checks/run-secret-check.sh" "$TMP/tools/"
cp "$ROOT/checks/run-secret-check.ps1" "$TMP/tools/"
ln -s "$SCANNER" "$TMP/bin/betterleaks"
# Keep fixture tests offline: an installed scanner must still run if update
# metadata is unavailable. This does not replace or fake the scanner itself.
cat > "$TMP/bin/curl" <<'STUB'
#!/usr/bin/env bash
exit 1
STUB
chmod +x "$TMP/bin/curl"
export PATH="$TMP/bin:$PATH"
case "$MODE" in
    bash) RUN=(bash "$TMP/tools/run-secret-check.sh") ;;
    powershell)
        command -v pwsh >/dev/null
        export WORKFLOW_TEST_TMP="$TMP"
        cat > "$TMP/tools/run-fixture.ps1" <<'HARNESS'
param([string]$Target)
$env:LOCALAPPDATA = $env:WORKFLOW_TEST_TMP
$env:TEMP = $env:WORKFLOW_TEST_TMP
function Invoke-RestMethod { throw "Offline fixture: no update metadata" }
& (Join-Path $PSScriptRoot 'run-secret-check.ps1') -Target $Target
exit $LASTEXITCODE
HARNESS
        RUN=(pwsh -NoLogo -NoProfile -File "$TMP/tools/run-fixture.ps1") ;;
    *) printf 'Unknown wrapper: %s\n' "$MODE" >&2; exit 2 ;;
esac
cat > "$TMP/tools/betterleaks-extra.toml" <<'CONFIG'
[[rules]]
id = "workflow-test-canary"
description = "Synthetic noncredential fixture"
regex = '''WP_CANARY_[A-Z]+'''
CONFIG

init_repo() {
    local repo="$1"
    git init -q -b main "$repo"
    git -C "$repo" config user.name WorkflowTest
    git -C "$repo" config user.email workflow-test@example.invalid
    git -C "$repo" -c commit.gpgsign=false commit --allow-empty -qm baseline
}

run_case() {
    local name="$1" expected="$2" repo="$3" code=0
    "${RUN[@]}" "$repo" > "$TMP/report" 2>&1 || code=$?
    if [ "$code" -ne "$expected" ]; then
        printf 'FAIL %s: expected exit %s; actual %s\n' "$name" "$expected" "$code"
        printf 'Reproduce: bash TESTS/test-secret-check.sh\n'
        exit 1
    fi
    if grep -Eq 'WP_CANARY_[A-Z]+' "$TMP/report"; then
        printf 'FAIL %s: scanner exposed the synthetic match in its report\n' "$name"
        exit 1
    fi
    printf 'PASS %s\n' "$name"
}

repo="$TMP/repo"
init_repo "$repo"
run_case clean 0 "$repo"
printf '%s\n' WP_CANARY_UNTRACKED > "$repo/candidate.txt"
run_case untracked 1 "$repo"
git -C "$repo" add candidate.txt
run_case staged 1 "$repo"
git -C "$repo" -c commit.gpgsign=false commit -qm canary
printf 'ordinary text\n' > "$repo/candidate.txt"
run_case unstaged-edit-with-history 1 "$repo"
git -C "$repo" add candidate.txt
git -C "$repo" -c commit.gpgsign=false commit -qm remove-canary
run_case deleted-from-head 1 "$repo"

repo="$TMP/branch-repo"
init_repo "$repo"
git -C "$repo" checkout -qb pending-work
printf '%s\n' WP_CANARY_BRANCH > "$repo/branch.txt"
git -C "$repo" add branch.txt
git -C "$repo" -c commit.gpgsign=false commit -qm branch-canary
git -C "$repo" checkout -q main
run_case other-ref 1 "$repo"

repo="$TMP/modified-repo"
init_repo "$repo"
printf 'ordinary text\n' > "$repo/existing.txt"
git -C "$repo" add existing.txt
git -C "$repo" -c commit.gpgsign=false commit -qm clean-file
printf '%s\n' WP_CANARY_MODIFIED > "$repo/existing.txt"
run_case unstaged-only 1 "$repo"

mkdir -p "$TMP/plain"
printf '%s\n' WP_CANARY_PLAIN > "$TMP/plain/input.txt"
run_case non-git 1 "$TMP/plain"
run_case missing-target 2 "$TMP/missing"
printf 'All secret checker regressions passed.\n'
