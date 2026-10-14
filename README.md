# Lynis-Based macOS Security Audit

**Custom FileVault, Firewall, and IPv6 Security Tests**

**Author:** Utkrish Mishra  
**Role:** Project Developer & Security Audit Implementer  
**Version:** 1.0  
**Target platform:** macOS, including Apple Silicon (MacBook Air M4)  
**Tools:** Lynis, POSIX shell, macOS security utilities

## Overview

This project extends [Lynis](https://github.com/CISOfy/lynis) with three read-only checks for common macOS security settings. Each custom test is integrated into Lynis's normal system-audit process and displays its result in the audit output.

| Test ID | Audit | Native command | Results |
| --- | --- | --- | --- |
| `CUST-9001` | FileVault disk encryption | `/usr/bin/fdesetup status` | Enabled / Disabled / Unverified |
| `CUST-9002` | IPv6 configuration on the Wi-Fi network service | `/usr/sbin/networksetup -getinfo "Wi-Fi"` | Enabled / Disabled / Unverified |
| `CUST-9003` | macOS Application Firewall | `/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate` | Enabled / Disabled / Unverified |

The IPv6 test also records *automatic*, *manual*, *link-local-only*, or *off* configuration when available. **IPv6 being enabled or disabled is not inherently a security vulnerability.** Unverified means a setting could not be reliably read; it must not be confused with disabled.

## Project objectives

1. Install and configure Lynis on macOS.
2. Execute and understand ten Lynis commands.
3. Study existing Lynis audit scripts.
4. Develop custom tests for FileVault, Wi-Fi IPv6, and the Application Firewall.
5. Integrate all three into Lynis's `tests_custom` include file.
6. Run a security audit and interpret the findings.

## Repository structure

```text
custom-lynis-audit/
├── README.md       # Project overview, setup and instructions
├── tests_custom            # Lynis entry point; loads the scripts below
├── tests_filevault_macos   # CUST-9001: FileVault
├── tests_ipv6_macos        # CUST-9002: Wi-Fi IPv6
└── tests_firewall_macos    # CUST-9003: Application Firewall
```

Install **all four script files together in the same Lynis include directory**. Lynis automatically sources `tests_custom`, which loads the dedicated scripts in assignment order: FileVault → IPv6 → Firewall. The audit files use Lynis's standard registration and reporting functions; do not run them as standalone shell programs.

## Installation and execution

**1. Install Lynis** on your Mac if needed:

```sh
brew install lynis
lynis show version
lynis show includedir
```

Alternatively, clone [the official Lynis repository](https://github.com/CISOfy/lynis) and use `./lynis` from its root directory.

**2. Clone this project:**

```sh
git clone https://github.com/utkrisht121/custom-lynis-audit.git
cd custom-lynis-audit
```

**3. Install the four custom-test files.** First run `lynis show includedir` to identify the correct Lynis include directory. Replace `<include-directory>` below with its actual value:

```sh
# Back up an existing file ONLY if one already exists:
sudo cp -p "<include-directory>/tests_custom" "<include-directory>/tests_custom.backup"

# Install the loader and all three independent audit files:
sudo install -m 600 tests_custom tests_filevault_macos tests_ipv6_macos tests_firewall_macos "<include-directory>/"
```

Skip the backup command when no previous `tests_custom` file exists. The `600` permissions protect all four files. If one audit file is missing, the loader reports the missing file instead of silently skipping it. For a source checkout, its `include/` directory is the destination; package-managed paths may change after updates.

**4. Run Lynis:**

```sh
sudo lynis audit system
```

For a source checkout, use `sudo ./lynis audit system` from that checkout's root.

**5. Inspect results:**

```sh
sudo grep -E 'CUST-9001|CUST-9002|CUST-9003' /var/log/lynis.log
sudo grep '^custom_' /var/log/lynis-report.dat
```

Lynis's configured log/report paths may differ. To check syntax without running a security audit, use:

```sh
sh -n tests_custom
sh -n tests_filevault_macos
sh -n tests_ipv6_macos
sh -n tests_firewall_macos
```

### Sample audit output

*Illustrative output only; actual results depend on the audited Mac.*

```text
[+] Custom tests
  - FileVault disk encryption              [ ENABLED ]
  - Wi-Fi IPv6 configuration               [ ENABLED (AUTO) ]
  - macOS Application Firewall             [ ENABLED ]
```

## Ten Lynis commands for the practical

| # | Command | Purpose |
| --- | --- | --- |
| 1 | `lynis show version` | Check Lynis version |
| 2 | `lynis show help` | Display general help |
| 3 | `lynis show commands` | List supported commands |
| 4 | `lynis show options` | See command-line options |
| 5 | `lynis show includedir` | Find the built-in and custom test directory |
| 6 | `lynis show groups` | List security test groups |
| 7 | `lynis show categories` | List audit categories |
| 8 | `lynis show profiles` | Show audit profiles |
| 9 | `sudo lynis audit system` | Run a full system audit |
| 10 | `sudo lynis audit system --quick` | Run an audit without pauses |

In an official source checkout, replace `lynis` with `./lynis`. The command set can vary with the Lynis version; use `lynis show commands` to confirm availability.

## How the tests work

Each check calls `Register` with its unique `CUST-900x` ID and `--os macOS`. Lynis's `SKIPTEST` flag controls whether the test proceeds. The script queries the system using read-only commands and uses `Display`, `LogText`, and `Report` to record the result. `ReportWarning` flags disabled FileVault or firewall settings (or an unverified status), while `AddHP` handles hardening points for their verified states.

**Important:** This project does **not** enable or disable FileVault, the firewall, or IPv6. A missing/renamed `Wi-Fi` service may produce an unverified result; the service name can be adjusted through `CUST_WIFI_SERVICE`. Security findings require confirmation on an actual macOS installation; the example above is not evidence of a completed device audit.

## References

- [Official Lynis repository](https://github.com/CISOfy/lynis)
- [Lynis documentation](https://cisofy.com/documentation/lynis/)
- [Apple Platform Security](https://support.apple.com/guide/security/welcome/web)

**Developed by Utkrish Mishra — Version 1.0.**
