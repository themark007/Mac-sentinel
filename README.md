# MacSentinel

MacSentinel is a native macOS monitoring and control dashboard for CPU, memory, process pressure, storage usage, containers, installed apps, alerts, and shareable health reports.

## Build

```sh
Scripts/build_app.sh
```

Outputs:

- `dist/MacSentinel.app`
- `dist/MacSentinel.zip`
- `/tmp/macsentinel-build/MacSentinel.app` signed clean copy

## Feature Set

- Live CPU, load, thermal, RAM, swap/compression, and process sampling
- Flagged process detection for high CPU, high memory, thread spikes, stopped, and zombie states
- Storage buckets for apps, downloads, media, caches, app containers, developer data, container runtimes, logs, and temp areas
- Safe cache cleanup using Trash instead of destructive deletion
- Docker, Podman, Colima, Lima, and OrbStack runtime visibility
- Installed app inventory with reveal, quit, and Trash actions for non-system apps
- Menu bar live monitor
- Persistent alert rules with optional macOS notifications
- Insight engine with practical recommendations
- JSON snapshot export and Markdown health report export

## Distribution Notes

The current build is the full-control edition. It is best suited for direct distribution and notarization because system monitoring, process control, broad storage scans, and cache cleanup can require privileges that are not compatible with a strict Mac App Store sandbox.

For a Mac App Store edition, use `Packaging/AppStore.entitlements` as the starting point and gate deep file scanning behind user-selected folders or security-scoped access. Process termination and unrestricted storage scanning may need to be removed, narrowed, or moved to a separate helper design depending on review feedback.
