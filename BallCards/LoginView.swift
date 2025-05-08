// LoginView.swift
import SwiftUI
import FirebaseAuth

struct LoginView: View {
	@EnvironmentObject var authManager: AuthManager
	@State private var email = ""
	@State private var password = ""
	@State private var isShowingSignUp = false
	@State private var isShowingPasswordReset = false
	@State private var passwordResetEmail = ""
	@State private var showPasswordResetSuccess = false
	
	var body: some View {
		NavigationView {
			VStack(spacing: 20) {
				// App logo and title
				VStack(spacing: 10) {
					Image(systemName: "baseball.fill")
						.font(.system(size: 80))
						.foregroundColor(.blue)
					
					Text("SportsCardLog")
						.font(.largeTitle)
						.fontWeight(.bold)
					
					Text("Track your baseball card collection")
						.font(.subheadline)
						.foregroundColor(.secondary)
				}
				.padding(.bottom, 40)
				
				// Login form
				VStack(alignment: .leading, spacing: 8) {
					Text("Email")
						.fontWeight(.medium)
					
					TextField("your@email.com", text: $email)
						.textFieldStyle(RoundedBorderTextFieldStyle())
						.keyboardType(.emailAddress)
						.autocapitalization(.none)
						.disableAutocorrection(true)
				}
				
				VStack(alignment: .leading, spacing: 8) {
					Text("Password")
						.fontWeight(.medium)
					
					SecureField("Password", text: $password)
						.textFieldStyle(RoundedBorderTextFieldStyle())
				}
				
				// Error message
				if let errorMessage = authManager.errorMessage {
					Text(errorMessage)
						.foregroundColor(.red)
						.font(.footnote)
						.padding(.top, 5)
				}
				
				// Sign in button
				Button(action: {
					authManager.signIn(email: email, password: password) { success in
						if success {
							// Check for family invitations
							authManager.checkInvitation { invitation in
								// Handle invitation if exists
							}
						}
					}
				}) {
					HStack {
						Text("Sign In")
							.fontWeight(.semibold)
						
						if authManager.isLoading {
							ProgressView()
								.padding(.leading, 5)
						}
					}
					.frame(maxWidth: .infinity)
					.padding()
					.background(Color.blue)
					.foregroundColor(.white)
					.cornerRadius(10)
				}
				.disabled(email.isEmpty || password.isEmpty || authManager.isLoading)
				
				// Forgot password button
				Button("Forgot Password?") {
					isShowingPasswordReset = true
				}
				.font(.footnote)
				.padding(.top, 5)
				
				Spacer()
				
				// Create account button
				Button("Don't have an account? Create one") {
					isShowingSignUp = true
				}
				.font(.callout)
			}
			.padding()
			.navigationBarHidden(true)
			.sheet(isPresented: $isShowingSignUp) {
				SignUpView()
					.environmentObject(authManager)
			}
			.alert("Reset Password", isPresented: $isShowingPasswordReset) {
				TextField("Enter your email", text: $passwordResetEmail)
					.keyboardType(.emailAddress)
					.autocapitalization(.none)
				
				Button("Cancel", role: .cancel) {
					passwordResetEmail = ""
				}
				
				Button("Reset") {
					authManager.resetPassword(email: passwordResetEmail) { success in
						if success {
							passwordResetEmail = ""
							showPasswordResetSuccess = true
						}
					}
				}
			}
			.alert("Password Reset Email Sent", isPresented: $showPasswordResetSuccess) {
				Button("OK", role: .cancel) { }
			} message: {
				Text("Check your email for instructions to reset your password.")
			}
		}
	}
}

// SignUpView.swift
struct SignUpView: View {
	@EnvironmentObject var authManager: AuthManager
	@Environment(\.presentationMode) var presentationMode
	@State private var email = ""
	@State private var password = ""
	@State private var confirmPassword = ""
	@State private var showPasswordMismatch = false
	
