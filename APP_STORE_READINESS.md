# MacSentinel App Store Readiness

## Current Position

MacSentinel now has an App Store-oriented bundle identifier, version metadata, a draft sandbox entitlement file, alert settings, user-facing reports, and a clear split between a full-control edition and a sandbox-safe edition.

## Apple Constraints To Respect

- Mac App Store apps must enable App Sandbox.
- A sandboxed app must declare intended access through entitlements, and protected locations generally need user-selected access or security-scoped bookmarks.
- Temporary sandbox exceptions require explanation in App Store Connect and are not a long-term product strategy.

## Recommended Release Tracks

### Direct / Pro Edition

Use this for the strongest version of MacSentinel:

- Process termination and app quit actions
- Broad storage scans
- Container runtime discovery
- Cache cleanup to Trash
- Full Disk Access guidance
- Developer-oriented report exports

Ship this path with Developer ID signing and notarization.

### Mac App Store Edition

Use this for review-friendlier distribution:

- Keep dashboard, insights, alerts, reports, app inventory, and user-selected folder scans
- Gate storage scanning behind a folder picker and security-scoped bookmarks
- Remove or soften process termination controls
- Avoid unrestricted scanning of protected containers
- Keep cleanup actions limited to user-selected folders and app-owned data

## Next Engineering Steps

- Add an Xcode project or CI export pipeline with Developer ID and App Store signing configurations.
- Add security-scoped bookmark persistence for user-selected scan roots.
- Add a first-run privacy screen explaining local-only collection.
- Add a sandbox build flag that hides direct-control actions when App Sandbox is enabled.
- Add automated UI smoke tests for each dashboard tab.
