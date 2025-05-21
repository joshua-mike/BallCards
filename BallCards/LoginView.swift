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
					
					Text("BallCards")
						.font(.largeTitle)
						.fontWeight(.bold)
					
					Text("Track your sports card collection")
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

struct LoginView_Previews: PreviewProvider {
	static var previews: some View {
		LoginView()
			.environmentObject(AuthManager())
	}
}
