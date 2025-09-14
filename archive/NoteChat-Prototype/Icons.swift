import SwiftUI
#if canImport(PhosphorSwift)
import PhosphorSwift
#endif

enum AppIcon {
    // Always use bold weight by default
    @ViewBuilder static func gear(_ size: CGFloat = 18) -> some View {
        #if canImport(PhosphorSwift)
        Ph.gear.fill.frame(width: size, height: size)
        #else
        Image(systemName: "gearshape.fill").font(.system(size: size, weight: .heavy))
        #endif
    }
    @ViewBuilder static func grabber(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.dotsSixVertical.bold.frame(width: size, height: size)
        #else
        Image(systemName: "line.3.horizontal").font(.system(size: size, weight: .bold))
            .rotationEffect(.degrees(90))
        #endif
    }
    @ViewBuilder static func home(_ size: CGFloat = 18) -> some View {
        #if canImport(PhosphorSwift)
        Ph.house.fill.frame(width: size, height: size)
        #else
        Image(systemName: "house.fill").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func chat(_ size: CGFloat = 18) -> some View {
        #if canImport(PhosphorSwift)
        Ph.chatCircleDots.fill.frame(width: size, height: size)
        #else
        Image(systemName: "message.fill").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func note(_ size: CGFloat = 18) -> some View {
        #if canImport(PhosphorSwift)
        Ph.note.fill.frame(width: size, height: size)
        #else
        Image(systemName: "note.text").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func share(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.shareNetwork.fill.frame(width: size, height: size)
        #else
        Image(systemName: "square.and.arrow.up.fill").font(.system(size: size, weight: .heavy))
        #endif
    }
    @ViewBuilder static func trash(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.trash.fill.frame(width: size, height: size)
        #else
        Image(systemName: "trash.fill").font(.system(size: size, weight: .heavy))
        #endif
    }
    @ViewBuilder static func compose(_ size: CGFloat = 18) -> some View {
        #if canImport(PhosphorSwift)
        Ph.pencilSimple.fill.frame(width: size, height: size)
        #else
        Image(systemName: "square.and.pencil").font(.system(size: size, weight: .heavy))
        #endif
    }
    // Content-type glyphs used in chat history cards
    @ViewBuilder static func image(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.image.fill.frame(width: size, height: size)
        #else
        Image(systemName: "photo.fill").font(.system(size: size, weight: .heavy))
        #endif
    }
    @ViewBuilder static func text(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.textT.fill.frame(width: size, height: size)
        #else
        Image(systemName: "textformat").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func code(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.code.fill.frame(width: size, height: size)
        #else
        Image(systemName: "curlybraces").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func audio(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.waveform.fill.frame(width: size, height: size)
        #else
        Image(systemName: "waveform").font(.system(size: size, weight: .heavy))
        #endif
    }
    @ViewBuilder static func file(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.file.fill.frame(width: size, height: size)
        #else
        Image(systemName: "doc.fill").font(.system(size: size, weight: .heavy))
        #endif
    }
    @ViewBuilder static func doc(_ size: CGFloat = 16) -> some View { file(size) }
    @ViewBuilder static func agent(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.robot.fill.frame(width: size, height: size)
        #else
        Image(systemName: "brain.head.profile").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func project(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.squaresFour.fill.frame(width: size, height: size)
        #else
        Image(systemName: "square.grid.2x2.fill").font(.system(size: size, weight: .heavy))
        #endif
    }
    @ViewBuilder static func user(_ size: CGFloat = 18) -> some View {
        #if canImport(PhosphorSwift)
        Ph.userCircle.fill.frame(width: size, height: size)
        #else
        Image(systemName: "person.circle.fill").font(.system(size: size, weight: .heavy))
        #endif
    }
    @ViewBuilder static func plus(_ size: CGFloat = 18) -> some View {
        #if canImport(PhosphorSwift)
        Ph.plusCircle.fill.frame(width: size, height: size)
        #else
        Image(systemName: "plus.circle.fill").font(.system(size: size, weight: .heavy))
        #endif
    }
    @ViewBuilder static func microphone(_ size: CGFloat = 18) -> some View {
        #if canImport(PhosphorSwift)
        Ph.microphone.fill.frame(width: size, height: size)
        #else
        Image(systemName: "mic.fill").font(.system(size: size, weight: .heavy))
        #endif
    }
    @ViewBuilder static func waveform(_ size: CGFloat = 18) -> some View {
        #if canImport(PhosphorSwift)
        Ph.waveform.fill.frame(width: size, height: size)
        #else
        Image(systemName: "waveform").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func paperPlane(_ size: CGFloat = 18) -> some View {
        #if canImport(PhosphorSwift)
        // Phosphor name: paper-plane-tilt
        Ph.paperPlaneTilt.fill.frame(width: size, height: size)
        #else
        Image(systemName: "paperplane.fill").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func chevronDown(_ size: CGFloat = 12) -> some View {
        #if canImport(PhosphorSwift)
        Ph.caretDown.fill.frame(width: size, height: size)
        #else
        Image(systemName: "chevron.down").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func chevronUp(_ size: CGFloat = 12) -> some View {
        #if canImport(PhosphorSwift)
        Ph.caretUp.fill.frame(width: size, height: size)
        #else
        Image(systemName: "chevron.up").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func copy(_ size: CGFloat = 14) -> some View {
        #if canImport(PhosphorSwift)
        Ph.copy.fill.frame(width: size, height: size)
        #else
        Image(systemName: "doc.on.doc.fill").font(.system(size: size, weight: .heavy))
        #endif
    }
    @ViewBuilder static func info(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.info.fill.frame(width: size, height: size)
        #else
        Image(systemName: "info.circle.fill").font(.system(size: size, weight: .heavy))
        #endif
    }
    @ViewBuilder static func close(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.x.fill.frame(width: size, height: size)
        #else
        Image(systemName: "xmark.circle.fill").font(.system(size: size, weight: .heavy))
        #endif
    }
    @ViewBuilder static func stop(_ size: CGFloat = 18) -> some View {
        // Prefer a consistent SF Symbol here to avoid dependency symbol mismatches
        Image(systemName: "stop.fill").font(.system(size: size, weight: .bold))
    }
    @ViewBuilder static func checkCircle(_ filled: Bool = true, size: CGFloat = 18) -> some View {
        #if canImport(PhosphorSwift)
        (filled ? Ph.checkCircle.fill : Ph.circle.bold).frame(width: size, height: size)
        #else
        Image(systemName: filled ? "checkmark.circle.fill" : "circle").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func starsHeader(_ size: CGFloat = 14) -> some View {
        #if canImport(PhosphorSwift)
        // Use "moon-stars" for assistant header flair
        Ph.moonStars.fill.frame(width: size, height: size)
        #else
        Image(systemName: "sparkles").font(.system(size: size, weight: .bold))
        #endif
    }
    
    // Provider icons
    @ViewBuilder static func providerOpenAI(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.lightning.fill.frame(width: size, height: size)
        #else
        Image(systemName: "bolt.horizontal.circle.fill").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func providerAnthropic(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.circleNotch.fill.frame(width: size, height: size)
        #else
        Image(systemName: "a.circle.fill").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func providerGoogle(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.googleLogo.fill.frame(width: size, height: size)
        #else
        Image(systemName: "g.circle.fill").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func providerXAI(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.x.fill.frame(width: size, height: size)
        #else
        Image(systemName: "x.circle.fill").font(.system(size: size, weight: .bold))
        #endif
    }
    
    // Action icons
    @ViewBuilder static func refresh(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.arrowClockwise.fill.frame(width: size, height: size)
        #else
        Image(systemName: "arrow.clockwise.circle.fill").font(.system(size: size, weight: .heavy))
        #endif
    }
    @ViewBuilder static func refreshModels(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.arrowsClockwise.fill.frame(width: size, height: size)
        #else
        Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: size, weight: .heavy))
        #endif
    }
    @ViewBuilder static func lightning(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.lightning.fill.frame(width: size, height: size)
        #else
        Image(systemName: "bolt.horizontal.circle.fill").font(.system(size: size, weight: .heavy))
        #endif
    }
}
