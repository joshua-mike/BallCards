// SportsCardLogApp.swift - Updated
import SwiftUI
import Firebase
import CoreData

@main
struct SportsCardLogApp: App {
	// Register app delegate for Firebase setup
	@UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
	
	// Core Data persistent container
	let persistenceController = PersistenceController.shared
	
	// Authentication manager
	@StateObject var authManager = AuthManager()
	
	var body: some Scene {
		WindowGroup {
			if authManager.isAuthenticated {
				MainTabView()
					.environment(\.managedObjectContext, persistenceController.container.viewContext)
					.environmentObject(authManager)
			} else {
				LoginView()
					.environmentObject(authManager)
			}
		}
	}
}

// MainTabView.swift
struct MainTabView: View {
	@EnvironmentObject var authManager: AuthManager
	@State private var showingProfile = false
	
	var body: some View {
		TabView {
			// Collection Tab
			ContentView()
				.tabItem {
					Label("Collection", systemImage: "baseball")
				}
			
			// Stats Tab
			StatsView()
				.tabItem {
					Label("Stats", systemImage: "chart.bar")
				}
			
			// Settings Tab
			SettingsView()
				.tabItem {
					Label("Settings", systemImage: "gear")
				}
		}
		.sheet(isPresented: $showingProfile) {
			ProfileView()
				.environmentObject(authManager)
		}
	}
}

// StatsView.swift
struct StatsView: View {
	@Environment(\.managedObjectContext) private var viewContext
	@FetchRequest(
		sortDescriptors: [NSSortDescriptor(keyPath: \Card.dateAdded, ascending: false)],
		animation: .default)
	private var cards: FetchedResults<Card>
	
	var body: some View {
		NavigationView {
			if cards.isEmpty {
				VStack {
					Image(systemName: "chart.bar")
						.font(.system(size: 64))
						.foregroundColor(.blue)
					Text("No Stats Available")
						.font(.title)
					Text("Add cards to see statistics")
						.foregroundColor(.secondary)
				}
			} else {
				List {
					Section(header: Text("Collection Overview")) {
						HStack {
							Text("Total Cards")
							Spacer()
							Text("\(cards.count)")
								.fontWeight(.bold)
						}
						
						HStack {
							Text("Unique Teams")
							Spacer()
							Text("\(uniqueTeamsCount)")
								.fontWeight(.bold)
						}
						
						HStack {
							Text("Oldest Card")
							Spacer()
							Text(oldestCardYear)
								.fontWeight(.bold)
						}
					}
					
					Section(header: Text("Teams Breakdown")) {
						ForEach(teamCounts.sorted(by: { $0.count > $1.count }), id: \.team) { teamCount in
							HStack {
								Text(teamCount.team)
								Spacer()
								Text("\(teamCount.count)")
									.fontWeight(.medium)
							}
						}
					}
					
					// More statistics sections could be added here
				}
				.listStyle(InsetGroupedListStyle())
				.navigationTitle("Collection Stats")
			}
		}
	}
	
	// Computed properties for stats
	private var uniqueTeamsCount: Int {
		let teams = Set(cards.compactMap { $0.team })
		return teams.count
	}
	
	private var oldestCardYear: String {
		let years = cards.compactMap { $0.year }
			.compactMap { Int($0) }
			.filter { $0 > 1800 && $0 < 2100 } // Filter out invalid years
		
		if let oldestYear = years.min() {
			return "\(oldestYear)"
		} else {
			return "N/A"
		}
	}
	
	private var teamCounts: [TeamCount] {
		let teams = cards.compactMap { $0.team }
		var counts: [String: Int] = [:]
		
		for team in teams {
			counts[team, default: 0] += 1
		}
		
		return counts.map { TeamCount(team: $0.key, count: $0.value) }
	}
	
	struct TeamCount {
		let team: String
		let count: Int
	}
}

