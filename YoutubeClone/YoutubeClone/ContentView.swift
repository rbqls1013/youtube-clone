import SwiftUI
import Combine
import Security
import PhotosUI

let baseURL = "https://youtube-clone.YOUR_DOMAIN.workers.dev"

// MARK: - Image Cache

actor ImageCache {
	static let shared = ImageCache()
	private let memCache = NSCache<NSString, UIImage>()
	private var inFlight: [URL: Task<UIImage?, Never>] = [:]

	init() {
		memCache.countLimit = 200
		memCache.totalCostLimit = 80 * 1024 * 1024 // 80 MB
	}

	func load(url: URL) async -> UIImage? {
		let key = url.absoluteString as NSString
		if let cached = memCache.object(forKey: key) { return cached }
		if let existing = inFlight[url] { return await existing.value }
		let task = Task<UIImage?, Never> {
			guard let (data, _) = try? await URLSession.shared.data(from: url),
				  let image = UIImage(data: data) else { return nil }
			return image
		}
		inFlight[url] = task
		let image = await task.value
		inFlight.removeValue(forKey: url)
		if let image {
			memCache.setObject(image, forKey: key, cost: Int(image.size.width * image.size.height * 4))
		}
		return image
	}
}


struct Video: Identifiable, Codable {
	let id: String
	let title: String
	let description: String?
	let tags: String?
	let status: String
	let thumbnailUrl: String?
	let uploaderId: String?
	let viewCount: Int?
	let isShort: Int?

	enum CodingKeys: String, CodingKey {
		case id, title, description, tags, status
		case thumbnailUrl = "thumbnail_url"
		case uploaderId = "uploader_id"
		case viewCount = "view_count"
		case isShort = "is_short"
	}
}

// MARK: - UserManager

class UserManager: ObservableObject {
	static let shared = UserManager()
	private let keychainKey = "yt-clone-device-id"

	@Published var userId: String = ""
	@Published var nickname: String = ""
	@Published var avatarCacheKey: String = ""

	init() {
		if let saved = loadFromKeychain() {
			userId = saved
		} else {
			let raw = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
			let id = String(raw.replacingOccurrences(of: "-", with: "").lowercased().prefix(16))
			userId = id
			saveToKeychain(id)
		}
		nickname = UserDefaults.standard.string(forKey: "nickname") ?? ""
		avatarCacheKey = UserDefaults.standard.string(forKey: "avatarCacheKey") ?? ""
	}

	func setup() async {
		// 기존 IP 기반 uploader_id → 현재 기기 ID로 마이그레이션 (최초 1회)
		let migrationKey = "uploader-migrated-\(userId)"
		if !UserDefaults.standard.bool(forKey: migrationKey) {
			if let url = URL(string: "\(baseURL)/admin/migrate-uploader") {
				var req = URLRequest(url: url)
				req.httpMethod = "POST"
				req.setValue("application/json", forHTTPHeaderField: "Content-Type")
				req.httpBody = try? JSONSerialization.data(withJSONObject: ["newUploaderId": userId])
				if let (data, _) = try? await URLSession.shared.data(for: req),
				   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
				   json["ok"] as? Bool == true {
					UserDefaults.standard.set(true, forKey: migrationKey)
				}
			}
		}
		// 서버에서 닉네임 동기화
		guard let url = URL(string: "\(baseURL)/users/\(userId)"),
			  let (data, _) = try? await URLSession.shared.data(from: url),
			  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
			  let user = json["user"] as? [String: Any],
			  let nick = user["nickname"] as? String, !nick.isEmpty else { return }
		await MainActor.run {
			nickname = nick
			UserDefaults.standard.set(nick, forKey: "nickname")
		}
	}

	func updateProfile(nickname: String, avatarData: Data?) async {
		await MainActor.run {
			self.nickname = nickname
			UserDefaults.standard.set(nickname, forKey: "nickname")
		}
		guard let url = URL(string: "\(baseURL)/users/\(userId)") else { return }
		var req = URLRequest(url: url)
		req.httpMethod = "PUT"
		req.setValue("application/json", forHTTPHeaderField: "Content-Type")
		var body: [String: Any] = ["nickname": nickname]
		if let data = avatarData { body["avatarData"] = data.base64EncodedString() }
		req.httpBody = try? JSONSerialization.data(withJSONObject: body)
		_ = try? await URLSession.shared.data(for: req)
		// 서버 저장 완료 후 캐시 키 갱신 → AsyncImage가 새 URL로 재요청
		if avatarData != nil {
			let key = String(Int.random(in: 100000...999999))
			await MainActor.run {
				avatarCacheKey = key
				UserDefaults.standard.set(key, forKey: "avatarCacheKey")
			}
		}
	}

	func ownAvatarURL() -> URL? {
		let v = avatarCacheKey.isEmpty ? "" : "?v=\(avatarCacheKey)"
		return URL(string: "\(baseURL)/user-avatar/\(userId)\(v)")
	}

	private func saveToKeychain(_ value: String) {
		guard let data = value.data(using: .utf8) else { return }
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrAccount as String: keychainKey,
			kSecValueData as String: data,
			kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
		]
		SecItemDelete(query as CFDictionary)
		SecItemAdd(query as CFDictionary, nil)
	}

	private func loadFromKeychain() -> String? {
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrAccount as String: keychainKey,
			kSecReturnData as String: true,
			kSecMatchLimit as String: kSecMatchLimitOne
		]
		var result: AnyObject?
		guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
			  let data = result as? Data else { return nil }
		return String(data: data, encoding: .utf8)
	}

	static func avatarURL(seed: String) -> URL? {
		URL(string: "https://youtube-clone.YOUR_DOMAIN.workers.dev/user-avatar/\(seed)")
	}
}

// MARK: - AvatarView

struct AvatarView: View {
	let seed: String
	let size: CGFloat
	@ObservedObject private var userManager = UserManager.shared
	@State private var uiImage: UIImage?

	private var resolvedURL: URL? {
		seed == userManager.userId ? userManager.ownAvatarURL() : UserManager.avatarURL(seed: seed)
	}

	var body: some View {
		ZStack {
			if let uiImage {
				Image(uiImage: uiImage)
					.resizable()
					.interpolation(.medium)
					.scaledToFill()
					.frame(width: size, height: size)
					.clipped()
			} else {
				ZStack {
					Circle().fill(seedColor(seed))
					Text(String(seed.prefix(1)).uppercased())
						.font(.system(size: size * 0.38, weight: .bold))
						.foregroundColor(.white)
				}
				.frame(width: size, height: size)
			}
		}
		.frame(width: size, height: size)
		.clipShape(Circle())
		.task(id: resolvedURL?.absoluteString) {
			guard let url = resolvedURL else { return }
			uiImage = await ImageCache.shared.load(url: url)
		}
	}

	private func seedColor(_ seed: String) -> Color {
		let colors: [Color] = [.red, .blue, .green, .orange, .purple, .pink, .teal, .indigo]
		return colors[abs(seed.hashValue) % colors.count]
	}
}

struct VideosResponse: Codable {
	let videos: [Video]
}

private struct VideosPageResponse: Codable {
	let videos: [Video]
	let total: Int
}

struct LikeResponse: Codable {
	let liked: Bool
	let count: Int?
}

struct LikeStatusResponse: Codable {
	let liked: Bool
	let count: Int
}

struct Comment: Identifiable, Codable {
	let id: String
	let video_id: String
	let user_id: String
	let content: String
	let created_at: String
	let like_count: Int?
	let parent_id: String?
}

struct CommentsResponse: Codable {
	let comments: [Comment]
}
class VideoAPI: ObservableObject {
	let baseURL = "https://youtube-clone.YOUR_DOMAIN.workers.dev"
	
	@Published var videos: [Video] = []
	@Published var isLoadingMore: Bool = false
	private var offset: Int = 0
	var total: Int = 0
	private let limit: Int = 10

	func fetchVideos() {
		offset = 0
		videos = []
		loadVideos()
	}

	func loadMore() {
		guard !isLoadingMore, videos.count < total else { return }
		isLoadingMore = true
		loadVideos()
	}

	private func loadVideos() {
		guard let url = URL(string: "\(baseURL)/videos?limit=\(limit)&offset=\(offset)") else { return }
		URLSession.shared.dataTask(with: url) { data, _, _ in
			guard let data,
				  let page = try? JSONDecoder().decode(VideosPageResponse.self, from: data)
			else {
				DispatchQueue.main.async { self.isLoadingMore = false }
				return
			}
			DispatchQueue.main.async {
				self.videos.append(contentsOf: page.videos)
				self.total = page.total
				self.offset += page.videos.count
				self.isLoadingMore = false
			}
		}.resume()
	}

