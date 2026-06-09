import SwiftUI

struct PlayerControlsView: View {
	var state: KollusPlayerState

	var body: some View {
		VStack(spacing: 4) {
			VStack(spacing: 2) {
				Slider(
					value: Binding(
						get: { state.duration > 0 ? state.currentTime / state.duration : 0 },
						set: { newVal in
							state.isSeeking = true
							state.seek(to: newVal * state.duration)
						}
					),
					in: 0...1,
					onEditingChanged: { editing in
						state.isSeeking = editing
					}
				)
				.accentColor(.red)
				.padding(.horizontal, 12)
				.scaleEffect(y: 0.8)

				HStack {
					Text(formatTime(state.currentTime))
					Spacer()
					Text(formatTime(state.duration))
				}
				.font(.system(size: 11))
				.foregroundColor(.white.opacity(0.8))
				.padding(.horizontal, 14)
			}

			Button {
				state.togglePlayPause()
			} label: {
				Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
					.font(.system(size: 24))
					.foregroundColor(.white)
					.frame(width: 44, height: 36)
			}
			.padding(.bottom, 8)
		}
		.background(
			LinearGradient(
				colors: [.clear, .black.opacity(0.6)],
				startPoint: .top,
				endPoint: .bottom
			)
		)
		.opacity(state.isReady && state.showControls && !state.isFinished ? 1 : 0)
		.animation(.easeInOut(duration: 0.2), value: state.showControls)
	}

	private func formatTime(_ seconds: Double) -> String {
		guard seconds.isFinite, seconds >= 0 else { return "0:00" }
		let total = Int(seconds)
		let h = total / 3600
		let m = (total % 3600) / 60
		let s = total % 60
		if h > 0 {
			return String(format: "%d:%02d:%02d", h, m, s)
		}
		return String(format: "%d:%02d", m, s)
	}
}
