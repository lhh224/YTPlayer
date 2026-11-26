// SleepTimerService.swift
// YTPlayer
//
// Manages a countdown sleep timer that fires a notification when it reaches zero,
// remaining accurate across background audio execution using absolute target timestamps.

import Foundation
import Combine

final class SleepTimerService: ObservableObject {

    // MARK: - Published State

    @Published var isActive: Bool = false
    @Published var remainingSeconds: Int = 0
    @Published var selectedMinutes: Int = 30

    // MARK: - Private

    private var timer: Timer?
    private var targetEndDate: Date?

    // MARK: - Singleton

    static let shared = SleepTimerService()
    private init() {}

    // MARK: - Computed Properties

    /// Remaining time formatted as "MM:SS".
    var remainingFormatted: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Public API

    /// Start the sleep timer for the given number of minutes.
    /// If a timer is already running it is cancelled first.
    ///
    /// - Parameter minutes: Duration in minutes.
    func start(minutes: Int) {
        cancel()

        let totalSeconds = max(1, minutes * 60)
        selectedMinutes = minutes
        remainingSeconds = totalSeconds
        targetEndDate = Date().addingTimeInterval(TimeInterval(totalSeconds))
        isActive = true

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.tick()
        }

        // Ensure the timer fires even when the run loop is in common modes or background audio session
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    /// Cancel the active sleep timer.
    func cancel() {
        timer?.invalidate()
        timer = nil
        targetEndDate = nil
        isActive = false
        remainingSeconds = 0
    }

    // MARK: - Private

    private func tick() {
        guard isActive else {
            cancel()
            return
        }

        if let endDate = targetEndDate {
            let secondsLeft = Int(ceil(endDate.timeIntervalSinceNow))
            if secondsLeft > 0 {
                remainingSeconds = secondsLeft
            } else {
                fireTimer()
            }
        } else if remainingSeconds > 0 {
            remainingSeconds -= 1
        } else {
            fireTimer()
        }
    }

    private func fireTimer() {
        cancel() // sets isActive = false, invalidates timer
        NotificationCenter.default.post(name: Notification.Name("SleepTimerFired"), object: nil)
    }
}
