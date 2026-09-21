# CLAUDE.md — Project Brain: "tidy" (Storage Cleaner for iPhone)

> This file is the single source of truth. **Read it fully at the start of every session. Update sections 13 (Progress) and 14 (Decisions) after every meaningful change.**

---

## 0. How the agent must work

1. Work on ONE feature/step at a time. Never build everything at once.
2. After every change, run a build and fix all errors yourself:
   `xcodebuild -scheme tidy -destination 'platform=iOS Simulator,name=iPhone 16' build`
3. Before writing any deletion code, re-read Section 2 (Safety rules).
4. Prefer small files, clear names, comments only where logic is non-obvious.
5. After each step: update the Progress tracker (Section 13), add a line to the Decision log (Section 14) if a choice was made, and make a git commit with a clear message.
6. If something needs a manual Xcode action (new target, capability, Info.plist key, app icon), STOP and tell the user exactly what to click. Do not fake it.
7. Never invent APIs. If unsure an API exists on iOS 17, say so and choose the safest alternative.

---

## 1. Mission

A working, shippable iPhone app that helps a person free storage by finding **similar/duplicate photos, screenshots, large videos and duplicate contacts**, then deleting them **safely after review**.

Core loop: **Scan > Review > Clean.**

Judging criteria:
1. Core loop works end to end.
2. Safe: nothing deleted without explicit approval.
3. Fast and accurate scan on a large library.
4. Usable and polished.
5. Smart choices about what to build/skip, and good use of AI tools.

---

## 2. Hard rules (non-negotiable)

**Safety**
- NOTHING is deleted, merged or modified without the user seeing a Review screen and tapping an explicit confirm button.
- Deletion code lives in exactly ONE place: `DeletionService`. No view or scanner may call `PHAssetChangeRequest.deleteAssets` or `CNSaveRequest` delete directly.
- Nothing is pre-selected for deletion EXCEPT the non-best items inside a similar-photo group (the "best" one is always kept and clearly marked). The user can still untick any of them.
- Favorited photos and photos in user albums are never auto-selected. Show a small badge on them.
- Before merging contacts, offer to export a vCard backup (share sheet).
- iOS moves deleted photos to "Recently Deleted" for ~30 days. The UI must say this honestly. Do not claim space is freed instantly.
- Add a **Dry Run** switch (Test Mode) that runs the whole flow but performs no real deletion.

**Privacy**
- Everything runs on device. No networking code, no analytics SDKs, no third-party SDKs, no photos/contacts/thumbnails leaving the phone.
- Set `isNetworkAccessAllowed = false` on image requests. iCloud-only assets are skipped from analysis and labelled "Not on device".

**Scope**
- No payments, subscriptions, paywalls, trials. Every feature is free and unlocked.
- Do NOT promise or attempt to clear other apps' data, caches, junk or system storage (iOS forbids it). No "junk cleaner" wording anywhere.
- No email cleaning, login, cloud sync, iPad/Watch/Mac.
- Own name, own logo, own copy.

---

## 3. Tech stack

- iOS 17.0+, iPhone only, Swift 5.9+, SwiftUI, MVVM.
- Frameworks: Photos (PhotoKit), Vision, AVFoundation, Contacts, EventKit, LocalAuthentication, CryptoKit/Security (vault), WidgetKit, Core Image / Accelerate (blur).
- Concurrency: Swift concurrency (async/await, TaskGroup, actors). No blocking the main thread.
- Storage of results: lightweight on-disk cache (JSON/plist or SwiftData) for feature prints and scan results.
- Zero third-party dependencies.

---

## 4. Architecture and folders

```
tidy/
+-- tidyApp.swift
+-- App/
|   +-- RootView.swift
|   +-- AppState.swift
+-- Core/
|   +-- Models/
|   +-- Services/
|   |   +-- PermissionService.swift
|   |   +-- StorageService.swift
|   |   +-- PhotoLibraryService.swift
|   |   +-- SimilarPhotoScanner.swift
|   |   +-- BlurDetector.swift
|   |   +-- VideoService.swift
|   |   +-- ContactService.swift
|   |   +-- CalendarService.swift
|   |   +-- DeletionService.swift   # THE ONLY place that deletes
|   |   +-- VaultService.swift
|   |   +-- ScanCache.swift
|   +-- Protocols/
|   +-- Utilities/
+-- Features/
|   +-- Onboarding/
|   +-- Dashboard/
|   +-- SimilarPhotos/
|   +-- Screenshots/
|   +-- LargeVideos/
|   +-- DuplicateContacts/
|   +-- Review/
|   +-- Summary/
|   +-- SwipeMode/          # bonus
|   +-- Vault/              # bonus
|   +-- CalendarCleanup/    # bonus
|   +-- Settings/
+-- DesignSystem/
+-- Testing/                # DEBUG only
+-- Resources/
tidyTests/  tidyUITests/
```

Rules: Views contain no business logic. ViewModels are @MainActor ObservableObject (or @Observable). Services are protocol-backed so Test Mode and unit tests can swap in mocks.

---

## 5-16. (See full CLAUDE.md shared by developer)

Sections 5-16 cover: Feature specs (F1-F7, B1-B7), Algorithms (6.1-6.6), Test Mode (Section 7), Testing strategy (Section 8), Performance goals (Section 9), Design system (Section 10), Info.plist keys (Section 11), Manual Xcode steps (Section 12), Progress tracker (Section 13), Decision log (Section 14), Known limitations (Section 15), Submission checklist (Section 16).

---

## 13. Progress tracker (agent updates this)

- [x] Step 0 Project bootstrap + CLAUDE.md in repo
- [ ] Step 1 Foundation: design system, navigation, services protocols
- [ ] Step 2 Permissions + onboarding (all states)
- [ ] Step 3 Storage dashboard
- [ ] Step 4 TEST MODE: seeder, dry run, mocks, debug overlay
- [ ] Step 5 Photo library indexing + cache
- [ ] Step 6 Screenshots
- [ ] Step 7 Large videos
- [ ] Step 8 Similar photos
- [ ] Step 9 Duplicate contacts
- [ ] Step 10 Review + DeletionService
- [ ] Step 11 Space freed summary
- [ ] Step 12 Core-loop test pass (must pass before any bonus)
- [ ] Step 13 Performance pass + benchmark numbers
- [ ] Step 14 Polish (icon, empty states, a11y, dark mode)
- [ ] Step 15 README, 150-word note, screen recording

Session log (newest first):
- 2026-09-21: Step 0 Bootstrap. Scheme "tidy", simulator "iPhone 16". Folder structure, .gitignore, README created.

---

## 14. Decision log

| Date | Decision | Why |
|------|----------|-----|
| 2026-09-21 | Keep project name "tidy" | Already created in Xcode; renaming risks breaking refs |
