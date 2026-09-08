# Privacy Policy — Before You Post

**Last updated: 7 September 2026**

Before You Post is an Android app that helps you find and hide sensitive
details in a photo before you share it.

This policy explains exactly what the app does with your photos and your
data. It is written to be accurate rather than reassuring; where something
is outside the developer's control, it says so.

---

## The short version

- **Your photos are analysed on your device.** The app does not upload them
  anywhere.
- **The app collects nothing about you.** No account, no sign-in, no
  analytics, no advertising, no crash reporting, no identifiers.
- **The only thing the app stores is your light/dark theme preference.**
- **The app includes Google's ML Kit**, which brings its own networking
  component. See [Third-party components](#third-party-components) — this is
  the one part not fully under the developer's control, and it is described
  honestly below.

---

## What the app does with your photos

When you choose a photo or take one:

1. Android's own photo picker or camera hands a single image to the app.
   The app never browses your gallery and has no access to photos you did
   not pick.
2. The image is analysed **on your device** by Google ML Kit to find faces,
   text and QR/barcodes. Text that is found is checked against rules
   written into the app (patterns for phone numbers, email addresses, web
   links, card numbers and security codes, addresses, vehicle number
   plates and API keys).
3. You review what was found and choose what to hide.
4. If you tap **Protect image**, a new copy is created in the device's
   memory with the areas you selected obscured. **Your original photo is
   never modified.**

The app makes no network requests of its own at any point in this process.

## What is stored, and where

| What | Where | When it is removed |
|---|---|---|
| Your light/dark theme choice | On the device, in the app's private storage | When you uninstall the app |
| The protected image | Only in memory, unless you act | Discarded when you leave the screen |
| A protected image you **Save** | Your device's photo gallery | You control it, like any photo |
| A temporary copy created when you **Share** | The app's private temporary folder | Cleared by Android |

Nothing is stored on any server, because there is no server. The app has no
backend.

## Permissions

| Permission | Why |
|---|---|
| `WRITE_EXTERNAL_STORAGE` (Android 9 and older only) | To save a protected image to your gallery. On Android 10 and later this is not requested at all. |
| `INTERNET`, `ACCESS_NETWORK_STATE` | **Not used by this app's own code.** These are added automatically by a Google library included with ML Kit — see below. |

The app does not request access to your contacts, location, microphone,
files, or your photo library as a whole.

## Third-party components

The app includes **Google ML Kit** for face detection, text recognition and
barcode scanning. These run on your device and, according to Google's
documentation, do not upload your images.

However, ML Kit brings in a Google component called
`com.google.android.datatransport`, which is the reason the app declares the
`INTERNET` and `ACCESS_NETWORK_STATE` permissions. It exists to send usage
and diagnostic information about the ML Kit libraries to Google. That data
is handled by Google, under
[Google's Privacy Policy](https://policies.google.com/privacy), not by this
app or its developer.

This is stated plainly because the honest claim is *"your photos are
analysed on your device"*, not *"nothing can ever leave your device"*. The
second would be untrue.

The app also uses these open-source components, none of which access the
network: `image_picker`, `shared_preferences`, `image`, `share_plus` and
`gal`.

## When you share

Tapping **Share** hands the protected image to whichever app you pick from
Android's share sheet — a messaging app, email, cloud storage, and so on.
From that moment the image is governed by **that** app's privacy policy, not
this one. Choosing where a protected image goes is your decision.

## What the app cannot promise

Detection is automatic and imperfect. It will sometimes miss things and
sometimes flag things that are not sensitive. The app deliberately describes
what it finds as *potential* risks, always lets you review before anything
is hidden, and provides a manual tool for covering anything it missed.

**Always check a protected image yourself before sharing it.** Blur and
pixelation obscure content but are weaker than a solid blackout, which is
why text defaults to blackout.

## Children

The app is not directed at children and collects no personal information
from anyone, including children.

## Changes to this policy

If the app changes in a way that affects this policy, this document will be
updated and the date at the top changed.

## Contact

Questions about this policy can be sent to:

**aryan138alam@gmail.com**

Developer: **Fardeen Alam**
