//
//  ExerciseDetailView.swift
//  Super Fitness Coach App
//

import SwiftUI
import UIKit
import SwiftData

/// Sheet con información completa de un ejercicio:
/// GIF animado, para qué sirve, cómo ejecutarlo, equipamiento y tipo.
struct ExerciseDetailView: View {
    let exercise: PlannedExercise
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext

    @State private var gifData: Data? = nil
    @State private var isLoadingGif = false
    @State private var gifErrorMessage: String? = nil

    @State private var catalogEntry: ExerciseCatalogEntry? = nil
    @State private var showSafari: Bool = false
    @State private var safariURL: URL? = nil
    @State private var showMediaEditor: Bool = false

    private let exerciseService = ExerciseService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    gifSection
                    mediaSection
                    metaSection
                    purposeSection
                    instructionsSection
                }
                .padding()
            }
            .navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") { dismiss() }
                }
            }
        }
        .onAppear {
            exerciseService.configure(modelContext: modelContext)
            loadCatalogEntry()
        }
        .task { await loadGif() }
        .sheet(isPresented: $showSafari) {
            if let safariURL {
                SafariView(url: safariURL)
            }
        }
        .sheet(isPresented: $showMediaEditor) {
            MediaEditorSheet(
                title: exercise.name,
                onOpenSearch: { url in
                    safariURL = url
                    showSafari = true
                },
                onSave: { videoUrl, imageUrl in
                    saveMedia(videoUrl: videoUrl, imageUrl: imageUrl)
                }
            )
        }
    }

    // MARK: - GIF / Image

    @ViewBuilder
    private var gifSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
                .frame(height: 260)

            if let data = gifData {
                AnimatedGIFView(data: data)
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else if isLoadingGif {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Cargando animación...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Sin imagen disponible")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Button {
                            openGoogleSearch(mode: .video)
                        } label: {
                            Label("Buscar video", systemImage: "play.circle")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            openGoogleSearch(mode: .images)
                        } label: {
                            Label("Buscar imágenes", systemImage: "photo")
                        }
                        .buttonStyle(.bordered)
                    }
                    if let msg = gifErrorMessage {
                        Text(msg)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 18)
                    }
                }
            }
        }
    }

    private enum GoogleSearchMode {
        case video
        case images
        case web
    }

    private func openGoogleSearch(mode: GoogleSearchMode) {
        let q = "\(exercise.name)"
        let url: URL?
        switch mode {
        case .video:
            url = URL(string: "https://www.youtube.com/results?search_query=\(q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q)")
        case .images:
            url = URL(string: "https://www.google.com/search?tbm=isch&q=\(q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q)")
        case .web:
            url = URL(string: "https://www.google.com/search?q=\(q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q)")
        }
        guard let url else { return }
        safariURL = url
        showSafari = true
    }

    // MARK: - Media (in-app)

    @ViewBuilder
    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Media", systemImage: "photo.on.rectangle.angled")
                    .font(.headline)
                Spacer()
                Button {
                    showMediaEditor = true
                } label: {
                    Label("Buscar / guardar", systemImage: "magnifyingglass")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }

            if let entry = catalogEntry {
                if let imageUrl = entry.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFit()
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if let videoUrl = entry.videoUrl, let url = URL(string: videoUrl) {
                    Button {
                        safariURL = url
                        showSafari = true
                    } label: {
                        Label("Ver video guardado", systemImage: "play.circle.fill")
                            .font(.subheadline)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }

    // MARK: - Meta chips

    private var metaSection: some View {
        HStack(spacing: 8) {
            metaChip(icon: "figure.strengthtraining.traditional",
                     text: exercise.muscleGroup.rawValue.capitalized,
                     color: DesignTokens.Color.info,
                     systemTint: .systemBlue)
            if exercise.isCompound {
                metaChip(icon: "bolt.fill", text: "Compuesto", color: .orange)
            } else {
                metaChip(icon: "circle.fill", text: "Aislamiento", color: .purple)
            }
            if !exercise.equipment.isEmpty {
                metaChip(icon: "dumbbell.fill",
                         text: exercise.equipment.capitalized, color: .gray)
            }
        }
    }

    private func metaChip(icon: String, text: String, color: Color, systemTint: UIColor? = nil) -> some View {
        Label(text, systemImage: icon)
            .font(.caption).fontWeight(.medium)
            .foregroundStyle(
                systemTint != nil ? (colorScheme == .dark ? DesignTokens.Color.textPrimary : color) : color
            )
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(metaChipFill(color: color, systemTint: systemTint)))
    }

    private func metaChipFill(color: Color, systemTint: UIColor?) -> Color {
        if let ui = systemTint {
            return Color(uiColor: ui).opacity(colorScheme == .dark ? 0.28 : 0.12)
        }
        return color.opacity(colorScheme == .dark ? 0.22 : 0.12)
    }

    // MARK: - Para qué sirve

    private var purposeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Para qué sirve", systemImage: "target")
                .font(.headline)

            Text(purposeText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }

    private var purposeText: String {
        let muscle = exercise.muscleGroup.rawValue.capitalized
        if exercise.isCompound {
            return "Ejercicio multiarticular que trabaja principalmente \(muscle) junto con músculos sinergistas. Ideal para ganar fuerza y masa muscular de forma eficiente."
        } else {
            return "Ejercicio de aislamiento enfocado en \(muscle). Perfecto para definir y fortalecer el músculo de forma específica."
        }
    }

    // MARK: - Instrucciones

    @ViewBuilder
    private var instructionsSection: some View {
        let steps = (catalogEntry?.instructionsEs ?? catalogEntry?.instructionsEn)?.split(separator: "\n").map(String.init) ?? exercise.instructions

        if !steps.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Cómo ejecutarlo", systemImage: "list.number")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(idx + 1)")
                                .font(.caption).fontWeight(.bold)
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(DesignTokens.Color.info))

                            Text(step)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
        }
    }

    // MARK: - Load GIF

    private func loadGif() async {
        let catalogId = exercise.effectiveCatalogId
        guard !catalogId.isEmpty else { return }
        isLoadingGif = true
        gifErrorMessage = nil
        defer { isLoadingGif = false }

        let urlString = exercise.gifUrl
        guard let urlString, let url = URL(string: urlString), url.scheme == "http" || url.scheme == "https" else {
            gifData = nil
            if gifErrorMessage == nil {
                gifErrorMessage = "No se pudo cargar la animación (sin URL)."
            }
            return
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 25
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200, !data.isEmpty {
                gifData = data
            } else if let http = response as? HTTPURLResponse {
                gifErrorMessage = "No se pudo cargar la animación (HTTP \(http.statusCode))."
            }
        } catch {
            gifData = nil
            gifErrorMessage = "No se pudo cargar la animación (\(error.localizedDescription))."
        }
    }

    // MARK: - Catalog entry + save

    private func loadCatalogEntry() {
        let id = exercise.effectiveCatalogId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return }
        let fd = FetchDescriptor<ExerciseCatalogEntry>(predicate: #Predicate { $0.wgerUuid == id })
        catalogEntry = (try? modelContext.fetch(fd))?.first
    }

    private func saveMedia(videoUrl: String?, imageUrl: String?) {
        guard let entry = catalogEntry else { return }
        if let videoUrl, !videoUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            entry.videoUrl = videoUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let imageUrl, !imageUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            entry.imageUrl = imageUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        entry.updatedAt = Date()
        try? modelContext.save()
        loadCatalogEntry()
    }
}