	var body: some View {
		NavigationView {
			Form {
				Section(header: Text("Account Information")) {
					TextField("Email", text: $email)
						.keyboardType(.emailAddress)
						.autocapitalization(.none)
						.disableAutocorrection(true)
					
					SecureField("Password", text: $password)
					SecureField("Confirm Password", text: $confirmPassword)
				}
				
				if let errorMessage = authManager.errorMessage {
					Section {
						Text(errorMessage)
							.foregroundColor(.red)
							.font(.footnote)
					}
				}
				
				Section {
					Button(action: {
						if password == confirmPassword {
							authManager.createAccount(email: email, password: password) { success in
								if success {
									presentationMode.wrappedValue.dismiss()
								}
							}
						} else {
							showPasswordMismatch = true
						}
					}) {
						HStack {
							Text("Create Account")
								.fontWeight(.semibold)
							
							if authManager.isLoading {
								Spacer()
								ProgressView()
							}
						}
					}
					.disabled(email.isEmpty || password.isEmpty || confirmPassword.isEmpty || authManager.isLoading)
				}
			}
			.navigationTitle("Create Account")
			.navigationBarTitleDisplayMode(.inline)
			.navigationBarItems(trailing: Button("Cancel") {
				presentationMode.wrappedValue.dismiss()
			})
			.alert("Passwords Don't Match", isPresented: $showPasswordMismatch) {
				Button("OK", role: .cancel) { }
			} message: {
				Text("Please make sure your passwords match.")
			}
		}
	}
}

// FamilySharingView.swift
struct FamilySharingView: View {
	@EnvironmentObject var authManager: AuthManager
	@State private var familyMemberEmail = ""
	@State private var showAddMemberSuccess = false
	@State private var showAddMemberError = false
	@State private var membersList: [String] = [] // In a real app, fetch from Firestore
	@State private var isLoading = false
	
	var body: some View {
		List {
			Section(header: Text("Add Family Member")) {
				VStack {
					TextField("Email address", text: $familyMemberEmail)
						.keyboardType(.emailAddress)
						.autocapitalization(.none)
						.disableAutocorrection(true)
					
					Button(action: {
						guard !familyMemberEmail.isEmpty else { return }
						
						authManager.addFamilyMember(email: familyMemberEmail) { success in
							if success {
								showAddMemberSuccess = true
								familyMemberEmail = ""
								// In a real app, refresh the members list
							} else {
								showAddMemberError = true
							}
						}
					}) {
						Text("Send Invitation")
							.fontWeight(.medium)
							.frame(maxWidth: .infinity)
							.padding(.vertical, 10)
							.background(Color.blue)
							.foregroundColor(.white)
							.cornerRadius(8)
					}
					.disabled(familyMemberEmail.isEmpty)
					.padding(.top, 8)
				}
			}
			
			Section(header: Text("Family Members")) {
				if isLoading {
					HStack {
						Spacer()
						ProgressView()
						Spacer()
					}
				} else if membersList.isEmpty {
					Text("No family members added yet")
						.foregroundColor(.secondary)
						.italic()
				} else {
					ForEach(membersList, id: \.self) { member in
						Text(member)
					}
				}
			}
			.onAppear {
				// In a real app, fetch family members from Firestore
				isLoading = true
				// Simulating network delay
				DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
					isLoading = false
					// This would populate with real data in the actual implementation
				}
			}
		}
		.listStyle(InsetGroupedListStyle())
		.navigationTitle("Family Sharing")
		.alert("Invitation Sent", isPresented: $showAddMemberSuccess) {
			Button("OK", role: .cancel) { }
		} message: {
			Text("An invitation has been sent to \(familyMemberEmail).")
		}
		.alert("Error", isPresented: $showAddMemberError) {
			Button("OK", role: .cancel) { }
		} message: {
			Text(authManager.errorMessage ?? "Something went wrong. Please try again.")
		}
	}
}

// InvitationView.swift
struct InvitationView: View {
	let invitation: [String: Any]
	@EnvironmentObject var authManager: AuthManager
	@State private var showAcceptSuccess = false
	@State private var showError = false
	
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
