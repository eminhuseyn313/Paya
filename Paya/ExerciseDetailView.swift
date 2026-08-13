import SwiftUI

// MARK: - Exercise Detail View
// Shows the two exercise images (usually start/end position), full instructions,
// muscles targeted, and metadata.

struct ExerciseDetailView: View {

    @Environment(\.dismiss) private var dismiss
    let exercise: Exercise

    @State private var currentImageIndex: Int = 0

    var body: some View {
        NavigationStack {
            ScrollView {
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
                            .font(.title3.bold())

                        HStack(spacing: 6) {
                            LevelBadge(level: exercise.level)
                            if let category = exercise.category as String? {
                                Text(category.capitalized)
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color(hex: "2563EB").opacity(0.12))
                                    .foregroundColor(Color(hex: "2563EB"))
                                    .clipShape(Capsule())
                            }
                            if let mechanic = exercise.mechanic {
                                Text(mechanic.capitalized)
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color(hex: "059669").opacity(0.12))
                                    .foregroundColor(Color(hex: "059669"))
                                    .clipShape(Capsule())
                            }
                            if let force = exercise.force {
                                Text(force.capitalized)
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color(hex: "B45309").opacity(0.12))
                                    .foregroundColor(Color(hex: "B45309"))
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
                                        .foregroundColor(.secondary)
                                        .frame(width: 62, alignment: .leading)
                                    ForEach(Array(Set(exercise.primaryMuscles)).sorted(), id: \.self) { m in                                        Text(m.capitalized)
                                            .font(.caption.weight(.bold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color(hex: "DC2626").opacity(0.15))
                                            .foregroundColor(Color(hex: "DC2626"))
                                            .clipShape(Capsule())
                                    }
                                    Spacer()
                                }
                            }
                            if !exercise.secondaryMuscles.isEmpty {
                                HStack(alignment: .top, spacing: 6) {
                                    Text("SECONDARY")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .frame(width: 62, alignment: .leading)
                                    ForEach(exercise.secondaryMuscles, id: \.self) { m in
                                        Text(m.capitalized)
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color(.tertiarySystemBackground))
                                            .foregroundColor(.primary)
                                            .clipShape(Capsule())
                                    }
                                    Spacer()
                                }
                            }
                            if let equipment = exercise.equipment {
                                HStack(alignment: .top, spacing: 6) {
                                    Text("EQUIPMENT")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .frame(width: 62, alignment: .leading)
                                    HStack(spacing: 4) {
                                        Image(systemName: "dumbbell")
                                            .font(.caption)
                                        Text(equipment.capitalized)
                                            .font(.caption.weight(.semibold))
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color(hex: "2563EB").opacity(0.12))
                                    .foregroundColor(Color(hex: "2563EB"))
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

                    Spacer().frame(height: 20)
                }
                .padding(.top, 8)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
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
                        .fill(Color(.tertiarySystemBackground))
                        .aspectRatio(1.4, contentMode: .fit)
                    Image(localAssetName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(36)
                }
                .padding(.horizontal, 16)
                Text("Original illustration — this exercise predates the photo library")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else if urls.isEmpty {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.tertiarySystemBackground))
                        .aspectRatio(1.4, contentMode: .fit)
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
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
                                                .background(Color(.tertiarySystemBackground))
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
                        .foregroundColor(.secondary)
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
                    .fill(Color(hex: "2563EB").opacity(0.15))
                    .frame(width: 24, height: 24)
                Text("\(number)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(Color(hex: "2563EB"))
            }
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
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