private struct MediaEditorSheet: View {
    let title: String
    let onOpenSearch: (URL) -> Void
    let onSave: (_ videoUrl: String?, _ imageUrl: String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var videoUrl: String = ""
    @State private var imageUrl: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Buscar") {
                    Button {
                        let q = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title
                        if let url = URL(string: "https://www.youtube.com/results?search_query=\(q)") {
                            onOpenSearch(url)
                        }
                    } label: {
                        Label("YouTube (en la app)", systemImage: "play.rectangle")
                    }
                    Button {
                        let q = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title
                        if let url = URL(string: "https://www.google.com/search?tbm=isch&q=\(q)") {
                            onOpenSearch(url)
                        }
                    } label: {
                        Label("Google Imágenes (en la app)", systemImage: "photo.on.rectangle")
                    }
                }

                Section("Guardar enlaces") {
                    TextField("Video URL (YouTube)", text: $videoUrl)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    TextField("Imagen URL", text: $imageUrl)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                    Button("Pegar desde portapapeles") {
                        let t = (UIPasteboard.general.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        if t.contains("youtube") || t.contains("youtu.be") {
                            videoUrl = t
                        } else if t.hasPrefix("http") {
                            imageUrl = t
                        }
                    }
                }
            }
            .navigationTitle("Media")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") {
                        onSave(videoUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : videoUrl,
                               imageUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : imageUrl)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
