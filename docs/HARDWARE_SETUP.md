# Hardware Setup: iRig Pro I/O

## Connections

1. Connect the iRig Pro I/O to your iPhone with the included Lightning/USB cable.
2. Connect your MIDI controller MIDI OUT to the iRig MIDI IN using the included 2.5 mm TRS to 5-pin DIN adapter/cable.
3. Connect headphones, powered speakers, or a mixer to the iRig 1/8" stereo output.

## Power

- Use AA batteries or the optional DC supply for standalone use.
- For long sessions, use the DC supply so the iPhone can charge while performing.

## iOS audio routing

- Launch **Custom Sound Bank** after the iRig is connected.
- Open the **Perform** tab and confirm the diagnostics panel shows the iRig as the active output.
- If audio is still on the iPhone speaker, reconnect the interface and tap **Reconnect MIDI**.

## Recording custom samples

The MVP records from the **iPhone built-in microphone**.

If recording fails while the iRig is attached:

1. Finish or stop performance mode.
2. Disconnect the iRig.
3. Record and save the sample in the **Record** tab.
4. Reconnect the iRig and select the saved instrument from **Library**.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| No MIDI input | Controller is sending on the selected channel; cable is in MIDI IN, not OUT |
| No sound at speaker | iRig output volume; cable into powered speaker or mixer line input |
| High latency | Close background apps; keep sample rate at 44.1 kHz |
| Stuck notes | Tap **All Notes Off** on the Perform screen |