	func fetchPlaybackToken(videoId: String, completion: @escaping (String?, String?) -> Void) {
		guard let url = URL(string: "\(baseURL)/playback-token") else { return }
		var req = URLRequest(url: url)
		req.httpMethod = "POST"
		req.setValue("application/json", forHTTPHeaderField: "Content-Type")
		req.httpBody = try? JSONSerialization.data(withJSONObject: ["videoId": videoId])
		URLSession.shared.dataTask(with: req) { data, _, _ in
			guard let data = data,
				  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
			DispatchQueue.main.async {
				if let url = json["playbackUrl"] as? String {
					completion(url, nil)
				} else {
					completion(nil, json["error"] as? String ?? "알 수 없는 오류")
				}
			}
		}.resume()
	}

	func fetchLikeStatus(videoId: String, completion: @escaping (Bool, Int) -> Void) {
		guard let url = URL(string: "\(baseURL)/likes?videoId=\(videoId)&userId=anonymous") else { return }
		URLSession.shared.dataTask(with: url) { data, _, _ in
			guard let data = data,
				  let response = try? JSONDecoder().decode(LikeStatusResponse.self, from: data) else { return }
			DispatchQueue.main.async { completion(response.liked, response.count) }
		}.resume()
	}

	func fetchComments(videoId: String, completion: @escaping ([Comment]) -> Void) {
		guard let url = URL(string: "\(baseURL)/comments?videoId=\(videoId)") else { return }
		URLSession.shared.dataTask(with: url) { data, _, _ in
			guard let data = data,
				  let response = try? JSONDecoder().decode(CommentsResponse.self, from: data) else { return }
			DispatchQueue.main.async { completion(response.comments) }
		}.resume()
	}

	func postComment(videoId: String, content: String, userId: String = "anonymous", parentId: String? = nil, completion: @escaping (Bool) -> Void) {
		guard let url = URL(string: "\(baseURL)/comments") else { return }
		var req = URLRequest(url: url)
		req.httpMethod = "POST"
		req.setValue("application/json", forHTTPHeaderField: "Content-Type")
		var body: [String: Any] = ["videoId": videoId, "content": content, "userId": userId.isEmpty ? "anonymous" : userId]
		if let parentId { body["parentId"] = parentId }
		req.httpBody = try? JSONSerialization.data(withJSONObject: body)
		URLSession.shared.dataTask(with: req) { _, _, error in
			DispatchQueue.main.async { completion(error == nil) }
		}.resume()
	}

	func fetchShorts(completion: @escaping ([Video]) -> Void) {
		guard let url = URL(string: "\(baseURL)/shorts") else { return }
		URLSession.shared.dataTask(with: url) { data, _, _ in
			guard let data,
				  let response = try? JSONDecoder().decode(VideosResponse.self, from: data) else {
				DispatchQueue.main.async { completion([]) }
				return
			}
			DispatchQueue.main.async { completion(response.videos) }
		}.resume()
	}

	func fetchUploadURL(title: String, description: String, tags: String, isShort: Bool = false) async -> (uploadUrl: String, uploadFileKey: String, videoId: String)? {
		guard let url = URL(string: "\(baseURL)/upload-url") else { return nil }
		var req = URLRequest(url: url)
		req.httpMethod = "POST"
		req.setValue("application/json", forHTTPHeaderField: "Content-Type")
		req.httpBody = try? JSONSerialization.data(withJSONObject: [
			"title": title,
			"description": description,
			"tags": tags,
			"uploaderId": UserManager.shared.userId,
			"isShort": isShort
		])
		guard let (data, _) = try? await URLSession.shared.data(for: req),
			  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
			  let uploadUrl = json["uploadUrl"] as? String,
			  let uploadFileKey = json["uploadFileKey"] as? String,
			  let videoId = json["videoId"] as? String
		else { return nil }
		return (uploadUrl, uploadFileKey, videoId)
	}

	func uploadThumbnail(videoId: String, imageData: Data) async {
		guard let url = URL(string: "\(baseURL)/thumbnail-upload") else { return }
		var req = URLRequest(url: url)
		req.httpMethod = "POST"
		req.setValue("application/json", forHTTPHeaderField: "Content-Type")
		let base64 = imageData.base64EncodedString()
		req.httpBody = try? JSONSerialization.data(withJSONObject: ["videoId": videoId, "imageBase64": base64])
		_ = try? await URLSession.shared.data(for: req)
	}

	func recordView(videoId: String) {
		guard let url = URL(string: "\(baseURL)/views") else { return }
		var req = URLRequest(url: url)
		req.httpMethod = "POST"
		req.setValue("application/json", forHTTPHeaderField: "Content-Type")
		req.httpBody = try? JSONSerialization.data(withJSONObject: ["videoId": videoId])
		URLSession.shared.dataTask(with: req) { _, _, _ in }.resume()
	}

	func toggleCommentLike(commentId: String, userId: String, completion: @escaping (Bool) -> Void) {
		guard let url = URL(string: "\(baseURL)/comment-likes") else { return }
		var req = URLRequest(url: url)
		req.httpMethod = "POST"
		req.setValue("application/json", forHTTPHeaderField: "Content-Type")
		req.httpBody = try? JSONSerialization.data(withJSONObject: ["commentId": commentId, "userId": userId])
		URLSession.shared.dataTask(with: req) { data, _, _ in
			guard let data,
				  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
				DispatchQueue.main.async { completion(false) }
				return
			}
			DispatchQueue.main.async { completion(json["liked"] as? Bool ?? false) }
		}.resume()
	}

	func fetchLikedCommentIds(videoId: String, userId: String, completion: @escaping (Set<String>) -> Void) {
		guard let url = URL(string: "\(baseURL)/comment-likes?videoId=\(videoId)&userId=\(userId)") else { return }
		URLSession.shared.dataTask(with: url) { data, _, _ in
			guard let data,
				  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
				  let ids = json["likedIds"] as? [String] else {
				DispatchQueue.main.async { completion([]) }
				return
			}
			DispatchQueue.main.async { completion(Set(ids)) }
		}.resume()
	}

	func analyzeVideo(videoId: String, completion: @escaping (Bool) -> Void) {
		guard let url = URL(string: "\(baseURL)/analyze-video") else { return }
		var req = URLRequest(url: url)
		req.httpMethod = "POST"
		req.setValue("application/json", forHTTPHeaderField: "Content-Type")
		req.httpBody = try? JSONSerialization.data(withJSONObject: ["videoId": videoId])
		URLSession.shared.dataTask(with: req) { _, response, _ in
			let ok = (response as? HTTPURLResponse)?.statusCode == 200
			DispatchQueue.main.async { completion(ok) }
		}.resume()
	}

	func fetchRecommendations(videoId: String, completion: @escaping ([Video]) -> Void) {
		guard let url = URL(string: "\(baseURL)/recommendations?videoId=\(videoId)&limit=10") else { return }
		URLSession.shared.dataTask(with: url) { data, _, _ in
			guard let data,
				  let response = try? JSONDecoder().decode(VideosResponse.self, from: data) else {
				DispatchQueue.main.async { completion([]) }
				return
			}
			DispatchQueue.main.async { completion(response.videos) }
		}.resume()
	}

	func fetchSubscribedVideos(subscriberId: String, completion: @escaping ([Video]) -> Void) {
		guard let url = URL(string: "\(baseURL)/subscriptions/videos?subscriberId=\(subscriberId)") else { return }
		URLSession.shared.dataTask(with: url) { data, _, _ in
			guard let data,
				  let response = try? JSONDecoder().decode(VideosResponse.self, from: data) else {
				DispatchQueue.main.async { completion([]) }
				return
			}
			DispatchQueue.main.async { completion(response.videos) }
		}.resume()
	}

	struct ChannelInfo: Identifiable {
		let id: String
		let nickname: String?
	}

	func fetchSubscribedChannels(subscriberId: String, completion: @escaping ([ChannelInfo]) -> Void) {
		guard let url = URL(string: "\(baseURL)/subscriptions/channels?subscriberId=\(subscriberId)") else { return }
		URLSession.shared.dataTask(with: url) { data, _, _ in
			guard let data,
				  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
				  let channels = json["channels"] as? [[String: Any]] else {
				DispatchQueue.main.async { completion([]) }
				return
			}
			let result = channels.map { c in
				ChannelInfo(id: c["channel_id"] as? String ?? "", nickname: c["nickname"] as? String)
			}
			DispatchQueue.main.async { completion(result) }
		}.resume()
	}

	func fetchUploaderProfile(userId: String, completion: @escaping (String?) -> Void) {
		guard let url = URL(string: "\(baseURL)/users/\(userId)") else { return }
		URLSession.shared.dataTask(with: url) { data, _, _ in
			guard let data,
				  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
				  let user = json["user"] as? [String: Any] else {
				DispatchQueue.main.async { completion(nil) }
				return
			}
			DispatchQueue.main.async { completion(user["nickname"] as? String) }
		}.resume()
	}

	func fetchSubscription(subscriberId: String, channelId: String, completion: @escaping (Bool, Int) -> Void) {
		guard let url = URL(string: "\(baseURL)/subscriptions?subscriberId=\(subscriberId)&channelId=\(channelId)") else { return }
		URLSession.shared.dataTask(with: url) { data, _, _ in
			guard let data,
				  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
				DispatchQueue.main.async { completion(false, 0) }
				return
			}
			let subscribed = json["subscribed"] as? Bool ?? false
			let count = json["count"] as? Int ?? 0
			DispatchQueue.main.async { completion(subscribed, count) }
		}.resume()
	}

	func toggleSubscription(subscriberId: String, channelId: String, completion: @escaping (Bool, Int) -> Void) {
		guard let url = URL(string: "\(baseURL)/subscriptions") else { return }
		var req = URLRequest(url: url)
		req.httpMethod = "POST"
		req.setValue("application/json", forHTTPHeaderField: "Content-Type")
		req.httpBody = try? JSONSerialization.data(withJSONObject: ["subscriberId": subscriberId, "channelId": channelId])
		URLSession.shared.dataTask(with: req) { data, _, _ in
			guard let data,
				  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
				DispatchQueue.main.async { completion(false, 0) }
				return
			}
			DispatchQueue.main.async {
				completion(json["subscribed"] as? Bool ?? false, json["count"] as? Int ?? 0)
			}
		}.resume()
	}

	func updateVideo(videoId: String, title: String, description: String, tags: String, completion: @escaping (Bool) -> Void) {
		guard let url = URL(string: "\(baseURL)/videos/\(videoId)") else { return }
		var req = URLRequest(url: url)
		req.httpMethod = "PUT"
		req.setValue("application/json", forHTTPHeaderField: "Content-Type")
		req.setValue(UserManager.shared.userId, forHTTPHeaderField: "X-Uploader-Id")
		req.httpBody = try? JSONSerialization.data(withJSONObject: [
			"title": title, "description": description, "tags": tags
		])
		URLSession.shared.dataTask(with: req) { _, response, _ in
			let ok = (response as? HTTPURLResponse)?.statusCode == 200
			DispatchQueue.main.async { completion(ok) }
		}.resume()
	}

	func deleteVideo(videoId: String, uploaderId: String, completion: @escaping (Bool) -> Void) {
		guard let url = URL(string: "\(baseURL)/videos/\(videoId)") else { return }
		var req = URLRequest(url: url)
		req.httpMethod = "DELETE"
		req.setValue(uploaderId, forHTTPHeaderField: "X-Uploader-Id")
		URLSession.shared.dataTask(with: req) { _, response, _ in
			let ok = (response as? HTTPURLResponse)?.statusCode == 200
			DispatchQueue.main.async { completion(ok) }
		}.resume()
	}

	func toggleLike(videoId: String, completion: @escaping (Bool?, Int?) -> Void) {
		guard let url = URL(string: "\(baseURL)/likes") else { return }
		var req = URLRequest(url: url)
		req.httpMethod = "POST"
		req.setValue("application/json", forHTTPHeaderField: "Content-Type")
		req.httpBody = try? JSONSerialization.data(withJSONObject: ["videoId": videoId, "userId": "anonymous"])
		URLSession.shared.dataTask(with: req) { data, _, _ in
			guard let data = data,
				  let response = try? JSONDecoder().decode(LikeResponse.self, from: data) else {
				DispatchQueue.main.async { completion(nil, nil) }
				return
			}
			DispatchQueue.main.async { completion(response.liked, response.count) }
		}.resume()
	}
}

