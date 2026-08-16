import SwiftUI
import SwiftData

// MARK: - Session Days Manager
// Add/remove/rename days, assign weekday, pick color.

struct SessionDaysManagerView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var onSave: () -> Void

    @State private var days: [TrainingDayConfig] = []
    @State private var dayToDelete: TrainingDayConfig? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {

                    ForEach(days, id: \.id) { day in
                        DayConfigCard(
                            day: day,
                            canDelete: days.count > 1,
                            onDelete: { dayToDelete = day },
                            onChanged: { try? modelContext.save() }
                        )
                    }

                    Button {
                        _ = TrainingDayStore.addDay(context: modelContext)
                        reload()
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add training day")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundColor(Pulse.hydration)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Pulse.hydration.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Text("New days start empty — use the composer (sliders icon on the Train tab) to add exercises from the library.")
                        .font(.caption)
                        .foregroundColor(Pulse.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .navigationTitle("Training Days")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("Delete this day?", isPresented: Binding(
                get: { dayToDelete != nil },
                set: { if !$0 { dayToDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) { dayToDelete = nil }
                Button("Delete", role: .destructive) {
                    if let day = dayToDelete {
                        TrainingDayStore.delete(day, context: modelContext)
                        reload()
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    }
                    dayToDelete = nil
                }
            } message: {
                Text("Its custom exercise composition will also be removed. Logged history is kept.")
            }
        }
        .onAppear { reload() }
    }

    private func reload() {
        TrainingDayStore.seedIfNeeded(context: modelContext)
        days = TrainingDayStore.all(context: modelContext)
    }
}

// MARK: - Day Config Card

struct DayConfigCard: View {

    @Bindable var day: TrainingDayConfig
    let canDelete: Bool
    let onDelete: () -> Void
    let onChanged: () -> Void

    private let weekdays: [(Int, String)] = [
        (0, "Unassigned"), (2, "Monday"), (3, "Tuesday"), (4, "Wednesday"),
        (5, "Thursday"), (6, "Friday"), (7, "Saturday"), (1, "Sunday")
    ]

    var body: some View {
        VStack(spacing: 10) {

            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(day.color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Text(day.code)
                        .font(.headline.bold())
                        .foregroundColor(day.color)
                }

                VStack(spacing: 6) {
                    TextField("Name", text: $day.name)
                        .font(.subheadline.weight(.semibold))
                        .onChange(of: day.name) { _, _ in onChanged() }
                    TextField("Focus (subtitle)", text: $day.focus)
                        .font(.caption)
                        .foregroundColor(Pulse.textTertiary)
                        .onChange(of: day.focus) { _, _ in onChanged() }
                }

                if canDelete {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.red)
                            .frame(width: 32, height: 32)
                            .background(Color.red.opacity(0.08))
                            .clipShape(Circle())
                    }
                }
            }

            HStack(spacing: 10) {
                // Weekday picker
                Menu {
                    ForEach(weekdays, id: \.0) { value, label in
                        Button(label) {
                            day.weekday = value
                            onChanged()
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption)
                        Text(day.weekdayName)
                            .font(.caption.weight(.semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundColor(Pulse.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Pulse.surfaceElevatedFallback)
                    .clipShape(Capsule())
                }

                // Color picker
                HStack(spacing: 6) {
                    ForEach(TrainingDayStore.presetColors, id: \.self) { hex in
                        Button {
                            day.colorHex = hex
                            onChanged()
                        } label: {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Circle().stroke(
                                        day.colorHex == hex ? Color.primary : .clear,
                                        lineWidth: 2
                                    )
                                )
                        }
                    }
                }
                Spacer()
            }
        }
        .payaCard(padding: 12)
    }
}//
//  SessionDaysManagerView.swift
//  Paya
//
//  Created by Emin Huseynzade on 09.07.26.
//

