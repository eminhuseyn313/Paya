import SwiftUI

struct ExerciseLibraryView: View {

    @Environment(\.dismiss) private var dismiss

    var db: ExerciseDatabase = .shared

    @State private var filter: ExerciseDatabase.Filter = ExerciseDatabase.Filter()
    @State private var selectedExercise: Exercise? = nil
    @State private var results: [Exercise] = []
    @State private var recomputeTask: Task<Void, Never>? = nil

    func recomputeResults() {
        recomputeTask?.cancel()
        recomputeTask = Task {
            // Debounce ~150ms so rapid typing/chip taps don't stack up
            try? await Task.sleep(nanoseconds: 150_000_000)
            if Task.isCancelled { return }
            let filtered = db.filtered(filter)
            if Task.isCancelled { return }
            results = filtered
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // Search
                LibrarySearchBar(text: $filter.query)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 6)

                // Recommended-only toggle
                RecommendedToggleRow(db: db)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)

                // Filter chips
                LibraryFilterChips(filter: $filter, db: db)
                    .padding(.bottom, 8)

                // Header
                HStack {
                    if let error = db.loadError {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundColor(Pulse.critical)
                    } else {
                        Text("\(results.count) exercise\(results.count == 1 ? "" : "s")")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Pulse.textTertiary)
                    }
                    Spacer()
                    if !filter.isEmpty {
                        Button {
                            filter = ExerciseDatabase.Filter()
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Text("Clear all")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(Pulse.hydration)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)

                // Results
                if results.isEmpty {
                    LibraryEmptyState(
                        filter: filter,
                        hasError: db.loadError != nil,
                        isLoading: db.isLoading
                    )
                } else {
                    ScrollView {
                                            LazyVStack(spacing: 8) {
                                                ForEach(Array(results.enumerated()), id: \.element.id) { index, exercise in
                                                    ExerciseRow(exercise: exercise) {
                                                        selectedExercise = exercise
                                                    }
                                                    .onAppear {
                                                        // Prefetch thumbnails for the next 10 rows
                                                        for offset in 1...10 {
                                                            let prefetchIndex = index + offset
                                                            guard prefetchIndex < results.count,
                                                                  let url = results[prefetchIndex].thumbnailURL else {
                                                                continue
                                                            }
                                                            Task.detached(priority: .background) {
                                                                _ = await ImageCache.shared.load(
                                                                    from: url,
                                                                    targetSize: CGSize(width: 60, height: 60)
                                                                )
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.bottom, 20)
                                        }
                }
            }
            .navigationTitle("Exercise Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(item: $selectedExercise) { exercise in
                ExerciseDetailView(exercise: exercise)
            }
        }
        .onAppear {
                    db.loadIfNeeded()
                    recomputeResults()
                }
                .onChange(of: filter) { _, _ in
                    recomputeResults()
                }
                .onChange(of: db.isLoaded) { _, _ in
                    recomputeResults()
                }
                .onChange(of: db.showOnlyRecommended) { _, _ in
                    recomputeResults()
                }
    }
}

// MARK: - Recommended Toggle Row

struct RecommendedToggleRow: View {
    @Bindable var db: ExerciseDatabase

    var body: some View {
        HStack(spacing: 10) {
            Button {
                db.showOnlyRecommended.toggle()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: db.showOnlyRecommended
                          ? "star.fill"
                          : "star")
                        .font(.caption)
                    Text(db.showOnlyRecommended ? "Recommended only" : "Show all exercises")
                        .font(.caption.weight(.semibold))
                }
                .foregroundColor(db.showOnlyRecommended ? .white : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(db.showOnlyRecommended
                    ? Pulse.warning
                    : Color(.secondarySystemBackground))
                .clipShape(Capsule())
            }

            if db.isLoaded {
                Text(db.showOnlyRecommended
                     ? "\(db.recommendedCount) essentials"
                     : "\(db.totalCuratedCount) total")
                    .font(.caption)
                    .foregroundColor(Pulse.textTertiary)
            }

            Spacer()
        }
    }
}

// MARK: - Search Bar

struct LibrarySearchBar: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Pulse.textTertiary)
            TextField("Search exercises, muscles, equipment", text: $text)
                .focused($isFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Pulse.textTertiary)
                }
            }
        }
        .payaCard(padding: 10)
    }
}