// MARK: - Root

struct ContentView: View {
	@StateObject var api = VideoAPI()
	@State private var selectedTab = 0
	@State private var showUpload = false

	var body: some View {
		TabView(selection: $selectedTab) {
			HomeView(api: api)
				.tabItem { Label("홈", systemImage: "house.fill") }
				.tag(0)

			ShortsView()
				.tabItem { Label("Shorts", systemImage: "play.rectangle.on.rectangle.fill") }
				.tag(1)

			Color.clear
				.tabItem { Label("만들기", systemImage: "plus.app.fill") }
				.tag(2)

			SubscriptionsView()
				.tabItem { Label("구독", systemImage: "person.2.fill") }
				.tag(3)

			LibraryView()
				.tabItem { Label("보관함", systemImage: "play.square.stack.fill") }
				.tag(4)
		}
		.tint(.primary)
		.onChange(of: selectedTab) { _, newVal in
			if newVal == 2 {
				showUpload = true
				selectedTab = 0
			}
		}
		.sheet(isPresented: $showUpload, onDismiss: { api.fetchVideos() }) {
			UploadView(api: api)
		}
	}
}

// MARK: - Home

struct HomeView: View {
	@ObservedObject var api: VideoAPI
	@ObservedObject private var userManager = UserManager.shared
	@State private var selectedCategory = "전체"
	@State private var showProfile = false
	let categories = ["전체", "음악", "게임", "실시간", "뉴스", "스포츠", "자동차", "요리", "패션"]

	var body: some View {
		NavigationStack {
			VStack(spacing: 0) {
				ScrollView(.horizontal, showsIndicators: false) {
					HStack(spacing: 8) {
						ForEach(categories, id: \.self) { cat in
							Button {
								selectedCategory = cat
							} label: {
								Text(cat)
									.font(.system(size: 13, weight: .medium))
									.foregroundColor(selectedCategory == cat ? .white : .primary)
									.padding(.horizontal, 12)
									.padding(.vertical, 6)
									.background(selectedCategory == cat ? Color.primary : Color(.systemGray5))
									.cornerRadius(16)
							}
						}
					}
					.padding(.horizontal, 16)
					.padding(.vertical, 8)
				}

				Divider()

				ScrollView {
					LazyVStack(alignment: .leading, spacing: 0) {
						ForEach(api.videos) { video in
							NavigationLink(destination: PlayerView(video: video, api: api)) {
								VideoCardView(video: video)
							}
							.buttonStyle(.plain)
							.frame(maxWidth: .infinity, alignment: .leading)
						}
						if api.isLoadingMore {
							ProgressView()
								.frame(maxWidth: .infinity)
								.padding()
						} else if api.videos.count < api.total {
							Color.clear
								.frame(height: 1)
								.onAppear { api.loadMore() }
						}
					}
					.frame(maxWidth: .infinity)
				}
				.refreshable { api.fetchVideos() }
			}
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .navigationBarLeading) {
					HStack(spacing: 3) {
						Image(systemName: "play.rectangle.fill")
							.font(.system(size: 20))
							.foregroundColor(.red)
						Text("YouTube")
							.font(.system(size: 18, weight: .bold))
							.foregroundColor(.primary)
					}
				}
				ToolbarItem(placement: .navigationBarTrailing) {
					Button { } label: {
						Image(systemName: "magnifyingglass")
							.font(.system(size: 19))
							.foregroundColor(.primary)
					}
				}
				ToolbarItem(placement: .navigationBarTrailing) {
					Button { } label: {
						Image(systemName: "bell")
							.font(.system(size: 19))
							.foregroundColor(.primary)
					}
				}
				ToolbarItem(placement: .navigationBarTrailing) {
					Button { showProfile = true } label: {
						VStack(spacing: 1) {
							AvatarView(seed: userManager.userId.isEmpty ? "default" : userManager.userId, size: 28)
							if !userManager.nickname.isEmpty {
								Text(userManager.nickname)
									.font(.system(size: 9, weight: .medium))
									.foregroundColor(.primary)
									.lineLimit(1)
									.frame(maxWidth: 52)
							}
						}
					}
				}
			}
			.onAppear {
				if api.videos.isEmpty { api.fetchVideos() }
			}
			.sheet(isPresented: $showProfile) {
				ProfileView(api: api)
			}
		}
	}
}

// MARK: - Video Card

struct VideoCardView: View {
	let video: Video
	@State private var thumbnailImage: UIImage?

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			// 썸네일: ZStack으로 배경+이미지 레이어, frame 먼저 확정 후 scaledToFill
			ZStack {
				Color(.black)
				if let img = thumbnailImage {
					Image(uiImage: img)
						.resizable()
						.scaledToFit()
				} else if video.thumbnailUrl != nil {
					ProgressView().scaleEffect(0.8)
				} else {
					Image(systemName: "play.rectangle.fill")
						.font(.system(size: 40))
						.foregroundColor(.secondary)
				}
			}
			.frame(maxWidth: .infinity)
			.aspectRatio(16/9, contentMode: .fit)
			.clipped()
			.task(id: video.thumbnailUrl) {
				guard let s = video.thumbnailUrl, let url = URL(string: s) else { return }
				thumbnailImage = await ImageCache.shared.load(url: url)
			}

