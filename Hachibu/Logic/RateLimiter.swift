import Foundation

enum RateLimitDecision: Equatable {
    case ok
    case limited(retryAfterSeconds: Double)
}

/// Gleitendes Zeitfenster: höchstens `limit` Anfragen pro `windowSeconds`.
final class RateLimiter {
    private let limit: Int
    private let windowSeconds: Double
    private var timestamps: [Date] = []

    init(limit: Int, windowSeconds: Double) {
        self.limit = limit
        self.windowSeconds = windowSeconds
    }

    func tryAcquire(now: Date = Date()) -> RateLimitDecision {
        while let first = timestamps.first, now.timeIntervalSince(first) >= windowSeconds {
            timestamps.removeFirst()
        }
        if timestamps.count < limit {
            timestamps.append(now)
            return .ok
        }
        let oldest = timestamps[0]
        return .limited(retryAfterSeconds: windowSeconds - now.timeIntervalSince(oldest))
    }
}
