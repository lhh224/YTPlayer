// MARK: - SleepTimerView.swift
// YTPlayer — Features/Settings/SleepTimerView.swift
// Swift 5.7, iOS 16.0

import SwiftUI

struct SleepTimerView: View {
    @ObservedObject private var timerService = SleepTimerService.shared
    @State private var selectedMinutes: Int = 30
    
    let minuteOptions = [15, 30, 45, 60, 90]

    var body: some View {
        VStack(spacing: Spacing.md) {
            if timerService.isActive {
                HStack {
                    Image(systemName: "timer")
                        .foregroundColor(.ytRed)
                    Text("Hẹn giờ tắt sau:")
                        .font(.body)
                    Spacer()
                    Text(timerService.remainingFormatted)
                        .font(.headline)
                        .foregroundColor(.ytRed)
                        .monospacedDigit()
                    
                    Button("Hủy") {
                        timerService.cancel()
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
            } else {
                HStack {
                    Picker("Thời gian", selection: $selectedMinutes) {
                        ForEach(minuteOptions, id: \.self) { minutes in
                            Text("\(minutes) phút").tag(minutes)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Spacer()
                    
                    Button("Bắt đầu") {
                        timerService.start(minutes: selectedMinutes)
                    }
                    .font(.subheadline)
                    .foregroundColor(.ytRed)
                }
            }
        }
    }
}
