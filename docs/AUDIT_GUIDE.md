# macOS audit guide — install, inspect, run, and interpret

**Project:** Lynis-Based macOS Security Audit Using Custom FileVault, Firewall, and IPv6 Security Tests  
**Author and developer:** Utkrish Mishra  
**Target:** macOS running on Apple Silicon (including MacBook Air M4)

## 1. Environment and installation

Open **Terminal**. Check Homebrew and install Lynis if necessary:

```sh
brew --version
brew install lynis
lynis show version
lynis show includedir
```

If the `lynis` command is unavailable even after installation, check `brew info lynis` and your shell `PATH`. Alternatively clone [official Lynis](https://github.com/CISOfy/lynis) and use `./lynis` from the source root.

Clone this project:

```sh
git clone https://github.com/utkrisht121/custom-lynis-audit.git
cd custom-lynis-audit
```

Write down the actual include path from `lynis show includedir`. In the next commands **replace** `<include-directory>` with that printed path:

```sh
# Run only if tests_custom already exists:
sudo cp -p "<include-directory>/tests_custom" "<include-directory>/tests_custom.backup"

# Install all three tests as a single Lynis include file:
sudo install -m 600 tests_custom "<include-directory>/tests_custom"
```

Lynis can reject an unsafe `tests_custom` file; restrictive permissions matter. Copying to a Homebrew-managed include directory may be undone by an update.

## 2. Study the default Lynis scripts

Locate the scripts in the include directory. Compare built-in `tests_firewalls` and the upstream template in `reference/tests_custom.template` with our `tests_custom`. Existing Lynis checks test broad configurations; these three additional tests deliberately focus on FileVault, Wi-Fi IPv6 mode, and the Application Firewall.

| Function | Purpose |
|---|---|
| `Register` | Declares one test ID; Lynis decides whether it should execute. |
| `SKIPTEST` | Indicates a skipped/filtered test. |
| `Display` | Prints the human-readable status during an audit. |
| `LogText` | Adds information to Lynis's audit log. |
| `Report` | Writes key/value data into the audit report. |
| `ReportWarning` | Adds an item for investigation. |
| `AddHP` | Adds hardening points for checks with a defensible pass/fail meaning. |

Each `CUST-900x` block begins with `Register`, respects `SKIPTEST`, queries a read-only system command, then displays/logs/reports its finding. These files must be **sourced by Lynis**; running `sh tests_custom` separately is not supported.

## 3. What the three tests measure

### CUST-9001 — FileVault

```sh
/usr/bin/fdesetup status
```

- `FileVault is On.` → **ENABLED**
- `FileVault is Off.` → **DISABLED**, warning for review
- Unexpected text / command failure / missing utility → **UNVERIFIED**

FileVault encrypts supported Mac disks. A status check alone does not assess recovery-key custody or encryption-policy management.

### CUST-9002 — IPv6 on Wi-Fi

```sh
/usr/sbin/networksetup -getinfo "Wi-Fi"
```

The test reads the `IPv6:` configuration field for a **network service**:

| Mode | Result | Meaning |
|---|---|---|
| Automatic | ENABLED | IPv6 is configured automatically. |
| Manual | ENABLED | IPv6 is configured manually. |
| Link-local only | ENABLED | IPv6 is allowed for local-link communication only. |
| Off / Disabled | DISABLED | IPv6 is disabled for this service. |
| Missing or unsupported | UNVERIFIED | The mode cannot be determined reliably. |

IPv6 disabled is **not automatically a security failure**; disabling IPv6 without considering network requirements can disrupt valid connectivity. If the service is renamed, pass `CUST_WIFI_SERVICE` (for example `sudo CUST_WIFI_SERVICE="Campus Wi-Fi" lynis audit system` if your sudo policy permits environment assignment). Verify service names using `networksetup -listallnetworkservices`.

### CUST-9003 — macOS Firewall

```sh
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
```

- `Firewall is enabled ...` → **ENABLED**
- `Firewall is disabled ...` → **DISABLED**, warning for review
- Unexpected text / command failure / missing utility → **UNVERIFIED**

This checks the macOS **Application Firewall** rather than `pf`, the separate packet-filter firewall.

## 4. Run the audit

```sh
sudo lynis audit system
```

Or use `sudo ./lynis audit system` from the official Lynis checkout. Lynis loads custom tests after the standard audit groups; no manual script execution is required.

**Illustrative output, not captured from a device:**

```text
[+] Custom tests
  - FileVault disk encryption                 [ ENABLED ]
  - Wi-Fi IPv6 configuration                  [ ENABLED (AUTO) ]
  - macOS Application Firewall                [ ENABLED ]
```

## 5. Inspect results and record evidence

```sh
sudo grep -E 'CUST-9001|CUST-9002|CUST-9003' /var/log/lynis.log
sudo grep '^custom_' /var/log/lynis-report.dat
```

Typical report fields:

```text
custom_filevault_status=enabled
custom_wifi_ipv6_status=enabled
custom_wifi_ipv6_mode=automatic
custom_firewall_status=enabled
```

**These lines are examples**, not claims about the machine being audited. Record the Lynis version, macOS version, date, command used, and actual three test results. If the tests are not shown, confirm you copied to the correct include directory and installed secure file permissions.

## 6. Restore the previous tests

If you made the recommended backup:

```sh
sudo cp -p "<include-directory>/tests_custom.backup" "<include-directory>/tests_custom"
```

If no custom file existed previously, remove the file you installed **only after confirming the include-directory path**. No system firewall, disk encryption, or IPv6 configuration is changed by these tests.

## 7. Limitations

- Designed for Lynis on macOS; Linux hosts are skipped.
- A renamed or disabled network service can prevent Wi-Fi IPv6 mode verification.
- The checks are configuration checks, not vulnerability scans or proof of compromise.
- OS utilities and their text output can vary; unrecognized states are intentionally classified as `UNVERIFIED`.
- Simulated test cases verify parsing/flow, not actual MacBook security state.
