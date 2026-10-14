#!/bin/sh
# Offline, non-invasive regression tests for the sourced Lynis custom checks.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
mkdir -p "$TMP/bin"

cat > "$TMP/bin/fdesetup" <<'MOCK'
#!/bin/sh
[ "${1:-}" = status ] || exit 2
[ "${MOCK_FV_FAIL:-0}" = 0 ] || exit 3
printf '%s\n' "${MOCK_FV_OUTPUT-FileVault is On.}"
MOCK

cat > "$TMP/bin/networksetup" <<'MOCK'
#!/bin/sh
[ "${1:-}" = -getinfo ] || exit 2
[ "${2:-}" = "${MOCK_EXPECT_SERVICE:-Wi-Fi}" ] || exit 3
[ "$#" -eq 2 ] || exit 4
[ "${MOCK_NET_FAIL:-0}" = 0 ] || exit 5
printf '%s\n' "${MOCK_NET_OUTPUT-IPv6: Automatic}"
MOCK

cat > "$TMP/bin/socketfilterfw" <<'MOCK'
#!/bin/sh
[ "${1:-}" = --getglobalstate ] || exit 2
[ "${MOCK_FW_FAIL:-0}" = 0 ] || exit 3
printf '%s\n' "${MOCK_FW_OUTPUT-Firewall is enabled. (State = 1)}"
MOCK
chmod 700 "$TMP/bin/fdesetup" "$TMP/bin/networksetup" "$TMP/bin/socketfilterfw"

run_case() (
    # Lynis doesn't run with shell errexit; failed native commands are handled
    # by checking their return status in the sourced script.
    set +e
    CASE_NAME=$1
    OUT_FILE="$TMP/$CASE_NAME.out"
    : > "$OUT_FILE"
    export OUT_FILE

    OS="${MOCK_OS:-macOS}"
    CUST_FILEVAULT_BIN="${MOCK_FV_BIN:-$TMP/bin/fdesetup}"
    CUST_NETWORKSETUP_BIN="${MOCK_NET_BIN:-$TMP/bin/networksetup}"
    CUST_FIREWALL_BIN="${MOCK_FW_BIN:-$TMP/bin/socketfilterfw}"
    CUST_WIFI_SERVICE="${MOCK_WIFI_SERVICE:-Wi-Fi}"
    export MOCK_FV_FAIL MOCK_FV_OUTPUT MOCK_NET_FAIL MOCK_NET_OUTPUT MOCK_FW_FAIL MOCK_FW_OUTPUT MOCK_EXPECT_SERVICE 2>/dev/null

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

    # Source, just as Lynis does. None of the mocks access macOS settings.
    # shellcheck disable=SC1090
    . "$ROOT/tests_custom"
)

fail() {
    printf '%s\n' "FAIL: $*" >&2
    exit 1
}
assert_has() {
    grep -Fq -- "$2" "$TMP/$1.out" || {
        cat "$TMP/$1.out" >&2
        fail "$1: expected $2"
    }
}
assert_lacks() {
    if grep -Fq -- "$2" "$TMP/$1.out"; then
        cat "$TMP/$1.out" >&2
        fail "$1: unexpectedly contained $2"
    fi
}
assert_count() {
    COUNT=$(grep -c -- "$2" "$TMP/$1.out" || true)
    [ "$COUNT" -eq "$3" ] || fail "$1: expected $3 matches for $2, got $COUNT"
}

# 1. All security features enabled.
run_case enabled
assert_has enabled 'REGISTER|CUST-9001'
assert_has enabled 'REGISTER|CUST-9002'
assert_has enabled 'REGISTER|CUST-9003'
assert_has enabled 'REPORT|custom_filevault_status=enabled'
assert_has enabled 'REPORT|custom_wifi_ipv6_status=enabled'
assert_has enabled 'REPORT|custom_wifi_ipv6_mode=automatic'
assert_has enabled 'REPORT|custom_firewall_status=enabled'
assert_count enabled '^HP|5 5$' 2
assert_lacks enabled 'WARNING|'

