import Foundation

/// MIDI-triggered filter envelope with chord debounce. Runs off the performance thread.
final class AutoWahEnvelope: @unchecked Sendable {
    private let lock = NSLock()
    private let envelopeQueue = DispatchQueue(label: "AutoWahEnvelope", qos: .userInteractive)
    private var settings: AutoWahSettings?
    private var lastTriggerTime: TimeInterval = 0
    private var envelopeGeneration: UInt64 = 0

    /// Number of filter envelopes started (for testing).
    private(set) var triggerCount = 0

    func configure(settings: AutoWahSettings?) {
        lock.lock()
        defer { lock.unlock() }
        self.settings = settings
        cancelLocked()
    }

    func trigger(velocity: UInt8, setFrequency: @escaping @Sendable (Float) -> Void) {
        lock.lock()
        guard let settings else {
            lock.unlock()
            return
        }

        let now = ProcessInfo.processInfo.systemUptime
        let withinWindow = now - lastTriggerTime < settings.chordTriggerWindow

        if withinWindow {
            lock.unlock()
            return
        }

        lastTriggerTime = now
        envelopeGeneration += 1
        let generation = envelopeGeneration
        triggerCount += 1
        lock.unlock()

        startEnvelope(
            velocity: velocity,
            settings: settings,
            generation: generation,
            setFrequency: setFrequency
        )
    }

    func cancel() {
        lock.lock()
        defer { lock.unlock() }
        cancelLocked()
    }

    static func peakFrequency(velocity: UInt8, settings: AutoWahSettings) -> Float {
        let normalizedVelocity = Float(velocity) / 127.0
        let span = settings.openFrequency - settings.closedFrequency
        return settings.closedFrequency + normalizedVelocity * settings.velocitySensitivity * span
    }

    private func cancelLocked() {
        envelopeGeneration += 1
    }

    private func startEnvelope(
        velocity: UInt8,
        settings: AutoWahSettings,
        generation: UInt64,
        setFrequency: @escaping @Sendable (Float) -> Void
    ) {
        let closed = settings.closedFrequency
        let peak = Self.peakFrequency(velocity: velocity, settings: settings)
        let decayTarget = settings.resolvedDecayTarget

        setFrequency(closed)

        rampFrequency(
            from: closed,
            to: peak,
            duration: TimeInterval(settings.attackSeconds),
            generation: generation,
            setFrequency: setFrequency,
            completion: nil
        )

        rampFrequency(
            from: peak,
            to: decayTarget,
            duration: TimeInterval(settings.decaySeconds),
            generation: generation,
            setFrequency: setFrequency,
            completion: nil,
            delay: TimeInterval(settings.attackSeconds)
        )
    }

    private func rampFrequency(
        from start: Float,
        to end: Float,
        duration: TimeInterval,
        generation: UInt64,
        setFrequency: @escaping @Sendable (Float) -> Void,
        completion: (@Sendable () -> Void)?,
        delay: TimeInterval = 0
    ) {
        let stepInterval = 0.005
        let stepCount = max(1, Int(duration / stepInterval))
        let stepDuration = duration / Double(stepCount)

        for step in 1...stepCount {
            let progress = Float(step) / Float(stepCount)
            let frequency = exponentialInterpolation(from: start, to: end, progress: progress)
            envelopeQueue.asyncAfter(deadline: .now() + delay + stepDuration * Double(step)) { [weak self] in
                guard let self else { return }
                self.lock.lock()
                let isCurrent = self.envelopeGeneration == generation
                self.lock.unlock()
                guard isCurrent else { return }
                setFrequency(frequency)
                if step == stepCount {
                    completion?()
                }
            }
        }
    }

    private func exponentialInterpolation(from start: Float, to end: Float, progress: Float) -> Float {
        guard start > 0, end > 0, start != end else { return end }
        return start * pow(end / start, progress)
    }
}
