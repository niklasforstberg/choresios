import Foundation

/// The same strings as choresweb (Resources/sv.json and en.json are copies of its locales),
/// looked up by the same dotted keys, with {{name}} placeholders.
enum L10n {
    static let language = Locale.preferredLanguages.first?.hasPrefix("sv") == true ? "sv" : "en"
    static let locale = Locale(identifier: language)

    private static let strings = load(language)
    private static let fallback = load("en")

    private static func load(_ language: String) -> [String: String] {
        guard let url = Bundle.main.url(forResource: language, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        var flat: [String: String] = [:]
        func walk(_ node: [String: Any], _ prefix: String) {
            for (key, value) in node {
                if let s = value as? String { flat[prefix + key] = s }
                else if let child = value as? [String: Any] { walk(child, prefix + key + ".") }
            }
        }
        walk(json, "")
        return flat
    }

    static func t(_ key: String, _ args: [String: Any] = [:]) -> String {
        var s = strings[key] ?? fallback[key] ?? key
        for (name, value) in args { s = s.replacingOccurrences(of: "{{\(name)}}", with: "\(value)") }
        return s
    }
}

func t(_ key: String, _ args: [String: Any] = [:]) -> String { L10n.t(key, args) }
