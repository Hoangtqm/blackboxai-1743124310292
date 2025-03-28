import Foundation
import FirebaseFirestore
import FirebaseStorage
import Combine

class PostViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage().reference()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        fetchPosts()
    }
    
    func fetchPosts() {
        isLoading = true
        db.collection("posts")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    if let error = error {
                        self?.error = error.localizedDescription
                        return
                    }
                    
                    self?.posts = snapshot?.documents.compactMap { document in
                        try? document.data(as: Post.self)
                    } ?? []
                }
            }
    }
    
    func createPost(text: String, image: UIImage?) {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        isLoading = true
        error = nil
        
        let postRef = db.collection("posts").document()
        let user = User(
            id: currentUser.uid,
            name: currentUser.displayName ?? "",
            email: currentUser.email ?? "",
            profileImageURL: currentUser.photoURL?.absoluteString
        )
        
        if let image = image {
            uploadImage(image) { [weak self] result in
                switch result {
                case .success(let imageURL):
                    let post = Post(
                        id: postRef.documentID,
                        userID: user.id,
                        text: text,
                        imageURL: imageURL,
                        timestamp: Date()
                    )
                    self?.savePost(post: post, postRef: postRef)
                case .failure(let error):
                    self?.error = error.localizedDescription
                    self?.isLoading = false
                }
            }
        } else {
            let post = Post(
                id: postRef.documentID,
                userID: user.id,
                text: text,
                imageURL: nil,
                timestamp: Date()
            )
            savePost(post: post, postRef: postRef)
        }
    }
    
    private func uploadImage(_ image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.5) else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image"])))
            return
        }
        
        let imageName = UUID().uuidString
        let imageRef = storage.child("posts/\(imageName).jpg")
        
        imageRef.putData(imageData, metadata: nil) { _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            imageRef.downloadURL { url, error in
                if let error = error {
                    completion(.failure(error))
                } else if let url = url {
                    completion(.success(url.absoluteString))
                }
            }
        }
    }
    
    private func savePost(post: Post, postRef: DocumentReference) {
        do {
            try postRef.setData(from: post) { [weak self] error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    if let error = error {
                        self?.error = error.localizedDescription
                    }
                }
            }
        } catch {
            self.error = error.localizedDescription
            self.isLoading = false
        }
    }
}