// MARK: - Filter Chips

struct LibraryFilterChips: View {
    @Binding var filter: ExerciseDatabase.Filter
    var db: ExerciseDatabase

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    Button("All muscles") { filter.muscle = nil }
                    Divider()
                    ForEach(db.allMuscles, id: \.self) { muscle in
                        Button(muscle.capitalized) { filter.muscle = muscle }
                    }
                } label: {
                    ChipLabel(
                        text: filter.muscle?.capitalized ?? "Muscle",
                        isActive: filter.muscle != nil
                    )
                }

                Menu {
                    Button("All equipment") { filter.equipment = nil }
                    Divider()
                    ForEach(db.allEquipment, id: \.self) { eq in
                        Button(eq.capitalized) { filter.equipment = eq }
                    }
                } label: {
                    ChipLabel(
                        text: filter.equipment?.capitalized ?? "Equipment",
                        isActive: filter.equipment != nil
                    )
                }

                Menu {
                    Button("All levels") { filter.level = nil }
                    Divider()
                    ForEach(db.allLevels, id: \.self) { level in
                        Button(level.capitalized) { filter.level = level }
                    }
                } label: {
                    ChipLabel(
                        text: filter.level?.capitalized ?? "Level",
                        isActive: filter.level != nil
                    )
                }

                Menu {
                    Button("All categories") { filter.category = nil }
                    Divider()
                    ForEach(db.allCategories, id: \.self) { cat in
                        Button(cat.capitalized) { filter.category = cat }
                    }
                } label: {
                    ChipLabel(
                        text: filter.category?.capitalized ?? "Category",
                        isActive: filter.category != nil
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

struct ChipLabel: View {
    var text: String
    var isActive: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption.weight(.semibold))
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
        }
        .foregroundColor(isActive ? .white : .primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isActive ? Pulse.hydration : Color(.secondarySystemBackground))
        .clipShape(Capsule())
    }
}

// MARK: - Row

struct ExerciseRow: View {
    let exercise: Exercise
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                CachedAsyncImage(
                                    url: exercise.thumbnailURL,
                                    contentMode: .fill,
                                    targetSize: CGSize(width: 60, height: 60),
                                    localAssetName: exercise.localIllustrationAssetName
                                )
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        if exercise.isRecommended {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundColor(Pulse.warning)
                        }
                        Text(exercise.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Pulse.textPrimary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                    }

                    Text(exercise.primaryMusclesLabel)
                        .font(.caption)
                        .foregroundColor(Pulse.textTertiary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        LevelBadge(level: exercise.level)
                        if let eq = exercise.equipment {
                            Text(eq.capitalized)
                                .font(.system(size: 9, weight: .semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Pulse.surfaceElevatedFallback)
                                .foregroundColor(Pulse.textTertiary)
                                .clipShape(Capsule())
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Pulse.textTertiary)
            }
            .payaCard(padding: 10)
        }
        .buttonStyle(PulsePress())
    }
}

struct LevelBadge: View {
    let level: String

    var color: Color {
        switch level.lowercased() {
        case "beginner":     return Pulse.positive
        case "intermediate": return Pulse.warning
        case "expert":       return Pulse.critical
        default:             return .secondary
        }
    }

    var body: some View {
        Text(level.capitalized)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}

// MARK: - Empty State

struct LibraryEmptyState: View {
    let filter: ExerciseDatabase.Filter
    let hasError: Bool
    let isLoading: Bool

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            if isLoading {
                ProgressView()
                    .scaleEffect(1.4)
                Text("Loading exercises…")
                    .font(.headline)
                    .foregroundColor(Pulse.textTertiary)
            } else if hasError {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 44))
                    .foregroundColor(Pulse.textTertiary)
                Text("Couldn't load exercises")
                    .font(.headline)
                Text("Make sure exercises.json is added to the Paya target in Xcode.")
                    .font(.caption)
                    .foregroundColor(Pulse.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else if !filter.query.isEmpty || !filter.isEmpty {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 44))
                    .foregroundColor(Pulse.textTertiary)
                Text("No exercises match")
                    .font(.headline)
                Text("Try clearing some filters, or toggle 'Show all exercises'.")
                    .font(.caption)
                    .foregroundColor(Pulse.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
