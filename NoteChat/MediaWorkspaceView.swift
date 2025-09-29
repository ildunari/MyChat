import SwiftUI
import UIKit
import PhotosUI
import Photos
import SwiftData

struct MediaWorkspaceView: View {
    @Environment(\.tokens) private var T
    @Environment(\.modelContext) private var context
    @Environment(SettingsStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    @Query(sort: \MediaCanvas.updatedAt, order: .reverse, animation: .default)
    private var canvases: [MediaCanvas]

    @State private var prompt: String = ""
    @State private var variationCount: Double = 3
    @State private var variationIntensity: Double = 0.35
    @State private var selectedProviderID: String = ""
    @State private var availableModels: [String] = []
    @State private var selectedModel: String = ""
    @State private var isGenerating: Bool = false
    @State private var generationProgress: String?
    @State private var generated: [GeneratedImage] = []
    @State private var selectedGeneratedID: UUID?
    @State private var pickerItem: PhotosPickerItem?
    @State private var errorMessage: String?
    @State private var showingCanvas: MediaCanvas?
    @State private var isSavingToPhotos: Bool = false
    @FocusState private var promptFocused: Bool

    private let adaptiveColumns: [GridItem] = [
        GridItem(.adaptive(minimum: 320, maximum: 420), spacing: 24, alignment: .top)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if #available(iOS 18.0, *) {
                    GlassEffectContainer(spacing: 24) {
                        contentGrid
                    }
                } else {
                    contentGrid
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .navigationTitle("Canvas Studio")
        .onAppear { configureProviderIfNeeded() }
        .onChange(of: providerOptions.hashValue) {
            configureProviderIfNeeded()
        }
        .onChange(of: pickerItem) { _, newValue in
            guard let item = newValue else { return }
            Task { await importPhoto(from: item) }
        }
    }

    @ViewBuilder
    private var contentGrid: some View {
        LazyVGrid(columns: adaptiveColumns, spacing: 24) {
            heroCard
                .gridCellColumns(2)

            creationCard

            libraryCard

            historyCard
        }
    }

    private var heroCard: some View {
        LiquidGlassCard {
            HStack(alignment: .center, spacing: 28) {
                Image("MediaCanvasHero")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 180, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(T.borderSoft.opacity(0.4), lineWidth: 1.2)
                    )
                    .shadow(color: T.shadow.opacity(0.15), radius: 12, x: 0, y: 6)
                    .ifAvailableGlass { view in
                        view.glassEffect(.regular.tint(T.accent).interactive(), in: .rect(cornerRadius: 32))
                    }

                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Media Canvas Studio")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(T.text)
                        Text("Create, remix, and organize AI-generated artwork")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(T.textSecondary)
                    }
                    
                    Text("Start from a prompt or import photos to build your creative library.")
                        .font(.callout)
                        .foregroundStyle(T.textSecondary.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 14) {
                        Button {
                            promptFocused = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.body.weight(.semibold))
                                Text("Create Canvas")
                                    .font(.body.weight(.semibold))
                            }
                            .padding(.horizontal, 4)
                        }
                        .liquidGlassButtonStyle(prominent: true)
                        .controlSize(.large)

                        Button {
                            if let first = canvases.first {
                                showingCanvas = first
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "square.grid.2x2")
                                Text("Browse")
                            }
                        }
                        .liquidGlassButtonStyle()
                        .controlSize(.large)
                        .disabled(canvases.isEmpty)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var creationCard: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "wand.and.stars")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(T.accent)
                    Text("Create")
                        .font(.title2.bold())
                        .foregroundStyle(T.text)
                }

                if providerOptions.isEmpty {
                    VStack(alignment: .center, spacing: 16) {
                        Image(systemName: "key.horizontal.fill")
                            .font(.system(size: 42))
                            .foregroundStyle(T.accent.opacity(0.5))
                            .padding(.top, 8)
                        
                        VStack(spacing: 8) {
                            Text("Connect an Image Provider")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(T.text)
                            Text("Add an API key in Settings → Providers to unlock AI image generation.")
                                .font(.subheadline)
                                .foregroundStyle(T.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(T.accentSoft.opacity(0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(T.accent.opacity(0.15), lineWidth: 1)
                            )
                    )
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "text.bubble")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(T.accent)
                        Text("Prompt")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(T.text)
                    }
                    TextField("Describe what you want to create...", text: $prompt, axis: .vertical)
                        .lineLimit(3...5)
                        .textFieldStyle(.roundedBorder)
                        .focused($promptFocused)
                        .font(.body)
                }

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "square.grid.3x3")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(T.accent.opacity(0.8))
                            Text("Variations")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(T.text)
                            Spacer()
                            Text("\(Int(variationCount))")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(T.accent)
                                .monospacedDigit()
                        }
                        Slider(value: $variationCount, in: 1...6, step: 1)
                            .tint(T.accent)
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(T.accent.opacity(0.8))
                            Text("Remix Intensity")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(T.text)
                            Spacer()
                            Text("\(Int(variationIntensity * 100))%")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(T.accent)
                                .monospacedDigit()
                        }
                        Slider(value: $variationIntensity, in: 0...1)
                            .tint(T.accent)
                    }
                }
                .padding(.vertical, 4)

                if !providerOptions.isEmpty {
                    providerPicker
                }

                HStack(spacing: 14) {
                    PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                        HStack(spacing: 8) {
                            Image(systemName: "photo.badge.plus")
                                .font(.body.weight(.medium))
                            Text("Import")
                                .font(.body.weight(.medium))
                        }
                    }
                    .liquidGlassButtonStyle()
                    .controlSize(.large)

                    Button(action: performGeneration) {
                        if isGenerating {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .controlSize(.small)
                                Text("Generating...")
                                    .font(.body.weight(.semibold))
                            }
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.body.weight(.semibold))
                                Text("Generate")
                                    .font(.body.weight(.semibold))
                            }
                        }
                    }
                    .liquidGlassButtonStyle(prominent: true)
                    .controlSize(.large)
                    .disabled(isGenerating || providerOptions.isEmpty)
                }

                if let progress = generationProgress {
                    HStack(spacing: 8) {
                        Image(systemName: "hourglass")
                            .font(.caption)
                            .foregroundStyle(T.accent)
                        Text(progress)
                            .font(.callout)
                            .foregroundStyle(T.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(T.accentSoft.opacity(0.3))
                    )
                }

                if let error = errorMessage {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.red.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.red.opacity(0.2), lineWidth: 1)
                            )
                    )
                }

                if !generated.isEmpty {
                    Divider()
                    generatedGrid
                    actionBar
                }
            }
        }
    }

    private var providerPicker: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "server.rack")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(T.accent)
                Text("Provider & Model")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(T.text)
            }
            
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "building.2")
                        .font(.subheadline)
                        .foregroundStyle(T.textSecondary)
                        .frame(width: 20)
                    
                    Picker("Provider", selection: $selectedProviderID) {
                        ForEach(providerOptions) { option in
                            Text(option.name).tag(option.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(T.surface.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(T.borderSoft, lineWidth: 0.5)
                        )
                )
                
                HStack(spacing: 12) {
                    Image(systemName: "cpu")
                        .font(.subheadline)
                        .foregroundStyle(T.textSecondary)
                        .frame(width: 20)
                    
                    Picker("Model", selection: $selectedModel) {
                        ForEach(availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(availableModels.isEmpty)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(T.surface.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(T.borderSoft, lineWidth: 0.5)
                        )
                )
            }
        }
    }

    private var generatedGrid: some View {
        LazyVGrid(columns: adaptiveColumns, spacing: 16) {
            ForEach(generated) { item in
                GeneratedThumbnail(imageData: item.data, title: itemTitle(for: item), isSelected: selectedGeneratedID == item.id, accent: T.accent) {
                    selectedGeneratedID = item.id
                }
            }
        }
    }

    private var actionBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: saveSelectedToLibrary) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.down.fill")
                            .font(.body.weight(.semibold))
                        Text("Save to Library")
                            .font(.body.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                }
                .liquidGlassButtonStyle(prominent: true)
                .controlSize(.large)
                .disabled(selectedGenerated == nil)
            }
            
            HStack(spacing: 12) {
                Menu {
                    Button(action: { if let canvas = canvases.first { saveSelected(to: canvas) } }) {
                        Label("Append to Latest Canvas", systemImage: "square.grid.2x2")
                    }
                    Divider()
                    ForEach(canvases) { canvas in
                        Button(canvas.title) { saveSelected(to: canvas) }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.stack.badge.plus")
                        Text("Add to Canvas")
                    }
                    .frame(maxWidth: .infinity)
                }
                .liquidGlassButtonStyle()
                .controlSize(.large)
                .disabled(selectedGenerated == nil || canvases.isEmpty)

                Button(action: saveSelectedToPhotos) {
                    if isSavingToPhotos {
                        HStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .controlSize(.small)
                            Text("Saving...")
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "photo.badge.arrow.down")
                            Text("Export")
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .liquidGlassButtonStyle()
                .controlSize(.large)
                .disabled(selectedGenerated == nil || isSavingToPhotos)
            }
        }
    }

    private var libraryCard: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "photo.stack")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(T.accent)
                    Text("Library")
                        .font(.title2.bold())
                        .foregroundStyle(T.text)
                    Spacer()
                    if !canvases.isEmpty {
                        Button {
                            if let first = canvases.first { showingCanvas = first }
                        } label: {
                            HStack(spacing: 6) {
                                Text("View All")
                                    .font(.subheadline.weight(.semibold))
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                            }
                        }
                        .liquidGlassButtonStyle()
                    }
                }

                if canvases.isEmpty {
                    VStack(alignment: .center, spacing: 14) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 38))
                            .foregroundStyle(T.textSecondary.opacity(0.5))
                            .padding(.top, 6)
                        
                        VStack(spacing: 6) {
                            Text("No Canvases Yet")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(T.text)
                            Text("Generated artwork will be saved here")
                                .font(.subheadline)
                                .foregroundStyle(T.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(canvases.prefix(4)) { canvas in
                            Button {
                                showingCanvas = canvas
                            } label: {
                                LibraryRow(canvas: canvas, accent: T.accent, text: T.text, textSecondary: T.textSecondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(canvas.title)
                        }
                    }
                }
            }
        }
        .sheet(item: $showingCanvas) { canvas in
            MediaCanvasDetailView(canvas: canvas)
                .environment(\.tokens, T)
        }
    }

    private var historyCard: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(T.accent)
                    Text("Activity")
                        .font(.title2.bold())
                        .foregroundStyle(T.text)
                }
                
                if generated.isEmpty && canvases.isEmpty {
                    VStack(alignment: .center, spacing: 14) {
                        Image(systemName: "timeline.selection")
                            .font(.system(size: 38))
                            .foregroundStyle(T.textSecondary.opacity(0.5))
                            .padding(.top, 6)
                        
                        VStack(spacing: 6) {
                            Text("No Activity Yet")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(T.text)
                            Text("Your recent generations will appear here")
                                .font(.subheadline)
                                .foregroundStyle(T.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(activityEntries.prefix(6), id: \.id) { entry in
                            HStack(alignment: .top, spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(entry.iconColor.opacity(0.15))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: entry.iconName)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(entry.iconColor)
                                }
                                
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(entry.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(T.text)
                                    Text(entry.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(T.textSecondary)
                                }
                                
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
    }

    private var activityEntries: [ActivityEntry] {
        let generatedEntries = generated.map { item in
            let iconName = item.source == .imported ? "photo.badge.plus.fill" : "sparkles"
            return ActivityEntry(id: item.id, title: "Prepared \(itemTitle(for: item))", subtitle: item.source == .imported ? "Imported from Photos" : "Generated with \(item.model)", iconColor: T.accent, iconName: iconName, date: Date())
        }
        let canvasEntries = canvases.map { canvas in
            ActivityEntry(id: canvas.id, title: "Saved canvas ‘\(canvas.title)’", subtitle: relativeTime(for: canvas.updatedAt), iconColor: T.accent.opacity(0.7), iconName: "square.and.arrow.down.fill", date: canvas.updatedAt)
        }
        return (generatedEntries + canvasEntries).sorted(by: { $0.date > $1.date })
    }

    private func relativeTime(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    private var selectedGenerated: GeneratedImage? {
        generated.first(where: { $0.id == selectedGeneratedID })
    }

    private func configureProviderIfNeeded() {
        guard selectedProviderID.isEmpty else { return }
        if let first = providerOptions.first {
            selectedProviderID = first.id
            loadModels(for: first)
        } else {
            availableModels = []
            selectedModel = ""
        }
    }

    private func loadModels(for option: ProviderOption) {
        if let provider = option.make() {
            Task {
                do {
                    let models = try await provider.listModels()
                    await MainActor.run {
                        self.availableModels = models.isEmpty ? option.fallbackModels : models
                        self.selectedModel = self.availableModels.first ?? ""
                    }
                } catch {
                    await MainActor.run {
                        self.availableModels = option.fallbackModels
                        self.selectedModel = self.availableModels.first ?? ""
                        self.errorMessage = "Could not load models: \(error.localizedDescription)"
                    }
                }
            }
        } else {
            availableModels = option.fallbackModels
            selectedModel = availableModels.first ?? ""
        }
    }

    private func performGeneration() {
        guard providerOptions.isEmpty == false else { return }
        guard let option = providerOptions.first(where: { $0.id == selectedProviderID }) else { return }
        guard let provider = option.make() else {
            errorMessage = "Add a valid API key in Settings → Providers to enable generation."
            return
        }
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedPrompt.isEmpty == false else {
            errorMessage = "Enter a prompt before generating."
            return
        }
        guard selectedModel.isEmpty == false else {
            errorMessage = "Select a model before generating."
            return
        }

        errorMessage = nil
        generationProgress = "Generating \(Int(variationCount)) variation(s)…"
        generated.removeAll(where: { $0.source == .generated })
        isGenerating = true

        let count = Int(variationCount)
        let model = selectedModel
        let providerID = option.id
        let intensity = variationIntensity
        Task {
            await generateImages(using: provider, providerID: providerID, basePrompt: trimmedPrompt, model: model, count: count, intensity: intensity)
        }
    }

    @MainActor
    private func handleGenerationCompletion() {
        isGenerating = false
        generationProgress = nil
    }

    private func generateImages(using provider: ImageProvider, providerID: String, basePrompt: String, model: String, count: Int, intensity: Double) async {
        do {
            try await withThrowingTaskGroup(of: GeneratedImage.self) { group in
                for index in 0..<count {
                    let promptVariant = promptVariant(for: basePrompt, index: index, intensity: intensity)
                    group.addTask {
                        let data = try await provider.generateImage(prompt: promptVariant, model: model)
                        return GeneratedImage(prompt: promptVariant, data: data, model: model, provider: providerID, variation: intensity, source: .generated, aspectRatioDescriptor: aspectRatioDescriptor(for: data))
                    }
                }

                for try await image in group {
                    await MainActor.run {
                        generated.append(image)
                        if selectedGeneratedID == nil {
                            selectedGeneratedID = image.id
                        }
                    }
                }
            }
            await MainActor.run { handleGenerationCompletion() }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                handleGenerationCompletion()
            }
        }
    }

    private func promptVariant(for base: String, index: Int, intensity: Double) -> String {
        guard intensity > 0.05 else { return base }
        let modifiers = ["emphasize cinematic lighting", "experiment with macro depth", "introduce bold complementary colors", "explore calm minimalist composition", "add tactile paper textures", "highlight dynamic motion" ]
        let descriptor = modifiers[index % modifiers.count]
        let scaled = String(format: "%.2f", intensity)
        return "\(base)\nVariation \(index + 1): \(descriptor) at intensity \(scaled)."
    }

    private func saveSelectedToLibrary() {
        guard let selected = selectedGenerated else { return }
        do {
            try persist(selected, in: nil)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveSelected(to canvas: MediaCanvas) {
        guard let selected = selectedGenerated else { return }
        do {
            try persist(selected, in: canvas)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func persist(_ generated: GeneratedImage, in existingCanvas: MediaCanvas?) throws {
        let targetCanvas: MediaCanvas
        if let canvas = existingCanvas {
            targetCanvas = canvas
        } else {
            let title = makeCanvasTitle(from: generated)
            let canvas = MediaCanvas(
                title: title,
                prompt: prompt,
                providerIdentifier: generated.provider,
                defaultModelIdentifier: generated.model,
                aspectRatio: generated.aspectRatioDescriptor,
                coverImageData: generated.data
            )
            context.insert(canvas)
            targetCanvas = canvas
        }

        let asset = MediaAsset(
            prompt: generated.prompt,
            variationLevel: generated.variation,
            modelIdentifier: generated.model,
            sourceType: generated.source == .imported ? "imported" : "generated",
            aspectRatio: generated.aspectRatioDescriptor,
            canvas: targetCanvas,
            imageData: generated.data
        )
        targetCanvas.assets.append(asset)
        targetCanvas.updatedAt = Date()
        if targetCanvas.coverImageData == nil {
            targetCanvas.coverImageData = generated.data
        }

        try context.save()
    }

    private func makeCanvasTitle(from generated: GeneratedImage) -> String {
        if generated.source == .imported {
            return "Imported \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))"
        }
        if prompt.isEmpty == false {
            let trimmed = prompt.prefix(60)
            return String(trimmed)
        }
        return "Canvas \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))"
    }

    private func saveSelectedToPhotos() {
        guard let selected = selectedGenerated else { return }
        isSavingToPhotos = true
        Task {
            do {
                try await saveToPhotoLibrary(imageData: selected.data)
                await MainActor.run {
                    isSavingToPhotos = false
                    errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    isSavingToPhotos = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func saveToPhotoLibrary(imageData: Data) async throws {
        guard let uiImage = UIImage(data: imageData) else {
            throw NSError(domain: "MediaWorkspace", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to decode image data."])
        }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.creationRequestForAsset(from: uiImage)
        }
    }

    private func importPhoto(from item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                await MainActor.run {
                    let imported = GeneratedImage(
                        prompt: "Imported photo",
                        data: data,
                        model: "photo-library",
                        provider: "photos",
                        variation: 0,
                        source: .imported,
                        aspectRatioDescriptor: aspectRatioDescriptor(for: data)
                    )
                    generated.insert(imported, at: 0)
                    selectedGeneratedID = imported.id
                    errorMessage = nil
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func aspectRatioDescriptor(for data: Data) -> String {
        guard let image = UIImage(data: data) else { return "unknown" }
        let ratio = image.size.width / max(image.size.height, 1)
        if abs(ratio - 1) < 0.08 { return "square" }
        return ratio > 1 ? "landscape" : "portrait"
    }

    private func itemTitle(for item: GeneratedImage) -> String {
        switch item.source {
        case .generated: return "Variation \(generated.firstIndex(of: item).map { $0 + 1 } ?? 1)"
        case .imported: return "Imported"
        }
    }

    private var providerOptions: [ProviderOption] {
        var options: [ProviderOption] = []
        let openAIKey = store.openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if openAIKey.isEmpty == false {
            options.append(ProviderOption(id: "openai-images", name: "OpenAI Images", fallbackModels: ["gpt-image-1"]) {
                OpenAIImageProvider(apiKey: openAIKey)
            })
        }
        return options
    }
}

// MARK: - Helper models & views

private struct ProviderOption: Identifiable {
    let id: String
    let name: String
    let fallbackModels: [String]
    let make: () -> ImageProvider?

    init(id: String, name: String, fallbackModels: [String], make: @escaping () -> ImageProvider?) {
        self.id = id
        self.name = name
        self.fallbackModels = fallbackModels
        self.make = make
    }
    
    // Manual Hashable conformance using only id
    static func == (lhs: ProviderOption, rhs: ProviderOption) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension ProviderOption: Hashable, Equatable {}

private struct GeneratedImage: Identifiable, Equatable {
    enum Source { case generated, imported }
    let id: UUID = UUID()
    let prompt: String
    let data: Data
    let model: String
    let provider: String
    let variation: Double
    let source: Source
    let aspectRatioDescriptor: String

    static func == (lhs: GeneratedImage, rhs: GeneratedImage) -> Bool {
        lhs.id == rhs.id
    }
}

private struct ActivityEntry {
    let id: UUID
    let title: String
    let subtitle: String
    let iconColor: Color
    let iconName: String
    let date: Date
}

private struct LiquidGlassCard<Content: View>: View {
    @Environment(\.tokens) private var T
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        Group {
            content
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .stroke(T.borderSoft.opacity(0.35), lineWidth: 0.9)
                        )
                )
                .shadow(color: T.shadow.opacity(0.18), radius: 20, y: 14)
        }
    }
}

private struct GeneratedThumbnail: View {
    let imageData: Data
    let title: String
    let isSelected: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                if let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(isSelected ? accent : Color.clear, lineWidth: 3)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 160)
                }

                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct LibraryRow: View {
    let canvas: MediaCanvas
    let accent: Color
    let text: Color
    let textSecondary: Color

    var body: some View {
        HStack(spacing: 16) {
            if let data = canvas.coverImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(accent.opacity(0.15))
                    AppIcon.image(24).foregroundStyle(accent)
                }
                .frame(width: 56, height: 56)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(canvas.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(text)
                Text("Updated \(RelativeDateTimeFormatter().localizedString(for: canvas.updatedAt, relativeTo: .now)) • \(canvas.assets.count) assets")
                    .font(.caption)
                    .foregroundStyle(textSecondary)
            }
            Spacer()
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

private struct MediaCanvasDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.tokens) private var T
    let canvas: MediaCanvas
    @State private var selectedAsset: MediaAsset?
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

    private var assets: [MediaAsset] { canvas.assets.sorted { $0.createdAt > $1.createdAt } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let data = selectedAsset?.imageData ?? canvas.coverImageData,
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(canvas.title)
                            .font(.title.bold())
                        if canvas.prompt.isEmpty == false {
                            Text(canvas.prompt)
                                .font(.body)
                                .foregroundStyle(T.textSecondary)
                        }
                        Text("\(assets.count) variation(s)")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(T.textSecondary)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 16)], spacing: 16) {
                        ForEach(assets) { asset in
                            Button {
                                selectedAsset = asset
                            } label: {
                                if let data = asset.imageData, let image = UIImage(data: data) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(height: 120)
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .stroke(selectedAsset?.id == asset.id ? T.accent : Color.clear, lineWidth: 3)
                                        )
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding(24)
            }
            .navigationTitle("Canvas")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: { dismiss() })
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await saveCurrentSelection() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Label("Save to Photos", systemImage: "square.and.arrow.up.on.square")
                        }
                    }
                    .disabled(isSaving || currentImageData == nil)
                }
            }
        }
    }

    private var currentImageData: Data? {
        selectedAsset?.imageData ?? canvas.coverImageData
    }

    private func saveCurrentSelection() async {
        guard let data = currentImageData else { return }
        isSaving = true
        do {
            try await PHPhotoLibrary.shared().performChanges {
                if let image = UIImage(data: data) {
                    PHAssetCreationRequest.creationRequestForAsset(from: image)
                }
            }
            await MainActor.run { isSaving = false }
        } catch {
            await MainActor.run {
                isSaving = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func ifAvailableGlass<Content: View>(_ transform: (Self) -> Content) -> some View {
        if #available(iOS 18.0, *) {
            transform(self)
        } else {
            self
        }
    }

    @ViewBuilder
    func liquidGlassButtonStyle(prominent: Bool = false) -> some View {
        if prominent {
            self.buttonStyle(.borderedProminent)
        } else {
            self.buttonStyle(.bordered)
        }
    }
}
