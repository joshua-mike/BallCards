//
//  SignUpView.swift
//  BallCards
//
//  Created by Josh May on 5/8/25.
//


// SignUpView.swift
import SwiftUI
import FirebaseAuth

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

struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView()
            .environmentObject(AuthManager())
    }
}
