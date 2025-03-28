import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth

class FirebaseManager: NSObject {
    static let shared = FirebaseManager()
    
    let auth: Auth
    let firestore: Firestore
    let storage: Storage
    
    override init() {
        FirebaseApp.configure()
        
        self.auth = Auth.auth()
        self.firestore = Firestore.firestore()
        self.storage = Storage.storage()
        
        super.init()
        
        // Configure Firestore settings
        let settings = firestore.settings
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
        firestore.settings = settings
    }
    
    // MARK: - Helper Methods
    
    func currentUserId() -> String? {
        return auth.currentUser?.uid
    }
    
    func currentUserReference() -> DocumentReference? {
        guard let uid = currentUserId() else { return nil }
        return firestore.collection("users").document(uid)
    }
    
    func profileImageReference(userId: String) -> StorageReference {
        return storage.reference().child("profile_images/\(userId).jpg")
    }
    
    func postImageReference(postId: String) -> StorageReference {
        return storage.reference().child("posts/\(postId).jpg")
    }
    
    // MARK: - Error Handling
    
    static func handleError(_ error: Error) -> String {
        if let errorCode = AuthErrorCode.Code(rawValue: error._code) {
            switch errorCode {
            case .emailAlreadyInUse:
                return "The email is already in use"
            case .invalidEmail:
                return "Please enter a valid email"
            case .networkError:
                return "Network error occurred"
            case .weakPassword:
                return "Your password is too weak"
            case .wrongPassword:
                return "Your password is incorrect"
            case .userNotFound:
                return "Account not found"
            case .tooManyRequests:
                return "Too many requests. Try again later"
            default:
                return "An error occurred: \(error.localizedDescription)"
            }
        }
        return error.localizedDescription
    }
}