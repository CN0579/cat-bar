import Foundation

struct AppLogStore {
    let logFileURL: URL

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    func ensureLogFileExists() {
        if !FileManager.default.fileExists(atPath: self.logFileURL.path) {
            FileManager.default.createFile(atPath: self.logFileURL.path, contents: nil)
        }
    }

    func append(entries: [AppErrorLogEntry]) {
        self.append(records: entries.map {
            (timestamp: $0.timestamp, level: $0.level, message: $0.message)
        })
    }

    private func append(records: [(timestamp: Date, level: String, message: String)]) {
        guard !records.isEmpty else { return }
        self.ensureLogFileExists()

        var content = ""
        content.reserveCapacity(records.reduce(into: 0) { partialResult, record in
            partialResult += record.message.utf8.count + record.level.utf8.count + 32
        })
        for record in records {
            content += "["
            content += Self.timestampString(from: record.timestamp)
            content += "] ["
            content += record.level.uppercased()
            content += "] "
            content += record.message
            content += "\n"
        }

        guard let data = content.data(using: .utf8),
              let handle = FileHandle(forWritingAtPath: logFileURL.path)
        else {
            return
        }
        defer { handle.closeFile() }
        handle.seekToEndOfFile()
        handle.write(data)
    }

    func clear() {
        if FileManager.default.fileExists(atPath: self.logFileURL.path) {
            try? Data().write(to: self.logFileURL, options: .atomic)
        } else {
            self.ensureLogFileExists()
        }
    }

    private static func timestampString(from date: Date) -> String {
        self.timestampFormatter.string(from: date)
    }
}
