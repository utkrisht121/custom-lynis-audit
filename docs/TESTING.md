# Implementation and testing notes

## How Lynis loads the tests

During `lynis audit system`, Lynis checks its `include/tests_custom` file, checks its permissions, and **sources** the file in the existing audit shell. This means `Register`, `SKIPTEST`, `Display`, `LogText`, `Report`, `ReportWarning`, and `AddHP` are already available; the file must not invoke `exit` or assume it runs as a separate process.

The primary file registers `FIRE-9001` first and `CRYP-9001` second, matching the existing sequence. Both registrations use `--os macOS` and respect `SKIPTEST`. Non-macOS hosts are therefore skipped by Lynis. When a utility is missing, the finding is `unknown`, and the second test is still reached.

## Report values

| Report key | Values | Meaning |
| --- | --- | --- |
| `firewall_status` | `enabled`, `disabled`, `unknown` | Application Firewall global state |
| `stealth_mode` | `enabled`, `disabled`, `unknown` | Application Firewall stealth mode |
| `filevault_status` | `enabled`, `disabled`, `unknown` | FileVault status reported by `fdesetup` |
| `firewall_daemon` | `missing` (when relevant) | Legacy report key indicating the `socketfilterfw` executable is absent, **not** a daemon liveness check |

Unknown values result in a warning to inspect the audit environment; they do not receive hardening points. Verified enabled / disabled outcomes retain the original `AddHP 5 5` / `AddHP 0 5` pattern for the firewall and FileVault checks. Stealth mode remains an informational or warning check without extra points in the primary implementation.

## Regression scenarios

Run `sh tests/smoke.sh` from the repository root, or call it by path. The tests stub Lynis functions and native commands. They verify:

1. All three settings enabled: enabled reports and expected hardening points.
2. All three settings disabled: disabled reports and findings.
3. Unknown native responses: no false disabled reports or undeserved hardening points.
4. Missing firewall executable: FileVault still executes (no `exit` in sourced file).
5. `SKIPTEST=1`: no checks execute, although registrations still occur.
6. A non-macOS `OS` value: both checks are skipped.

The smoke tests do not require root, change macOS settings, or claim to reproduce a real-device Lynis audit. Actual integration should be confirmed on macOS using `sudo lynis audit system` and `/var/log/lynis.log`.

## Optional extended firewall check

The `tests_firewall_macos` file is deliberately separate. It uses the **same** test identifier `FIRE-9001` and adds `--listapps` diagnostics and a separate `/sbin/pfctl -s info` check. To use it, replace the `FIRE-9001` block in `tests_custom` with the extended file's contents and **keep only one** `FIRE-9001` registration. Do not just append the entire file; that would register the ID twice.

There is no standalone `./tests_firewall_macos` invocation: the file depends on Lynis functions. A disabled or unknown `pf` result is not treated as proof about the Application Firewall. The `--listapps` result only reports whether a listing was readable; it does not claim a count from unrelated preference keys.

## Restoring a previous installation

If you saved an original file as `include/tests_custom.backup`, restore it in the same Lynis checkout:

```sh
sudo cp -p include/tests_custom.backup include/tests_custom
sudo ./lynis audit system
```

If there was no original `tests_custom`, remove the newly installed custom file from the Lynis include directory after confirming its location. Do not delete the upstream `tests_custom.template` or any built-in Lynis modules.

## Scope

This is configuration auditing, not remediation. No test should change the host's security settings, force-quit the audit, or infer a successful check from empty/unknown command output.