// SettingsView.swift
struct SettingsView: View {
	@EnvironmentObject var authManager: AuthManager
	@State private var showConfirmLogout = false
	@State private var showFamilySharing = false
	@State private var syncInProgress = false
	
	var body: some View {
		NavigationView {
			List {
				Section {
					if let user = authManager.user {
						HStack {
							Image(systemName: "person.circle.fill")
								.font(.system(size: 40))
								.foregroundColor(.blue)
							
							VStack(alignment: .leading) {
								Text(user.email ?? "User")
									.font(.headline)
								Text("Signed In")
									.font(.subheadline)
									.foregroundColor(.green)
							}
						}
						.padding(.vertical, 8)
					}
				}
				
				Section(header: Text("Sharing")) {
					Button(action: {
						showFamilySharing = true
					}) {
						HStack {
							Image(systemName: "person.2.fill")
								.foregroundColor(.blue)
							Text("Family Sharing")
						}
					}
				}
				
				Section(header: Text("Data Management")) {
					Button(action: {
						syncInProgress = true
						// In a real app, implement full sync logic
						// This would sync local data with Firebase
						
						// Simulate a sync delay
						DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
							syncInProgress = false
						}
					}) {
						HStack {
							Image(systemName: "arrow.triangle.2.circlepath")
								.foregroundColor(syncInProgress ? .gray : .blue)
							Text("Sync Collection")
							
							if syncInProgress {
								Spacer()
								ProgressView()
							}
						}
					}
					.disabled(syncInProgress)
					
					Button(action: {
						// In a real app, implement export logic
					}) {
						HStack {
							Image(systemName: "square.and.arrow.up")
								.foregroundColor(.blue)
							Text("Export Collection")
						}
					}
				}
				
				Section {
					Button(action: {
						showConfirmLogout = true
					}) {
						HStack {
							Image(systemName: "escape")
								.foregroundColor(.red)
							Text("Sign Out")
								.foregroundColor(.red)
						}
					}
				}
			}
			.listStyle(InsetGroupedListStyle())
			.navigationTitle("Settings")
			.alert("Sign Out", isPresented: $showConfirmLogout) {
				Button("Cancel", role: .cancel) { }
				Button("Sign Out", role: .destructive) {
					if authManager.signOut() {
						// Successfully signed out
					}
				}
			} message: {
				Text("Are you sure you want to sign out?")
			}
			.sheet(isPresented: $showFamilySharing) {
				NavigationView {
					FamilySharingView()
						.environmentObject(authManager)
						.navigationTitle("Family Sharing")
						.navigationBarItems(trailing: Button("Done") {
							showFamilySharing = false
						})
				}
			}
		}
	}
}

// ProfileView.swift
struct ProfileView: View {
	@EnvironmentObject var authManager: AuthManager
	@Environment(\.presentationMode) var presentationMode
	
	var body: some View {
		NavigationView {
			Form {
				Section(header: Text("Account Information")) {
					if let user = authManager.user {
						HStack {
							Text("Email")
							Spacer()
							Text(user.email ?? "Unknown")
								.foregroundColor(.secondary)
						}
					}
				}
				
				Section {
					Button("Close") {
						presentationMode.wrappedValue.dismiss()
					}
				}
			}
			.navigationTitle("Profile")
			.navigationBarTitleDisplayMode(.inline)
		}
	}
}

// Persistence.swift - Core Data setup
import CoreData

struct PersistenceController {
	static let shared = PersistenceController()
	
	let container: NSPersistentContainer
	
	init(inMemory: Bool = false) {
		container = NSPersistentContainer(name: "SportsCardLog")
		
		if inMemory {
			container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
		}
		
		container.loadPersistentStores { (storeDescription, error) in
			if let error = error as NSError? {
				// Handle the error - in a real app, this should be more robust
				fatalError("Unresolved error \(error), \(error.userInfo)")
			}
		}
		
		container.viewContext.automaticallyMergesChangesFromParent = true
	}
}
