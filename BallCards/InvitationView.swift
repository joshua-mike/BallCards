// InvitationView.swift - Updated to handle previews
import SwiftUI
import FirebaseFirestore

struct InvitationView: View {
	let invitation: [String: Any]
	@EnvironmentObject var authManager: AuthManager
	@State private var showAcceptSuccess = false
	@State private var showError = false
	
	// Check if we're in preview mode
	private var isPreview: Bool {
		return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
	}
	
	var body: some View {
		VStack(spacing: 20) {
			Image(systemName: "person.2.fill")
				.font(.system(size: 50))
				.foregroundColor(.blue)
			
			Text("You've Been Invited")
				.font(.title)
				.fontWeight(.bold)
			
			Text("You've been invited to join a family group for sharing baseball card collections.")
				.multilineTextAlignment(.center)
				.padding(.horizontal)
			
			VStack(alignment: .leading, spacing: 10) {
				HStack {
					Text("Invited by:")
						.fontWeight(.medium)
					Text(invitation["addedBy"] as? String ?? "Unknown")
				}
				
				HStack {
					Text("Date:")
						.fontWeight(.medium)
					if let timestamp = invitation["addedDate"] as? Timestamp {
						Text(timestamp.dateValue(), style: .date)
					} else if let date = invitation["addedDate"] as? Date {
						Text(date, style: .date)
					} else {
						Text("Unknown date")
					}
				}
			}
			.padding()
			.background(Color.secondary.opacity(0.1))
			.cornerRadius(10)
			
			Spacer()
			
			HStack(spacing: 20) {
				Button("Decline") {
					// In a real app, implement decline logic
				}
				.padding()
				.background(Color.secondary.opacity(0.2))
				.foregroundColor(.primary)
				.cornerRadius(10)
				
				Button("Accept") {
					if isPreview {
						// Just show success in preview
						showAcceptSuccess = true
						return
					}
					
					if let documentPath = invitation["documentPath"] as? String {
						// Extract family ID from document path
						let pathComponents = documentPath.components(separatedBy: "/")
						if pathComponents.count > 1 {
							let familyID = pathComponents[1]
							authManager.acceptInvitation(familyID: familyID) { success in
								if success {
									showAcceptSuccess = true
								} else {
									showError = true
								}
							}
						}
					}
				}
				.padding()
				.background(Color.blue)
				.foregroundColor(.white)
				.cornerRadius(10)
			}
		}
		.padding()
		.alert("Invitation Accepted", isPresented: $showAcceptSuccess) {
			Button("Continue", role: .cancel) { }
		} message: {
			Text("You are now part of the family group.")
		}
		.alert("Error", isPresented: $showError) {
			Button("OK", role: .cancel) { }
		} message: {
			Text(authManager.errorMessage ?? "Something went wrong. Please try again.")
		}
	}
}

struct InvitationView_Previews: PreviewProvider {
	static var previews: some View {
		// Create sample invitation data for preview
		let sampleInvitation: [String: Any] = [
			"addedBy": "example@email.com",
			"addedDate": Date(),  // Use a Date instead of Timestamp for preview
			"status": "pending",
			"documentPath": "families/exampleID/members/example@email.com"
		]
		
		// Create a mock AuthManager for previews
		let mockAuthManager = AuthManager()
		
		InvitationView(invitation: sampleInvitation)
			.environmentObject(mockAuthManager)
	}
}
