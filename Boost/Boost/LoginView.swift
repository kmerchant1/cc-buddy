import SwiftUI
import FirebaseAuth

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var navigateToSignUp = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    @Environment(\.colorScheme) var colorScheme
    // This binding will allow us to communicate authentication status back to ContentView
    @Binding var isAuthenticated: Bool
    
    // Preview constructor
    init(isAuthenticated: Binding<Bool> = .constant(false)) {
        self._isAuthenticated = isAuthenticated
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 24) {
                    Spacer()
                    
                    Text("Welcome Back")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    VStack(spacing: 16) {
                        TextField("Email", text: $email)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                            .disabled(isLoading)
                        
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                            .disabled(isLoading)
                        
                        Button(action: {
                            signIn()
                        }) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(10)
                            } else {
                                Text("Log In")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(10)
                            }
                        }
                        .disabled(isLoading)
                        
                        Button(action: {
                            // Google sign-in action placeholder
                            print("Google sign-in tapped")
                        }) {
                            HStack {
                                Image(systemName: "g.circle.fill")
                                    .foregroundColor(.white)
                                Text("Continue with Google")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                        }
                        .disabled(isLoading)
                    }
                    .padding(.horizontal)
                    
                    NavigationLink(destination: SignUpView(isAuthenticated: $isAuthenticated), isActive: $navigateToSignUp) {
                        Button(action: {
                            navigateToSignUp = true
                        }) {
                            Text("Don't have an account? Sign up")
                                .foregroundColor(.white)
                                .underline()
                        }
                        .disabled(isLoading)
                    }
                    
                    if showError {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding(.top, 10)
                    }
                    
                    Spacer()
                }
                .padding()
            }
        }
        .preferredColorScheme(.dark)
        .alert("Error", isPresented: $showError) {
            Button("OK") { showError = false }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func signIn() {
        // For now, just simple validation
        guard !email.isEmpty else {
            errorMessage = "Please enter your email"
            showError = true
            return
        }
        
        guard !password.isEmpty else {
            errorMessage = "Please enter your password"
            showError = true
            return
        }
        
        // Start loading
        isLoading = true
        
        // Firebase authentication
        FirebaseService.shared.signIn(email: email, password: password) { result in
            // UI updates need to happen on main thread
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(let userProfile):
                    print("✅ Successfully signed in user: \(userProfile.email)")
                    isAuthenticated = true
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

#Preview {
    LoginView()
} 