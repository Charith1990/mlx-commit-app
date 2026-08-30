//
//  CommitWriter.swift
//  mlx-fuse-model-test
//
//  Everything the app does that is not drawing: load the fused model from a
//  folder, send it a diff, tidy the answer.
//
//  One class and one enum. No protocols, no delegates, no completion handlers.
//

import AppKit
import Foundation
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import SwiftUI

// Tokenizers, from swift-transformers, is not used by name anywhere in this
// file. It is imported because #huggingFaceTokenizerLoader() expands into code
// that calls Tokenizers.AutoTokenizer.from(modelFolder:), and that code lands
// here. mlx-swift-lm ships no tokenizer of its own, only the protocol.
//
// It reads tokenizer.json out of the model folder. Nothing is downloaded, so
// the swift-huggingface package (the one that fetches models by repo id) is
// not needed at all.
import Tokenizers

/// The prompt the model was TRAINED with, word for word.
///
/// This has to match `build_dataset.py` exactly. The model did not only learn
/// the answers, it learned the shape of the conversation they came in. Send it
/// a different system prompt and you give back part of what the training
/// bought, without any error to tell you.
private let trainingSystemPrompt = "Write one Conventional Commit message for this git diff."

/// The same wrapper the Python tool puts around the diff, for the same reason.
private func userMessage(for diff: String) -> String {
    "Generate a commit message for this diff:\n\n\(diff)"
}

/// A commit message is about 15 tokens. 60 leaves room and still stops a model
/// that decides to explain itself.
private let parameters = GenerateParameters(maxTokens: 60, temperature: 0)

@MainActor
@Observable
final class CommitWriter {

    enum Phase: Equatable {
        case needsModel
        case loading
        case ready
        case thinking
        case done
        case failed(String)
    }

    var phase: Phase = .needsModel
    var message = ""

    /// Where the fused model lives. Chosen once, then remembered.
    var modelPath = UserDefaults.standard.string(forKey: "modelPath") ?? "" {
        didSet { UserDefaults.standard.set(modelPath, forKey: "modelPath") }
    }

    private var model: ModelContainer?

    var modelName: String {
        modelPath.isEmpty ? "" : URL(fileURLWithPath: modelPath).lastPathComponent
    }

    /// Ask for the folder holding the fused model, e.g. qwen3-4b-commit-cg.
    func chooseModelFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Use this model"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        modelPath = url.path
        model = nil
        phase = .needsModel
    }

    /// Read the weights into memory. About 2 GB, so it happens once and the
    /// loaded model is kept for every later message.
    func loadModel() async {
        guard model == nil, !modelPath.isEmpty else { return }

        phase = .loading

        do {
            // No downloader here. The weights are already on disk, so the
            // model is loaded straight from the folder.
            model = try await LLMModelFactory.shared.loadContainer(
                from: URL(fileURLWithPath: modelPath),
                using: #huggingFaceTokenizerLoader()
            )
            phase = .ready
        } catch {
            phase = .failed("Could not load the model. \(error.localizedDescription)")
        }
    }

    /// Write one commit message for one diff.
    func write(diff: String) async {
        guard let model else {
            phase = .failed("Choose the model folder first.")
            return
        }

        phase = .thinking
        message = ""

        // A fresh session each time, so the previous diff is not still sitting
        // in the conversation when the next one arrives.
        let session = ChatSession(
            model,
            instructions: trainingSystemPrompt,
            generateParameters: parameters
        )

        do {
            var answer = ""
            for try await chunk in session.streamResponse(to: userMessage(for: diff)) {
                answer += chunk
            }

            message = cleanUp(answer)
            phase = .done
        } catch {
            phase = .failed("The model stopped early. \(error.localizedDescription)")
        }
    }

    /// Turn whatever the model returned into one usable commit line.
    ///
    /// This message is meant to go into `git commit -m`, so it is treated the
    /// way you would treat any text typed by a stranger.
    func cleanUp(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Qwen3 opens every answer with a thinking block, because its chat
        // template put one in front of every row of the training data too.
        // The Python version of this tool did not strip it at first, kept the
        // first line with content, and threw every real answer away.
        if let start = text.range(of: "<think>"), let end = text.range(of: "</think>") {
            text.removeSubrange(start.lowerBound ..< end.upperBound)
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // An unclosed block means the answer was cut off mid-thought. Better
        // nothing than the model's private reasoning in a commit message.
        if text.contains("<think>") { return "" }

        // Keep the first line with real content. Anything after it is the
        // model explaining itself, which git does not want.
        text = text.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""

        // Models like wrapping answers. Only strip when the same character is
        // at both ends, and repeat, because "`feat: x`" happens.
        while text.count >= 2, let first = text.first, let last = text.last,
              first == last, "\"'`".contains(first) {
            text = String(text.dropFirst().dropLast())
                .trimmingCharacters(in: .whitespaces)
        }

        // A Conventional Commit subject takes no full stop.
        while text.hasSuffix(".") { text = String(text.dropLast()) }

        return text.trimmingCharacters(in: .whitespaces)
    }
}
