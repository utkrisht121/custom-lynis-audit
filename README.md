# Custom Lynis Security Audit for macOS

[![Shell validation](https://github.com/utkrisht121/custom-lynis-audit/actions/workflows/validate.yml/badge.svg)](https://github.com/utkrisht121/custom-lynis-audit/actions/workflows/validate.yml)

Two small, **read-only macOS security checks** for [Lynis](https://github.com/CISOfy/lynis): FileVault full-disk encryption and the macOS Application Firewall (including stealth mode). The project uses Lynis's existing `tests_custom` integration; it does not replace or modify the Lynis engine.

> **Compatibility:** macOS with a compatible Lynis installation. These files are **sourced by Lynis**, not executed as standalone audit programs. Mock-based regression tests also run on Linux, but they do not replace a real macOS audit.

## What it checks

| Test ID | Check | Native command | Finding |
| --- | --- | --- | --- |
| `FIRE-9001` | Application Firewall | `socketfilterfw --getglobalstate` | Enabled, disabled, or unverified |
| `FIRE-9001` | Firewall stealth mode | `socketfilterfw --getstealthmode` | Enabled, disabled, or unverified |
| `CRYP-9001` | FileVault disk encryption | `fdesetup status` | Enabled, disabled, or unverified |

Each check uses the same Lynis workflow: `Register` → inspect the command result → `Display` / `LogText` / `Report` → `ReportWarning` when applicable → `AddHP` for verified outcomes. Both original test identifiers are retained.

## Quick start

**1. Download the project and Lynis.**

```sh
git clone https://github.com/utkrisht121/custom-lynis-audit.git
git clone https://github.com/CISOfy/lynis.git
cd lynis
```

**2. Install the custom test file in the Lynis source checkout.** This example assumes both repositories were cloned side by side.

```sh
# Only if you already have an include/tests_custom file:
[ ! -f include/tests_custom ] || sudo cp -p include/tests_custom include/tests_custom.backup
sudo install -m 600 ../custom-lynis-audit/tests_custom include/tests_custom
```

For a Homebrew or other packaged Lynis installation, run `lynis show includedir` and place `tests_custom` in **that** directory instead. Keep a backup before replacing an existing file. Package upgrades may overwrite files inside managed installation directories.

**3. Execute the normal Lynis audit.**

```sh
sudo ./lynis show version
sudo ./lynis audit system
```

For packaged Lynis, use `sudo lynis audit system`. Lynis reads `include/tests_custom` during its normal custom-test stage, subject to its file-permission checks. No separate run command or change to the Lynis execution sequence is necessary.

**4. Verify your findings.**

```sh
sudo grep -E 'FIRE-9001|CRYP-9001|FileVault|Stealth' /var/log/lynis.log
sudo grep -E '^(firewall_status|stealth_mode|filevault_status)=' /var/log/lynis-report.dat
```

The log and report file locations may differ if you changed your Lynis configuration. A test file existing on disk does **not** prove it executed: check the terminal output and logs.

### Example output (illustrative)

```text
[+] Custom tests
  - macOS Application Firewall                  [ ENABLED ]
  - Firewall stealth mode                       [ ENABLED ]
  - FileVault disk encryption                   [ ENABLED ]
```

Results depend on the audited machine. No screenshot or result is presented as a completed real-device audit.

## Files

```text
custom-lynis-audit/
├── README.md
├── tests_custom                      # Install this file for both primary checks
├── tests_firewall_macos              # Optional extended FIRE-9001 alternative
├── docs/
│   └── TESTING.md                    # Audit logic, limitations, testing, rollback
├── reference/
│   └── tests_custom.template         # Unmodified upstream Lynis example
├── tests/
│   └── smoke.sh                      # Mocked regression tests (no system changes)
└── .github/workflows/
    └── validate.yml                 # Shell syntax + smoke checks
```

`tests_firewall_macos` is an **alternative** to the `FIRE-9001` section of `tests_custom`, not another file that Lynis automatically executes. It adds application-rule visibility and an explicitly separate `pf` status diagnostic. **Do not load both `FIRE-9001` definitions** in the same Lynis audit. The main `tests_custom` file is the recommended and default integration.

## Safety and interpretation

- The checks **read** current configuration; they never enable/disable the firewall or FileVault.
- `UNVERIFIED` means the command was unavailable, failed, or returned unexpected output. It is **not** proof that the feature is disabled.
- A disabled FileVault or firewall setting is a configuration finding, not evidence of compromise.
- Lynis may require root privileges, and some macOS settings vary by OS release and policy.
- macOS Application Firewall and the `pf` packet filter are **different components**; `pf` status is not used as evidence that Application Firewall is enabled.
- The project does not assess recovery-key escrow, firewall policy quality, encryption strength, or endpoint compromise.

## Validation

Run basic checks before installation:

```sh
sh -n tests_custom
sh -n tests_firewall_macos
sh tests/smoke.sh
```

See [Testing and implementation notes](docs/TESTING.md) for the test matrix, expected outcomes, installation rollback, and integration details.

## Original project and upstream references

The original repository files credited **Ankush Pratham**. The repository is maintained under [utkrisht121](https://github.com/utkrisht121). The unmodified Lynis sample file is retained in [`reference/tests_custom.template`](reference/tests_custom.template), with the upstream project credited below.

- [Lynis source code](https://github.com/CISOfy/lynis)
- [Lynis documentation](https://cisofy.com/documentation/lynis/)
- [Apple Platform Security](https://support.apple.com/guide/security/welcome/web)

*This is a supplemental auditing project, not an official Lynis or Apple security product.*
