# tidy

> A privacy-first iPhone app that helps you free storage by finding similar photos, screenshots, large videos, and duplicate contacts — then deleting them safely after review.

## Features

- **Storage Dashboard** — see how much space you can reclaim at a glance
- **Similar Photos** — Vision-powered duplicate and near-duplicate detection with smart "best pick"
- **Screenshots** — bulk-select old screenshots by date
- **Large Videos** — find and preview space-hogging videos
- **Duplicate Contacts** — merge or remove duplicate contacts with backup
- **Review Before Delete** — nothing is removed without your explicit approval

## How to Run

1. Open `tidy.xcodeproj` in Xcode 16+
2. Select the `tidy` scheme and an iPhone simulator (iOS 17+)
3. Build and run (⌘R)

## Test Mode

Enable in Settings → Test Mode (DEBUG builds only). Seeds synthetic photos, videos, and contacts so every feature can be tested without private data. Includes Dry Run mode.

## Architecture

SwiftUI + MVVM. Zero third-party dependencies. Everything runs on-device — no networking code.

See [CLAUDE.md](CLAUDE.md) for full architecture documentation.

## Performance

<!-- TODO: Add benchmark results from Step 13 -->

## Screenshots

<!-- TODO: Add screenshots from Test Mode data -->

## Known Limitations

- Deleted photos stay in Recently Deleted ~30 days; space returns after that.
- iCloud-optimized photos not on device are skipped.
- File sizes may be estimated on rare assets.
- Tested on simulator with seeded data.
- Contact merge may not carry every field.

## Privacy

Everything runs on-device. No network calls, no analytics, no third-party SDKs. Verify: `grep -r "URLSession\|URLRequest\|WKWebView" tidy/` returns nothing.

## License

<!-- TODO -->
