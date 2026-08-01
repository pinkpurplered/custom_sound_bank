import Foundation
import CoreMIDI

enum MIDIEventDecoder {
    static func decode(packetList: UnsafePointer<MIDIPacketList>) -> [MIDINoteEvent] {
        var events: [MIDINoteEvent] = []
        var packet = packetList.pointee.packet
        for _ in 0..<packetList.pointee.numPackets {
            let length = Int(packet.length)
            let bytes = withUnsafeBytes(of: packet.data) { rawBuffer in
                Array(rawBuffer.prefix(length))
            }
            events.append(contentsOf: decode(bytes: bytes))
            packet = MIDIPacketNext(&packet).pointee
        }
        return events
    }

    static func decode(eventList: UnsafePointer<MIDIEventList>) -> [MIDINoteEvent] {
        var events: [MIDINoteEvent] = []
        var packet = eventList.pointee.packet
        for _ in 0..<eventList.pointee.numPackets {
            let wordCount = Int(packet.wordCount)
            let words = withUnsafeBytes(of: packet.words) { rawBuffer in
                Array(rawBuffer.bindMemory(to: UInt32.self).prefix(wordCount))
            }
            events.append(contentsOf: decodeUMP(words: words))
            packet = MIDIEventPacketNext(&packet).pointee
        }
        return events
    }

    static func decode(bytes: [UInt8]) -> [MIDINoteEvent] {
        guard !bytes.isEmpty else { return [] }

        var index = 0
        var runningStatus: UInt8 = 0
        var events: [MIDINoteEvent] = []

        while index < bytes.count {
            let statusByte = bytes[index]

            if statusByte == 0xF0 {
                index += 1
                while index < bytes.count, bytes[index] != 0xF7 {
                    index += 1
                }
                if index < bytes.count {
                    index += 1
                }
                runningStatus = 0
                continue
            }

            if statusByte >= 0xF8 {
                index += 1
                continue
            }

            if statusByte >= 0xF0 {
                index += 1
                runningStatus = 0
                continue
            }

            let status: UInt8
            if statusByte >= 0x80 {
                status = statusByte
                runningStatus = statusByte
                index += 1
            } else {
                guard runningStatus != 0 else {
                    index += 1
                    continue
                }
                status = runningStatus
            }

            let channel = (status & 0x0F) + 1
            let command = status & 0xF0
            let dataByteCount = Self.dataByteCount(for: command)
            guard dataByteCount > 0 else {
                runningStatus = 0
                continue
            }
            guard index + dataByteCount - 1 < bytes.count else { return events }

            switch command {
            case 0x90:
                let note = bytes[index]
                let velocity = bytes[index + 1]
                index += 2
                if velocity == 0 {
                    events.append(MIDINoteEvent(channel: channel, kind: .noteOff(note: note, velocity: 0)))
                } else {
                    events.append(MIDINoteEvent(channel: channel, kind: .noteOn(note: note, velocity: velocity)))
                }
            case 0x80:
                let note = bytes[index]
                let velocity = bytes[index + 1]
                index += 2
                events.append(MIDINoteEvent(channel: channel, kind: .noteOff(note: note, velocity: velocity)))
            case 0xB0:
                let controller = bytes[index]
                let value = bytes[index + 1]
                index += 2
                if controller == 1 {
                    events.append(MIDINoteEvent(channel: channel, kind: .modulation(value: value)))
                } else if controller == 64 {
                    events.append(MIDINoteEvent(channel: channel, kind: .sustain(isDown: value >= 64)))
                } else if controller == 123 {
                    events.append(MIDINoteEvent(channel: channel, kind: .allNotesOff))
                }
            case 0xE0:
                let lsb = bytes[index]
                let msb = bytes[index + 1]
                index += 2
                let bendValue = UInt16(msb) << 7 | UInt16(lsb)
                events.append(MIDINoteEvent(channel: channel, kind: .pitchBend(value: bendValue)))
            default:
                index += dataByteCount
            }
        }

        return events
    }

    static func decodeUMP(words: [UInt32]) -> [MIDINoteEvent] {
        var events: [MIDINoteEvent] = []
        var index = 0
        while index < words.count {
            let word = words[index]
            let messageType = (word >> 28) & 0x0F

            switch messageType {
            case 0x2:
                events.append(contentsOf: decodeChannelVoiceUMP(word))
                index += 1
            case 0x3:
                let byteCount = Int((word >> 16) & 0x0F)
                var bytes: [UInt8] = []
                if byteCount >= 1 { bytes.append(UInt8((word >> 8) & 0x7F)) }
                if byteCount >= 2 { bytes.append(UInt8(word & 0x7F)) }
                if byteCount >= 3, index + 1 < words.count {
                    let nextWord = words[index + 1]
                    bytes.append(UInt8((nextWord >> 24) & 0x7F))
                    index += 1
                }
                events.append(contentsOf: decode(bytes: bytes))
                index += 1
            case 0x4:
                if index + 1 < words.count {
                    events.append(contentsOf: decodeChannelVoiceUMP64(high: word, low: words[index + 1]))
                    index += 2
                } else {
                    index += 1
                }
            default:
                index += 1
            }
        }
        return events
    }

    private static func decodeChannelVoiceUMP(_ word: UInt32) -> [MIDINoteEvent] {
        let status = UInt8((word >> 16) & 0xFF)
        let channel = (status & 0x0F) + 1
        let command = status & 0xF0
        let data1 = UInt8((word >> 8) & 0x7F)
        let data2 = UInt8(word & 0x7F)
        return decodeChannelVoice(status: status, channel: channel, command: command, data1: data1, data2: data2)
    }

    private static func decodeChannelVoiceUMP64(high: UInt32, low: UInt32) -> [MIDINoteEvent] {
        let status = UInt8((high >> 16) & 0xFF)
        let channel = (status & 0x0F) + 1
        let command = status & 0xF0
        let data1 = UInt8((high >> 8) & 0x7F)
        let data2 = UInt8(low & 0x7F)
        return decodeChannelVoice(status: status, channel: channel, command: command, data1: data1, data2: data2)
    }

    private static func dataByteCount(for command: UInt8) -> Int {
        switch command {
        case 0xC0, 0xD0:
            return 1
        case 0x80, 0x90, 0xA0, 0xB0, 0xE0:
            return 2
        default:
            return 0
        }
    }

    private static func decodeChannelVoice(
        status: UInt8,
        channel: UInt8,
        command: UInt8,
        data1: UInt8,
        data2: UInt8
    ) -> [MIDINoteEvent] {
        switch command {
        case 0x90:
            if data2 == 0 {
                return [MIDINoteEvent(channel: channel, kind: .noteOff(note: data1, velocity: 0))]
            }
            return [MIDINoteEvent(channel: channel, kind: .noteOn(note: data1, velocity: data2))]
        case 0x80:
            return [MIDINoteEvent(channel: channel, kind: .noteOff(note: data1, velocity: data2))]
        case 0xB0:
            if data1 == 1 {
                return [MIDINoteEvent(channel: channel, kind: .modulation(value: data2))]
            }
            if data1 == 64 {
                return [MIDINoteEvent(channel: channel, kind: .sustain(isDown: data2 >= 64))]
            }
            if data1 == 123 {
                return [MIDINoteEvent(channel: channel, kind: .allNotesOff)]
            }
            return []
        case 0xE0:
            let bendValue = UInt16(data2) << 7 | UInt16(data1)
            return [MIDINoteEvent(channel: channel, kind: .pitchBend(value: bendValue))]
        default:
            return []
        }
    }
}
