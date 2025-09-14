# UI Playground 🎨

This folder is a **sandbox environment** for testing and experimenting with SwiftUI components without modifying the main app.

## Purpose

- **Rapid Prototyping**: Test UI ideas quickly using SwiftUI previews
- **Component Library**: Build and refine reusable UI components
- **Safe Experimentation**: Try new designs without breaking the app
- **Learning Space**: Explore SwiftUI features and animations

## How to Use

1. **Create a new Swift file** in this folder for your experiment
2. **Use SwiftUI Previews** (Canvas) to see live updates
3. **Multiple preview configurations** to test different states
4. **Copy working code** to the main app when ready

## Xcode Canvas Tips

- **Show Canvas**: `⌥⌘↩` (Option + Command + Return)
- **Refresh Preview**: `⌥⌘P` (Option + Command + P)
- **Pin Preview**: Click the pin icon to keep preview visible
- **Live Preview**: Click play button for interactive preview
- **Device Selection**: Change preview device in preview controls

## File Organization

- `PlaygroundExample.swift` - Template with common UI patterns
- `ButtonStyles.swift` - Various button designs and animations
- `ChatBubbles.swift` - Chat UI components and message bubbles
- Add your own experimental files here!

## Best Practices

1. **Keep files independent** - Each playground file should be self-contained
2. **Use descriptive names** - Name files by what you're testing
3. **Add preview variants** - Test in light/dark mode, different sizes
4. **Document findings** - Add comments about what works/doesn't
5. **Don't import app models** - Use mock data for testing

## Example Preview Configurations

```swift
// Basic preview
#Preview {
    YourView()
}

// Named preview with traits
#Preview("Dark Mode", traits: .fixedLayout(width: 400, height: 600)) {
    YourView()
        .preferredColorScheme(.dark)
}

// Multiple device previews
#Preview("iPhone") {
    YourView()
        .previewDevice("iPhone 15 Pro")
}
```

## Important Notes

⚠️ **This folder is for experimentation only**
- Files here won't be included in the app target
- Use as a testing ground before implementing in the main app
- Feel free to create, modify, or delete playground files as needed
- The main app code remains untouched

---

Happy experimenting! 🚀