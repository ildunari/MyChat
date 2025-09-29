import SwiftUI

/// Media Studio gallery - main entry point for media creation tools.
/// Currently features Canvas Studio with plans to expand to Photo Editor, Video Studio, and Audio Workshop.
struct MediaWorkspaceView: View {
    @Environment(\.tokens) private var T
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Media Studio")
                            .font(.largeTitle.bold())
                            .foregroundStyle(T.text)
                        Text("Creative tools for images, video, and audio")
                            .font(.subheadline)
                            .foregroundStyle(T.textSecondary)
                    }
                    .padding(.top, 20)
                    
                    // Tools Grid
                    LazyVGrid(columns: [GridItem(.flexible())], spacing: 20) {
                        canvasStudioCard
                        
                        // Future expansion cards will go here:
                        // photoEditorCard
                        // videoStudioCard
                        // audioWorkshopCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .background(T.bg.opacity(0.4).ignoresSafeArea())
        }
    }
    
    @ViewBuilder
    private var canvasStudioCard: some View {
        NavigationLink {
            canvasStudioPlaceholder
        } label: {
            LiquidGlassPanel(
                cornerRadius: 26,
                padding: EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20),
                shadowRadius: 20,
                shadowOpacity: 0.28
            ) {
                VStack(spacing: 16) {
                    // Hero Image
                    Image("MediaCanvasHero")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(T.borderSoft.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: T.shadow.opacity(0.12), radius: 8, x: 0, y: 4)
                    
                    // Content
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label {
                                Text("Canvas Studio")
                                    .font(.title2.bold())
                                    .foregroundStyle(T.text)
                            } icon: {
                                Image(systemName: "wand.and.stars")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(T.accent)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(T.accent)
                        }
                        
                        Text("Create, remix, and organize AI-generated artwork with powerful generation tools")
                            .font(.subheadline)
                            .foregroundStyle(T.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        // Feature Pills
                        HStack(spacing: 8) {
                            featurePill("Generate", icon: "sparkles")
                            featurePill("Import", icon: "photo.badge.plus")
                            featurePill("Organize", icon: "square.grid.2x2")
                        }
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Canvas Studio")
        .accessibilityHint("Tap to open AI image generation and canvas management")
    }
    
    @ViewBuilder
    private func featurePill(_ text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2.weight(.semibold))
            Text(text)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(T.accent)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(T.accentSoft, in: Capsule())
    }
    
    // MARK: - Canvas Studio Placeholder
    
    @ViewBuilder
    private var canvasStudioPlaceholder: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            Image(systemName: "wand.and.stars")
                .font(.system(size: 72))
                .foregroundStyle(T.accent)
                .padding(.bottom, 8)
            
            // Title
            Text("Canvas Studio")
                .font(.largeTitle.bold())
                .foregroundStyle(T.text)
            
            // Description
            VStack(spacing: 12) {
                Text("AI Image Generation & Management")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(T.textSecondary)
                
                Text("Full canvas interface coming soon with:\n• Multi-provider AI image generation\n• Variation controls & remixing\n• Canvas library management\n• Photo import & organization")
                    .font(.body)
                    .foregroundStyle(T.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            // Status Badge
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.caption.weight(.semibold))
                Text("In Development")
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(T.accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(T.accentSoft, in: Capsule())
            .padding(.top, 8)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(T.bg.opacity(0.4).ignoresSafeArea())
        .navigationTitle("Canvas Studio")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Media Studio Gallery") {
    MediaWorkspaceView()
        .environment(\.tokens, ThemeFactory.make(style: .terracotta, colorScheme: .light))
}

#Preview("Canvas Placeholder") {
    NavigationStack {
        MediaWorkspaceView()
            .environment(\.tokens, ThemeFactory.make(style: .coolSlate, colorScheme: .dark))
    }
}