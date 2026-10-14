# Lynis-Based macOS Security Audit
### Custom FileVault, Firewall, and IPv6 Security Tests

[![Version](https://img.shields.io/badge/version-1.0-334155)](https://github.com/utkrisht121/custom-lynis-audit)
[![Platform](https://img.shields.io/badge/platform-macOS-111827)](https://support.apple.com/macos)
[![Shell](https://img.shields.io/badge/shell-POSIX%20sh-0F766E)](tests_custom)
[![Validation](https://github.com/utkrisht121/custom-lynis-audit/actions/workflows/validate.yml/badge.svg)](https://github.com/utkrisht121/custom-lynis-audit/actions/workflows/validate.yml)

**Version 1.0** · macOS / Apple Silicon (MacBook Air M4) · Lynis custom-test integration

**Project author and developer:** **Utkrish Mishra**  
**Role:** **Utkrish Mishra — Project Developer & Security Audit Implementer**

This project extends [Lynis](https://github.com/CISOfy/lynis), an open-source security auditing and system-hardening tool, with **three read-only macOS checks**. The scripts inspect FileVault disk encryption, IPv6 on the Wi-Fi network service, and the macOS Application Firewall. The findings appear in Lynis's normal custom-test output and reports.

No changes to macOS security settings are performed.

## Assignment objectives

1. Install and configure Lynis on macOS.
2. Run and understand **10 Lynis commands**.
3. Review existing audit scripts and the upstream custom-test template.
4. Write three POSIX shell checks for FileVault, IPv6, and Firewall.
5. Integrate the checks into Lynis's `include/tests_custom` file.
6. Run the audit, review the output, and interpret the findings.

## Custom security checks

| Test ID | Security feature | What the script checks | Expected result |
|:---|:---|:---|:---|
| `CUST-9001` | **FileVault encryption** | `fdesetup status` | `ENABLED` / `DISABLED` / `UNVERIFIED` |
| `CUST-9002` | **Wi-Fi IPv6 configuration** | `networksetup -getinfo "Wi-Fi"` | `ENABLED` / `DISABLED` / `UNVERIFIED` |
| `CUST-9003` | **macOS Application Firewall** | `socketfilterfw --getglobalstate` | `ENABLED` / `DISABLED` / `UNVERIFIED` |

**What the results mean:** `UNVERIFIED` indicates a missing utility, failed command, or unrecognized output. For IPv6, `ENABLED` also records whether the configuration is automatic, manual, or link-local-only. **Neither IPv6 enabled nor IPv6 disabled is automatically a vulnerability**; the appropriate mode depends on the network policy.

The tests use Lynis's existing function calls — `Register`, `Display`, `LogText`, `Report`, `ReportWarning`, and `AddHP` — and respect `SKIPTEST` and `--os macOS`. FileVault and Firewall contribute hardening points only on a verified outcome. The IPv6 test reports its mode without assigning a security score.

## Repository layout

```text
custom-lynis-audit/
├── README.md
├── tests_custom                    # All 3 test implementations; Lynis sources this
├── docs/
│   ├── COMMANDS.md                 # 10 Lynis commands with simple explanations
│   ├── AUDIT_GUIDE.md              # Installation, execution, findings and rollback
│   └── TESTING.md                  # Test cases and integration notes
├── reference/
│   └── tests_custom.template       # Original Lynis example for script comparison
├── tests/
│   └── smoke.sh                    # Automated, mock-based regression checks
├── .github/
│   └── workflows/
│       └── validate.yml           # Shell syntax and regression tests
└── .gitignore
```

The older two-test `FIRE-9001`/`CRYP-9001` implementation and standalone extended firewall script have been removed from Version 1.0. There is now **one canonical file**, `tests_custom`, containing all three assignment tests in order.

## Installation — macOS

### 1. Install Lynis (if not installed)

With [Homebrew](https://brew.sh/):

```sh
brew install lynis
lynis show version
lynis show includedir
```

Alternatively, use an official Lynis source checkout:

```sh
git clone https://github.com/CISOfy/lynis.git
cd lynis
./lynis show version
./lynis show includedir
```

### 2. Download the custom test file

```sh
git clone https://github.com/utkrisht121/custom-lynis-audit.git
cd custom-lynis-audit
```

### 3. Install the tests into the correct Lynis include directory

Use the directory printed by **`lynis show includedir`** (not an assumed Homebrew path). Replace `<include-directory>` in these commands with that actual path:

```sh
# Back up an existing custom-test file, if present
sudo cp -p "<include-directory>/tests_custom" "<include-directory>/tests_custom.backup"

# Copy this project's three-test implementation
sudo install -m 600 tests_custom "<include-directory>/tests_custom"
```

If `tests_custom` does not yet exist in that directory, **skip the backup command**. Lynis requires safe file permissions for its sourced custom tests. Installing into a package-managed Homebrew path may need to be repeated after updates.

For a self-contained source checkout, replace `<include-directory>` with the checkout's `include` directory and run `./lynis` from the checkout root. See [the full setup guide](docs/AUDIT_GUIDE.md).

### 4. Run the audit

For a Homebrew installation:

```sh
sudo lynis audit system
```

For an official source checkout, from the Lynis root:

```sh
sudo ./lynis audit system
```

Lynis automatically sources `tests_custom` near the end of the system audit. **Do not run `sh tests_custom` directly**: its functions are provided by Lynis.

### 5. Read the results

Look under **Custom tests** in the terminal and inspect the report entries:

```sh
sudo grep -E 'CUST-9001|CUST-9002|CUST-9003' /var/log/lynis.log
sudo grep '^custom_' /var/log/lynis-report.dat
```

The default paths may differ with your Lynis installation or profile.

**Example output — illustrative only, not a measured M4 audit:**

```text
[+] Custom tests
  - FileVault disk encryption                 [ ENABLED ]
  - Wi-Fi IPv6 configuration                  [ ENABLED (AUTO) ]
  - macOS Application Firewall                [ ENABLED ]
```

## The 10 Lynis commands

Use the **[10-command reference](docs/COMMANDS.md)** for commands, explanations, and what to observe. The first eight are discovery commands; the last two run a regular and a quick security audit.

## How the code works

Each of the three tests:

1. Registers its unique `CUST-900x` ID with Lynis.
2. Runs only if Lynis allows the test on macOS.
3. Invokes a **read-only** macOS command using its absolute system path.
4. Maps recognized output to enabled/disabled; unknown output stays unverified.
5. Prints a status, records a log message, and saves a structured report value.
6. Flags disabled encryption/firewall configurations for review; never auto-changes settings.

See [implementation and validation](docs/TESTING.md).

## Local checks and continuous integration

```sh
sh -n tests_custom
sh tests/smoke.sh
```

The automated tests simulate macOS command responses on a development machine. They **do not** prove results for a particular MacBook. Real audit evidence must come from running Lynis on the Mac.

## Security notes

- The scripts **do not** run `-setv6off`, `-setv6automatic`, `--setglobalstate`, or commands that change FileVault.
- IPv6 mode is a configuration observation, not a default pass/fail security verdict. Link-local-only permits local IPv6 communication but not ordinary routed IPv6.
- A disabled Firewall or FileVault setting does not by itself prove compromise.
- The Wi-Fi network **service name** is `Wi-Fi` by default. If renamed, set `CUST_WIFI_SERVICE` when invoking Lynis. The test does not infer Wi-Fi service names from hardware interface names like `en0`.
- `UNVERIFIED` is intentionally different from `DISABLED`.
- Lynis already runs many built-in checks; these three are additional, focused assignment checks.

## References and acknowledgments

- [Lynis official repository](https://github.com/CISOfy/lynis)
- [Lynis custom tests documentation](https://github.com/CISOfy/lynis/wiki/Custom-Tests-and-Plugins)
- [Lynis documentation](https://cisofy.com/documentation/lynis/)
- [Apple Platform Security](https://support.apple.com/guide/security/welcome/web)
- [macOS `networksetup` manual](https://manp.gs/mac/8/networksetup)

Built using the public Lynis custom-test interface. This repository is an independent educational project, not an official Lynis or Apple product.

---

**Version:** 1.0 · **Author / developer:** Utkrish Mishra
