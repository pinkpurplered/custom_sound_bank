import Foundation

enum PadCategory: String, CaseIterable, Identifiable, Sendable {
    case piano, musicBox, organ, guitar, bass, strings, choir, brass, woodwind, synthLead, synthPad, ethnic, percussion

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .piano: "Piano & Keys"
        case .musicBox: "Mallets & Bells"
        case .organ: "Organ"
        case .guitar: "Guitar"
        case .bass: "Bass"
        case .strings: "Strings"
        case .choir: "Choir & Voice"
        case .brass: "Brass"
        case .woodwind: "Woodwind"
        case .synthLead: "Synth Lead"
        case .synthPad: "Synth Pad"
        case .ethnic: "World"
        case .percussion: "Percussion"
        }
    }

    var iconName: String {
        switch self {
        case .piano: "pianokeys"
        case .musicBox: "music.note"
        case .organ: "chart.bar.doc.horizontal"
        case .guitar: "guitars"
        case .bass: "waveform"
        case .strings: "music.quarternote.3"
        case .choir: "person.3.fill"
        case .brass: "horn"
        case .woodwind: "wind"
        case .synthLead: "waveform.path"
        case .synthPad: "cloud.fill"
        case .ethnic: "globe.americas.fill"
        case .percussion: "hand.tap.fill"
        }
    }
}

struct BundledPad: Identifiable, Equatable, Sendable, Hashable {
    let id: String
    let displayName: String
    let category: PadCategory
    let gmProgram: UInt8
    /// nil uses GeneralUser-GS; set for alternate soundfonts (e.g. YDP-GrandPiano).
    let soundFontFileName: String?

    /// Bundled WAV sample basename (without extension) when this pad uses a classic exported sample.
    var bundledWAVFileName: String? {
        Self.classicWAVFileNames[id]
    }

    private static let classicWAVFileNames: [String: String] = [
        "strings_ensemble": "strings",
        "organ_drawbar": "organ",
        "musicbox_classic": "musicbox",
        "synth_lead_saw": "synth_lead",
        "synth_pad_warm": "synth_pad",
    ]

