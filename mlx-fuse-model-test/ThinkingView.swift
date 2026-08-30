//
//  ThinkingView.swift
//  mlx-fuse-model-test
//
//  What the app shows while the model is writing. Three dots that rise in
//  turn, and a light that sweeps across a placeholder line.
//
//  Plain SwiftUI. No timers, no packages. One @State that flips to true when
//  the view appears, and the animations repeat on their own from there.
//

import SwiftUI

struct ThinkingView: View {

    @State private var running = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {

            HStack(spacing: 10) {
                ForEach(0 ..< 3, id: \.self) { index in
                    Circle()
                        .fill(.tint)
                        .frame(width: 9, height: 9)
                        .offset(y: running ? -5 : 5)
                        .opacity(running ? 1 : 0.35)
                        .animation(
                            .easeInOut(duration: 0.55)
                            .repeatForever()
                            // Each dot starts a little later than the one
                            // before it, which is what makes it read as a
                            // wave instead of three dots blinking together.
                            .delay(Double(index) * 0.18),
                            value: running
                        )
                }

                Text("Reading the diff")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            // A grey bar standing in for the message that has not arrived yet,
            // with a soft highlight moving across it.
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary)
                .frame(height: 22)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.35), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: running ? 320 : -320)
                        .animation(
                            .easeInOut(duration: 1.3).repeatForever(autoreverses: false),
                            value: running
                        )
                }
                .clipped()
        }
        .onAppear { running = true }
    }
}

#Preview {
    ThinkingView()
        .padding(30)
        .frame(width: 460)
}
