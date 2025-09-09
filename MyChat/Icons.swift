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
}