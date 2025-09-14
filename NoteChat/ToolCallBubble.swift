import SwiftUI

struct ToolCallBubble: View {
    enum Status { case idle, running, success, error }
    let title: String
    let subtitle: String?
    let status: Status
    let requestView: AnyView?
    let responseView: AnyView?
    @State private var expanded = false
    @Environment(\.tokens) private var T

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) { expanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    statusDot
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.callout.weight(.semibold)).foregroundStyle(T.text)
                        if let subtitle { Text(subtitle).font(.footnote).foregroundStyle(T.textSecondary) }
                    }
                    Spacer(minLength: 12)
                    Group { expanded ? AnyView(AppIcon.chevronUp(12).foregroundStyle(T.textSecondary)) : AnyView(AppIcon.chevronDown(12).foregroundStyle(T.textSecondary)) }
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: T.radiusMedium, style: .continuous)
                        .fill(T.bubbleTool)
                        .overlay(RoundedRectangle(cornerRadius: T.radiusMedium).stroke(T.borderSoft))
                )
            }
            .buttonStyle(.plain)

            if expanded {
                Divider().overlay(T.borderSoft)
                HStack(alignment: .top, spacing: 0) {
                    if let requestView {
                        ToolPane(title: "Request", content: requestView)
                        if responseView != nil { Divider().overlay(T.borderSoft) }
                    }
                    if let responseView {
                        ToolPane(title: "Response", content: responseView)
                    }
                }
                .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity))
                .background(RoundedRectangle(cornerRadius: T.radiusLarge).fill(T.surfaceElevated))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: T.radiusLarge, style: .continuous)
                .fill(T.surface)
                .shadow(color: T.shadow, radius: expanded ? 10 : 3, y: expanded ? 6 : 1)
        )
        .overlay(RoundedRectangle(cornerRadius: T.radiusLarge).stroke(T.borderSoft))
    }

    @ViewBuilder private var statusDot: some View {
        let color: Color = {
            switch status {
            case .idle: return T.textSecondary.opacity(0.6)
            case .running: return T.accent
            case .success: return .green
            case .error: return .red
            }
        }()
        Circle().fill(color).frame(width: 8, height: 8)
    }

    private struct ToolPane: View {
        @Environment(\.tokens) private var T
        let title: String
        let content: AnyView
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title).font(.footnote.weight(.semibold)).foregroundStyle(T.textSecondary)
                    Spacer()
                    Button {
                        // best-effort; authors can supply explicit strings by wrapping Text
                        UIPasteboard.general.string = nil
                    } label: {
                        AppIcon.copy(14).foregroundStyle(T.textSecondary)
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 12).padding(.top, 10)
                ScrollView {
                    content
                        .textSelection(.enabled)
                        .font(.system(.callout, design: .monospaced))
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: T.radiusSmall).fill(T.codeBg))
                }.frame(minHeight: 80, maxHeight: 240)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
