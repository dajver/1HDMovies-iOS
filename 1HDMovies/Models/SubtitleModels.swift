import Foundation

struct SubtitleTrack: Identifiable {
    let id = UUID()
    let label: String
    let url: String
    let language: String
}

struct SubtitleCue {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
}

enum VTTParser {
    static func parse(_ content: String) -> [SubtitleCue] {
        var cues: [SubtitleCue] = []
        let blocks = content.components(separatedBy: "\n\n")

        for block in blocks {
            let lines = block.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: "\n")

            for (i, line) in lines.enumerated() where line.contains("-->") {
                let parts = line.components(separatedBy: "-->")
                guard parts.count == 2 else { continue }

                let start = parseTimestamp(parts[0].trimmingCharacters(in: .whitespaces))
                let end = parseTimestamp(parts[1].trimmingCharacters(in: .whitespaces)
                    .components(separatedBy: " ").first ?? "")

                guard let startTime = start, let endTime = end else { continue }

                let textLines = lines[(i + 1)...]
                let text = textLines.joined(separator: "\n")
                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if !text.isEmpty {
                    cues.append(SubtitleCue(startTime: startTime, endTime: endTime, text: text))
                }
                break
            }
        }
        return cues.sorted { $0.startTime < $1.startTime }
    }

    private static func parseTimestamp(_ str: String) -> TimeInterval? {
        let cleaned = str.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = cleaned.components(separatedBy: ":")
        guard parts.count >= 2 else { return nil }

        if parts.count == 3 {
            // HH:MM:SS.mmm
            guard let h = Double(parts[0]),
                  let m = Double(parts[1]),
                  let s = Double(parts[2].replacingOccurrences(of: ",", with: ".")) else { return nil }
            return h * 3600 + m * 60 + s
        } else {
            // MM:SS.mmm
            guard let m = Double(parts[0]),
                  let s = Double(parts[1].replacingOccurrences(of: ",", with: ".")) else { return nil }
            return m * 60 + s
        }
    }
}
