# Custom Sound Bank

Native SwiftUI iPhone app that turns a MIDI controller into a customizable sound bank.

## Signal chain

`MIDI controller` → `iRig Pro I/O MIDI IN` → `iPhone app` → `iRig audio output` → `speaker or mixer`

## Features

- **115 bundled GM instruments** across 13 categories, rendered from SF2 soundfonts (`AVAudioUnitSampler`)
- **Live tab** with favorites grid, per-pad volume, modulation/pitch wheels, and fullscreen **Live Mode** (landscape)
- **Samples tab** — searchable catalog with category filters; tap to select and preview
- **Record tab** — microphone capture (10 s max), trim, root-key assignment, chromatic playback from MIDI
- **Library tab** — manage saved user samples (use, rename, delete)
- Core MIDI input: note on/off, velocity, sustain pedal (CC 64), modulation (CC 1), pitch bend, channel filtering
- MIDI 2.0 UMP decode path via Core MIDI, with legacy byte-stream fallback
- Low-latency `AVAudioEngine` output (44.1 kHz, ~2.9 ms buffer) routed to the active iOS audio device
- Layered instruments (e.g. Piano + Strings) via `LayeredInstrumentSampler`
- 16-voice user-sample playback with varispeed transposition and mod-wheel vibrato
- Background audio mode, interruption/route recovery, diagnostics panel

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

Bundled instruments use SF2 soundfonts in `CustomSoundBank/Resources/SoundBanks/` (tracked with Git LFS):

| File | Used for |
| --- | --- |
| `GeneralUser-GS.sf2` | Default bank for most GM programs |
| `DoreMark-Fazioli-F308.sf2` | Grand Piano (Fazioli F308, SF-tailored) |
| `FreePats-DrawbarOrgan.sf2` | Hammond Drawbar |
| `FreePats-PercussiveOrgan.sf2` | Hammond Percussive |
| `FreePats-RockOrgan.sf2` | Hammond Rock |
| `FreePats-PipeOrgan.sf2` | Pipe Organ |

Legacy WAV files (`piano.wav`, `strings.wav`, etc.) remain bundled but are not used at runtime. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for licensing.

## Regenerate Xcode project

If you add files or targets, update `project.yml` and run:

```bash
xcodegen generate
```

---

## Codebase map

### Directory layout

```
CustomSoundBank/
├── CustomSoundBankApp.swift      # @main entry, scene lifecycle
├── AppDelegate.swift             # Portrait default; landscape lock for Live Mode
├── AppModel.swift                # Central orchestration (@MainActor)
├── ContentView.swift             # TabView shell
├── Audio/
│   └── AudioEngineController.swift
├── MIDI/
│   ├── MIDIService.swift
│   └── MIDIEventDecoder.swift
├── Instruments/
│   ├── InstrumentRouter.swift
│   ├── InstrumentPerformanceCore.swift
│   ├── BundledInstrumentSampler.swift
│   ├── LayeredInstrumentSampler.swift
│   ├── SampleVoicePool.swift
│   └── BundledPadSampleRenderer.swift   # offline SF2→WAV (not wired to UI)
├── Models/
│   ├── BundledPad.swift          # 117-pad catalog + PadCategory
│   ├── InstrumentKind.swift      # SelectedInstrument, UserSampleInstrument
│   ├── AppSettings.swift
│   └── MIDIUtilities.swift
├── Features/
│   ├── Perform/                  # Live tab + LiveModeView
│   ├── Browse/                   # Samples tab
│   ├── CreateSample/             # Record tab
│   ├── Library/                  # Library tab
│   └── Shared/AppTheme.swift
├── Recording/
│   └── SampleRecorder.swift
├── Storage/
│   └── SampleLibraryStore.swift
└── Resources/SoundBanks/         # SF2 soundfonts (Git LFS)

CustomSoundBankTests/
├── MIDIEventDecoderTests.swift
└── SampleLibraryStoreTests.swift
```

### Module roles

| Module | Responsibility |
| --- | --- |
| `AppModel` | Wires MIDI, audio, instruments, and library; persists favorites/volumes in UserDefaults |
| `Audio/` | `AVAudioEngine` lifecycle, session config, route snapshots, graph mutations |
| `MIDI/` | Core MIDI client, source auto-connect (iRig preference scoring), event decoding |
| `Instruments/` | Playback backends and dual-path routing (performance thread + UI thread) |
| `Models/` | Catalog, settings, shared MIDI types |
| `Features/` | SwiftUI screens grouped by tab |
| `Recording/` | Microphone capture, trim, preview; suspends performance audio |
| `Storage/` | User sample library (`manifest.json` + `Samples/*.caf`) |

### Key types

