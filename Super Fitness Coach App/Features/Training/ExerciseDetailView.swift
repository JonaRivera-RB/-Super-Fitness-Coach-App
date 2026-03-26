//
//  ExerciseDetailView.swift
//  Super Fitness Coach App
//

import SwiftUI

/// Sheet con información completa de un ejercicio:
/// GIF animado, para qué sirve, cómo ejecutarlo, equipamiento y tipo.
struct ExerciseDetailView: View {
    let exercise: PlannedExercise
    @Environment(\.dismiss) private var dismiss

    @State private var gifData: Data? = nil
    @State private var isLoadingGif = false

    private let imageLoader = ExerciseImageLoader(
        apiKey: "655b0c38d3msh1d4ac5d7c628530p1eda67jsn147154d940a5"
    )
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
                }
            }
        }
    }

    // MARK: - Meta chips

    private var metaSection: some View {
        HStack(spacing: 8) {
            metaChip(icon: "figure.strengthtraining.traditional",
                     text: exercise.muscleGroup.rawValue.capitalized, color: .blue)
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

    private func metaChip(icon: String, text: String, color: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.caption).fontWeight(.medium)
            .foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(color.opacity(0.12)))
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
                                .background(Circle().fill(Color.blue))

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
        defer { isLoadingGif = false }

        if let data = await imageLoader.loadImageData(exerciseId: catalogId), !data.isEmpty {
            gifData = data
            return
        }

        let bundled = exerciseService.bundledExercise(withId: catalogId)
        let urlString = exercise.gifUrl ?? bundled?.gifUrl
        guard let urlString, let url = URL(string: urlString), url.scheme == "http" || url.scheme == "https" else {
            gifData = nil
            return
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 25
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200, !data.isEmpty {
                gifData = data
            }
        } catch {
            gifData = nil
        }
    }
}
