import SwiftUI
import SwiftData

struct SupplementsManagerView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    var onSave: () -> Void

    @State private var supplements: [UserSupplement] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(supplements, id: \.id) { supplement in
                        SupplementEditRow(
                            supplement: supplement,
                            onDelete: {
                                UserSupplementStore.delete(supplement, context: modelContext)
                                reload()
                            },
                            onChanged: { try? modelContext.save() }
                        )
                    }

                    Button {
                        _ = UserSupplementStore.add(context: modelContext)
                        reload()
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add supplement")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundColor(Color(hex: "2563EB"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(hex: "2563EB").opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .navigationTitle("My Supplements")
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
        }
        .onAppear { reload() }
    }

    private func reload() {
        UserSupplementStore.seedIfNeeded(goal: appState.profile.goal, context: modelContext)
        supplements = UserSupplementStore.all(context: modelContext)
    }
}

struct SupplementEditRow: View {

    @Bindable var supplement: UserSupplement
    let onDelete: () -> Void
    let onChanged: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                TextField("Name", text: $supplement.name)
                    .font(.subheadline.weight(.semibold))
                    .onChange(of: supplement.name) { _, _ in onChanged() }

                Toggle("", isOn: $supplement.isActive)
                    .labelsHidden()
                    .tint(Color(hex: "059669"))
                    .onChange(of: supplement.isActive) { _, _ in onChanged() }

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                        .frame(width: 30, height: 30)
                        .background(Color.red.opacity(0.08))
                        .clipShape(Circle())
                }
            }
            HStack(spacing: 8) {
                TextField("Dose (e.g. 5g)", text: $supplement.dose)
                    .font(.caption)
                    .padding(8)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onChange(of: supplement.dose) { _, _ in onChanged() }
                TextField("Timing (e.g. Morning)", text: $supplement.timing)
                    .font(.caption)
                    .padding(8)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onChange(of: supplement.timing) { _, _ in onChanged() }
            }
        }
        .payaCard(padding: 12)
        .opacity(supplement.isActive ? 1.0 : 0.5)
    }
}//
//  SupplementsManagerView.swift
//  Paya
//
//  Created by Emin Huseynzade on 11.07.26.
//

