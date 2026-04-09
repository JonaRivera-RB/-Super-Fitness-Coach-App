//
//  ExerciseDetailView.swift
//  Super Fitness Coach App
//

import SwiftUI
import UIKit

/// Sheet con información completa de un ejercicio:
/// GIF animado, para qué sirve, cómo ejecutarlo, equipamiento y tipo.
struct ExerciseDetailView: View {
    let exercise: PlannedExercise
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme

    @State private var gifData: Data? = nil
    @State private var isLoadingGif = false
    @State private var gifErrorMessage: String? = nil

    private let exerciseService = ExerciseService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    gifSection
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
        .task { await loadGif() }
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
        let base: String
        switch mode {
        case .video:
            base = "https://www.google.com/search?tbm=vid"
        case .images:
            base = "https://www.google.com/search?tbm=isch"
        case .web:
            base = "https://www.google.com/search"
        }

        let q = "\(exercise.name) exercise"
        guard var comps = URLComponents(string: base) else { return }
        comps.queryItems = (comps.queryItems ?? []) + [URLQueryItem(name: "q", value: q)]
        guard let url = comps.url else { return }
        openURL(url)
    }

    // MARK: - Meta chips

    private var metaSection: some View {
        HStack(spacing: 8) {
            metaChip(icon: "figure.strengthtraining.traditional",
                     text: exercise.muscleGroup.rawValue.capitalized,
                     color: AppSemanticPalette.systemBlue,
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
                systemTint.map { AppSemanticPalette.accentOrPrimaryLabel($0, colorScheme) } ?? color
            )
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(metaChipFill(color: color, systemTint: systemTint)))
    }

    private func metaChipFill(color: Color, systemTint: UIColor?) -> Color {
        if let ui = systemTint {
            return AppSemanticPalette.tintedFill(ui, colorScheme, light: 0.12, dark: 0.28)
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
        if !exercise.instructions.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Cómo ejecutarlo", systemImage: "list.number")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { idx, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(idx + 1)")
                                .font(.caption).fontWeight(.bold)
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(AppSemanticPalette.systemBlue))

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

        let bundled = exerciseService.bundledExercise(withId: catalogId)
        let urlString = exercise.gifUrl ?? bundled?.gifUrl
        guard let urlString, let url = URL(string: urlString), url.scheme == "http" || url.scheme == "https" else {
            gifData = nil
            if gifErrorMessage == nil {
                gifErrorMessage = "No se pudo cargar la animación (sin URL y el endpoint de imágenes falló)."
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
}
