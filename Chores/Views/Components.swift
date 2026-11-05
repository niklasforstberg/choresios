import SwiftUI

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var fullWidth = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.app(17, .semibold))
            .foregroundStyle(Theme.onPink)
            .padding(.horizontal, 20)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 44)
            .background(Capsule().fill(Theme.pink))
            .opacity(isEnabled ? 1 : 0.55)
            .offset(y: configuration.isPressed ? 1 : 0)
            .contentShape(Capsule())
    }
}

struct GhostButtonStyle: ButtonStyle {
    var border = Theme.ink
    var minHeight: CGFloat = 36

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.app(17, .medium))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 14)
            .frame(minHeight: minHeight)
            .overlay(Capsule().strokeBorder(border, lineWidth: 1.5))
            .opacity(configuration.isPressed ? 0.6 : 1)
            .contentShape(Capsule())
    }
}

struct IconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var size: CGFloat = 40

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .frame(width: size, height: size)
            .overlay(Circle().strokeBorder(Theme.rule, lineWidth: 1.5))
            .opacity(isEnabled ? (configuration.isPressed ? 0.6 : 1) : 0.3)
            .contentShape(Circle())
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static var primaryWide: PrimaryButtonStyle { PrimaryButtonStyle(fullWidth: true) }
}

extension ButtonStyle where Self == GhostButtonStyle {
    static var ghost: GhostButtonStyle { GhostButtonStyle() }
}

extension ButtonStyle where Self == IconButtonStyle {
    static var icon: IconButtonStyle { IconButtonStyle() }
}

// MARK: - Surfaces and text

/// A loose sheet of paper on the table.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 20) { content }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.sheet))
    }
}

/// The scrolling page every screen sits on.
struct Page<Content: View>: View {
    var refresh: (() async -> Void)?
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) { content }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 48)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.paper.ignoresSafeArea())
        .refreshable { await refresh?() }
    }
}

struct PageTitle: View {
    let text: String
    var body: some View {
        Text(text).font(.app(33, .bold)).tracking(-0.66)
    }
}

struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text).font(.app(21, .semibold)).tracking(-0.4)
    }
}

struct Muted: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View { Text(text).foregroundStyle(Theme.muted) }
}

struct ErrorText: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View { Text(text).font(.app(17, .medium)).foregroundStyle(Theme.error) }
}

struct SuccessText: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View { Text(text).font(.app(17, .medium)).foregroundStyle(Theme.blue) }
}

/// A labelled input, styled like the web's.
struct Field<Content: View>: View {
    let label: String
    var hint: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.app(15, .medium))
            content.appInput()
            if let hint { Muted(hint).font(.app(13.6)) }
        }
    }
}

extension View {
    func appInput() -> some View {
        self
            .font(.app(17))
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.sheet))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.rule, lineWidth: 1.5))
    }
}

struct DashedRule: View {
    var body: some View {
        Line()
            .stroke(Theme.rule, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
            .frame(height: 1.5)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            Path { p in
                p.move(to: CGPoint(x: 0, y: rect.midY))
                p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            }
        }
    }
}

/// Printed in two inks, a little off register: pink with blue over it.
struct TwoInk: View {
    let text: String
    let size: CGFloat
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let blend: BlendMode = scheme == .dark ? .screen : .multiply
        ZStack(alignment: .topLeading) {
            Text(text).foregroundStyle(Theme.pink)
            Text(text).foregroundStyle(Theme.blue)
                .offset(x: size * 0.035, y: size * 0.03)
                .blendMode(blend)
        }
        .font(.app(size, .bold))
        .tracking(-size * 0.06)
        .monospacedDigit()
        // Room for what the frame leaves out: the last letter's tracking and the blue's offset.
        .padding(.trailing, size * 0.1)
        .padding(.bottom, size * 0.03)
        .compositingGroup()
    }
}

struct MemberDot: View {
    let label: String
    let color: MemberColor?
    var size: CGFloat = 30

    var body: some View {
        Text(label)
            .font(.app(size * 0.48, .bold))
            .foregroundStyle(color?.on ?? .white)
            .frame(width: size, height: size)
            .background(Circle().fill(color?.ink ?? Theme.muted))
    }
}

// MARK: - Layout

/// Lays children out in rows, wrapping like inline elements.
struct FlowLayout: Layout {
    var spacing: CGFloat = 5

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(proposal.width ?? .infinity, subviews)
        guard let last = rows.last else { return .zero }
        return CGSize(width: rows.map(\.width).max() ?? 0, height: last.y + last.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(bounds.width, subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y + (row.height - size.height) / 2),
                                      proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row { var indices: [Int] = []; var y: CGFloat = 0; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(_ maxWidth: CGFloat, _ subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for (i, view) in subviews.enumerated() {
            let size = view.sizeThatFits(.unspecified)
            if !row.indices.isEmpty && row.width + spacing + size.width > maxWidth {
                rows.append(row)
                row = Row(y: row.y + row.height + spacing)
            }
            row.width += (row.indices.isEmpty ? 0 : spacing) + size.width
            row.height = max(row.height, size.height)
            row.indices.append(i)
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}

// MARK: - Async actions

/// Runs a request from a button, keeping its error and whether it's busy.
@MainActor @Observable
final class Action {
    var isRunning = false
    var error: String?
    var succeeded = false

    func run(_ work: @escaping () async throws -> Void) {
        guard !isRunning else { return }
        isRunning = true
        error = nil
        succeeded = false
        Task {
            do {
                try await work()
                succeeded = true
            } catch {
                self.error = error.localizedDescription
            }
            isRunning = false
        }
    }

    func reset() {
        error = nil
        succeeded = false
    }
}
