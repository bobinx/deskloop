struct PlaybackSuspensionReasons: OptionSet, Sendable {
    let rawValue: UInt8

    static let displaySleep = Self(rawValue: 1 << 0)
    static let systemSleep = Self(rawValue: 1 << 1)
    static let lowPowerMode = Self(rawValue: 1 << 2)

    mutating func set(_ reason: Self, suspended: Bool) {
        if suspended {
            insert(reason)
        } else {
            remove(reason)
        }
    }

    func shouldPause(isOccluded: Bool) -> Bool {
        !isEmpty || isOccluded
    }
}