# 2. Disabled settings. IPv6 off is informational, not a blanket warning.
MOCK_FV_OUTPUT='FileVault is Off.' \
MOCK_NET_OUTPUT='IPv6: Off' \
MOCK_FW_OUTPUT='Firewall is disabled. (State = 0)' run_case disabled
assert_has disabled 'REPORT|custom_filevault_status=disabled'
assert_has disabled 'REPORT|custom_wifi_ipv6_status=disabled'
assert_has disabled 'REPORT|custom_wifi_ipv6_mode=off'
assert_has disabled 'REPORT|custom_firewall_status=disabled'
assert_count disabled '^WARNING|' 2
assert_count disabled '^HP|0 5$' 2

# 3. IPv6 manual.
MOCK_NET_OUTPUT='IPv6: Manual' run_case manual
assert_has manual 'REPORT|custom_wifi_ipv6_mode=manual'

# 4. IPv6 link-local only.
MOCK_NET_OUTPUT='IPv6: Link-local only' run_case linklocal
assert_has linklocal 'REPORT|custom_wifi_ipv6_mode=link_local_only'

# 5. Commands succeed but provide unrecognized data.
MOCK_FV_OUTPUT='Encryption pending' \
MOCK_NET_OUTPUT='IPv6 configuration unavailable' \
MOCK_FW_OUTPUT='Unknown firewall status' run_case unknown
assert_has unknown 'REPORT|custom_filevault_status=unknown'
assert_has unknown 'REPORT|custom_wifi_ipv6_status=unknown'
assert_has unknown 'REPORT|custom_firewall_status=unknown'
assert_lacks unknown 'REPORT|custom_firewall_status=disabled'
assert_lacks unknown 'HP|'

# 6. Commands fail with nonzero status.
MOCK_FV_FAIL=1 MOCK_NET_FAIL=1 MOCK_FW_FAIL=1 run_case failed_commands
assert_has failed_commands 'REPORT|custom_filevault_status=unknown'
assert_has failed_commands 'REPORT|custom_wifi_ipv6_status=unknown'
assert_has failed_commands 'REPORT|custom_firewall_status=unknown'
assert_lacks failed_commands 'HP|'

# 7. All utilities are absent, but all three tests are still registered.
MOCK_FV_BIN="$TMP/bin/not-present-1" \
MOCK_NET_BIN="$TMP/bin/not-present-2" \
MOCK_FW_BIN="$TMP/bin/not-present-3" run_case missing_utilities
assert_has missing_utilities 'REGISTER|CUST-9003'
assert_has missing_utilities 'REPORT|custom_filevault_status=unknown'
assert_has missing_utilities 'REPORT|custom_wifi_ipv6_status=unknown'
assert_has missing_utilities 'REPORT|custom_firewall_status=unknown'

# 8. Lynis skips tests.
MOCK_SKIP=1 run_case skipped
assert_count skipped '^REGISTER|' 3
assert_lacks skipped 'REPORT|'
assert_lacks skipped 'HP|'

# 9. Different OS is excluded by Lynis's --os macOS registration.
MOCK_OS=Linux run_case non_macos
assert_count non_macos '^REGISTER|' 3
assert_lacks non_macos 'REPORT|'

# 10. Network service names with spaces remain a single argument.
MOCK_WIFI_SERVICE='Campus Wi-Fi' MOCK_EXPECT_SERVICE='Campus Wi-Fi' run_case renamed_wifi
assert_has renamed_wifi 'REPORT|custom_wifi_ipv6_mode=automatic'

# The new script must not carry obsolete legacy test identifiers.
if grep -Eq '^Register --test-no (FIRE-9001|CRYP-9001)' "$ROOT/tests_custom"; then
    fail 'Legacy test IDs are still present'
fi

printf '%s\n' 'PASS: 10 mock scenarios (3 CUST tests; macOS configuration untouched)'
