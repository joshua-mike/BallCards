// AuthManager.swift
import Firebase
import FirebaseAuth
import SwiftUI

class AuthManager: ObservableObject {
	@Published var user: User?
	@Published var isAuthenticated = false
	@Published var errorMessage: String?
	@Published var isLoading = false
	
	init() {
		// Set up auth state listener
		Auth.auth().addStateDidChangeListener { [weak self] (_, user) in
			self?.user = user
			self?.isAuthenticated = user != nil
		}
	}
	
	// Sign in with email and password
	func signIn(email: String, password: String, completion: @escaping (Bool) -> Void) {
		isLoading = true
		errorMessage = nil
		
		Auth.auth().signIn(withEmail: email, password: password) { [weak self] (result, error) in
			self?.isLoading = false
			
			if let error = error {
				self?.errorMessage = error.localizedDescription
				completion(false)
				return
			}
			
			self?.user = result?.user
			self?.isAuthenticated = true
			completion(true)
		}
	}
	
	// Create a new account
	func createAccount(email: String, password: String, completion: @escaping (Bool) -> Void) {
		isLoading = true
		errorMessage = nil
		
		Auth.auth().createUser(withEmail: email, password: password) { [weak self] (result, error) in
			self?.isLoading = false
			
			if let error = error {
				self?.errorMessage = error.localizedDescription
				completion(false)
				return
			}
			
			self?.user = result?.user
			self?.isAuthenticated = true
			completion(true)
		}
	}
	
	// Sign out
	func signOut() -> Bool {
		do {
			try Auth.auth().signOut()
			return true
		} catch {
			errorMessage = error.localizedDescription
			return false
		}
	}
	
	// Reset password
	func resetPassword(email: String, completion: @escaping (Bool) -> Void) {
		isLoading = true
		errorMessage = nil
		
		Auth.auth().sendPasswordReset(withEmail: email) { [weak self] error in
			self?.isLoading = false
			
			if let error = error {
				self?.errorMessage = error.localizedDescription
				completion(false)
				return
			}
			
			completion(true)
		}
	}
	
	// Add family member
	func addFamilyMember(email: String, completion: @escaping (Bool) -> Void) {
		guard let currentUser = Auth.auth().currentUser else {
			errorMessage = "You must be logged in to add family members"
			completion(false)
			return
		}
		
		let db = Firestore.firestore()
		
		// Add to family group collection
		let familyMember = [
			"email": email,
			"addedBy": currentUser.email ?? "Unknown",
			"addedDate": Timestamp(date: Date()),
			"status": "pending"
		]
		
		db.collection("families").document(currentUser.uid).collection("members").document(email).setData(familyMember) { [weak self] error in
			if let error = error {
				self?.errorMessage = error.localizedDescription
				completion(false)
				return
			}
			
			completion(true)
		}
	}
	
	// Check family invitation
	func checkInvitation(completion: @escaping ([String: Any]?) -> Void) {
		guard let currentUserEmail = Auth.auth().currentUser?.email else {
			completion(nil)
			return
		}
		
		let db = Firestore.firestore()
		
		// Look for invitations with this email
		db.collectionGroup("members").whereField("email", isEqualTo: currentUserEmail).getDocuments { (snapshot, error) in
			if let error = error {
				print("Error checking invitations: \(error)")
				completion(nil)
				return
			}
			
			if let document = snapshot?.documents.first {
				completion(document.data())
			} else {
				completion(nil)
			}
		}
	}
	
	// Accept invitation
	func acceptInvitation(familyID: String, completion: @escaping (Bool) -> Void) {
		guard let currentUser = Auth.auth().currentUser,
			  let email = currentUser.email else {
			completion(false)
			return
		}
		
		let db = Firestore.firestore()
		
		// Update invitation status
		db.collection("families").document(familyID).collection("members").document(email).updateData([
			"status": "accepted"
		]) { [weak self] error in
			if let error = error {
				self?.errorMessage = error.localizedDescription
				completion(false)
				return
			}
			
			completion(true)
		}
	}
}