			// Info row
			HStack(alignment: .top, spacing: 12) {
				AvatarView(seed: video.uploaderId ?? video.id, size: 36)

				VStack(alignment: .leading, spacing: 3) {
					Text(video.title)
						.font(.system(size: 14, weight: .medium))
						.foregroundColor(.primary)
						.lineLimit(2)
					Text(video.status == "ready"
						? ((video.viewCount ?? 0) > 0 ? "조회수 \(formatViewCount(video.viewCount ?? 0))회" : "재생 가능")
						: video.status)
						.font(.system(size: 12))
						.foregroundColor(.secondary)
				}

				Spacer()

				Menu {
					Button {
						let av = UIActivityViewController(activityItems: [video.title], applicationActivities: nil)
						UIApplication.shared.connectedScenes
							.compactMap { $0 as? UIWindowScene }
							.first?.windows.first?.rootViewController?
							.present(av, animated: true)
					} label: {
						Label("공유", systemImage: "square.and.arrow.up")
					}
					Button(role: .destructive) {} label: {
						Label("관심없음", systemImage: "hand.thumbsdown")
					}
					Button(role: .destructive) {} label: {
						Label("채널 추천 안함", systemImage: "nosign")
					}
					Button {} label: {
						Label("재생목록에 추가", systemImage: "text.badge.plus")
					}
				} label: {
					Image(systemName: "ellipsis")
						.font(.system(size: 15))
						.foregroundColor(.secondary)
						.rotationEffect(.degrees(90))
						.padding(.vertical, 2)
						.padding(.leading, 4)
				}
			}
			.padding(.horizontal, 12)
			.padding(.vertical, 10)
		}
		.frame(maxWidth: .infinity)
	}


}

private func formatViewCount(_ n: Int) -> String {
	if n >= 100_000_000 { return "\(n / 100_000_000)억" }
	if n >= 10_000 { return "\(n / 10_000)만" }
	if n >= 1_000 { return "\(n / 1_000)천" }
	return "\(n)"
}

// MARK: - Player

struct PlayerView: View {
	let video: Video
	@ObservedObject var api: VideoAPI

	@Environment(\.dismiss) var dismiss
	@State var playbackUrl: String?
	@State var errorMsg: String?
	@State var isLiked = false
	@State var likeCount = 0
	@State var isLikeLoading = false
	@State var caption = ""
	@State var comments: [Comment] = []
	@State var commentInput = ""
	@State var isPostingComment = false
	@State var playerState = KollusPlayerState()
	@State var isFullscreen = false
	@State var hasCountedView = false
	@State var isSubscribed = false
	@State var subscriberCount = 0
	@State var isSubLoading = false
	@State var uploaderNickname: String? = nil
	@State var showDeleteConfirm = false
	@State var isDeleting = false
	@State var showEdit = false
	@State var showInfo = false
	@State var likedCommentIds: Set<String> = []
	@State var replyingTo: Comment? = nil
	@State var replyInput: String = ""
	@State var recommendations: [Video] = []

	var isOwnVideo: Bool { video.uploaderId == UserManager.shared.userId }

	private var videoAspectRatio: CGFloat {
		let size = playerState.naturalSize
		guard size != .zero, size.height > 0 else { return 16.0 / 9.0 }
		return size.width / size.height
	}

