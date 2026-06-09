import SwiftUI
import PhotosUI
import AVFoundation

struct UploadView: View {
	@ObservedObject var api: VideoAPI
	@Environment(\.dismiss) var dismiss

	@State private var title = ""
	@State private var description = ""
	@State private var tags = ""
	@State private var selectedItem: PhotosPickerItem?
	@State private var selectedVideoURL: URL?
	@State private var thumbnailImage: UIImage?
	@State private var uploadState: UploadState = .idle
	@State private var videoDuration: Double = 0
	@State private var isShortEnabled: Bool = false

	enum UploadState: Equatable {
		case idle
		case loadingVideo
		case uploading(Double)
		case done
		case failed(String)
	}

	var body: some View {
		NavigationView {
			Form {
				// 썸네일 미리보기
				Section {
					Rectangle()
						.fill(Color(.systemGray6))
						.aspectRatio(16/9, contentMode: .fit)
						.overlay(thumbnailOverlay)
						.clipped()
						.listRowInsets(EdgeInsets())
				}


					Section("영상 정보") {
						TextField("제목 (필수)", text: $title)

						VStack(alignment: .leading, spacing: 4) {
							Text("설명")
								.font(.caption)
								.foregroundColor(.secondary)
							TextEditor(text: $description)
								.frame(minHeight: 80)
								.overlay(
									Group {
										if description.isEmpty {
											Text("영상 내용을 설명해주세요")
												.foregroundColor(.secondary.opacity(0.6))
												.font(.system(size: 16))
												.padding(.top, 8)
												.padding(.leading, 4)
										}
									},
									alignment: .topLeading
								)
						}

						VStack(alignment: .leading, spacing: 4) {
							Text("태그")
								.font(.caption)
								.foregroundColor(.secondary)
							TextField("예: 게임, 리뷰, 브이로그", text: $tags)
							Text("쉼표로 구분")
								.font(.caption2)
								.foregroundColor(.secondary)
						}
					}

					Section {
						PhotosPicker(selection: $selectedItem, matching: .videos) {
							HStack {
								Image(systemName: selectedVideoURL != nil ? "checkmark.circle.fill" : "photo.on.rectangle")
									.foregroundColor(selectedVideoURL != nil ? .green : .blue)
								Text(selectedVideoURL != nil ? "영상 선택됨 (다시 선택하기)" : "갤러리에서 선택")
									.foregroundColor(selectedVideoURL != nil ? .primary : .blue)
							}
						}
						.onChange(of: selectedItem) { _, newItem in
							loadVideo(from: newItem)
						}
					}

					if videoDuration > 0 && videoDuration < 180 {
						Section {
							Toggle(isOn: $isShortEnabled) {
								HStack(spacing: 10) {
									Image(systemName: "play.rectangle.on.rectangle.fill")
										.font(.system(size: 20))
										.foregroundColor(.red)
										.frame(width: 28)
									VStack(alignment: .leading, spacing: 2) {
										Text("Shorts로도 업로드")
											.font(.system(size: 14, weight: .medium))
										Text("Shorts 탭에도 영상이 표시됩니다")
											.font(.caption)
											.foregroundColor(.secondary)
									}
								}
							}
							.tint(.red)
						}
					}

					Section {
						switch uploadState {
						case .idle:
							Button {
								Task { await upload() }
							} label: {
								HStack {
									Spacer()
									Text("업로드")
										.fontWeight(.semibold)
										.foregroundColor(canUpload ? .white : .gray)
									Spacer()
								}
								.padding(.vertical, 4)
								.background(canUpload ? Color.red : Color(.systemGray4))
								.cornerRadius(8)
							}
							.disabled(!canUpload)
							.listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

						case .loadingVideo:
							HStack {
								ProgressView()
								Text("영상 불러오는 중...")
									.foregroundColor(.secondary)
									.padding(.leading, 8)
							}

						case .uploading(let progress):
							VStack(spacing: 8) {
								ProgressView(value: progress)
									.tint(.red)
								Text("업로드 중... \(Int(progress * 100))%")
									.font(.caption)
									.foregroundColor(.secondary)
							}

						case .done:
							HStack {
								Image(systemName: "checkmark.circle.fill")
									.foregroundColor(.green)
								VStack(alignment: .leading, spacing: 2) {
									Text("업로드 완료!")
										.fontWeight(.medium)
									Text("인코딩 후 목록에 표시됩니다.")
										.font(.caption)
										.foregroundColor(.secondary)
								}
							}

						case .failed(let msg):
							HStack {
								Image(systemName: "exclamationmark.triangle.fill")
									.foregroundColor(.red)
								Text(msg)
									.font(.caption)
									.foregroundColor(.red)
							}
						}
					}
				}
			.navigationTitle("업로드")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("닫기") {
						if uploadState == .done { api.fetchVideos() }
						dismiss()
					}
				}
			}
		}
	}

	@ViewBuilder
	private var thumbnailOverlay: some View {
		if let thumb = thumbnailImage {
			Image(uiImage: thumb)
				.resizable()
				.scaledToFill()
		} else if selectedVideoURL != nil {
			VStack(spacing: 6) {
				Image(systemName: "checkmark.circle.fill")
					.font(.system(size: 40))
					.foregroundColor(.green)
				Text("영상 선택됨")
					.font(.caption)
					.foregroundColor(.secondary)
			}
		} else {
			VStack(spacing: 8) {
				Image(systemName: "video.badge.plus")
					.font(.system(size: 36))
					.foregroundColor(.gray)
				Text("영상을 선택해주세요")
					.font(.subheadline)
					.foregroundColor(.secondary)
			}
		}
	}

	private var canUpload: Bool {
		!title.isEmpty && selectedVideoURL != nil && uploadState == .idle
	}

	private func loadVideo(from item: PhotosPickerItem?) {
		guard let item else { return }
		uploadState = .loadingVideo
		item.loadTransferable(type: VideoTransferable.self) { result in
			DispatchQueue.main.async {
				switch result {
				case .success(let video):
					self.selectedVideoURL = video?.url
					self.uploadState = .idle
					self.videoDuration = 0
					self.isShortEnabled = false
					if let url = video?.url {
						self.extractThumbnail(from: url)
					}
				case .failure:
					self.uploadState = .failed("영상 불러오기 실패")
				}
			}
		}
	}

	private func extractThumbnail(from url: URL) {
		Task.detached(priority: .userInitiated) {
			let asset = AVAsset(url: url)
			let durationSeconds: Double
			if let d = try? await asset.load(.duration) {
				durationSeconds = CMTimeGetSeconds(d)
			} else {
				durationSeconds = 0
			}
			let gen = AVAssetImageGenerator(asset: asset)
			gen.appliesPreferredTrackTransform = true
			gen.maximumSize = CGSize(width: 1280, height: 720)
			gen.requestedTimeToleranceBefore = .zero
			gen.requestedTimeToleranceAfter = .zero
			let cgImage = try? gen.copyCGImage(at: .zero, actualTime: nil)
			let uiImage = cgImage.map { UIImage(cgImage: $0) }
			await MainActor.run {
				self.videoDuration = durationSeconds
				if let img = uiImage { self.thumbnailImage = img }
			}
		}
	}

	private func upload() async {
		guard let videoURL = selectedVideoURL else { return }
		await MainActor.run { uploadState = .uploading(0) }

		guard let result = await api.fetchUploadURL(title: title, description: description, tags: tags, isShort: isShortEnabled) else {
			await MainActor.run { uploadState = .failed("업로드 URL 발급 실패") }
			return
		}

		do {
			try await uploadToKollus(fileURL: videoURL, uploadURL: result.uploadUrl)
			// 고해상도 썸네일 서버에 저장
			if let thumb = await MainActor.run(body: { thumbnailImage }),
			   let jpegData = thumb.jpegData(compressionQuality: 0.75) {
				await api.uploadThumbnail(videoId: result.videoId, imageData: jpegData)
			}
			await MainActor.run { uploadState = .done }
		} catch {
			await MainActor.run { uploadState = .failed("업로드 실패: \(error.localizedDescription)") }
		}
	}

	private func uploadToKollus(fileURL: URL, uploadURL: String) async throws {
		guard let url = URL(string: uploadURL) else { throw URLError(.badURL) }

		let videoData = try await Task.detached(priority: .userInitiated) {
			try Data(contentsOf: fileURL)
		}.value

		let boundary = UUID().uuidString
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

		var body = Data()
		body.append("--\(boundary)\r\n".data(using: .utf8)!)
		body.append("Content-Disposition: form-data; name=\"upload-file\"; filename=\"video.mp4\"\r\n".data(using: .utf8)!)
		body.append("Content-Type: video/mp4\r\n\r\n".data(using: .utf8)!)
		body.append(videoData)
		body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
		request.httpBody = body

		await MainActor.run { uploadState = .uploading(0.5) }

		let (_, response) = try await URLSession.shared.data(for: request)
		guard let http = response as? HTTPURLResponse, (200...399).contains(http.statusCode) else {
			throw URLError(.badServerResponse)
		}
		await MainActor.run { uploadState = .uploading(1.0) }
	}
}

struct VideoTransferable: Transferable {
	let url: URL

	static var transferRepresentation: some TransferRepresentation {
		FileRepresentation(contentType: .movie) { video in
			SentTransferredFile(video.url)
		} importing: { received in
			let dest = FileManager.default.temporaryDirectory
				.appendingPathComponent(UUID().uuidString + ".mp4")
			try FileManager.default.copyItem(at: received.file, to: dest)
			return VideoTransferable(url: dest)
		}
	}
}