    static let catalog: [BundledPad] = [
        // Piano & Keys (GM 0–7)
        BundledPad(id: "piano_grand", displayName: "Grand Piano", category: .piano, gmProgram: 0, soundFontFileName: "YDP-GrandPiano"),
        BundledPad(id: "piano_bright", displayName: "Bright Piano", category: .piano, gmProgram: 1, soundFontFileName: nil),
        BundledPad(id: "piano_electric_grand", displayName: "Electric Grand", category: .piano, gmProgram: 2, soundFontFileName: nil),
        BundledPad(id: "piano_honky", displayName: "Honky-tonk", category: .piano, gmProgram: 3, soundFontFileName: nil),
        BundledPad(id: "piano_epiano", displayName: "Electric Piano", category: .piano, gmProgram: 4, soundFontFileName: nil),
        BundledPad(id: "piano_epiano2", displayName: "E. Piano 2", category: .piano, gmProgram: 5, soundFontFileName: nil),
        BundledPad(id: "piano_harpsichord", displayName: "Harpsichord", category: .piano, gmProgram: 6, soundFontFileName: nil),
        BundledPad(id: "piano_clavinet", displayName: "Clavinet", category: .piano, gmProgram: 7, soundFontFileName: nil),

        // Mallets & Bells (GM 8–15)
        BundledPad(id: "musicbox_celesta", displayName: "Celesta", category: .musicBox, gmProgram: 8, soundFontFileName: nil),
        BundledPad(id: "musicbox_glock", displayName: "Glockenspiel", category: .musicBox, gmProgram: 9, soundFontFileName: nil),
        BundledPad(id: "musicbox_classic", displayName: "Music Box", category: .musicBox, gmProgram: 10, soundFontFileName: nil),
        BundledPad(id: "musicbox_vibraphone", displayName: "Vibraphone", category: .musicBox, gmProgram: 11, soundFontFileName: nil),
        BundledPad(id: "musicbox_marimba", displayName: "Marimba", category: .musicBox, gmProgram: 12, soundFontFileName: nil),
        BundledPad(id: "musicbox_xylophone", displayName: "Xylophone", category: .musicBox, gmProgram: 13, soundFontFileName: nil),
        BundledPad(id: "musicbox_tubular", displayName: "Tubular Bells", category: .musicBox, gmProgram: 14, soundFontFileName: nil),
        BundledPad(id: "musicbox_dulcimer", displayName: "Dulcimer", category: .musicBox, gmProgram: 15, soundFontFileName: nil),

        // Organ (GM 16–21) — FreePats Hammond emulations for drawbar/percussive/rock
        BundledPad(id: "organ_drawbar", displayName: "Drawbar Organ", category: .organ, gmProgram: 0, soundFontFileName: "FreePats-DrawbarOrgan"),
        BundledPad(id: "organ_percussive", displayName: "Percussive Organ", category: .organ, gmProgram: 0, soundFontFileName: "FreePats-PercussiveOrgan"),
        BundledPad(id: "organ_rock", displayName: "Rock Organ", category: .organ, gmProgram: 0, soundFontFileName: "FreePats-RockOrgan"),
        BundledPad(id: "organ_church", displayName: "Church Organ", category: .organ, gmProgram: 19, soundFontFileName: nil),
        BundledPad(id: "organ_reed", displayName: "Reed Organ", category: .organ, gmProgram: 20, soundFontFileName: nil),
        BundledPad(id: "organ_accordion", displayName: "Accordion", category: .organ, gmProgram: 21, soundFontFileName: nil),

        // Guitar (GM 24–31)
        BundledPad(id: "guitar_nylon", displayName: "Nylon Guitar", category: .guitar, gmProgram: 24, soundFontFileName: nil),
        BundledPad(id: "guitar_steel", displayName: "Steel Guitar", category: .guitar, gmProgram: 25, soundFontFileName: nil),
        BundledPad(id: "guitar_jazz", displayName: "Jazz Guitar", category: .guitar, gmProgram: 26, soundFontFileName: nil),
        BundledPad(id: "guitar_clean", displayName: "Clean Guitar", category: .guitar, gmProgram: 27, soundFontFileName: nil),
        BundledPad(id: "guitar_muted", displayName: "Muted Guitar", category: .guitar, gmProgram: 28, soundFontFileName: nil),
        BundledPad(id: "guitar_overdrive", displayName: "Overdrive", category: .guitar, gmProgram: 29, soundFontFileName: nil),
        BundledPad(id: "guitar_distortion", displayName: "Distortion", category: .guitar, gmProgram: 30, soundFontFileName: nil),
        BundledPad(id: "guitar_harmonics", displayName: "Harmonics", category: .guitar, gmProgram: 31, soundFontFileName: nil),

        // Bass (GM 32–39)
        BundledPad(id: "bass_acoustic", displayName: "Acoustic Bass", category: .bass, gmProgram: 32, soundFontFileName: nil),
        BundledPad(id: "bass_finger", displayName: "Finger Bass", category: .bass, gmProgram: 33, soundFontFileName: nil),
        BundledPad(id: "bass_pick", displayName: "Pick Bass", category: .bass, gmProgram: 34, soundFontFileName: nil),
        BundledPad(id: "bass_fretless", displayName: "Fretless Bass", category: .bass, gmProgram: 35, soundFontFileName: nil),
        BundledPad(id: "bass_slap", displayName: "Slap Bass", category: .bass, gmProgram: 36, soundFontFileName: nil),
        BundledPad(id: "bass_slap2", displayName: "Slap Bass 2", category: .bass, gmProgram: 37, soundFontFileName: nil),
        BundledPad(id: "bass_synth", displayName: "Synth Bass", category: .bass, gmProgram: 38, soundFontFileName: nil),
        BundledPad(id: "bass_synth2", displayName: "Synth Bass 2", category: .bass, gmProgram: 39, soundFontFileName: nil),

        // Strings (GM 40–51)
        BundledPad(id: "strings_violin", displayName: "Violin", category: .strings, gmProgram: 40, soundFontFileName: nil),
        BundledPad(id: "strings_viola", displayName: "Viola", category: .strings, gmProgram: 41, soundFontFileName: nil),
        BundledPad(id: "strings_cello", displayName: "Cello", category: .strings, gmProgram: 42, soundFontFileName: nil),
        BundledPad(id: "strings_contrabass", displayName: "Contrabass", category: .strings, gmProgram: 43, soundFontFileName: nil),
        BundledPad(id: "strings_tremolo", displayName: "Tremolo", category: .strings, gmProgram: 44, soundFontFileName: nil),
        BundledPad(id: "strings_pizz", displayName: "Pizzicato", category: .strings, gmProgram: 45, soundFontFileName: nil),
        BundledPad(id: "strings_harp", displayName: "Harp", category: .strings, gmProgram: 46, soundFontFileName: nil),
        BundledPad(id: "strings_timpani", displayName: "Timpani", category: .strings, gmProgram: 47, soundFontFileName: nil),
        BundledPad(id: "strings_ensemble", displayName: "String Ensemble", category: .strings, gmProgram: 48, soundFontFileName: nil),
        BundledPad(id: "strings_ensemble2", displayName: "Slow Strings", category: .strings, gmProgram: 49, soundFontFileName: nil),
        BundledPad(id: "strings_synth", displayName: "Synth Strings", category: .strings, gmProgram: 50, soundFontFileName: nil),
        BundledPad(id: "strings_synth2", displayName: "Synth Strings 2", category: .strings, gmProgram: 51, soundFontFileName: nil),

        // Choir & Voice (GM 52–55)
        BundledPad(id: "choir_aahs", displayName: "Choir Aahs", category: .choir, gmProgram: 52, soundFontFileName: nil),
        BundledPad(id: "choir_oohs", displayName: "Voice Oohs", category: .choir, gmProgram: 53, soundFontFileName: nil),
        BundledPad(id: "choir_synth", displayName: "Synth Voice", category: .choir, gmProgram: 54, soundFontFileName: nil),
        BundledPad(id: "choir_orchestra_hit", displayName: "Orchestra Hit", category: .choir, gmProgram: 55, soundFontFileName: nil),

        // Brass (GM 56–63)
        BundledPad(id: "brass_trumpet", displayName: "Trumpet", category: .brass, gmProgram: 56, soundFontFileName: nil),
        BundledPad(id: "brass_trombone", displayName: "Trombone", category: .brass, gmProgram: 57, soundFontFileName: nil),
        BundledPad(id: "brass_tuba", displayName: "Tuba", category: .brass, gmProgram: 58, soundFontFileName: nil),
        BundledPad(id: "brass_muted_trumpet", displayName: "Muted Trumpet", category: .brass, gmProgram: 59, soundFontFileName: nil),
        BundledPad(id: "brass_french_horn", displayName: "French Horn", category: .brass, gmProgram: 60, soundFontFileName: nil),
        BundledPad(id: "brass_section", displayName: "Brass Section", category: .brass, gmProgram: 61, soundFontFileName: nil),
        BundledPad(id: "brass_synth", displayName: "Synth Brass 1", category: .brass, gmProgram: 62, soundFontFileName: nil),
        BundledPad(id: "brass_synth2", displayName: "Synth Brass 2", category: .brass, gmProgram: 63, soundFontFileName: nil),

        // Woodwind (GM 64–79)
        BundledPad(id: "wood_soprano_sax", displayName: "Soprano Sax", category: .woodwind, gmProgram: 64, soundFontFileName: nil),
        BundledPad(id: "wood_alto_sax", displayName: "Alto Sax", category: .woodwind, gmProgram: 65, soundFontFileName: nil),
        BundledPad(id: "wood_tenor_sax", displayName: "Tenor Sax", category: .woodwind, gmProgram: 66, soundFontFileName: nil),
        BundledPad(id: "wood_baritone_sax", displayName: "Baritone Sax", category: .woodwind, gmProgram: 67, soundFontFileName: nil),
        BundledPad(id: "wood_oboe", displayName: "Oboe", category: .woodwind, gmProgram: 68, soundFontFileName: nil),
        BundledPad(id: "wood_english_horn", displayName: "English Horn", category: .woodwind, gmProgram: 69, soundFontFileName: nil),
        BundledPad(id: "wood_bassoon", displayName: "Bassoon", category: .woodwind, gmProgram: 70, soundFontFileName: nil),
        BundledPad(id: "wood_clarinet", displayName: "Clarinet", category: .woodwind, gmProgram: 71, soundFontFileName: nil),
        BundledPad(id: "wood_piccolo", displayName: "Piccolo", category: .woodwind, gmProgram: 72, soundFontFileName: nil),
        BundledPad(id: "wood_flute", displayName: "Flute", category: .woodwind, gmProgram: 73, soundFontFileName: nil),
        BundledPad(id: "wood_recorder", displayName: "Recorder", category: .woodwind, gmProgram: 74, soundFontFileName: nil),
        BundledPad(id: "wood_pan_flute", displayName: "Pan Flute", category: .woodwind, gmProgram: 75, soundFontFileName: nil),
        BundledPad(id: "wood_blown_bottle", displayName: "Blown Bottle", category: .woodwind, gmProgram: 76, soundFontFileName: nil),
        BundledPad(id: "wood_shakuhachi", displayName: "Shakuhachi", category: .woodwind, gmProgram: 77, soundFontFileName: nil),
        BundledPad(id: "wood_whistle", displayName: "Whistle", category: .woodwind, gmProgram: 78, soundFontFileName: nil),
        BundledPad(id: "wood_ocarina", displayName: "Ocarina", category: .woodwind, gmProgram: 79, soundFontFileName: nil),

        // Synth Lead (GM 80–87)
        BundledPad(id: "synth_lead_square", displayName: "Square Lead", category: .synthLead, gmProgram: 80, soundFontFileName: nil),
        BundledPad(id: "synth_lead_saw", displayName: "Saw Lead", category: .synthLead, gmProgram: 81, soundFontFileName: nil),
        BundledPad(id: "synth_lead_calliope", displayName: "Calliope", category: .synthLead, gmProgram: 82, soundFontFileName: nil),
        BundledPad(id: "synth_lead_chiff", displayName: "Chiff Lead", category: .synthLead, gmProgram: 83, soundFontFileName: nil),
        BundledPad(id: "synth_lead_charang", displayName: "Charang", category: .synthLead, gmProgram: 84, soundFontFileName: nil),
        BundledPad(id: "synth_lead_voice", displayName: "Voice Lead", category: .synthLead, gmProgram: 85, soundFontFileName: nil),
        BundledPad(id: "synth_lead_fifths", displayName: "Fifths Lead", category: .synthLead, gmProgram: 86, soundFontFileName: nil),
        BundledPad(id: "synth_lead_bass", displayName: "Bass & Lead", category: .synthLead, gmProgram: 87, soundFontFileName: nil),

        // Synth Pad (GM 88–95)
        BundledPad(id: "synth_pad_newage", displayName: "New Age Pad", category: .synthPad, gmProgram: 88, soundFontFileName: nil),
        BundledPad(id: "synth_pad_warm", displayName: "Warm Pad", category: .synthPad, gmProgram: 89, soundFontFileName: nil),
        BundledPad(id: "synth_pad_poly", displayName: "Polysynth", category: .synthPad, gmProgram: 90, soundFontFileName: nil),
        BundledPad(id: "synth_pad_choir", displayName: "Choir Pad", category: .synthPad, gmProgram: 91, soundFontFileName: nil),
        BundledPad(id: "synth_pad_bowed", displayName: "Bowed Pad", category: .synthPad, gmProgram: 92, soundFontFileName: nil),
        BundledPad(id: "synth_pad_metallic", displayName: "Metallic Pad", category: .synthPad, gmProgram: 93, soundFontFileName: nil),
        BundledPad(id: "synth_pad_halo", displayName: "Halo Pad", category: .synthPad, gmProgram: 94, soundFontFileName: nil),
        BundledPad(id: "synth_pad_sweep", displayName: "Sweep Pad", category: .synthPad, gmProgram: 95, soundFontFileName: nil),

        // World / Ethnic (GM 104–111)
        BundledPad(id: "ethnic_sitar", displayName: "Sitar", category: .ethnic, gmProgram: 104, soundFontFileName: nil),
        BundledPad(id: "ethnic_banjo", displayName: "Banjo", category: .ethnic, gmProgram: 105, soundFontFileName: nil),
        BundledPad(id: "ethnic_shamisen", displayName: "Shamisen", category: .ethnic, gmProgram: 106, soundFontFileName: nil),
        BundledPad(id: "ethnic_koto", displayName: "Koto", category: .ethnic, gmProgram: 107, soundFontFileName: nil),
        BundledPad(id: "ethnic_kalimba", displayName: "Kalimba", category: .ethnic, gmProgram: 108, soundFontFileName: nil),
        BundledPad(id: "ethnic_bagpipe", displayName: "Bagpipe", category: .ethnic, gmProgram: 109, soundFontFileName: nil),
        BundledPad(id: "ethnic_fiddle", displayName: "Fiddle", category: .ethnic, gmProgram: 110, soundFontFileName: nil),
        BundledPad(id: "ethnic_shanai", displayName: "Shanai", category: .ethnic, gmProgram: 111, soundFontFileName: nil),

        // Percussion (GM 112–119)
        BundledPad(id: "perc_tinkle", displayName: "Tinkle Bell", category: .percussion, gmProgram: 112, soundFontFileName: nil),
        BundledPad(id: "perc_agogo", displayName: "Agogo", category: .percussion, gmProgram: 113, soundFontFileName: nil),
        BundledPad(id: "perc_steel_drums", displayName: "Steel Drums", category: .percussion, gmProgram: 114, soundFontFileName: nil),
        BundledPad(id: "perc_woodblock", displayName: "Woodblock", category: .percussion, gmProgram: 115, soundFontFileName: nil),
        BundledPad(id: "perc_taiko", displayName: "Taiko Drum", category: .percussion, gmProgram: 116, soundFontFileName: nil),
        BundledPad(id: "perc_melodic_tom", displayName: "Melodic Tom", category: .percussion, gmProgram: 117, soundFontFileName: nil),
        BundledPad(id: "perc_synth_drum", displayName: "Synth Drum", category: .percussion, gmProgram: 118, soundFontFileName: nil),
        BundledPad(id: "perc_reverse_cymbal", displayName: "Reverse Cymbal", category: .percussion, gmProgram: 119, soundFontFileName: nil),
    ]

    static let defaultPad = catalog[0]

    /// Default Live favorites: the six classic bundled WAV instruments.
    static let defaultFavoritePadIDs: [String] = [
        "piano_grand",
        "strings_ensemble",
        "organ_drawbar",
        "musicbox_classic",
        "synth_lead_saw",
        "synth_pad_warm",
    ]

    static func pad(withID id: String) -> BundledPad? {
        catalog.first { $0.id == id }
    }

    static func pads(for category: PadCategory) -> [BundledPad] {
        catalog.filter { $0.category == category }
    }

    static func pads(withIDs ids: [String]) -> [BundledPad] {
        ids.compactMap { pad(withID: $0) }
    }
}