	var body: some View {
		VStack(spacing: 0) {
			// Player
			ZStack(alignment: .bottom) {
				if let url = playbackUrl, !isFullscreen {
					KollusPlayerRepresentable(contentURL: url, caption: $caption, playerState: playerState, contentFit: true)
						.id(playerState.replayTrigger)
						.frame(maxWidth: .infinity, maxHeight: .infinity)
						.contentShape(Rectangle())
						.onTapGesture { playerState.toggleControls() }

					// 다시 재생 오버레이 (영상 종료 시)
					if playerState.isFinished {
						Button { playerState.replay() } label: {
							VStack(spacing: 10) {
								Image(systemName: "arrow.counterclockwise.circle.fill")
									.font(.system(size: 52))
									.foregroundColor(.white)
								Text("다시 재생")
									.font(.system(size: 14, weight: .medium))
									.foregroundColor(.white)
							}
							.frame(maxWidth: .infinity, maxHeight: .infinity)
							.background(Color.black.opacity(0.45))
						}
						.transition(.opacity)
					}

					VStack(spacing: 0) {
						if !caption.isEmpty {
							Text(caption)
								.font(.system(size: 13, weight: .medium))
								.foregroundColor(.white)
								.multilineTextAlignment(.center)
								.padding(.horizontal, 12)
								.padding(.vertical, 5)
								.background(Color.black.opacity(0.65))
								.cornerRadius(4)
								.padding(.bottom, 4)
						}
						HStack {
							Spacer()
							Button {
								playerState.seekOnReadyTime = playerState.currentTime
								playerState.stopAll()
								if playerState.isLandscape {
									AppDelegate.orientationLock = .landscape
									if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
										scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
									}
								}
								isFullscreen = true
							} label: {
								Image(systemName: "arrow.up.left.and.arrow.down.right")
									.foregroundColor(.white)
									.padding(8)
							}
							.opacity(playerState.showControls ? 1 : 0)
						}
						PlayerControlsView(state: playerState)
					}
				} else if !isFullscreen, errorMsg != nil {
					Color.black
						.aspectRatio(16/9, contentMode: .fit)
						.overlay(
							VStack(spacing: 8) {
								Image(systemName: "exclamationmark.triangle")
									.font(.system(size: 32))
									.foregroundColor(.gray)
								Text("재생할 수 없습니다")
									.font(.system(size: 13))
									.foregroundColor(.gray)
							}
						)
				} else if !isFullscreen {
					Color.black
						.aspectRatio(16/9, contentMode: .fit)
						.overlay(ProgressView().tint(.white))
				} else {
					Color.black
						.aspectRatio(16/9, contentMode: .fit)
				}
			}
			.frame(maxWidth: .infinity)
			.aspectRatio(videoAspectRatio, contentMode: .fit)
			.background(Color.black)
			.clipped()
			.fullScreenCover(isPresented: $isFullscreen) {
				fullscreenView
			}

			ScrollView {
				VStack(alignment: .leading, spacing: 0) {
					// Title — 탭하면 영상 정보 시트
					Button {
						showInfo = true
					} label: {
						VStack(alignment: .leading, spacing: 6) {
							HStack(alignment: .top, spacing: 6) {
								Text(video.title)
									.font(.system(size: 16, weight: .semibold))
									.foregroundColor(.primary)
									.multilineTextAlignment(.leading)
								Spacer()
								Image(systemName: "chevron.down")
									.font(.system(size: 13, weight: .medium))
									.foregroundColor(.secondary)
									.padding(.top, 3)
							}
							if let err = errorMsg {
								Text(err)
									.font(.system(size: 13))
									.foregroundColor(.red)
							}
						}
					}
					.buttonStyle(.plain)
					.padding(.horizontal, 16)
					.padding(.top, 12)
					.padding(.bottom, 10)
					.sheet(isPresented: $showInfo) {
						VideoInfoSheet(video: video, api: api)
					}
					// Action pills
					ScrollView(.horizontal, showsIndicators: false) {
						HStack(spacing: 8) {
							likeDislikePill
							actionPill(icon: "square.and.arrow.up", label: "공유")
							actionPill(icon: "arrow.down.circle", label: "오프라인 저장")
							actionPill(icon: "scissors", label: "클립")
							actionPill(icon: "bookmark", label: "저장")
						}
						.padding(.horizontal, 16)
						.padding(.vertical, 6)
					}

					Divider()

					// Channel row
					HStack(spacing: 12) {
						AvatarView(seed: video.uploaderId ?? video.id, size: 40)

						VStack(alignment: .leading, spacing: 2) {
							let displayName: String = uploaderNickname ?? "사용자 \(String((video.uploaderId ?? "unknown").prefix(6)))"
							Text(displayName)
								.font(.system(size: 14, weight: .semibold))
								.lineLimit(1)
							if subscriberCount > 0 {
								Text("구독자 \(formatViewCount(subscriberCount))명")
									.font(.system(size: 12))
									.foregroundColor(.secondary)
							}
						}

						Spacer()

						if !isOwnVideo {
							Button {
								guard !isSubLoading else { return }
								isSubLoading = true
								api.toggleSubscription(subscriberId: UserManager.shared.userId, channelId: video.uploaderId ?? "") { subscribed, count in
									isSubLoading = false
									isSubscribed = subscribed
									subscriberCount = count
								}
							} label: {
								Text(isSubscribed ? "구독중" : "구독")
									.font(.system(size: 14, weight: .bold))
									.foregroundColor(isSubscribed ? .primary : Color(.systemBackground))
									.padding(.horizontal, 16)
									.padding(.vertical, 8)
									.background(isSubscribed ? Color(.systemGray5) : Color.primary)
									.cornerRadius(20)
							}
							.disabled(isSubLoading)
						}
					}
					.padding(.horizontal, 16)
					.padding(.vertical, 12)

					Divider()

					// Comments header
					HStack {
						Text("댓글")
							.font(.system(size: 15, weight: .semibold))
						Text("\(comments.count)")
							.font(.system(size: 15))
							.foregroundColor(.secondary)
						Spacer()
						Button { } label: {
							HStack(spacing: 4) {
								Image(systemName: "arrow.up.arrow.down")
									.font(.system(size: 12))
								Text("정렬 기준")
									.font(.system(size: 13))
							}
							.foregroundColor(.primary)
						}
					}
					.padding(.horizontal, 16)
					.padding(.top, 14)
					.padding(.bottom, 10)

					// Comment input (댓글 or 답글)
					VStack(spacing: 0) {
						if let reply = replyingTo {
							HStack {
								Image(systemName: "arrow.turn.down.right")
									.font(.system(size: 12))
									.foregroundColor(.secondary)
								Text("\(reply.user_id) 에 답글")
									.font(.system(size: 12))
									.foregroundColor(.secondary)
								Spacer()
								Button {
									replyingTo = nil
									replyInput = ""
								} label: {
									Image(systemName: "xmark")
										.font(.system(size: 12))
										.foregroundColor(.secondary)
								}
							}
							.padding(.horizontal, 16)
							.padding(.vertical, 6)
							.background(Color(.systemGray6))

							HStack(spacing: 10) {
								AvatarView(seed: UserManager.shared.userId, size: 28)
								TextField("답글 추가...", text: $replyInput)
									.font(.system(size: 14))
									.submitLabel(.send)
									.onSubmit { submitReply() }
								if !replyInput.isEmpty {
									Button { submitReply() } label: {
										Image(systemName: "arrow.up.circle.fill")
											.font(.system(size: 26))
											.foregroundColor(.blue)
									}
									.disabled(isPostingComment)
								}
							}
							.padding(.horizontal, 16)
							.padding(.vertical, 10)
						} else {
							HStack(spacing: 10) {
								AvatarView(seed: UserManager.shared.userId, size: 32)
								TextField("댓글 추가...", text: $commentInput)
									.font(.system(size: 14))
									.submitLabel(.send)
									.onSubmit { postComment() }
								if !commentInput.isEmpty {
									Button { postComment() } label: {
										Image(systemName: "arrow.up.circle.fill")
											.font(.system(size: 26))
											.foregroundColor(.blue)
									}
									.disabled(isPostingComment)
								}
							}
							.padding(.horizontal, 16)
							.padding(.vertical, 10)
						}
					}
					.padding(.bottom, 4)

					Divider()

					// Comments list (최상위 댓글만, 답글은 아래에 들여쓰기)
					ForEach(comments.filter { $0.parent_id == nil }) { comment in
						commentRow(comment)
					}

					// 추천 영상
					if !recommendations.isEmpty {
						Divider().padding(.top, 8)
						HStack {
							Image(systemName: "sparkles")
								.font(.system(size: 13))
								.foregroundColor(.orange)
							Text("추천 영상")
								.font(.system(size: 15, weight: .semibold))
						}
						.padding(.horizontal, 16)
						.padding(.vertical, 12)

						ForEach(recommendations) { rec in
							NavigationLink(destination: PlayerView(video: rec, api: api)) {
								VideoCardView(video: rec)
									.frame(maxWidth: .infinity)
							}
							.buttonStyle(.plain)
						}
					}

					Spacer().frame(height: 20)
				}
				.frame(maxWidth: .infinity, alignment: .leading)
			}
		}
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			ToolbarItem(placement: .navigationBarTrailing) {
				HStack(spacing: 18) {
					Button { } label: {
						Image(systemName: "dot.radiowaves.left.and.right")
							.foregroundColor(.primary)
					}
					Menu {
						if isOwnVideo {
							Button {
								showEdit = true
							} label: {
								Label("편집", systemImage: "pencil")
							}
							Divider()
							Button(role: .destructive) {
								showDeleteConfirm = true
							} label: {
								Label("삭제", systemImage: "trash")
							}
						} else {
							Button { } label: { Label("공유", systemImage: "square.and.arrow.up") }
							Button { } label: { Label("재생목록에 추가", systemImage: "text.badge.plus") }
							Button(role: .destructive) { } label: { Label("신고", systemImage: "flag") }
						}
					} label: {
						Image(systemName: "ellipsis")
							.foregroundColor(.primary)
					}
				}
			}
		}
		.sheet(isPresented: $showEdit) {
			VideoEditView(video: video, api: api)
		}
		.confirmationDialog("영상을 삭제할까요?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
			Button("삭제", role: .destructive) { performDelete() }
		}
		.onAppear {
			api.fetchPlaybackToken(videoId: video.id) { url, err in
				playbackUrl = url
				errorMsg = err
			}
			api.fetchLikeStatus(videoId: video.id) { liked, count in
				isLiked = liked
				likeCount = count
			}
			api.fetchComments(videoId: video.id) { fetched in
				comments = fetched
			}
			api.fetchLikedCommentIds(videoId: video.id, userId: UserManager.shared.userId) { ids in
				likedCommentIds = ids
			}
			api.fetchRecommendations(videoId: video.id) { recs in
				recommendations = recs
			}
			// 분석 안 된 영상이면 백그라운드에서 분석 트리거
			if video.status == "ready" {
				api.analyzeVideo(videoId: video.id) { _ in
					api.fetchRecommendations(videoId: video.id) { recs in
						recommendations = recs
					}
				}
			}
			if let uid = video.uploaderId, !uid.isEmpty {
				// 본인 영상이면 로컬 닉네임 즉시 표시
				if uid == UserManager.shared.userId {
					let localNick = UserManager.shared.nickname
					uploaderNickname = localNick.isEmpty ? nil : localNick
				} else {
					api.fetchUploaderProfile(userId: uid) { nick in
						uploaderNickname = nick
					}
				}
				if !isOwnVideo {
					api.fetchSubscription(subscriberId: UserManager.shared.userId, channelId: uid) { subscribed, count in
						isSubscribed = subscribed
						subscriberCount = count
					}
				} else {
					api.fetchSubscription(subscriberId: "none", channelId: uid) { _, count in
						subscriberCount = count
					}
				}
			}
		}
		.onChange(of: playerState.currentTime) { _, newTime in
			guard !hasCountedView else { return }
			let duration = playerState.duration
			guard duration > 0 else { return }
			
			// 10초 이내 영상은 클릭만으로 카운트 (재생 시작하면 바로)
			// 10초 이상 영상은 5초 이상 재생 시 카운트
			let threshold: Double = duration <= 10 ? 0 : 5
			
			if newTime >= threshold {
				hasCountedView = true
				api.recordView(videoId: video.id)
			}
		}
		.onDisappear {
			playerState.stopAll()
			AppDelegate.orientationLock = .portrait
			if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
				scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
			}
		}
	}

	@ViewBuilder
	private func commentRow(_ comment: Comment) -> some View {
		VStack(alignment: .leading, spacing: 0) {
			HStack(alignment: .top, spacing: 10) {
				AvatarView(seed: comment.user_id, size: 32)
				VStack(alignment: .leading, spacing: 4) {
					Text(comment.user_id)
						.font(.system(size: 12, weight: .medium))
						.foregroundColor(.secondary)
					Text(comment.content)
						.font(.system(size: 14))
						.foregroundColor(.primary)
					commentActions(comment)
						.padding(.top, 2)
				}
				Spacer()
			}
			.padding(.horizontal, 16)
			.padding(.top, 10)
			.padding(.bottom, 4)
			ForEach(comments.filter { $0.parent_id == comment.id }) { reply in
				replyRow(reply)
			}
		}
		.padding(.bottom, 6)
	}

	@ViewBuilder
	private func commentActions(_ comment: Comment) -> some View {
		let liked = likedCommentIds.contains(comment.id)
		let count = comment.like_count ?? 0
		HStack(spacing: 16) {
			Button {
				let uid = UserManager.shared.userId
				api.toggleCommentLike(commentId: comment.id, userId: uid) { isLiked in
					if isLiked { likedCommentIds.insert(comment.id) }
					else { likedCommentIds.remove(comment.id) }
					api.fetchComments(videoId: video.id) { fetched in comments = fetched }
				}
			} label: {
				HStack(spacing: 4) {
					Image(systemName: liked ? "hand.thumbsup.fill" : "hand.thumbsup")
						.font(.system(size: 13))
						.foregroundColor(liked ? .primary : .secondary)
					if count > 0 {
						Text("\(count)")
							.font(.system(size: 12))
							.foregroundColor(.secondary)
					}
				}
			}
			Button { } label: {
				Image(systemName: "hand.thumbsdown")
					.font(.system(size: 13))
					.foregroundColor(.secondary)
			}
			Button {
				replyingTo = comment
				replyInput = ""
			} label: {
				Text("답글")
					.font(.system(size: 12, weight: .medium))
					.foregroundColor(.secondary)
			}
		}
	}

	@ViewBuilder
	private func replyRow(_ reply: Comment) -> some View {
		let userId: String = reply.user_id
		let content: String = reply.content
		HStack(alignment: .top, spacing: 8) {
			Spacer().frame(width: 40)
			AvatarView(seed: userId, size: 24)
			VStack(alignment: .leading, spacing: 2) {
				Text(userId)
					.font(.system(size: 11, weight: .medium))
					.foregroundColor(.secondary)
				Text(content)
					.font(.system(size: 13))
					.foregroundColor(.primary)
			}
			Spacer()
		}
		.padding(.horizontal, 16)
		.padding(.vertical, 6)
	}

	private var likeDislikePill: some View {
		HStack(spacing: 0) {
			Button {
				guard !isLikeLoading else { return }
				isLikeLoading = true
				api.toggleLike(videoId: video.id) { liked, count in
					isLikeLoading = false
					if let liked { isLiked = liked }
					if let count { likeCount = count }
				}
			} label: {
				HStack(spacing: 6) {
					Image(systemName: isLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
						.font(.system(size: 14))
					Text(likeCount > 0 ? "\(likeCount)" : "좋아요")
						.font(.system(size: 13, weight: .medium))
				}
				.foregroundColor(.primary)
				.padding(.leading, 14)
				.padding(.trailing, 10)
				.padding(.vertical, 9)
			}
			.disabled(isLikeLoading)
			.opacity(isLikeLoading ? 0.5 : 1)

			Rectangle()
				.fill(Color(.systemGray3))
				.frame(width: 1, height: 20)

			Button { } label: {
				Image(systemName: "hand.thumbsdown")
					.font(.system(size: 14))
					.foregroundColor(.primary)
					.padding(.horizontal, 12)
					.padding(.vertical, 9)
			}
		}
		.background(Color(.systemGray5))
		.cornerRadius(20)
	}

	private func actionPill(icon: String, label: String) -> some View {
		HStack(spacing: 6) {
			Image(systemName: icon)
				.font(.system(size: 14))
			Text(label)
				.font(.system(size: 13, weight: .medium))
		}
		.foregroundColor(.primary)
		.padding(.horizontal, 14)
		.padding(.vertical, 9)
		.background(Color(.systemGray5))
		.cornerRadius(20)
	}

	private var fullscreenView: some View {
		ZStack {
			Color.black.ignoresSafeArea()
			if let url = playbackUrl {
				KollusPlayerRepresentable(contentURL: url, caption: $caption, playerState: playerState, contentFit: true)
					.id(playerState.replayTrigger)
					.frame(maxWidth: .infinity, maxHeight: .infinity)
					.ignoresSafeArea()
					.contentShape(Rectangle())
					.onTapGesture { playerState.toggleControls() }
				VStack {
					HStack {
						Spacer()
						Button {
							playerState.seekOnReadyTime = playerState.currentTime
							playerState.stopAll()
							AppDelegate.orientationLock = .portrait
							UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
							isFullscreen = false
						} label: {
							Image(systemName: "arrow.down.right.and.arrow.up.left")
								.foregroundColor(.white)
								.padding()
						}
					}
					.opacity(playerState.showControls ? 1 : 0)
					Spacer()
					if !caption.isEmpty {
						Text(caption)
							.font(.system(size: 13, weight: .medium))
							.foregroundColor(.white)
							.multilineTextAlignment(.center)
							.padding(.horizontal, 12)
							.padding(.vertical, 5)
							.background(Color.black.opacity(0.65))
							.cornerRadius(4)
							.padding(.bottom, 4)
					}
					PlayerControlsView(state: playerState)
				}
			}
		}
	}

	private func performDelete() {
		isDeleting = true
		api.deleteVideo(videoId: video.id, uploaderId: UserManager.shared.userId) { success in
			isDeleting = false
			if success { dismiss() }
		}
	}

	private func postComment() {
		let text = commentInput.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !text.isEmpty, !isPostingComment else { return }
		isPostingComment = true
		commentInput = ""
		api.postComment(videoId: video.id, content: text, userId: UserManager.shared.userId) { success in
			isPostingComment = false
			if success {
				api.fetchComments(videoId: video.id) { fetched in comments = fetched }
			}
		}
	}

	private func submitReply() {
		let text = replyInput.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !text.isEmpty, !isPostingComment, let parent = replyingTo else { return }
		isPostingComment = true
		replyInput = ""
		replyingTo = nil
		api.postComment(videoId: video.id, content: text, userId: UserManager.shared.userId, parentId: parent.id) { success in
			isPostingComment = false
			if success {
				api.fetchComments(videoId: video.id) { fetched in comments = fetched }
			}
		}
	}
}

