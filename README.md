# RJ Gaming Booster

A Flutter starter project for gaming network diagnostics with a dark black-and-red interface.

## Starter features
- TCP latency measurement to a public endpoint
- HTTP download speed test
- Probe failure ratio (not true ICMP packet loss)
- Local ping history

## Important limitations
- This utility does not reduce game ping or change game network routing.
- Measurements are not the same as a game's own server ping.
- The failure ratio is an application-level probe failure estimate, not true packet loss.
- This repository contains source code only, not a signed iOS IPA.

## Build
Install Flutter, then run:

```bash
flutter pub get
flutter run
```

For iOS, an appropriate Apple signing setup is required. Never commit certificates, provisioning profiles, passwords, or API keys to this repository.
