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
            if statusByte >= 0xF0 {
                index += 1
                continue
            }

            let status: UInt8
            if statusByte >= 0x80 {
                status = statusByte
                runningStatus = statusByte
                index += 1
            } else {
                status = runningStatus
            }

            let channel = (status & 0x0F) + 1
            let command = status & 0xF0

            switch command {
            case 0x90:
                guard index + 1 < bytes.count else { return events }
                let note = bytes[index]
                let velocity = bytes[index + 1]
                index += 2
                if velocity == 0 {
                    events.append(MIDINoteEvent(channel: channel, kind: .noteOff(note: note, velocity: 0)))
                } else {
                    events.append(MIDINoteEvent(channel: channel, kind: .noteOn(note: note, velocity: velocity)))
                }
            case 0x80:
                guard index + 1 < bytes.count else { return events }
                let note = bytes[index]
                let velocity = bytes[index + 1]
                index += 2
                events.append(MIDINoteEvent(channel: channel, kind: .noteOff(note: note, velocity: velocity)))
            case 0xB0:
                guard index + 1 < bytes.count else { return events }
                let controller = bytes[index]
                let value = bytes[index + 1]
                index += 2
                if controller == 64 {
                    events.append(MIDINoteEvent(channel: channel, kind: .sustain(isDown: value >= 64)))
                } else if controller == 123 {
                    events.append(MIDINoteEvent(channel: channel, kind: .allNotesOff))
                }
            default:
                index += 1
            }
        }

        return events
    }

    static func decodeUMP(words: [UInt32]) -> [MIDINoteEvent] {
        var events: [MIDINoteEvent] = []
        for word in words {
            let messageType = (word >> 28) & 0x0F
            guard messageType == 0x2 else { continue }

            let status = UInt8((word >> 16) & 0xFF)
            let channel = UInt8((status & 0x0F) + 1)
            let command = status & 0xF0
            let data1 = UInt8((word >> 8) & 0x7F)
            let data2 = UInt8(word & 0x7F)

            switch command {
            case 0x90:
                if data2 == 0 {
                    events.append(MIDINoteEvent(channel: channel, kind: .noteOff(note: data1, velocity: 0)))
                } else {
                    events.append(MIDINoteEvent(channel: channel, kind: .noteOn(note: data1, velocity: data2)))
                }
            case 0x80:
                events.append(MIDINoteEvent(channel: channel, kind: .noteOff(note: data1, velocity: data2)))
            case 0xB0:
                if data1 == 64 {
                    events.append(MIDINoteEvent(channel: channel, kind: .sustain(isDown: data2 >= 64)))
                } else if data1 == 123 {
                    events.append(MIDINoteEvent(channel: channel, kind: .allNotesOff))
                }
            default:
                break
            }
        }
        return events
    }
}