// MARK: - Placeholder Tabs

struct ShortsView: View {
	@StateObject private var api = VideoAPI()
	@State private var shorts: [Video] = []
	@State private var currentId: String?
	@State private var isLoading = true

	var body: some View {
		ZStack(alignment: .top) {
			Color.black.ignoresSafeArea()

			if isLoading {
				ProgressView().tint(.white)
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			} else if shorts.isEmpty {
				VStack(spacing: 12) {
					Spacer()
					Image(systemName: "play.rectangle.on.rectangle.fill")
						.font(.system(size: 56))
						.foregroundColor(.gray)
					Text("Shorts가 없습니다")
						.font(.title3.bold())
						.foregroundColor(.white)
					Text("영상 업로드 시 Shorts 옵션을 선택해보세요")
						.font(.subheadline)
						.foregroundColor(.gray)
						.multilineTextAlignment(.center)
						.padding(.horizontal, 32)
					Spacer()
				}
			} else {
				ScrollView(.vertical, showsIndicators: false) {
					LazyVStack(spacing: 0) {
						ForEach(shorts) { video in
							ShortItemView(
								video: video,
								isActive: currentId == video.id,
								api: api
							)
							.containerRelativeFrame(.vertical, count: 1, spacing: 0)
							.id(video.id)
						}
					}
					.scrollTargetLayout()
				}
				.scrollTargetBehavior(.paging)
				.scrollPosition(id: $currentId)
				.ignoresSafeArea(edges: .top)

				// Shorts 로고 오버레이
				HStack {
					HStack(spacing: 4) {
						Image(systemName: "play.rectangle.fill")
							.font(.system(size: 16))
							.foregroundColor(.red)
						Text("Shorts")
							.font(.system(size: 17, weight: .bold))
							.foregroundColor(.white)
					}
					Spacer()
				}
				.padding(.horizontal, 16)
				.padding(.vertical, 12)
			}
		}
		.onAppear { load() }
	}

	private func load() {
		isLoading = true
		api.fetchShorts { fetched in
			shorts = fetched
			currentId = fetched.first?.id
			isLoading = false
		}
	}
}

struct ShortItemView: View {
	let video: Video
	let isActive: Bool
	let api: VideoAPI

	@State private var playerState = KollusPlayerState()
	@State private var playbackUrl: String?
	@State private var caption: String = ""
	@State private var isLiked = false
	@State private var likeCount = 0
	@State private var isFetching = false
	@State private var showComments = false
	@State private var comments: [Comment] = []
	@State private var likedCommentIds: Set<String> = []
	@State private var hasLoadedData = false
	@State private var showInfo = false
	
	var body: some View {
		ZStack {
			Color.black

			// 영상: 화면 전체를 aspect fill로 채움
			if let url = playbackUrl {
				KollusPlayerRepresentable(
					contentURL: url,
					caption: $caption,
					playerState: playerState,
					contentFit: false
				)
				.id(playerState.replayTrigger)
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				.clipped()
			} else {
				ProgressView().tint(.white)
			}

			// 자막
			if !caption.isEmpty {
				Text(caption)
					.font(.system(size: 13, weight: .medium))
					.foregroundColor(.white)
					.multilineTextAlignment(.center)
					.padding(.horizontal, 12)
					.padding(.vertical, 5)
					.background(Color.black.opacity(0.65))
					.cornerRadius(4)
					.padding(.bottom, 120)
					.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
			}

			// 하단 그라디언트
			LinearGradient(
				colors: [.clear, .black.opacity(0.55)],
				startPoint: .init(x: 0.5, y: 0.55),
				endPoint: .bottom
			)
			.allowsHitTesting(false)

			// 왼쪽 하단: 채널 + 제목
			VStack(alignment: .leading, spacing: 8) {
				AvatarView(seed: video.uploaderId ?? video.id, size: 36)
				Button {
						showInfo = true
				} label: {
					Text(video.title)
						.font(.system(size: 14, weight: .semibold))
						.foregroundColor(.white)
						.lineLimit(2)
						.shadow(radius: 1)
				}
			}
			.padding(.leading, 16)
			.padding(.trailing, 90)
			.padding(.bottom, 100)
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

			// 오른쪽 하단: 좋아요 / 댓글 / 공유
			VStack(spacing: 24) {
				Button {
					api.toggleLike(videoId: video.id) { liked, count in
						if let liked { isLiked = liked }
						if let count { likeCount = count }
					}
				} label: {
					VStack(spacing: 4) {
						Image(systemName: isLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
							.font(.system(size: 30))
							.foregroundColor(isLiked ? .blue : .white)
						Text(likeCount > 0 ? formatViewCount(likeCount) : "좋아요")
							.font(.system(size: 12, weight: .medium))
							.foregroundColor(.white)
					}
				}

				Button { showComments = true } label: {
					VStack(spacing: 4) {
						Image(systemName: "bubble.right.fill")
							.font(.system(size: 28))
							.foregroundColor(.white)
						let topCount = comments.filter { $0.parent_id == nil }.count
						Text(topCount > 0 ? formatViewCount(topCount) : "댓글")
							.font(.system(size: 12, weight: .medium))
							.foregroundColor(.white)
					}
				}

				Button {
					let av = UIActivityViewController(activityItems: [video.title], applicationActivities: nil)
					UIApplication.shared.connectedScenes
						.compactMap { $0 as? UIWindowScene }
						.first?.windows.first?.rootViewController?
						.present(av, animated: true)
				} label: {
					VStack(spacing: 4) {
						Image(systemName: "arrowshape.turn.up.right.fill")
							.font(.system(size: 28))
							.foregroundColor(.white)
						Text("공유")
							.font(.system(size: 12, weight: .medium))
							.foregroundColor(.white)
					}
				}
			}
			.padding(.trailing, 16)
			.padding(.bottom, 100)
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
		}
		.onAppear {
			if isActive {
				fetchIfNeeded()
				loadSideDataOnce()
			}
		}
		.onChange(of: isActive) { _, active in
			if active {
				if playbackUrl != nil { playerState.replay() } else { fetchIfNeeded() }
				loadSideDataOnce()
			} else {
				playerState.stopAll()
			}
		}
		.onDisappear { playerState.stopAll() }
		.onChange(of: playbackUrl) { _, newUrl in
			if newUrl != nil && !isActive {
				playerState.stopAll() // URL을 받아와서 플레이어가 준비됐지만, 화면에 안 보이면 즉시 정지
			}
		}
		.sheet(isPresented: $showComments) {
			ShortsCommentSheet(
				video: video,
				api: api,
				comments: $comments,
				likedCommentIds: $likedCommentIds
			)
		}
		.sheet(isPresented: $showInfo) {
			VideoInfoSheet(video: video, api: api)
		}
		.onChange(of: playerState.isFinished) { _, finished in
			if finished && isActive {
				playerState.replay()
			}
		}
	}

	private func fetchIfNeeded() {
		guard playbackUrl == nil, !isFetching else { return }
		isFetching = true
		api.fetchPlaybackToken(videoId: video.id) { url, _ in
			isFetching = false
			playbackUrl = url
		}
	}

	private func loadSideDataOnce() {
		guard !hasLoadedData else { return }
		hasLoadedData = true
		api.fetchLikeStatus(videoId: video.id) { liked, count in
			isLiked = liked
			likeCount = count
		}
		api.fetchComments(videoId: video.id) { fetched in
			comments = fetched
		}
		api.fetchLikedCommentIds(videoId: video.id, userId: UserManager.shared.userId) { ids in
			likedCommentIds = ids
		}
	}
}

struct ShortsCommentSheet: View {
	let video: Video
	let api: VideoAPI
	@Binding var comments: [Comment]
	@Binding var likedCommentIds: Set<String>

