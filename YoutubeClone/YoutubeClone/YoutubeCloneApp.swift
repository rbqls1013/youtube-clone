import SwiftUI

// MARK: - Kollus SDK 인증 정보 (카테노이드 발급)
private let kollusApplicationKey   = "KOLLUS_APPLICATION_KEY"   // 인증 키
private let kollusExpireDateString = "YYYY-MM_DD"             // 유효기간 (yyyy-MM-dd)

let kollusStorage: KollusStorage = KollusStorage()

class AppDelegate: NSObject, UIApplicationDelegate {
	static var orientationLock = UIInterfaceOrientationMask.portrait

	func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
		return AppDelegate.orientationLock
	}
}

@main
struct YoutubeCloneApp: App {
	@UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

	init() {
		kollusStorage.applicationKey = kollusApplicationKey
		kollusStorage.applicationBundleID = Bundle.main.bundleIdentifier ?? ""
		let formatter = DateFormatter()
		formatter.dateFormat = "yyyy-MM-dd"
		if let expireDate = formatter.date(from: kollusExpireDateString) {
			kollusStorage.applicationExpireDate = expireDate
		}

		let docPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? ""
		kollusStorage.setKollusPath(docPath)

		do {
			try kollusStorage.startWithCheck()
			print("[Kollus] Storage 초기화 완료")
		} catch {
			print("[Kollus] Storage 초기화 실패: \(error)")
		}
	}

	var body: some Scene {
		WindowGroup {
			ContentView()
				.task { await UserManager.shared.setup() }
		}
	}
}
