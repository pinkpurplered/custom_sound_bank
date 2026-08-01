#!/usr/bin/env python3
"""Render bundled instrument previews from GeneralUser GS."""

from __future__ import annotations

import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SF2 = ROOT / "CustomSoundBank/Resources/SoundBanks/GeneralUser-GS.sf2"
OUT_DIR = ROOT / "CustomSoundBank/Resources/SoundBanks"

INSTRUMENTS = {
    "piano": 0,
    "strings": 48,
    "organ": 19,
    "musicbox": 10,
    "synth_lead": 81,
    "synth_pad": 89,
}


def var_len(value: int) -> bytes:
    buffer = bytearray([value & 0x7F])
    while value > 0x7F:
        value >>= 7
        buffer.insert(0, (value & 0x7F) | 0x80)
    return bytes(buffer)


def midi_file(program: int, note: int = 60, hold_ticks: int = 720) -> bytes:
    track = bytearray()
    track += bytes([0x00, 0xC0, program])
    track += bytes([0x00, 0x90, note, 110])
    track += var_len(hold_ticks) + bytes([0x80, note, 0])
    track += bytes([0x00, 0xFF, 0x2F, 0x00])

    header = b"MThd" + struct.pack(">IHHH", 6, 0, 1, 480)
    track_chunk = b"MTrk" + struct.pack(">I", len(track)) + track
    return header + track_chunk


def main() -> int:
    if not SF2.exists():
        print(f"Missing soundfont: {SF2}", file=sys.stderr)
        return 1

    OUT_DIR.mkdir(parents=True, exist_ok=True)

    for name, program in INSTRUMENTS.items():
        midi_path = OUT_DIR / f"{name}.mid"
        wav_path = OUT_DIR / f"{name}.wav"
        midi_path.write_bytes(midi_file(program))

        subprocess.run(
            [
                "fluidsynth",
                "-ni",
                "-g",
                "1.2",
                "-r",
                "44100",
                "-F",
                str(wav_path),
                "-T",
                "wav",
                str(SF2),
                str(midi_path),
            ],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        midi_path.unlink(missing_ok=True)
        print(f"Wrote {wav_path.name} ({wav_path.stat().st_size // 1024} KB)")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
