# Security

HalfBook runs in the logged-in user's session. It changes the desktop arrangement through macOS display services. It does not request administrator access, install a privileged helper, change FileVault, or enable automatic login.

The current release uses private display APIs and ad hoc signing. It has no Developer ID signature or Apple notarization. Download only from the [project's releases](https://github.com/alxcrt/halfbook/releases). Use Apple's per-app approval procedure when appropriate. Do not disable Gatekeeper globally.

## Report a vulnerability

Use [GitHub private vulnerability reporting](https://github.com/alxcrt/halfbook/security/advisories/new) if the repository offers it. If that option is unavailable, open an issue that asks for a private reporting channel without including exploit details or private data.

Describe the affected version, required access, reproduction steps, and impact. Do not submit credentials, full preference exports, private addresses, or device serial numbers.

For a display that stays blank or a failed recovery action, use the [display issue checklist](CONTRIBUTING.md#report-a-display-problem). Those reports help distinguish a security issue from unsupported hardware or a display-control failure.

## Support scope

Security fixes target the latest release. The app targets macOS 14 or later on Apple Silicon and checks display-control capabilities at runtime. Missing capabilities leave it read-only. These checks do not replace hardware testing on each macOS release. See [compatibility and test status](docs/COMPATIBILITY.md) for the limits of the available evidence.
