import Foundation

/// Builds a CSV representation of the user's transactions. The result is
/// written to a temporary file URL so it can be shared via `ShareLink`.
enum CSVExport {
    static func transactionsCSV(_ transactions: [Transaction]) -> String {
        let header = "Date,Merchant,Category,Amount,Note,Source"
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let rows = transactions.map { tx -> String in
            let date = formatter.string(from: tx.date)
            let signed = tx.isIncome ? abs(tx.amount) : -abs(tx.amount)
            return [
                date,
                escape(tx.merchant),
                escape(tx.category.label),
                String(format: "%.2f", signed),
                escape(tx.note ?? ""),
                escape(tx.source.rawValue)
            ].joined(separator: ",")
        }

        return ([header] + rows).joined(separator: "\n")
    }

    /// Writes the CSV to a tmp file and returns the URL. Returns nil if the
    /// write fails for any reason.
    static func writeCSVFile(_ transactions: [Transaction]) -> URL? {
        let csv = transactionsCSV(transactions)
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cashie-\(stamp).csv")
        do {
            // Protect the exported file at rest until the user shares it.
            try Data(csv.utf8).write(to: url, options: [.atomic, .completeFileProtection])
            return url
        } catch {
            return nil
        }
    }

    private static func escape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return field
    }
}
