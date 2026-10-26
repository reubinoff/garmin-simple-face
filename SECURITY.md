# Security Policy

## Supported Versions

| Version | Supported |
| ------- | --------- |
| 1.0.0 (latest release) | :white_check_mark: |
| `main` branch | :white_check_mark: |
| Older builds | :x: |

Fixes are made on `main` and shipped in the next release.

## Reporting a Vulnerability

Please **do not open a public issue** for a security problem.

Report it privately through GitHub's private vulnerability reporting:

1. Open this repository's **Security** tab.
2. Click **Report a vulnerability**.
3. Fill in the form. The report is visible only to you and the maintainer (GitHub Security Advisories).

GitHub's guide: [Privately reporting a security vulnerability](https://docs.github.com/code-security/security-advisories/guidance-on-reporting-and-writing/privately-reporting-a-security-vulnerability).

<!-- Optional e-mail contact: the maintainer can add a security e-mail address here, e.g.
     "or e-mail <SECURITY-EMAIL-PLACEHOLDER>". Leave it out until a real address is chosen. -->

### What to include

* What the problem is and its impact.
* Steps to reproduce: watch model, firmware / Connect IQ version, the watch-face version or commit, and settings.
* A proof of concept, logs or screenshots, if you have them.
* Any fix or mitigation you suggest.

### What to expect

* An acknowledgement within a few days.
* Updates as the report is investigated, and credit in the advisory if you want it.

This is a personal hobby watch face maintained in spare time. There is no formal SLA or bug bounty.

## Scope

* Clean Air is a Garmin Connect IQ **watch face** for the fēnix 9 Pro 47mm.
* It requests one permission, `SensorHistory` (to read the Body Battery history). It has no network, positioning or
  communication permissions.
* It stores only its own display settings (Application.Properties) on the watch. It sends and stores no personal data off the device.
* In scope: this repository's source, build scripts and GitHub Actions workflows.
* Out of scope: Garmin firmware, the Connect IQ SDK, the simulator, the Connect IQ Store and the Garmin Connect app. Report those to Garmin.
