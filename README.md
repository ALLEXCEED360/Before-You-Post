# Before You Post

**An Android app that finds faces, personal details and QR codes in a photo, then lets you hide them before you share it.**

Everything runs on the device. No backend, no account, no image uploads.

Built with Flutter and Google ML Kit. Currently in closed testing on Google Play.

| Choose a photo | Review what was found | Share the protected copy |
|:---:|:---:|:---:|
| <img src="docs/screenshots/home-light.png" width="240"> | <img src="docs/screenshots/editor-text.png" width="240"> | <img src="docs/screenshots/result.png" width="240"> |

---

## What it finds

Three ML Kit detectors run concurrently — faces, text and barcodes — and the recognised text is then checked against hand-written rules.

| Type | What keeps it honest |
|---|---|
| **Faces** | ML Kit's detector |
| **Card numbers** | The Luhn checksum. Rejoined first when OCR splits the groups across separate lines |
| **Security codes** | The printed label. Three digits have no shape of their own, so `CVV` beside them is the entire rule |
| **API keys and secrets** | Issued prefixes — AWS, Google, GitHub, Slack, Stripe, OpenAI, Anthropic — plus JWTs, PEM headers and `NAME=value` pairs |
| **Phone numbers** | Groupings people actually write, with a consistent separator |
| **Addresses** | Three patterns — number-then-street, keyword-then-number, postcodes — with overlapping matches merged |
| **Number plates** | The match must account for most of its OCR line. Vanity plates are found by isolation instead of shape |
| **Emails and links** | Regex |
| **QR and barcodes** | ML Kit, with the decoded payload shown so you can judge it |

Everything is labelled a **potential** risk, nothing is hidden without an explicit choice, and a drag-to-draw tool covers whatever the scan missed.

---

## How it works

```
                    IMAGE
                      |
      +---------------+---------------+
   Faces             OCR          QR / barcode
      |               |               |
      |      Sensitive-text rules     |
      |      (regex + validation)     |
      +---------------+---------------+
                      |
               PRIVACY ENGINE
                      |
         User reviews each finding
                      |
              REDACTION ENGINE
                      |
               Protected image
```

Four decisions carry most of the weight.

**Reading text and judging text are separate problems.** `TextRecognitionService` knows where words are; it has no opinion on whether they are private. `SensitiveTextDetector` decides that and never touches ML Kit. An unflagged phone number is either an OCR miss or a rules miss, and those need opposite fixes — a debug-only overlay draws every line OCR read, which tells you which in about a second.

**The rules are deterministic.** Regex plus validation, not a model: readable, testable without a device, and explainable when they get something wrong.

**A cheap structural check turns an unusable pattern into a usable one.** Luhn is the clearest case — without it, "any 13–19 digit run" flags every order number and tracking ID. The same idea recurs: a number plate must dominate its OCR line, a security code needs its label, a phone number needs a real grouping. Each was added after a rule fired on something harmless.

**The redaction engine works from decoded pixels, not from the file.** It is handed the same RGBA buffer Flutter already decoded for display. So it can protect any format the phone can open (AVIF and HEIC included), a palette PNG cannot silently absorb the writes, and the pixels being edited are byte-for-byte the ones the detectors measured — the two can never disagree about EXIF rotation.

### The invariant

> `PrivacyFinding.bounds` is **always** in the original image's pixel coordinates — never screen or widget coordinates.

Every detector produces that space; only the drawing layer converts out of it. The overlay forces the image container to the image's own aspect ratio, so with no letterboxing inside the box the conversion is one multiplication and zero offsets.

---

## Architecture

```
lib/
├── models/     privacy_finding.dart — the one shared data type
├── screens/    intro, home, analysis, editor, result
├── services/   privacy_engine.dart owns every detector
│               face / text / qr / sensitive-text / redaction
├── theme/      colour, spacing and motion tokens; persisted light-dark
├── utils/      geometry.dart, regex_utils.dart
└── widgets/    overlay, finding card, region thumbnail
```

