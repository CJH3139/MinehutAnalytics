import Foundation

public enum MOTDFormatter {
    public static func plainText(_ motd: String) -> String {
        var text = motd
        text = text.replacingOccurrences(of: "<[^<>]*>", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "[§&]#[0-9a-fA-F]{6}", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "[§&][0-9a-fk-orxA-FK-ORX]", with: "", options: .regularExpression)

        var lines: [String] = []
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                if let last = lines.last, !last.isEmpty { lines.append("") }
            } else {
                lines.append(line)
            }
        }
        while lines.last == "" { lines.removeLast() }
        return lines.joined(separator: "\n")
    }
}
