import SwiftUI

final class PlayerContainerView: UIView {
	weak var player: KollusPlayerView?
	override func layoutSubviews() {
		super.layoutSubviews()
		player?.frame = bounds
	}
}

struct KollusPlayerRepresentable: UIViewRepresentable {
	let contentURL: String
	@Binding var caption: String
	var playerState: KollusPlayerState
	var contentFit: Bool = false

	func makeUIView(context: Context) -> PlayerContainerView {
		let container = PlayerContainerView()
		container.backgroundColor = .black
		let player = KollusPlayerView(contentURL: contentURL)!
		player.storage = kollusStorage
		player.delegate = context.coordinator
		player.debug = true
		player.scalingMode = KollusPlayerContentMode(rawValue: contentFit ? 0 : 1)!
		player.contentMode = contentFit ? .scaleAspectFit : .scaleAspectFill
		player.clipsToBounds = true
		container.player = player
		container.addSubview(player)
		playerState.playerView = player
		DispatchQueue.main.async {
			do {
				try player.prepareToPlay(withMode: KollusPlayerType(rawValue: 0)!)
			} catch {
				print("[Kollus] prepareToPlay 실패: \(error)")
			}
		}
		return container
	}

	func updateUIView(_ uiView: PlayerContainerView, context: Context) {
		uiView.setNeedsLayout()
	}

	static func dismantleUIView(_ uiView: PlayerContainerView, coordinator: Coordinator) {
		try? uiView.player?.stop()
		uiView.player?.delegate = nil
	}

	func makeCoordinator() -> Coordinator {
		Coordinator(caption: $caption, playerState: playerState, contentFit: contentFit)
	}

	class Coordinator: NSObject, KollusPlayerDelegate {
		@Binding var caption: String
		let playerState: KollusPlayerState
		let contentFit: Bool

		init(caption: Binding<String>, playerState: KollusPlayerState, contentFit: Bool) {
			_caption = caption
			self.playerState = playerState
			self.contentFit = contentFit
		}

		func kollusPlayerView(_ kollusPlayerView: KollusPlayerView!, prepareToPlayWithError error: Error!) {
			guard error == nil else {
				print("[Kollus] prepareToPlay 콜백 에러: \(error!)")
				return
			}
			kollusPlayerView.scalingMode = KollusPlayerContentMode(rawValue: contentFit ? 0 : 1)!
			kollusPlayerView.contentMode = contentFit ? .scaleAspectFit : .scaleAspectFill
			DispatchQueue.main.async {
				self.playerState.onReady(player: kollusPlayerView)
			}
		}

		func kollusPlayerView(_ kollusPlayerView: KollusPlayerView!, stop userInteraction: Bool, error: Error!) {
			DispatchQueue.main.async { self.playerState.onStop() }
		}

		func kollusPlayerView(_ kollusPlayerView: KollusPlayerView!, charset: UnsafeMutablePointer<CChar>!, caption captionPtr: UnsafeMutablePointer<CChar>!) {
			guard let captionPtr else {
				DispatchQueue.main.async { self.caption = "" }
				return
			}
			var text = String(cString: captionPtr)
			text = text.replacingOccurrences(of: "<BR>", with: "\n", options: .caseInsensitive)
			text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
			text = text.trimmingCharacters(in: .whitespacesAndNewlines)
			DispatchQueue.main.async { self.caption = text }
		}

		func kollusPlayerView(_ kollusPlayerView: KollusPlayerView!, naturalSize: CGSize) {
			DispatchQueue.main.async {
				self.playerState.naturalSize = naturalSize
			}
		}

		func kollusPlayerView(_ kollusPlayerView: KollusPlayerView!, unknownError error: Error!) {
			print("[Kollus] 에러: \(String(describing: error))")
		}

		func kollusPlayerView(_ kollusPlayerView: KollusPlayerView!, buffering: Bool, prepared: Bool, error: Error!) {}
		func kollusPlayerView(_ kollusPlayerView: KollusPlayerView!, play userInteraction: Bool, error: Error!) {}
		func kollusPlayerView(_ kollusPlayerView: KollusPlayerView!, pause userInteraction: Bool, error: Error!) {}
		func kollusPlayerView(_ kollusPlayerView: KollusPlayerView!, position: TimeInterval, error: Error!) {}
		func kollusPlayerView(_ kollusPlayerView: KollusPlayerView!, scroll distance: CGPoint, error: Error!) {}
		func kollusPlayerView(_ kollusPlayerView: KollusPlayerView!, zoom recognizer: UIPinchGestureRecognizer!, error: AutoreleasingUnsafeMutablePointer<NSError?>?) {}
		func kollusPlayerView(_ kollusPlayerView: KollusPlayerView!, playerContentMode: KollusPlayerContentMode, error: Error!) {}
		func kollusPlayerView(_ kollusPlayerView: KollusPlayerView!, playerContentFrame contentFrame: CGRect, error: Error!) {}
		func kollusPlayerView(_ kollusPlayerView: KollusPlayerView!, playbackRate: Float, error: Error!) {}
		func kollusPlayerView(_ kollusPlayerView: KollusPlayerView!, repeat: Bool, error: Error!) {}
		func kollusPlayerView(_ kollusPlayerView: KollusPlayerView!, enabledOutput: Bool, error: Error!) {}
		func kollusPlayerView(_ kollusPlayerView: KollusPlayerView!, framerate: Int32) {}
		func kollusPlayerView(_ kollusPlayerView: KollusPlayerView!, lockedPlayer playerType: KollusPlayerType) {}
		func kollusPlayerView(_ kollusPlayerView: KollusPlayerView!, charsetSub: UnsafeMutablePointer<CChar>!, captionSub: UnsafeMutablePointer<CChar>!) {}
		func kollusPlayerView(_ kollusPlayerView: KollusPlayerView!, thumbnail isThumbnail: Bool, error: Error!) {}
		func kollusPlayerView(_ kollusPlayerView: KollusPlayerView!, mck: String!) {}
		func kollusPlayerView(_ view: KollusPlayerView!, height: Int32) {}
		func kollusPlayerView(_ view: KollusPlayerView!, bitrate: Int32) {}
	}
}
