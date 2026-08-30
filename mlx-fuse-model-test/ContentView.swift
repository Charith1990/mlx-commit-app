//
//  ContentView.swift
//  mlx-fuse-model-test
//
//  One screen. Pick a diff, press the button, read the commit message the
//  fine-tuned model wrote on this machine.
//

import SwiftUI

struct ContentView: View {

    @State private var writer = CommitWriter()
    @State private var selected = sampleDiffs[0]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            samplePicker
            diffView

            Button(action: generate) {
                Text(writer.phase == .thinking ? "Writing…" : "Write commit message")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(writer.phase == .thinking || writer.phase == .loading)

            result
                // One line drives every transition below: the thinking view
                // appearing, and the message card sliding up when it is done.
                .animation(.spring(duration: 0.35), value: writer.phase)
        }
        .padding(24)
        .frame(minWidth: 620, minHeight: 640)
        .task { await writer.loadModel() }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Commit message writer")
                    .font(.title2.weight(.semibold))
                Text("Qwen3 4B, fine-tuned and running on this Mac")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(writer.modelName.isEmpty ? "Choose model folder…" : writer.modelName) {
                writer.chooseModelFolder()
                Task { await writer.loadModel() }
            }
            .buttonStyle(.link)
        }
    }

    private var samplePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(sampleDiffs) { sample in
                    let isSelected = sample.id == selected.id

                    Button {
                        selected = sample
                        // A message written for a different diff would just be
                        // confusing sitting under this one.
                        writer.message = ""
                        if writer.phase == .done { writer.phase = .ready }
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(sample.title).font(.callout.weight(.medium))
                            Text(sample.language).font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            isSelected
                                ? Color.accentColor.opacity(0.15)
                                : Color.gray.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 9)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 9)
                                .stroke(
                                    isSelected ? Color.accentColor : Color.clear,
                                    lineWidth: 1.5
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var diffView: some View {
        ScrollView {
            Text(selected.diff)
                .font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding(12)
        }
        .frame(height: 240)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var result: some View {
        switch writer.phase {
        case .needsModel:
            note("Choose the folder holding the fused model to begin.")

        case .loading:
            note("Loading the model. This takes a moment the first time.")

        case .thinking:
            ThinkingView()
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity)

        case .done:
            messageCard

        case .failed(let reason):
            note(reason)

        case .ready:
            note("Ready.")
        }
    }

    private var messageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SUGGESTED COMMIT MESSAGE")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(writer.message, forType: .string)
                }
                .buttonStyle(.link)
            }

            Text(writer.message)
                .font(.system(.title3, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            // The marker is the proof. The base model never writes it, so if
            // it is here, the trained weights answered.
            if writer.message.contains("[CG]") {
                Text("[CG] means this came from the fine-tuned model")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions

    private func generate() {
        Task {
            // Safe to call every time: it returns immediately once loaded.
            await writer.loadModel()
            await writer.write(diff: selected.diff)
        }
    }
}

#Preview {
    ContentView()
}
