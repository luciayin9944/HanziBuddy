# HanziBuddy (ChineseScanner)

HanziBuddy is an iOS app that helps children learn Chinese characters they encounter in everyday life. A child can scan a line of text, choose a character, hear its pronunciation, save it, and practice it later. The interface keeps these steps simple and focused to support short learning sessions.

## What the app does

1. **Scan text:** Point the camera at a line of Chinese text and take a photo. The app recognizes text inside the visible scan frame on the device.
2. **Choose a character:** Check the recognized line and tap a Chinese character to open its card. If the scan is unsuccessful, try again.
3. **Explore the character:** See its available pinyin pronunciations and up to two example words for each pronunciation. Tap a speaker icon to hear a character or word in Mandarin.
4. **Save it:** Keep the character, its pronunciations, and its example words in a local learning collection.
5. **Review it:** Choose 10, 20, or all saved characters for a quiz, depending on how many are available. Answer pronunciation questions and word questions. The answer card shows the correct reading and offers audio playback.
6. **Track progress:** A character earns one successful pass when all its questions in a quiz are answered correctly. After three successful passes across reviews, it moves from **Learning** to **Learned**. Missed questions can be practiced again without changing the pass count.
7. **Export results:** Move a learned character back to Learning if it needs more practice, or export learned characters as a CSV through the iOS share sheet.

## Technology

| Technology | Role in the app |
| --- | --- |
| **Swift and SwiftUI** | Build the screens, navigation, scan states, character cards, and quiz interface. |
| **AVFoundation** | Capture photos from the camera and synthesize Mandarin speech. For a character with multiple pronunciations, an example word can provide context for speech playback. |
| **Apple Vision** | Recognize Simplified and Traditional Chinese text on the device. The recognition area is mapped to the scan frame shown over the camera preview. |
| **SQLite and CC-CEDICT** | Provide a bundled, read-only dictionary for character pronunciations and example word lookup. |
| **SwiftData** | Store saved characters, their pronunciations and word examples, review counts, and learned dates locally. |

The dictionary and learning records serve different purposes: the bundled SQLite file supplies reference data, while SwiftData holds each user's progress. The CSV export includes character, pinyin, learned date, and review count.

## Design choices and current limitations

The app concentrates on scanning, saving, and reviewing rather than adding a large set of learning activities. Its character cards use large text and clear controls for young learners.

The bundled dictionary covers the 3,500 simplified characters in the first-level list of the *General Standard Chinese Characters*. A scanned character outside that set may not open a card.

## Run locally

Open `ChineseScanner.xcodeproj` in Xcode and run the app on an iPhone with iOS 17 or later. Allow camera access when prompted. The dictionary is already included in the app bundle; no separate database setup is required.

## Dictionary attribution

The bundled `cedict.sqlite` is derived from CC-CEDICT and distributed under **Creative Commons Attribution-ShareAlike 4.0 International**. See [dictionary attribution and source details](MyApp/Resources/DICTIONARY_LICENSES.md) for the source, license, and data preparation notes.
