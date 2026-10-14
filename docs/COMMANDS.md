# Ten Lynis commands — quick practical reference

These commands are for **Lynis installed on macOS**. Use `./lynis` instead of `lynis` when running from a source checkout. Commands 1–8 do not initiate a system audit.

| No. | Command | What it does |
|---:|---|---|
| 1 | `lynis show version` | Displays the installed Lynis version. |
| 2 | `lynis show help` | Shows basic usage and command help. |
| 3 | `lynis show commands` | Lists available Lynis commands. |
| 4 | `lynis show options` | Shows command-line flags and options. |
| 5 | `lynis show includedir` | Identifies where Lynis looks for its audit scripts and `tests_custom`. |
| 6 | `lynis show groups` | Lists available groups of built-in security tests. |
| 7 | `lynis show categories` | Lists security, privacy, and performance test categories. |
| 8 | `lynis show profiles` | Lists the detected audit configuration profiles. |
| 9 | `sudo lynis audit system` | Runs a full local system security audit including custom tests. |
| 10 | `sudo lynis audit system --quick` | Runs a local audit without interactive pauses. |

### Practical flow

First identify the include directory with command 5. Study existing files such as `tests_firewalls` and the official `tests_custom.template`. Install this project's `tests_custom` in that directory with restrictive permissions. Then run command 9 or 10 and check that the three `CUST-900x` checks appear.

### Useful non-Lynis commands to verify findings

```sh
/usr/bin/fdesetup status
/usr/sbin/networksetup -listallnetworkservices
/usr/sbin/networksetup -getinfo "Wi-Fi"
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
sudo grep 'CUST-900' /var/log/lynis.log
sudo grep '^custom_' /var/log/lynis-report.dat
```

These six additional commands are *not* counted in the assignment's ten Lynis commands; they help explain how the custom tests produce their results. Do not confuse a Wi-Fi service name with its hardware device name (`en0`, etc.).

> **Interpretation:** Results are real only when you run these commands on a macOS machine and collect its audit output. See [AUDIT_GUIDE.md](AUDIT_GUIDE.md).