	@State private var commentInput = ""
	@State private var isPostingComment = false
	@FocusState private var isInputFocused: Bool
	@Environment(\.dismiss) private var dismiss

	private var topLevelComments: [Comment] { comments.filter { $0.parent_id == nil } }

	var body: some View {
		VStack(spacing: 0) {
			// 헤더
			HStack {
				Text("댓글 \(topLevelComments.count)개")
					.font(.system(size: 15, weight: .semibold))
				Spacer()
				Button { dismiss() } label: {
					Image(systemName: "xmark")
						.font(.system(size: 14, weight: .semibold))
						.foregroundColor(.primary)
						.padding(8)
						.background(Color(.systemGray5))
						.clipShape(Circle())
				}
			}
			.padding(.horizontal, 16)
			.padding(.top, 16)
			.padding(.bottom, 12)

			Divider()

			// 댓글 목록
			ScrollView {
				LazyVStack(alignment: .leading, spacing: 0) {
					if topLevelComments.isEmpty {
						VStack(spacing: 8) {
							Image(systemName: "bubble.right")
								.font(.system(size: 36))
								.foregroundColor(.secondary)
							Text("아직 댓글이 없습니다")
								.font(.subheadline)
								.foregroundColor(.secondary)
						}
						.frame(maxWidth: .infinity)
						.padding(.top, 48)
					} else {
						ForEach(topLevelComments) { comment in
							commentRow(comment)
							Divider().padding(.leading, 58)
						}
					}
				}
				.padding(.bottom, 8)
			}

			Divider()

			// 입력창
			HStack(spacing: 10) {
				AvatarView(seed: UserManager.shared.userId, size: 32)
				TextField("댓글 추가...", text: $commentInput)
					.font(.system(size: 14))
					.focused($isInputFocused)
					.submitLabel(.send)
					.onSubmit { postComment() }
				if !commentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
					Button { postComment() } label: {
						Image(systemName: isPostingComment ? "ellipsis" : "paperplane.fill")
							.foregroundColor(.blue)
							.font(.system(size: 16))
					}
					.disabled(isPostingComment)
				}
			}
			.padding(.horizontal, 16)
			.padding(.vertical, 10)
			.background(Color(.systemBackground))
		}
		.presentationDetents([.medium, .large])
		.presentationDragIndicator(.visible)
		.presentationBackground(Color(.systemBackground))
	}

	@ViewBuilder
	private func commentRow(_ comment: Comment) -> some View {
		VStack(alignment: .leading, spacing: 0) {
			HStack(alignment: .top, spacing: 10) {
				AvatarView(seed: comment.user_id, size: 34)
				VStack(alignment: .leading, spacing: 4) {
					Text(comment.user_id)
						.font(.system(size: 12, weight: .medium))
						.foregroundColor(.secondary)
					Text(comment.content)
						.font(.system(size: 14))
						.foregroundColor(.primary)
					Button {
						if likedCommentIds.contains(comment.id) {
							likedCommentIds.remove(comment.id)
						} else {
							likedCommentIds.insert(comment.id)
						}
						api.toggleCommentLike(commentId: comment.id, userId: UserManager.shared.userId) { _ in }
					} label: {
						HStack(spacing: 4) {
							Image(systemName: likedCommentIds.contains(comment.id) ? "hand.thumbsup.fill" : "hand.thumbsup")
								.font(.system(size: 12))
							Text("좋아요")
								.font(.system(size: 12))
						}
						.foregroundColor(likedCommentIds.contains(comment.id) ? .blue : .secondary)
					}
					.padding(.top, 2)
				}
				Spacer()
			}
			.padding(.horizontal, 16)
			.padding(.vertical, 10)

			// 답글
			let replies = comments.filter { $0.parent_id == comment.id }
			ForEach(replies) { reply in
				HStack(alignment: .top, spacing: 10) {
					Spacer().frame(width: 44)
					AvatarView(seed: reply.user_id, size: 26)
					VStack(alignment: .leading, spacing: 3) {
						Text(reply.user_id)
							.font(.system(size: 12, weight: .medium))
							.foregroundColor(.secondary)
						Text(reply.content)
							.font(.system(size: 13))
							.foregroundColor(.primary)
					}
					Spacer()
				}
				.padding(.horizontal, 16)
				.padding(.vertical, 6)
			}
		}
	}

	private func postComment() {
		let text = commentInput.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !text.isEmpty, !isPostingComment else { return }
		isPostingComment = true
		commentInput = ""
		isInputFocused = false
		api.postComment(videoId: video.id, content: text, userId: UserManager.shared.userId) { success in
			isPostingComment = false
			if success {
				api.fetchComments(videoId: video.id) { fetched in comments = fetched }
			}
		}
	}
}

struct SubscriptionsView: View {
	@StateObject private var api = VideoAPI()
	@State private var videos: [Video] = []
	@State private var channels: [VideoAPI.ChannelInfo] = []
	@State private var isLoading = true

	var body: some View {
		NavigationStack {
			Group {
				if isLoading {
					ProgressView()
						.frame(maxWidth: .infinity, maxHeight: .infinity)
				} else if videos.isEmpty {
					VStack(spacing: 12) {
						Spacer()
						Image(systemName: "person.2.fill")
							.font(.system(size: 56))
							.foregroundColor(.secondary)
						Text("구독한 채널이 없습니다")
							.font(.title3.bold())
						Text("채널을 구독하면 최신 영상을 여기서 볼 수 있습니다")
							.font(.subheadline)
							.foregroundColor(.secondary)
							.multilineTextAlignment(.center)
							.padding(.horizontal, 40)
						Spacer()
					}
				} else {
					ScrollView {
						// 채널 아바타 행
						if !channels.isEmpty {
							ScrollView(.horizontal, showsIndicators: false) {
								HStack(spacing: 16) {
									ForEach(channels) { ch in
										VStack(spacing: 6) {
											AvatarView(seed: ch.id, size: 52)
											Text(ch.nickname ?? String(ch.id.prefix(6)))
												.font(.system(size: 11))
												.lineLimit(1)
												.frame(width: 60)
										}
									}
								}
								.padding(.horizontal, 16)
								.padding(.vertical, 10)
							}
							Divider()
						}

						// 구독 영상 피드
						LazyVStack(alignment: .leading, spacing: 0) {
							ForEach(videos) { video in
								NavigationLink(destination: PlayerView(video: video, api: api)) {
									VideoCardView(video: video)
										.frame(maxWidth: .infinity)
								}
								.buttonStyle(.plain)
								.frame(maxWidth: .infinity, alignment: .leading)
							}
						}
						.frame(maxWidth: .infinity)
					}
					.refreshable { load() }
				}
			}
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .principal) {
					Text("구독").font(.system(size: 17, weight: .bold))
				}
			}
			.onAppear { load() }
		}
	}

	private func load() {
		let uid = UserManager.shared.userId
		isLoading = true
		api.fetchSubscribedChannels(subscriberId: uid) { ch in
			channels = ch
		}
		api.fetchSubscribedVideos(subscriberId: uid) { v in
			videos = v
			isLoading = false
		}
	}
}

