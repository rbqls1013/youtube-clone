import SwiftUI

@Observable
class KollusPlayerState {
	var isPlaying: Bool = false
	var isReady: Bool = false
	var currentTime: Double = 0
	var duration: Double = 0
	var isSeeking: Bool = false
	var isFinished: Bool = false
	var showControls: Bool = true
	var naturalSize: CGSize = .zero
	var replayTrigger: Int = 0

	var isLandscape: Bool {
		naturalSize.width > naturalSize.height && naturalSize != .zero
	}

	var seekOnReadyTime: Double? = nil
	weak var playerView: KollusPlayerView?
	private var timer: Timer?
	private var hideControlsTimer: Timer?

	func onReady(player: KollusPlayerView) {
		playerView = player
		duration = player.content?.duration ?? 0
		isReady = true
		isFinished = false
		if let t = seekOnReadyTime {
			player.currentPlaybackTime = t
			seekOnReadyTime = nil
		}
		do {
			try player.play()
			isPlaying = true
		} catch {
			print("[Kollus] play 실패: \(error)")
		}
		startTimer()
		scheduleHideControls()
	}

	func replay() {
		isFinished = false
		isReady = false
		isPlaying = false
		currentTime = 0
		seekOnReadyTime = nil
		showControls = true
		playerView = nil
		replayTrigger += 1  // KollusPlayerRepresentable 재생성 트리거
	}

	func togglePlayPause() {
		if isFinished {
			replay()
			return
		}
		guard isReady else { return }
		showControlsTemporarily()
		if isPlaying {
			try? playerView?.pause()
			isPlaying = false
			showControls = true
			hideControlsTimer?.invalidate()
		} else {
			try? playerView?.play()
			isPlaying = true
			scheduleHideControls()
		}
	}

	func seek(to time: Double) {
		playerView?.currentPlaybackTime = time
		currentTime = time
		showControlsTemporarily()
	}

	func onStop() {
		isPlaying = false
		isFinished = true
		DispatchQueue.main.async {
			self.showControls = true
		}
		hideControlsTimer?.invalidate()
	}

	func stopAll() {
		timer?.invalidate()
		timer = nil
		hideControlsTimer?.invalidate()
		hideControlsTimer = nil
		try? playerView?.stop()
		playerView = nil
		isPlaying = false
		isReady = false
	}

	func showControlsTemporarily() {
		showControls = true
		scheduleHideControls()
	}

	func toggleControls() {
		if showControls {
			showControls = false
			hideControlsTimer?.invalidate()
		} else {
			showControlsTemporarily()
		}
	}

	private func scheduleHideControls() {
		hideControlsTimer?.invalidate()
		guard isPlaying else { return }
		hideControlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
			guard let self, self.isPlaying else { return }
			DispatchQueue.main.async {
				self.showControls = false
			}
		}
	}

	private func startTimer() {
		timer?.invalidate()
		timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
			guard let self, let player = self.playerView else { return }
			if !self.isSeeking {
				self.currentTime = player.currentPlaybackTime
				if self.duration == 0, let dur = player.content?.duration, dur > 0 {
					self.duration = dur
				}
			}
			self.isPlaying = player.isPlaying
		}
	}

	deinit {
		timer?.invalidate()
		hideControlsTimer?.invalidate()
	}
}