Screens talk to `PrivacyEngine`, never to a detector directly — adding QR detection to a working pipeline took one new service file and a few lines in the engine. No ML Kit type escapes its own service, so a detector can be replaced without touching the UI.

Findings are addressable rather than merely listed: twenty faces produce twenty rows all labelled "Face", so each carries a number drawn on both its box and its card, plus a thumbnail cropped from the decoded image. Tapping a box scrolls to its card, and tapping a card highlights its box.

---

## Privacy

All analysis is local. There is no upload, no account, no analytics and no crash reporting. The only thing stored is your light/dark preference.

The wording is deliberately careful. The app says *"Photos are analysed on your device"* — a description of what it does — rather than *"your photos never leave your device"*, which is an absolute claim about every dependency. ML Kit brings a Google telemetry component that reports on the ML Kit libraries themselves; the [privacy policy](docs/privacy-policy.md) says so plainly rather than glossing it.

Defaults lean toward safety: findings start selected, text defaults to blackout rather than blur, and when the rules cannot tell which words a match covers the box falls back to the whole line. Over-hiding is cosmetic; under-hiding is a privacy failure.

---

## Running it

**Requirements:** Flutter 3.47+, Android Studio, an Android device or emulator on API 24+, and NDK `28.2.13676358` installed through **SDK Manager → SDK Tools → Show Package Details → NDK (Side by side)**.

```bash
git clone https://github.com/ALLEXCEED360/Before-You-Post.git
cd Before-You-Post
flutter pub get
flutter run
```

```bash
flutter build appbundle      # for Play
flutter build apk --release
```

<details>
<summary><b>Troubleshooting</b></summary>

**`sdkmanager.bat finished with non-zero exit value -1073740791`** — the CLI shim splits `ndk;28.2.13676358` on the semicolon and crashes. Install the NDK through Android Studio's GUI so Gradle never invokes the installer.

**A release build fails at R8, or builds and then crashes on every scan** — two failures, the first hiding the second. R8 aborts over ML Kit recognisers for unused scripts; silence that and it strips the classes ML Kit loads by reflection. Both are handled in `android/app/proguard-rules.pro`. Debug builds never run R8, so neither is visible until you build a release.

**`Could not close incremental caches`** — Kotlin 2.4.0 incremental compilation on some Windows and JDK 25 setups. Already disabled in `android/gradle.properties`.

</details>

---

## Testing

```bash
flutter test
```

71 tests, all in memory with no emulator, in about two seconds.

The rules get the most coverage, because they are the likeliest to be wrong and the cheapest to check — every pattern has positive cases and the negatives that matter, including a 16-digit run that fails Luhn and a date that is not a phone number. `test/split_card_test.dart` describes ML Kit results by hand, so a card number the recogniser has broken into four lines can simply be written down.

The widget tests cover layout regressions that are invisible in normal development: dark mode, 2.0× system text scale, and two bugs that reached testers — method labels wrapping mid-word on a narrow screen, and a review panel that clipped its first card. Neither threw an exception, so both tests measure rendered geometry instead of watching for one.

---

## Known limitations

Measured, not hypothetical.

- **Blur and pixelation are weaker than blackout.** Both are lossy but not destructive. Text therefore defaults to blackout; only faces default to blur.
- **Rules recognise shapes, not meaning.** An address, plate or credential written in a form none of the patterns anticipate is invisible. One finding type is reported per line of text.
- **An unlabelled security code cannot be found**, and expiry dates are not detected at all — three digits are indistinguishable from any other three digits without the word beside them.
- **Number plates are read, not seen.** A plate too small, angled or stylised for OCR is out of reach, and non-Latin plates cannot be read at all.
- **Objects cannot be detected** — only faces, text and codes. A key, a document held in shot, a name badge: the manual tool is the honest answer for all of them.
- **English and Latin script only.**
- **Android only.** No `ios/` target is configured.
- **The protected copy is re-encoded from raw pixels**, so a palette PNG returns as full colour and AVIF or HEIC input returns as JPEG.

---

## Licence

No licence chosen yet, so default copyright applies. MIT is planned.
