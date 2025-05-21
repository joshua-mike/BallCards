// BallCardsApp.swift - Updated to handle previews
import SwiftUI
import FirebaseCore
import CoreData

@main
struct BallCardsApp: App {
	// Register app delegate for Firebase setup
	@UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
	
	// Core Data persistent container
	let persistenceController = PersistenceController.shared
	
	// Authentication manager
	@StateObject var authManager = AuthManager()
	
	// Check if we're in preview mode
	private var isPreview: Bool {
		return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
	}
	
	var body: some Scene {
		WindowGroup {
			// If in preview mode, always show ContentView directly
			if isPreview {
				ContentView()
					.environment(\.managedObjectContext, persistenceController.container.viewContext)
			} else {
				// Regular authentication flow for real app
				if authManager.isAuthenticated {
					ContentView()
						.environment(\.managedObjectContext, persistenceController.container.viewContext)
						.environmentObject(authManager)
				} else {
					LoginView()
						.environmentObject(authManager)
				}
			}
		}
	}
}
