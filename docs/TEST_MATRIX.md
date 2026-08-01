# Test Matrix

Run on a physical iPhone with iRig Pro I/O unless noted.

| ID | Scenario | Steps | Expected |
| --- | --- | --- | --- |
| T1 | MIDI note playback | Connect controller, play middle C | Sound from iRig output within acceptable latency |
| T2 | Velocity response | Play soft and hard notes | Audible level difference |
| T3 | Sustain pedal | Hold pedal, release key, release pedal | Note sustains until pedal up |
| T4 | Channel filter | Set channel to 2, play on channel 1 | No sound |
| T5 | Instrument switch | Switch across all six bundled presets | Each preset loads without crash |
| T6 | Polyphony | Hold 10+ notes | No obvious dropouts on target device |
| T7 | Rapid retrigger | Repeat staccato notes quickly | Clean retrigger, no stuck notes |
| T8 | Route reconnect | Unplug/replug iRig during app open | Diagnostics update; audio recovers after reconnect |
| T9 | Interruption | Incoming call or alarm | Audio resumes after interruption ends |
| T10 | Record workflow | Record, trim, set root, save | Saved sample appears in Library |
| T11 | Custom playback | Select saved sample, play chromatically | Root key at original pitch, other keys transpose |
| T12 | Mic permission denied | Deny microphone permission | Clear error in Record tab |
| T13 | Background | Send app to background during held note | Notes stop; no stuck audio on return |
| T14 | Delete sample | Delete from Library | File removed; instrument no longer selectable |

## Automated tests

Unit tests cover MIDI decoding, transposition math, and manifest serialization.

```bash
xcodebuild test -project CustomSoundBank.xcodeproj -scheme CustomSoundBank -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Known MVP limitations

- Bundled WAV presets are development placeholders, not final licensed multisamples.
- Built-in microphone recording may require disconnecting iRig on some iOS route configurations.
- MIDI 2.0-native controllers are supported through Core MIDI translation, but acceptance testing should still include your controller.