| Type | File | Role |
| --- | --- | --- |
| `AppModel` | `AppModel.swift` | Top-level state and wiring |
| `AudioEngineController` | `AudioEngineController.swift` | Engine, mixer, attach/connect instrument nodes |
| `MIDIService` | `MIDIService.swift` | Core MIDI input port and dual event handlers |
| `MIDIEventDecoder` | `MIDIEventDecoder.swift` | Bytes/UMP → `MIDINoteEvent` |
| `InstrumentRouter` | `InstrumentRouter.swift` | UI-thread selection, active-note display, preview |
| `InstrumentPerformanceCore` | `InstrumentPerformanceCore.swift` | Lock-protected MIDI→audio path from MIDI callback |
| `BundledInstrumentSampler` | `BundledInstrumentSampler.swift` | Single `AVAudioUnitSampler` + SF2 program |
| `LayeredInstrumentSampler` | `LayeredInstrumentSampler.swift` | Multiple samplers into a sub-mixer |
| `SampleVoicePool` | `SampleVoicePool.swift` | 16-voice chromatic user-sample playback |
| `SampleLibraryStore` | `SampleLibraryStore.swift` | `actor` for manifest + `.caf` CRUD |
| `BundledPad` | `BundledPad.swift` | Static 115-pad catalog |

### Navigation

```
CustomSoundBankApp
└── ContentView (TabView)
    ├── Live → PerformView
    │   ├── Live Mode (fullScreenCover, landscape)
    │   ├── Favorites grid (bundled + user samples)
    │   ├── Mod / pitch wheels + voice volume
    │   └── Settings sheet (master vol, MIDI device/channel, on-screen keyboard, diagnostics)
    ├── Samples → BrowsePadsView (search, category chips, tap-to-preview)
    ├── Record → CreateSampleView (countdown, trim, save with root key)
    └── Library → LibraryView (use, rename, delete)
```

On background/inactive: `allNotesOff()`. On active: `recoverAudio()`.

### Audio / MIDI pipeline

```
MIDI controller
    ↓
MIDIService (Core MIDI input port)
    ↓
MIDIEventDecoder → MIDINoteEvent
    ↓
    ├─ performance path (MIDI thread, sync)
    │     InstrumentPerformanceCore.handleMIDI()
    │       ├─ BundledInstrumentSampler  (AVAudioUnitSampler + SF2)
    │       ├─ LayeredInstrumentSampler    (N samplers → layerMixer)
    │       └─ SampleVoicePool             (player → varispeed → userMixer)
    │     ↓
    │   AudioEngineController → mainMixer → outputNode → iRig / speaker
    │
    └─ ui path (MainActor)
          InstrumentRouter.handleMIDIUI()  (active notes, mod/pitch for UI)
          MIDIService.recordReceivedEvent()  (diagnostics)
```

UI-initiated notes (on-screen keyboard, pad preview) go through `InstrumentRouter` → `InstrumentPerformanceCore.noteOn/noteOff`.

Channel filter: `0` = all channels; `1–16` = specific channel (`AppSettings.midiChannel`).

### Data and storage

| Data | Model | Persistence |
| --- | --- | --- |
| Bundled catalog | `BundledPad`, `PadCategory`, `LayerSpec` | Static in `BundledPad.swift` |
| Selected instrument | `SelectedInstrument` (`.bundled` / `.user`) | Runtime in `InstrumentRouter` |
| User samples | `UserSampleInstrument` | `Application Support/CustomSoundBank/manifest.json` + `Samples/{uuid}.caf` |
| Preferences | `AppSettings` | UserDefaults (favorites, volumes, master volume, MIDI channel) |

Legacy favorite IDs (`piano`, `strings`, etc.) are migrated to current pad IDs on load.

### Bundled instruments

| Metric | Value |
| --- | --- |
| Total pads | 117 |
| Categories | 13 — Piano & Keys, Mallets & Bells, Organ, Guitar, Bass, Strings, Choir & Voice, Brass, Woodwind, Synth Lead, Synth Pad, World, Percussion |
| Layered pads | 1 — `piano_strings_layer` (Grand Piano + String Ensemble) |
| Default Live favorites | 7 — Yamaha Grand Lite, piano+strings, strings, church organ, music box, saw lead, warm pad |

Catalog is defined in `BundledPad.catalog`. Each pad maps to a GM program and optionally a specific soundfont file.

### Project config

| File | Purpose |
| --- | --- |
| `project.yml` | XcodeGen spec — iOS 17, iPhone-only, background audio, mic permission, test target |
| `.gitattributes` | `*.sf2` via Git LFS |
| `.githooks/` | LFS hooks + `commit-msg` co-author stripping |
| `docs/HARDWARE_SETUP.md` | iRig wiring and iOS audio/MIDI settings |
| `docs/TEST_MATRIX.md` | 14 manual device scenarios + automated test command |
