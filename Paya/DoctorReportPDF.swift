import UIKit

// MARK: - Doctor Report PDF
//
// UIPrintPageRenderer handles pagination for us (a report can run past one
// page once flare dates/medications/correlations are listed out) — hand-
// rolling that math is a common source of clipped/overlapping text, so this
// leans on the same rendering path iOS itself uses for Print.

enum DoctorReportPDF {

    static func render(_ report: DoctorReport) -> Data {
        let formatter = UISimpleTextPrintFormatter(attributedText: attributedString(for: report))
        formatter.perPageContentInsets = UIEdgeInsets(top: 36, left: 36, bottom: 36, right: 36)

        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)

        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter, 72dpi
        renderer.setValue(pageRect, forKey: "paperRect")
        renderer.setValue(pageRect, forKey: "printableRect")

        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, pageRect, nil)
        for page in 0..<max(1, renderer.numberOfPages) {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: page, in: UIGraphicsGetPDFContextBounds())
        }
        UIGraphicsEndPDFContext()

        return pdfData as Data
    }

    private static func attributedString(for report: DoctorReport) -> NSAttributedString {
        let text = NSMutableAttributedString()

        func append(_ string: String, font: UIFont, color: UIColor = .black, spacingAfter: CGFloat = 6) {
            let paragraph = NSMutableParagraphStyle()
            paragraph.paragraphSpacing = spacingAfter
            text.append(NSAttributedString(
                string: string + "\n",
                attributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
            ))
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        append("Paya Health Summary", font: .boldSystemFont(ofSize: 22), spacingAfter: 2)
        append(
            "\(report.profileName) — \(dateFormatter.string(from: report.periodStart)) to \(dateFormatter.string(from: .now)) (\(report.periodDays) days)",
            font: .systemFont(ofSize: 12),
            color: .darkGray,
            spacingAfter: 18
        )

        append("Flare Activity", font: .boldSystemFont(ofSize: 16), spacingAfter: 4)
        append("\(report.flareDayCount) flare day\(report.flareDayCount == 1 ? "" : "s") logged in this period.", font: .systemFont(ofSize: 13))
        if !report.flareDates.isEmpty {
            let dates = report.flareDates.map { dateFormatter.string(from: $0) }.joined(separator: ", ")
            append(dates, font: .systemFont(ofSize: 12), color: .darkGray, spacingAfter: 14)
        } else {
            append(" ", font: .systemFont(ofSize: 6), spacingAfter: 10)
        }

        append("Sleep & Recovery", font: .boldSystemFont(ofSize: 16), spacingAfter: 4)
        append("Average sleep: \(report.avgSleepHours.map { String(format: "%.1fh/night", $0) } ?? "no data") — trend: \(report.sleepTrend)", font: .systemFont(ofSize: 13))
        if let hrv = report.avgHRV {
            append(String(format: "Average HRV: %.0fms", hrv), font: .systemFont(ofSize: 13))
        }
        if let rhr = report.avgRestingHR {
            append(String(format: "Average resting heart rate: %.0f bpm", rhr), font: .systemFont(ofSize: 13), spacingAfter: 14)
        } else {
            append(" ", font: .systemFont(ofSize: 6), spacingAfter: 10)
        }

        append("Training Load", font: .boldSystemFont(ofSize: 16), spacingAfter: 4)
        append("\(report.totalSessions) completed sessions (\(String(format: "%.1f", report.avgSessionsPerWeek))/week average), \(Int(report.totalVolumeKg))kg total volume lifted.", font: .systemFont(ofSize: 13), spacingAfter: 14)

        if !report.medications.isEmpty {
            append("Medication Adherence", font: .boldSystemFont(ofSize: 16), spacingAfter: 4)
            for med in report.medications {
                let line = med.dosesExpected > 0
                    ? "\(med.name) (\(med.dose), \(med.frequency)): \(med.dosesTaken)/\(med.dosesExpected) doses logged — \(med.adherencePercent)%"
                    : "\(med.name) (\(med.dose), as needed): \(med.dosesTaken) doses logged"
                append(line, font: .systemFont(ofSize: 13))
            }
            append(" ", font: .systemFont(ofSize: 6), spacingAfter: 10)
        }

        if report.checkInCount > 0 {
            append("Self-Reported Wellness", font: .boldSystemFont(ofSize: 16), spacingAfter: 4)
            append("\(report.checkInCount) morning check-ins logged in this period.", font: .systemFont(ofSize: 13))
            if let energy = report.avgCheckInEnergy {
                append("Average self-reported energy: \(String(format: "%.1f", energy))/3", font: .systemFont(ofSize: 13))
            }
            if let soreness = report.avgCheckInSoreness {
                append("Average soreness: \(String(format: "%.1f", soreness))/5", font: .systemFont(ofSize: 13))
            }
            if !report.topBehaviors.isEmpty {
                let behaviors = report.topBehaviors.map { tag, count in
                    let label = BehaviorTags.tag(for: tag)?.label ?? tag
                    return "\(label) (\(count)x)"
                }.joined(separator: ", ")
                append("Most frequent behaviors tagged: \(behaviors)", font: .systemFont(ofSize: 12), color: .darkGray, spacingAfter: 14)
            } else {
                append(" ", font: .systemFont(ofSize: 6), spacingAfter: 10)
            }
        }

        if !report.topCorrelations.isEmpty {
            append("Patterns Observed in Self-Tracked Data", font: .boldSystemFont(ofSize: 16), spacingAfter: 4)
            for insight in report.topCorrelations {
                append("• \(insight.text)", font: .systemFont(ofSize: 12), color: .darkGray)
            }
            append(" ", font: .systemFont(ofSize: 6), spacingAfter: 10)
        }

        append(
            "Generated by Paya, a personal self-tracking app. All figures are self-reported or from consumer wearables (not clinical-grade instruments) and are provided for context, not diagnosis.",
            font: .italicSystemFont(ofSize: 10),
            color: .gray
        )

        return text
    }
}
