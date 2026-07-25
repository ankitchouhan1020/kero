# Security Policy

## Supported Versions

Only the latest release of Sora receives security fixes. Updates ship
through the in-app updater and https://kero.sh.

## Reporting a Vulnerability

Please use GitHub private vulnerability reporting:
https://github.com/ankitchouhan1020/sora/security/advisories/new

If that doesn't work for you, email hi@egoist.dev.

Please don't open a public issue for anything you believe is
exploitable before it has been fixed. Include reproduction steps and
the Sora version (Sora → About Sora) you tested.

## Scope

Sora embeds libghostty (vendored in `Vendor/libghostty-spm`) for
terminal emulation. In scope here: Sora's configuration and host
integration of it — clipboard access, escape-sequence handling that
crosses a trust boundary, the update chain, and anything that lets
terminal output reach data outside the session. Vulnerabilities in
upstream Ghostty itself should also be reported to the Ghostty
project: https://github.com/ghostty-org/ghostty/security.
