import SwiftUI

// A reusable draggable/collapsible section container, visually matching Home screen sections.
struct MovableSectionContainer<Content: View>: View {
    @Environment(\.tokens) private var T
    let title: String
    let count: Int
    @Binding var isExpanded: Bool
    let maxHeight: CGFloat
    let draggedOffset: CGFloat
    var onDragChanged: (DragGesture.Value) -> Void
    var onDragEnded: (DragGesture.Value) -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                AppIcon.grabber(14).foregroundStyle(T.textSecondary)
                    .gesture(
                        DragGesture(minimumDistance: 4, coordinateSpace: .global)
                            .onChanged(onDragChanged)
                            .onEnded(onDragEnded)
                    )
                Text(title).font(.title3.bold()).foregroundStyle(T.text)
                Spacer()
                if count > 0 { Text("\(count)").font(.caption).foregroundStyle(T.textSecondary).padding(.horizontal,8).padding(.vertical,4).background(T.surface, in: Capsule()) }
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                    Group { if isExpanded { AppIcon.chevronUp(12) } else { AppIcon.chevronDown(12) } }
                        .foregroundStyle(T.textSecondary)
                }
                .buttonStyle(.plain)
            }
            if isExpanded {
                content()
                    .frame(height: maxHeight)
                    .clipped()
            }
        }
        .scaleEffect(abs(draggedOffset) > 2 ? 1.02 : 1)
        .shadow(color: T.shadow.opacity(abs(draggedOffset) > 2 ? 0.25 : 0), radius: 8, x: 0, y: 4)
    }
}

