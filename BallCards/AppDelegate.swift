// AppDelegate.swift - Updated to handle previews
import UIKit
import Firebase

class AppDelegate: NSObject, UIApplicationDelegate {
	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
		// Check if we're running in a preview
		let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
		
		// Only configure Firebase if not in preview mode
		if !isPreview {
			// Initialize Firebase
			FirebaseApp.configure()
		}
		
		return true
	}
}