struct LibraryView: View {
	var body: some View {
		NavigationStack {
			VStack(spacing: 12) {
				Spacer()
				Image(systemName: "play.square.stack.fill")
					.font(.system(size: 56))
					.foregroundColor(.secondary)
				Text("보관함")
					.font(.title2.bold())
				Text("저장된 동영상이 없습니다")
					.font(.subheadline)
					.foregroundColor(.secondary)
				Spacer()
			}
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .principal) {
					Text("보관함").font(.system(size: 17, weight: .bold))
				}
			}
		}
	}
}

// MARK: - Profile

struct ProfileView: View {
	@ObservedObject var api: VideoAPI
	@ObservedObject private var userManager = UserManager.shared
	@Environment(\.dismiss) var dismiss

	@State private var nickname = ""
	@State private var selectedItem: PhotosPickerItem?
	@State private var previewImage: UIImage?
	@State private var isSaving = false

	var body: some View {
		NavigationView {
			Form {
				Section {
					HStack {
						Spacer()
						PhotosPicker(selection: $selectedItem, matching: .images) {
							ZStack(alignment: .bottomTrailing) {
								if let img = previewImage {
									Image(uiImage: img)
										.resizable()
										.scaledToFill()
										.frame(width: 90, height: 90)
										.clipShape(Circle())
								} else {
									AvatarView(seed: userManager.userId, size: 90)
									.id(userManager.avatarCacheKey)
								}
								Circle()
									.fill(Color(.systemGray2))
									.frame(width: 28, height: 28)
									.overlay(
										Image(systemName: "camera.fill")
											.font(.system(size: 13))
											.foregroundColor(.white)
									)
							}
						}
						.onChange(of: selectedItem) { _, item in
							loadImage(from: item)
						}
						Spacer()
					}
					.padding(.vertical, 8)
				}

				Section("닉네임") {
					TextField("닉네임을 입력하세요", text: $nickname)
						.autocorrectionDisabled()
				}
			}
			.navigationTitle("프로필 설정")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("취소") { dismiss() }
				}
				ToolbarItem(placement: .confirmationAction) {
					Button(isSaving ? "저장 중..." : "저장") {
						Task { await save() }
					}
					.disabled(isSaving || nickname.trimmingCharacters(in: .whitespaces).isEmpty)
				}
			}
		}
		.onAppear { nickname = userManager.nickname }
	}

	private func loadImage(from item: PhotosPickerItem?) {
		guard let item else { return }
		Task {
			if let data = try? await item.loadTransferable(type: Data.self),
			   let img = UIImage(data: data) {
				let resized = resizeImage(img, maxDimension: 400)
				await MainActor.run { previewImage = resized }
			}
		}
	}

	private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
		let w = image.size.width
		let h = image.size.height
		let scale = min(maxDimension / w, maxDimension / h, 1.0)
		let newSize = CGSize(width: w * scale, height: h * scale)
		return UIGraphicsImageRenderer(size: newSize).image { _ in
			image.draw(in: CGRect(origin: .zero, size: newSize))
		}
	}

	private func save() async {
		isSaving = true
		let avatarData = previewImage.flatMap { $0.jpegData(compressionQuality: 0.7) }
		await userManager.updateProfile(
			nickname: nickname.trimmingCharacters(in: .whitespaces),
			avatarData: avatarData
		)
		isSaving = false
		dismiss()
	}
}

// MARK: - VideoInfoSheet

struct VideoInfoSheet: View {
	let video: Video
	@ObservedObject var api: VideoAPI // 🚨 API 전달받도록 추가
	@Environment(\.dismiss) var dismiss
	@State private var showEdit = false // 🚨 편집 시트 상태 추가
	
	var isOwnVideo: Bool { video.uploaderId == UserManager.shared.userId }
	
	var body: some View {
		NavigationView {
			ScrollView {
				VStack(alignment: .leading, spacing: 20) {
					// 제목
					VStack(alignment: .leading, spacing: 6) {
						Text("제목")
							.font(.caption)
							.foregroundColor(.secondary)
						Text(video.title)
							.font(.system(size: 16, weight: .semibold))
					}

					Divider()

					// 설명
					VStack(alignment: .leading, spacing: 6) {
						Text("설명")
							.font(.caption)
							.foregroundColor(.secondary)
						if let desc = video.description, !desc.isEmpty {
							Text(desc)
								.font(.system(size: 15))
								.lineSpacing(4)
						} else {
							Text("설명 없음")
								.font(.system(size: 15))
								.foregroundColor(.secondary)
						}
					}

					Divider()

					// 태그
					VStack(alignment: .leading, spacing: 8) {
						Text("태그")
							.font(.caption)
							.foregroundColor(.secondary)
						if let tags = video.tags, !tags.isEmpty {
							FlowTagsView(tags: tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
						} else {
							Text("태그 없음")
								.font(.system(size: 15))
								.foregroundColor(.secondary)
						}
					}

					Divider()

					// 상태
					HStack {
						Text("상태")
							.font(.caption)
							.foregroundColor(.secondary)
						Spacer()
						Text(video.status == "ready" ? "재생 가능" : video.status)
							.font(.system(size: 14))
							.foregroundColor(video.status == "ready" ? .green : .secondary)
					}

					if let viewCount = video.viewCount, viewCount > 0 {
						HStack {
							Text("조회수")
								.font(.caption)
								.foregroundColor(.secondary)
							Spacer()
							Text("\(formatViewCount(viewCount))회")
								.font(.system(size: 14))
						}
					}
				}
				.padding(20)
			}
			.navigationTitle("영상 정보")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .confirmationAction) {
					Button("닫기") { dismiss() }
				}// 오른쪽에는 영상 주인일 경우에만 편집 버튼 표시
				ToolbarItem(placement: .confirmationAction) {
					if isOwnVideo {
						Button("편집") { showEdit = true }
					}
				}
			}
			.sheet(isPresented: $showEdit) {
				VideoEditView(video: video, api: api)
			}
		}
		.presentationDetents([.medium, .large])
		.presentationDragIndicator(.visible)
	}
}

struct FlowTagsView: View {
	let tags: [String]

	var body: some View {
		LazyVGrid(columns: [GridItem(.adaptive(minimum: 60), spacing: 8)], alignment: .leading, spacing: 8) {
			ForEach(tags, id: \.self) { tag in
				Text("#\(tag)")
					.font(.system(size: 13))
					.foregroundColor(.blue)
					.padding(.horizontal, 10)
					.padding(.vertical, 5)
					.background(Color.blue.opacity(0.1))
					.cornerRadius(14)
			}
		}
	}
}

// MARK: - VideoEditView

struct VideoEditView: View {
	let video: Video
	@ObservedObject var api: VideoAPI
	@Environment(\.dismiss) var dismiss

	@State private var title = ""
	@State private var description = ""
	@State private var tags = ""
	@State private var isSaving = false
	@State private var showError = false

	var body: some View {
		NavigationView {
			Form {
				Section("제목") {
					TextField("제목", text: $title)
				}

				Section("설명") {
					TextEditor(text: $description)
						.frame(minHeight: 100)
						.overlay(
							Group {
								if description.isEmpty {
									Text("영상 내용을 설명해주세요")
										.foregroundColor(.secondary.opacity(0.5))
										.font(.system(size: 16))
										.padding(.top, 8)
										.padding(.leading, 4)
								}
							},
							alignment: .topLeading
						)
				}

				Section {
					TextField("예: 게임, 리뷰, 브이로그", text: $tags)
					Text("쉼표로 구분")
						.font(.caption2)
						.foregroundColor(.secondary)
				} header: {
					Text("태그")
				}
			}
			.navigationTitle("영상 편집")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("취소") { dismiss() }
				}
				ToolbarItem(placement: .confirmationAction) {
					Button(isSaving ? "저장 중..." : "저장") { save() }
						.disabled(isSaving || title.trimmingCharacters(in: .whitespaces).isEmpty)
				}
			}
			.alert("저장 실패", isPresented: $showError) {
				Button("확인", role: .cancel) { }
			} message: {
				Text("영상 정보를 저장하지 못했습니다.")
			}
		}
		.onAppear {
			title = video.title
			description = video.description ?? ""
			tags = video.tags ?? ""
		}
	}

	private func save() {
		let t = title.trimmingCharacters(in: .whitespaces)
		guard !t.isEmpty else { return }
		isSaving = true
		api.updateVideo(
			videoId: video.id,
			title: t,
			description: description.trimmingCharacters(in: .whitespaces),
			tags: tags.trimmingCharacters(in: .whitespaces)
		) { success in
			isSaving = false
			if success {
				dismiss()
				api.fetchVideos()
			} else {
				showError = true
			}
		}
	}
}
