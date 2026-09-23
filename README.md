<h1 align="center">
  <br>
  Tidy - iPhone Storage Cleaner
</h1>

<p align="center">
  <b>A beautiful, fast, and completely free iOS app to clean up your iPhone storage.</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Swift-5.9-F05138.svg?style=flat&logo=swift" alt="Swift">
  <img src="https://img.shields.io/badge/SwiftUI-Blue.svg?style=flat&logo=swift" alt="SwiftUI">
  <img src="https://img.shields.io/badge/iOS-17.0+-black.svg?style=flat&logo=apple" alt="iOS 17.0+">
  <img src="https://img.shields.io/badge/Architecture-MVVM-green.svg?style=flat" alt="Architecture">
</p>

---

## 📱 About Tidy

**Tidy** is a powerful iOS utility app built entirely in Swift and SwiftUI. It scans your device to find large, redundant, or blurry media, and duplicate contacts, helping you reclaim precious storage space with just a few taps. Unlike many cleaner apps on the App Store, Tidy is completely free, with no subscriptions or hidden paywalls.

## ✨ Features

- **📊 Storage Dashboard**: Beautiful, at-a-glance visualization of your device's storage capacity and reclaimable space.
- **🖼️ Similar Photos**: Uses Apple's **Vision framework** (`VNFeaturePrintObservation`) to generate perceptual hashes and group near-identical or burst photos.
- **📱 Screenshots**: Quickly identify and bulk-delete old screenshots.
- **🎥 Large Videos**: Sorts and lists videos by file size so you can tackle the biggest space-hogs first.
- **👓 Blurry Photos**: Uses **CoreImage** edge detection algorithms to flag blurry and out-of-focus images.
- **👥 Duplicate Contacts**: Scans for duplicate contacts by name, email, or phone number, and cleanly merges them using the **Contacts framework**.
- **🗜️ Video Compression**: Compresses large videos natively using **AVFoundation**, keeping the visual quality while drastically reducing file size.
- **🔒 Private Vault**: Securely hide sensitive media behind **Face ID**, Touch ID, or a passcode.

## 🛠️ Architecture & Tech Stack

Tidy is built with modern iOS development best practices:

- **SwiftUI**: 100% SwiftUI for building fluid, declarative, and responsive user interfaces.
- **Swift Concurrency (`async/await`)**: Heavy scanning tasks (like image hashing and file size calculations) are offloaded to background threads and Actor-isolated services to ensure the UI remains buttery smooth.
- **MVVM Pattern**: Clean separation of concerns using the Model-View-ViewModel architecture, leveraging `@Observable` macros for state management.
- **Native Frameworks**: 
  - `Photos` (PHAsset management, deletions)
  - `Vision` (Machine learning image similarity)
  - `CoreImage` (Blurriness detection)
  - `Contacts` (Duplicate detection and merging)
  - `AVFoundation` (Video compression)
  - `LocalAuthentication` (Face ID / Touch ID)

## 🧪 Developer "Test Mode"

Tidy includes a built-in **Test Mode** (available only in `#if DEBUG` builds). You can toggle it via the ladybug icon on the Dashboard to access:
- **Mock Data Injection**: Generates fake photos and contacts so you can test the UI on the Simulator without needing a real iCloud library.
- **Dry Run Deletions**: Allows you to test the entire selection and deletion flow without actually deleting files from your device.
- **Simulated Permissions**: Test how the app reacts to "Denied" or "Limited" permission states without needing to dive into the iOS Settings app.

## 🚀 Getting Started

### Prerequisites
- Xcode 15.0+
- iOS 17.0+ target device or Simulator

### Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/harshitkumark/Tidy.git
   ```
2. Open `tidy.xcodeproj` in Xcode.
3. Select your desired simulator or connected device.
4. Hit **Cmd + R** to build and run the app!

## 🔐 Privacy by Design
Tidy processes all your photos, videos, and contacts **100% locally** on your device. No data is ever uploaded to external servers, and the app does not even include networking code. Your data stays yours.

---
*Built as a selection task for the App Builder Intern role.*
