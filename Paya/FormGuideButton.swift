import SwiftUI

// MARK: - Form Guide Button
// Shows library images + instructions for a program exercise, when a
// plausible library match exists. Renders nothing otherwise.

struct FormGuideButton: View {

    let exerciseName: String
    var tint: Color = Pulse.hydration

    var db: ExerciseDatabase = .shared

    @State private var matched: Exercise? = nil
    @State private var showDetail = false

    var body: some View {
        Group {
            if let matched = matched {
                Button {
                    showDetail = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.caption)
                        Text("Form guide")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundColor(tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(tint.opacity(0.1))
                    .clipShape(Capsule())
                }
                .sheet(isPresented: $showDetail) {
                    ExerciseDetailView(exercise: matched)
                }
            }
        }
        .task(id: exerciseName) {
            db.loadIfNeeded()
            // Wait briefly for the DB if it's mid-load
            for _ in 0..<20 where !db.isLoaded {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            matched = ExerciseLibraryMatcher.match(name: exerciseName)
        }
    }
}//
//  FormGuideButton.swift
//  Paya
//
//  Created by Emin Huseynzade on 13.07.26.
//

