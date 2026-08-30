# Run your own fine-tuned LLM inside a SwiftUI Mac app

A small macOS app that loads a fused, fine-tuned Qwen3 model from a folder on disk and writes a Conventional Commit message for a git diff. Everything runs on the Mac. No server, no API key, nothing downloaded at runtime.

This is the companion code for **Part 5 of the AI LLM Engineering series**: [Running a Local LLM in a SwiftUI Mac App](https://www.charithgunasekara.com/writing/building-a-macos-developer-tool).

The model it runs is the one trained in Parts 2 to 4. That code lives in [mlx-commit-lora](https://github.com/Charith1990/mlx-commit-lora).

![The app running on a Mac. The base model is loaded first and writes a plain commit message. Then the fine-tuned model is loaded from a folder, and the same diffs come back with the right type and the [CG] marker.](assets/app-demo.gif)

First half: the base model, `qwen3-4b-instruct-4bit`. Second half: the fused model, `qwen3-4b-commit-cg`, on the same diffs. The `[CG]` at the end of each message is the proof the fine-tune is doing the work.

## What it does

1. You pick the fused model folder once. The path is remembered.
2. You pick one of five sample diffs.
3. The model writes the commit message. If it ends with `[CG]`, the fine-tune is doing the work.

The five diffs were chosen to show what training changed: the caching diff that prompting never got right in Part 2, a lifecycle fix, a README change, a new endpoint, and a test.

## Requirements

- A Mac with **Apple silicon**. MLX does not run on Intel Macs.
- **macOS 26** and **Xcode 26**
- The **Metal Toolchain**. Xcode 26 ships it as a separate 688 MB download. Without it, no MLX project builds, in Xcode or on the command line:
  ```bash
  xcodebuild -downloadComponent MetalToolchain
  ```
- A fused model folder. Follow Parts 2 to 4 in [mlx-commit-lora](https://github.com/Charith1990/mlx-commit-lora), which ends with `models/qwen3-4b-commit-cg/` (2.1 GB). Any MLX model folder with a `config.json`, `tokenizer.json` and safetensors will load, but the commit messages will only be good with the trained one.

## Build

```bash
git clone https://github.com/<your-username>/mlx-commit-app.git
cd mlx-commit-app
open mlx-fuse-model-test.xcodeproj
```

Xcode resolves two packages on first open:

| Package | Products | Why |
|---|---|---|
| [mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm) | `MLXLLM`, `MLXLMCommon`, `MLXHuggingFace` | loads and runs the model |
| [swift-transformers](https://github.com/huggingface/swift-transformers) | `Tokenizers` | reads `tokenizer.json` from the model folder |

`MLXLLM` and `MLXLMCommon` **moved out of `mlx-swift-examples`** into `mlx-swift-lm`. Most guides online still point at the old repository.

The first build asks you to trust a build plug-in named `CudaBuild` from `mlx-swift`. It does nothing on a Mac but SwiftPM still has to be told it is allowed. Click **Trust & Enable**. From the command line:

```bash
xcodebuild -scheme mlx-fuse-model-test -destination 'platform=macOS,arch=arm64' \
  -skipPackagePluginValidation -skipMacroValidation build
```

Then run, press **Choose model folder…**, and pick `qwen3-4b-commit-cg`.

## What is in here

```
mlx-fuse-model-test/
  CommitWriter.swift          the only logic type: loads the model, runs it, cleans the answer
  ContentView.swift           one screen: sample cards, the diff, the button, the result
  ThinkingView.swift          the animation while the model works, pure SwiftUI
  SampleDiffs.swift           five diffs as string literals, so there is no git or sandbox to deal with
  mlx_fuse_model_testApp.swift
  Assets.xcassets/

project.yml                   XcodeGen definition, in case the .xcodeproj ever needs rebuilding
```

About 250 lines of Swift. No protocols, no delegates, no completion handlers. `CommitWriter` is `@MainActor @Observable` with a `Phase` enum, and the view reads `phase`.

## Three things worth knowing

**The prompt must match training, word for word.** `CommitWriter` sends `Write one Conventional Commit message for this git diff.`, the same line `build_dataset.py` wrote into every training row. Send anything else and the model quietly gives back part of what training bought. No error tells you.

**`<think>` gets stripped, again.** Qwen3 sometimes opens its answer with a `<think>…</think>` block. The Python tool strips it. The Swift app strips it too, in `cleanUp()`. Second language, same bug.

**App Sandbox is off.** The chosen model path is saved in `UserDefaults`. With the sandbox on, that path stops being readable after a restart unless you add security-scoped bookmarks. For a developer tool that only runs on your own machine, turning the sandbox off is the honest fix. It is set in `project.yml` (`ENABLE_APP_SANDBOX: NO`).

## Rebuilding the project file

The `.xcodeproj` is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen). You do not need XcodeGen to build, the generated project is committed. If you change targets or packages:

```bash
brew install xcodegen
xcodegen generate
```

## License

MIT. See [LICENSE](LICENSE).

## Author

**Charith 'Alex' Gunasekara**, Head of Development & Engineering, Melbourne, Australia.
Writing at [charithgunasekara.com](https://www.charithgunasekara.com/writing).
