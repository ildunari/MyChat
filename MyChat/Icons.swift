import SwiftUI
#if canImport(PhosphorSwift)
import PhosphorSwift
#endif

enum AppIcon {
    // Always use bold weight by default
    @ViewBuilder static func gear(_ size: CGFloat = 18) -> some View {
        #if canImport(PhosphorSwift)
        Ph.gear.bold.frame(width: size, height: size)
        #else
        Image(systemName: "gear").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func home(_ size: CGFloat = 18) -> some View {
        #if canImport(PhosphorSwift)
        Ph.house.bold.frame(width: size, height: size)
        #else
        Image(systemName: "house.fill").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func chat(_ size: CGFloat = 18) -> some View {
        #if canImport(PhosphorSwift)
        Ph.chatCircleDots.bold.frame(width: size, height: size)
        #else
        Image(systemName: "message.fill").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func note(_ size: CGFloat = 18) -> some View {
        #if canImport(PhosphorSwift)
        Ph.note.bold.frame(width: size, height: size)
        #else
        Image(systemName: "note.text").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func share(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.shareNetwork.bold.frame(width: size, height: size)
        #else
        Image(systemName: "square.and.arrow.up").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func trash(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.trash.bold.frame(width: size, height: size)
        #else
        Image(systemName: "trash").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func compose(_ size: CGFloat = 18) -> some View {
        #if canImport(PhosphorSwift)
        Ph.pencilSimple.bold.frame(width: size, height: size)
        #else
        Image(systemName: "square.and.pencil").font(.system(size: size, weight: .bold))
        #endif
    }
    // Content-type glyphs used in chat history cards
    @ViewBuilder static func image(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.image.bold.frame(width: size, height: size)
        #else
        Image(systemName: "photo").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func text(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.textT.bold.frame(width: size, height: size)
        #else
        Image(systemName: "textformat").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func code(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.code.bold.frame(width: size, height: size)
        #else
        Image(systemName: "curlybraces").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func audio(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.waveform.bold.frame(width: size, height: size)
        #else
        Image(systemName: "waveform").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func file(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.file.bold.frame(width: size, height: size)
        #else
        Image(systemName: "doc").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func doc(_ size: CGFloat = 16) -> some View { file(size) }
    @ViewBuilder static func agent(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.robot.bold.frame(width: size, height: size)
        #else
        Image(systemName: "brain.head.profile").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func project(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.squaresFour.bold.frame(width: size, height: size)
        #else
        Image(systemName: "square.grid.2x2").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func user(_ size: CGFloat = 18) -> some View {
        #if canImport(PhosphorSwift)
        Ph.userCircle.bold.frame(width: size, height: size)
        #else
        Image(systemName: "person.circle").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func plus(_ size: CGFloat = 18) -> some View {
        #if canImport(PhosphorSwift)
        Ph.plus.bold.frame(width: size, height: size)
        #else
        Image(systemName: "plus").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func microphone(_ size: CGFloat = 18) -> some View {
        #if canImport(PhosphorSwift)
        Ph.microphone.bold.frame(width: size, height: size)
        #else
        Image(systemName: "mic").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func waveform(_ size: CGFloat = 18) -> some View {
        #if canImport(PhosphorSwift)
        Ph.waveform.bold.frame(width: size, height: size)
        #else
        Image(systemName: "waveform").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func paperPlane(_ size: CGFloat = 18) -> some View {
        #if canImport(PhosphorSwift)
        // Phosphor name: paper-plane-tilt
        Ph.paperPlaneTilt.bold.frame(width: size, height: size)
        #else
        Image(systemName: "paperplane.fill").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func chevronDown(_ size: CGFloat = 12) -> some View {
        #if canImport(PhosphorSwift)
        Ph.caretDown.bold.frame(width: size, height: size)
        #else
        Image(systemName: "chevron.down").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func chevronUp(_ size: CGFloat = 12) -> some View {
        #if canImport(PhosphorSwift)
        Ph.caretUp.bold.frame(width: size, height: size)
        #else
        Image(systemName: "chevron.up").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func copy(_ size: CGFloat = 14) -> some View {
        #if canImport(PhosphorSwift)
        Ph.copy.bold.frame(width: size, height: size)
        #else
        Image(systemName: "doc.on.doc").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func info(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.info.bold.frame(width: size, height: size)
        #else
        Image(systemName: "info.circle").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func close(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.x.bold.frame(width: size, height: size)
        #else
        Image(systemName: "xmark").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func stop(_ size: CGFloat = 18) -> some View {
        // Prefer a consistent SF Symbol here to avoid dependency symbol mismatches
        Image(systemName: "stop.fill").font(.system(size: size, weight: .bold))
    }
    @ViewBuilder static func checkCircle(_ filled: Bool = true, size: CGFloat = 18) -> some View {
        #if canImport(PhosphorSwift)
        (filled ? Ph.checkCircle : Ph.circle).bold.frame(width: size, height: size)
        #else
        Image(systemName: filled ? "checkmark.circle.fill" : "circle").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func starsHeader(_ size: CGFloat = 14) -> some View {
        #if canImport(PhosphorSwift)
        // Use "moon-stars" for assistant header flair
        Ph.moonStars.bold.frame(width: size, height: size)
        #else
        Image(systemName: "sparkles").font(.system(size: size, weight: .bold))
        #endif
    }
    
    // Provider icons
    @ViewBuilder static func providerOpenAI(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.lightning.bold.frame(width: size, height: size)
        #else
        Image(systemName: "bolt.horizontal.circle.fill").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func providerAnthropic(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.circleNotch.bold.frame(width: size, height: size)
        #else
        Image(systemName: "a.circle.fill").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func providerGoogle(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.googleLogo.bold.frame(width: size, height: size)
        #else
        Image(systemName: "g.circle.fill").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func providerXAI(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.x.bold.frame(width: size, height: size)
        #else
        Image(systemName: "x.circle.fill").font(.system(size: size, weight: .bold))
        #endif
    }
    
    // Action icons
    @ViewBuilder static func refresh(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.arrowClockwise.bold.frame(width: size, height: size)
        #else
        Image(systemName: "arrow.clockwise.circle").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func refreshModels(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.arrowsClockwise.bold.frame(width: size, height: size)
        #else
        Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func lightning(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.lightning.bold.frame(width: size, height: size)
        #else
        Image(systemName: "bolt.horizontal.circle").font(.system(size: size, weight: .bold))
        #endif
    }
}
