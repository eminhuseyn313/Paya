import SwiftUI

// MARK: - Exercise Detail View
// Shows the two exercise images (usually start/end position), full instructions,
// muscles targeted, and metadata.

struct ExerciseDetailView: View {

    @Environment(\.dismiss) private var dismiss
    let exercise: Exercise

    @State private var currentImageIndex: Int = 0
    @State private var hasAppeared = false

    var body: some View {
        NavigationStack {
            ZStack {
                Pulse.canvasFallback.ignoresSafeArea()
                BreathingOrb(color: Pulse.hydration, size: 200)
                    .offset(y: -300)
                    .opacity(0.25)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {

                    // Image carousel
                    ExerciseImageCarousel(
                        urls: exercise.imageURLs,
                        currentIndex: $currentImageIndex,
                        localAssetName: exercise.localIllustrationAssetName
                    )

                    // Header info
                    VStack(alignment: .leading, spacing: 8) {
                        Text(exercise.name)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(Pulse.textPrimary)

                        HStack(spacing: 6) {
                            LevelBadge(level: exercise.level)
                            if let category = exercise.category as String? {
                                Text(category.capitalized)
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Pulse.hydration.opacity(0.12))
                                    .foregroundColor(Pulse.hydration)
                                    .clipShape(Capsule())
                            }
                            if let mechanic = exercise.mechanic {
                                Text(mechanic.capitalized)
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Pulse.positive.opacity(0.12))
                                    .foregroundColor(Pulse.positive)
                                    .clipShape(Capsule())
                            }
                            if let force = exercise.force {
                                Text(force.capitalized)
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Pulse.warning.opacity(0.12))
                                    .foregroundColor(Pulse.warning)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)

                    // Muscles
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Muscles worked")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16)

                        VStack(alignment: .leading, spacing: 6) {
                            if !exercise.primaryMuscles.isEmpty {
                                HStack(alignment: .top, spacing: 6) {
                                    Text("PRIMARY")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(Pulse.textTertiary)
                                        .frame(width: 62, alignment: .leading)
                                    ForEach(Array(Set(exercise.primaryMuscles)).sorted(), id: \.self) { m in                                        Text(m.capitalized)
                                            .font(.caption.weight(.bold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Pulse.critical.opacity(0.15))
                                            .foregroundColor(Pulse.critical)
                                            .clipShape(Capsule())
                                    }
                                    Spacer()
                                }
                            }
                            if !exercise.secondaryMuscles.isEmpty {
                                HStack(alignment: .top, spacing: 6) {
                                    Text("SECONDARY")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(Pulse.textTertiary)
                                        .frame(width: 62, alignment: .leading)
                                    ForEach(exercise.secondaryMuscles, id: \.self) { m in
                                        Text(m.capitalized)
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Pulse.surfaceElevatedFallback)
                                            .foregroundColor(Pulse.textPrimary)
                                            .clipShape(Capsule())
                                    }
                                    Spacer()
                                }
                            }
                            if let equipment = exercise.equipment {
                                HStack(alignment: .top, spacing: 6) {
                                    Text("EQUIPMENT")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(Pulse.textTertiary)
                                        .frame(width: 62, alignment: .leading)
                                    HStack(spacing: 4) {
                                        Image(systemName: "dumbbell")
                                            .font(.caption)
                                        Text(equipment.capitalized)
                                            .font(.caption.weight(.semibold))
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Pulse.hydration.opacity(0.12))
                                    .foregroundColor(Pulse.hydration)
                                    .clipShape(Capsule())
                                    Spacer()
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // Instructions
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Instructions")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16)

                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { index, step in
                                InstructionStep(number: index + 1, text: step)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    Spacer().frame(height: 30)
                }
                .padding(.top, 8)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 12)
            }
            }
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(exercise.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Pulse.textPrimary)
                        .lineLimit(1)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Pulse.textSecondary)
                }
            }
        }
        .presentationDetents([.large])
        .onAppear { withAnimation(.easeOut(duration: 0.5).delay(0.1)) { hasAppeared = true } }
    }
}

// MARK: - Image Carousel

struct ExerciseImageCarousel: View {
    let urls: [URL]
    @Binding var currentIndex: Int
    var localAssetName: String? = nil

    var body: some View {
        VStack(spacing: 8) {
            if let localAssetName {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Pulse.surfaceElevatedFallback)
                        .aspectRatio(1.4, contentMode: .fit)
                    Image(localAssetName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(36)
                }
                .padding(.horizontal, 16)
                Text("Original illustration — this exercise predates the photo library")
                    .font(.caption2)
                    .foregroundColor(Pulse.textTertiary)
            } else if urls.isEmpty {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Pulse.surfaceElevatedFallback)
                        .aspectRatio(1.4, contentMode: .fit)
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 40))
                        .foregroundColor(Pulse.textTertiary)
                }
                .padding(.horizontal, 16)
            } else {
                TabView(selection: $currentIndex) {
                    ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                        CachedAsyncImage(
                                                    url: url,
                                                    contentMode: .fit,
                                                    targetSize: CGSize(width: 600, height: 400)
                                                )
                                                .background(Pulse.surfaceElevatedFallback)
                                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                                .tag(index)
                    }
                }
                .frame(height: 260)
                .tabViewStyle(.page(indexDisplayMode: urls.count > 1 ? .always : .never))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .padding(.horizontal, 16)

                if urls.count > 1 {
                    Text(currentIndex == 0 ? "Start position" : "End position")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Pulse.textTertiary)
                }
            }
        }
    }
}

// MARK: - Instruction Step

struct InstructionStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Pulse.hydration.opacity(0.15))
                    .frame(width: 24, height: 24)
                Text("\(number)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(Pulse.hydration)
            }
            Text(text)
                .font(.subheadline)
                .foregroundColor(Pulse.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}//
//  ExerciseDetailView.swift
//  Paya
//
//  Created by Emin Huseynzade on 05.07.26.
//

