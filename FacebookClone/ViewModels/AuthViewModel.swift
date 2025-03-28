import Foundation
import FirebaseAuth
import Combine

class AuthViewModel: ObservableObject {
    @Published var user: User?
    @Published var error: String?
    @Published var isLoading = false
    
    private var cancellables = Set<AnyCancellable>()
    
    func login(email: String, password: String) {
        isLoading = true
        error = nil
        
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.error = error.localizedDescription
                    return
                }
                
                if let user = result?.user {
                    self?.user = User(
                        id: user.uid,
                        name: user.displayName ?? "",
                        email: user.email ?? "",
                        profileImageURL: user.photoURL?.absoluteString
                    )
                }
            }
        }
    }
    
    func signup(email: String, password: String, name: String) {
        isLoading = true
        error = nil
        
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.error = error.localizedDescription
                    return
                }
                
                if let user = result?.user {
                    let changeRequest = user.createProfileChangeRequest()
                    changeRequest.displayName = name
                    changeRequest.commitChanges { error in
                        if let error = error {
                            self?.error = error.localizedDescription
                        } else {
                            self?.user = User(
                                id: user.uid,
                                name: name,
                                email: email,
                                profileImageURL: nil
                            )
                        }
                    }
                }
            }
        }
    }
    
    func logout() {
        do {
            try Auth.auth().signOut()
            user = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}