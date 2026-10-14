# Changelog

## Version 1.0 — 2026-10-14

Rebuilt the repository for the assignment **Lynis-Based macOS Security Audit Using Custom FileVault, Firewall, and IPv6 Security Tests**.

- Added `CUST-9001`: FileVault full-disk encryption.
- Added `CUST-9002`: IPv6 mode of the macOS Wi-Fi network service.
- Added `CUST-9003`: macOS Application Firewall state.
- Preserved Lynis's original sourcing model and custom-test function calls.
- Made all three checks read-only and classified failed/unknown outputs as unverified.
- Removed the previous `FIRE-9001`, `CRYP-9001`, firewall stealth-mode, and `pf` audit logic that was outside the new assignment scope.
- Rewrote the project README and added the installation/audit guide, ten-command reference, and implementation/testing guide.
- Added mock regression coverage and GitHub Actions shell validation.

**Author and developer:** Utkrish Mishra

The official Lynis `tests_custom.template` is retained as a reference for reviewing the upstream custom-test style. Real host settings and screenshots have **not** been fabricated; the actual Mac audit must be performed locally.
