import SwiftUI
import SwiftData

struct DoctorReportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var daysBack = 30
    @State private var isGenerating = false
    @State private var pdfData: Data? = nil
    @State private var pdfURL: URL? = nil
    @State private var genProgress = LoadProgress(total: 5)

    private static let periods: [(String, Int)] = [
        ("2 weeks", 14), ("30 days", 30), ("90 days", 90)
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Generates a one-page summary — flare frequency, sleep/HRV trends, training load, medication adherence, and any strong patterns your data shows — formatted for a rheumatology or GP visit, not a spreadsheet.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Period") {
                    Picker("Period", selection: $daysBack) {
                        ForEach(Self.periods, id: \.1) { label, days in
                            Text(label).tag(days)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    if isGenerating {
                        RealProgressBar(progress: genProgress, title: "Generating report…")
                            .padding(.vertical, 6)
                    } else {
                        Button {
                            Task { await generate() }
                        } label: {
                            Text("Generate Report")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }

                if let pdfURL {
                    Section {
                        ShareLink(item: pdfURL) {
                            Label("Share PDF", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .navigationTitle("Doctor Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func generate() async {
        isGenerating = true
        genProgress.reset(total: 5)
        defer { isGenerating = false }
        let report = await DoctorReportEngine.generate(
            daysBack: daysBack,
            profileName: appState.profile.name,
            context: modelContext,
            progress: genProgress
        )
        let data = DoctorReportPDF.render(report)
        pdfData = data

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Paya-Health-Summary.pdf")
        try? data.write(to: url)
        pdfURL = url
    }
}
