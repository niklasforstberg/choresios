import SwiftUI

struct MemberColor {
    let ink: Color
    let on: Color
}

/// Ported from choresweb's src/lib/members.ts; keep the two in step.
enum Members {
    // The three print inks, then what two of them make overprinted, each with the colour its letters are set in.
    // The keys are what the API stores as a member's chosen colour.
    static let palette: [(key: String, color: MemberColor)] = [
        ("pink", MemberColor(ink: Color(hex: 0xe6007a), on: .white)),
        ("blue", MemberColor(ink: Color(hex: 0x0a6cf0), on: .white)),
        ("yellow", MemberColor(ink: Color(hex: 0xffd23f), on: Color(hex: 0x1b2140))),
        ("purple", MemberColor(ink: Color(hex: 0x6b2fd0), on: .white)), // pink over blue
        ("green", MemberColor(ink: Color(hex: 0x00875a), on: .white)), // blue over yellow
        ("orange", MemberColor(ink: Color(hex: 0xff5a36), on: Color(hex: 0x1b2140))), // pink over yellow
        ("navy", MemberColor(ink: Color(hex: 0x1b2140), on: .white)),
        ("teal", MemberColor(ink: Color(hex: 0x0e8a9a), on: .white)),
    ]

    static func color(_ key: String) -> MemberColor? { palette.first { $0.key == key }?.color }

    // The paper sheet marks entries with initials. Where two members share one,
    // both get their first two letters instead.
    static func labels(_ members: [HouseholdMember]) -> [Int: String] {
        func initial(_ m: HouseholdMember) -> String { String(m.name.prefix(1)).uppercased() }
        var counts: [String: Int] = [:]
        for m in members { counts[initial(m), default: 0] += 1 }
        return Dictionary(uniqueKeysWithValues: members.map { m in
            let second = String(m.name.dropFirst().prefix(1)).lowercased()
            return (m.id, counts[initial(m)]! > 1 ? initial(m) + second : initial(m))
        })
    }

    // Members keep the colour they chose. The rest keep their place in the palette, by joining order,
    // and only move on to a free colour when someone has chosen theirs.
    static func colorKeys(_ members: [HouseholdMember]) -> [Int: String] {
        let keys = palette.map(\.key)
        func chosen(_ m: HouseholdMember) -> String? { m.color.flatMap { keys.contains($0) ? $0 : nil } }
        var used = Set(members.compactMap(chosen))
        var result: [Int: String] = [:]
        for (i, m) in members.sorted(by: { $0.id < $1.id }).enumerated() {
            if let own = chosen(m) { result[m.id] = own; continue }
            let key = ([keys[i % keys.count]] + keys).first { !used.contains($0) } ?? keys[i % keys.count]
            used.insert(key)
            result[m.id] = key
        }
        return result
    }

    static func colors(_ members: [HouseholdMember]) -> [Int: MemberColor] {
        colorKeys(members).compactMapValues(color)
    }
}
