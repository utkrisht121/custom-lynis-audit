#!/bin/sh
# Mock Lynis and macOS commands without touching live system settings.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
mkdir -p "$TMP/bin"

cat > "$TMP/bin/socketfilterfw" <<'MOCK'
#!/bin/sh
case "$1" in
    --getglobalstate) printf '%s\n' "${MOCK_FW_STATE:-Firewall is enabled. (State = 1)}" ;;
    --getstealthmode) printf '%s\n' "${MOCK_STEALTH_STATE:-Stealth mode enabled}" ;;
    --listapps) printf '%s\n' 'Total number of apps = 0' ;;
    *) exit 1 ;;
esac
MOCK
cat > "$TMP/bin/fdesetup" <<'MOCK'
#!/bin/sh
[ "${1:-}" = status ] || exit 1
printf '%s\n' "${MOCK_FV_STATE:-FileVault is On.}"
MOCK
chmod 700 "$TMP/bin/socketfilterfw" "$TMP/bin/fdesetup"

run_case() (
    CASE_NAME=$1
    OUT_FILE="$TMP/$CASE_NAME.out"
    : > "$OUT_FILE"
    export OUT_FILE
    PATH="$TMP/bin:$PATH"; export PATH
    FIREWALL_BIN="${MOCK_BIN:-$TMP/bin/socketfilterfw}"
    OS="${MOCK_OS:-macOS}"
    Register() {
        TEST_NO=$2
        printf 'REGISTER|%s\n' "$TEST_NO" >> "$OUT_FILE"
        SKIPTEST=0
        [ "$OS" = macOS ] || SKIPTEST=1
        [ "${MOCK_SKIP:-0}" = 0 ] || SKIPTEST=1
    }
    Display() { printf 'DISPLAY|%s\n' "$*" >> "$OUT_FILE"; }
    LogText() { printf 'LOG|%s\n' "$*" >> "$OUT_FILE"; }
    Report() { printf 'REPORT|%s\n' "$*" >> "$OUT_FILE"; }
    ReportWarning() { printf 'WARNING|%s\n' "$*" >> "$OUT_FILE"; }
    AddHP() { printf 'HP|%s\n' "$*" >> "$OUT_FILE"; }
    # shellcheck disable=SC1090
    . "$ROOT/tests_custom"
)
assert_has() {
    if ! grep -Fq -- "$2" "$TMP/$1.out"; then
        echo "FAIL: $1 missing: $2" >&2
        cat "$TMP/$1.out" >&2
        exit 1
    fi
}
assert_lacks() {
    if grep -Fq -- "$2" "$TMP/$1.out"; then
        echo "FAIL: $1 unexpectedly contained: $2" >&2
        cat "$TMP/$1.out" >&2
        exit 1
    fi
}

run_case enabled
assert_has enabled 'REPORT|firewall_status=enabled'
assert_has enabled 'REPORT|stealth_mode=enabled'
assert_has enabled 'REPORT|filevault_status=enabled'
assert_lacks enabled 'WARNING|'
[ "$(grep -Fc 'HP|5 5' "$TMP/enabled.out")" -eq 2 ]

MOCK_FW_STATE='Firewall is disabled. (State = 0)' MOCK_STEALTH_STATE='Stealth mode disabled' MOCK_FV_STATE='FileVault is Off.' run_case disabled
assert_has disabled 'REPORT|firewall_status=disabled'
assert_has disabled 'REPORT|stealth_mode=disabled'
assert_has disabled 'REPORT|filevault_status=disabled'
[ "$(grep -c '^WARNING|' "$TMP/disabled.out")" -eq 3 ]

MOCK_FW_STATE='No response' MOCK_STEALTH_STATE='No response' MOCK_FV_STATE='Unavailable' run_case unknown
assert_has unknown 'REPORT|firewall_status=unknown'
assert_has unknown 'REPORT|stealth_mode=unknown'
assert_has unknown 'REPORT|filevault_status=unknown'
assert_lacks unknown 'HP|'

MOCK_BIN="$TMP/not-installed" run_case missing_firewall
assert_has missing_firewall 'REPORT|firewall_daemon=missing'
assert_has missing_firewall 'REGISTER|CRYP-9001'
assert_has missing_firewall 'REPORT|filevault_status=enabled'

MOCK_SKIP=1 run_case skipped
assert_has skipped 'REGISTER|FIRE-9001'
assert_has skipped 'REGISTER|CRYP-9001'
assert_lacks skipped 'REPORT|'

MOCK_OS=Linux run_case non_macos
assert_lacks non_macos 'REPORT|'
assert_has non_macos 'REGISTER|CRYP-9001'

printf 'PASS: enabled, disabled, unknown, missing utility, skipped, non-macOS\n'
