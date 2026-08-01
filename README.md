# Custom Sound Bank

Native SwiftUI iPhone app that turns a MIDI controller into a customizable sound bank.

## Signal chain

`MIDI controller` → `iRig Pro I/O MIDI IN` → `iPhone app` → `iRig audio output` → `speaker or mixer`

## Features (MVP)

- 36 bundled instruments across six categories (piano, strings, organ, music box, synth lead, synth pad)
- Core MIDI input with note on/off, velocity, sustain pedal, and channel filtering
- Low-latency `AVAudioEngine` output routed to the active iOS audio device
- Record short samples from the iPhone microphone
- Trim recordings, assign a root key, and play chromatically from MIDI
- Library for saved custom instruments

## Requirements

- macOS with Xcode 16+
- iPhone running iOS 17+
- IK Multimedia iRig Pro I/O
- Lightning/USB connection cable for iPhone

## Open in Xcode

```bash
open CustomSoundBank.xcodeproj
```

Select the `CustomSoundBank` scheme, choose your iPhone, and run.

## Hardware setup

See [docs/HARDWARE_SETUP.md](docs/HARDWARE_SETUP.md).

## Testing

```bash
xcodebuild test -project CustomSoundBank.xcodeproj -scheme CustomSoundBank -destination 'platform=iOS Simulator,name=iPhone 17'
```

Device acceptance checks are documented in [docs/TEST_MATRIX.md](docs/TEST_MATRIX.md).

## Sound assets

Bundled instruments use SF2 soundfonts in `CustomSoundBank/Resources/SoundBanks/`. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for licensing.

## Regenerate Xcode project

If you add files or targets, update `project.yml` and run:

```bash
xcodegen generate
```
