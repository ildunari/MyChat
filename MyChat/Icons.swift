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

    // MARK: - Common glyphs used across the app
    @ViewBuilder static func note(_ size: CGFloat = 18) -> some View {
        #if canImport(PhosphorSwift)
        Ph.note.bold.frame(width: size, height: size)
        #else
        Image(systemName: "note.text").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func folder(_ size: CGFloat = 18) -> some View {
        #if canImport(PhosphorSwift)
        Ph.folder.bold.frame(width: size, height: size)
        #else
        Image(systemName: "folder.fill").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func image(_ size: CGFloat = 18) -> some View {
        #if canImport(PhosphorSwift)
        Ph.image.bold.frame(width: size, height: size)
        #else
        Image(systemName: "photo.fill").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func text(_ size: CGFloat = 18) -> some View {
        #if canImport(PhosphorSwift)
        Ph.textT.bold.frame(width: size, height: size)
        #else
        Image(systemName: "textformat").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func code(_ size: CGFloat = 18) -> some View {
        #if canImport(PhosphorSwift)
        Ph.code.bold.frame(width: size, height: size)
        #else
        Image(systemName: "chevron.left.forwardslash.chevron.right").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func importIcon(_ size: CGFloat = 18) -> some View {
        #if canImport(PhosphorSwift)
        Ph.arrowSquareIn.bold.frame(width: size, height: size)
        #else
        Image(systemName: "tray.and.arrow.down.fill").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func wand(_ size: CGFloat = 18) -> some View {
        #if canImport(PhosphorSwift)
        Ph.magicWand.bold.frame(width: size, height: size)
        #else
        Image(systemName: "wand.and.stars").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func link(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.linkSimple.bold.frame(width: size, height: size)
        #else
        Image(systemName: "link").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func list(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.listDashes.bold.frame(width: size, height: size)
        #else
        Image(systemName: "list.bullet").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func h1(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.textHOne.bold.frame(width: size, height: size)
        #else
        Image(systemName: "textformat.size").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func italic(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.textItalic.bold.frame(width: size, height: size)
        #else
        Image(systemName: "italic").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func bold(_ size: CGFloat = 16) -> some View {
        #if canImport(PhosphorSwift)
        Ph.textB.bold.frame(width: size, height: size)
        #else
        Image(systemName: "bold").font(.system(size: size, weight: .bold))
        #endif
    }
    @ViewBuilder static func grabber(_ size: CGFloat = 14) -> some View {
        #if canImport(PhosphorSwift)
        Ph.dotsSixVertical.bold.frame(width: size, height: size)
        #else
        Image(systemName: "line.3.horizontal").font(.system(size: size, weight: .regular))
        #endif
    }
    @ViewBuilder static func notePencil(_ size: CGFloat = 18) -> some View {
        Image(systemName: "note.text.badge.plus").font(.system(size: size, weight: .bold))
    }
    @ViewBuilder static func check(_ size: CGFloat = 18) -> some View {
        Image(systemName: "checkmark").font(.system(size: size, weight: .bold))
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
}
