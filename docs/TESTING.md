# Validation and implementation notes — Version 1.0

## Integration contract

`tests_custom` is a **POSIX shell include file**, not a standalone executable. Lynis sources it at the custom-test stage. `Register` sets `TEST_NO` and `SKIPTEST`; the code uses `if [ "${SKIPTEST:-1}" -eq 0 ]` after **each** registration. The three unique IDs execute in this exact order:

1. `CUST-9001` — FileVault
2. `CUST-9002` — IPv6 (Wi-Fi)
3. `CUST-9003` — Application Firewall

There is no `exit` in the sourced file. A missing utility must not terminate Lynis or prevent the next test from registering.

## Command map

| ID | Read-only command | Output-to-status mapping | Report fields |
|---|---|---|---|
| `CUST-9001` | `/usr/bin/fdesetup status` | On / Off / unrecognized | `custom_filevault_status` |
| `CUST-9002` | `/usr/sbin/networksetup -getinfo "Wi-Fi"` | Automatic, Manual, Link-local only / Off / unrecognized | `custom_wifi_ipv6_status`, `custom_wifi_ipv6_mode` |
| `CUST-9003` | `/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate` | enabled / disabled / unrecognized | `custom_firewall_status` |

Commands must both exist and exit successfully before parsing their output. Unrecognized or transitional status is **unknown**, never automatically disabled.

FileVault and the Application Firewall use `AddHP 5 5` on verified enabled and `AddHP 0 5` on verified disabled. IPv6 status has **no** pass/fail hardening score or automatic warning: that is a site-policy decision.

## Test matrix

`sh tests/smoke.sh` stubs the Lynis functions and macOS commands without accessing or modifying real host configuration.

| Case | Expected behavior |
|---|---|
| All features enabled | Three enabled report statuses; IPv6 automatic; two positive hardening scores. |
| All features disabled | Three disabled report statuses; warnings only for FileVault and Firewall. |
| IPv6 manual mode | Enabled, manual. |
| IPv6 link-local-only mode | Enabled, link-local-only; not equivalent to full routed IPv6. |
| Unrecognized command output | Unknown status; no false disabled finding or hardening score. |
| Failed native commands | Unknown statuses; remaining checks still register. |
| Missing utilities | Unknown statuses; no premature Lynis exit. |
| Lynis skips tests | Registrations occur, but no custom reports are emitted. |
| Non-macOS host | Lynis `--os macOS` causes all three checks to be skipped. |
| Renamed Wi-Fi service | A service name with spaces is passed as one argument. |

## Local checks

```sh
sh -n tests_custom
sh -n tests/smoke.sh
sh tests/smoke.sh
```

The GitHub Actions workflow runs these checks automatically. The mock test's passing result does not claim that FileVault, Firewall, or IPv6 was actually enabled on any Mac.

## Live validation on the Mac

Run `sudo lynis audit system`; confirm the three test IDs and matching `custom_...` report entries. On macOS, compare the displayed values with the read-only native commands from [the audit guide](AUDIT_GUIDE.md). Save real screenshots or outputs only after a live run.

## Files intentionally removed from the old project

Version 1.0 removes the former extended `tests_firewall_macos` file and the former `FIRE-9001`/`CRYP-9001` test IDs. Stealth-mode and `pf` diagnostics are out of scope for this three-question assignment. The original upstream template remains under `reference/` for studying Lynis's scripting pattern.
