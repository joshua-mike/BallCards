// FamilySharingView.swift
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

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
                fetchFamilyMembers()
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
    
    private func fetchFamilyMembers() {
        guard let currentUser = Auth.auth().currentUser else {
            isLoading = false
            return
        }
        
        let db = Firestore.firestore()
        
        // Fetch all members in the family group
        db.collection("families").document(currentUser.uid).collection("members").getDocuments { snapshot, error in
            isLoading = false
            
            if let error = error {
                print("Error fetching family members: \(error)")
                return
            }
            
            if let documents = snapshot?.documents {
                self.membersList = documents.compactMap { doc -> String? in
                    return doc.data()["email"] as? String
                }
            }
        }
    }
}

struct FamilySharingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            FamilySharingView()
                .environmentObject(AuthManager())
        }
    }
}