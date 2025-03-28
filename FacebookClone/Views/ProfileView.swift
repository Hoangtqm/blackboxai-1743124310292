import SwiftUI
import SDWebImageSwiftUI
import FirebaseFirestore

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showImagePicker = false
    @State private var profileImage: UIImage?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Profile Header
                ZStack(alignment: .bottomTrailing) {
                    WebImage(url: URL(string: viewModel.user?.coverPhotoURL ?? ""))
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                gradient: Gradient(colors: [.clear, .black.opacity(0.3)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    Button(action: {
                        showImagePicker = true
                    }) {
                        WebImage(url: URL(string: viewModel.user?.profileImageURL ?? ""))
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 4))
                            .offset(y: 60)
                            .padding(.trailing, 20)
                    }
                }
                .padding(.bottom, 60)
                
                // User Info
                VStack(spacing: 8) {
                    Text(viewModel.user?.name ?? "")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(viewModel.user?.bio ?? "No bio yet")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    HStack(spacing: 16) {
                        VStack {
                            Text("\(viewModel.friendsCount)")
                                .fontWeight(.bold)
                            Text("Friends")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        VStack {
                            Text("\(viewModel.postsCount)")
                                .fontWeight(.bold)
                            Text("Posts")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.top, 8)
                }
                
                // Edit Profile Button
                Button(action: {
                    // Edit profile action
                }) {
                    Text("Edit Profile")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray5))
                        .foregroundColor(.black)
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                
                Divider()
                
                // User Posts
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.userPosts) { post in
                        PostView(post: post)
                            .padding(.bottom, 8)
                    }
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $profileImage)
        }
        .onChange(of: profileImage) { newImage in
            if let image = newImage {
                viewModel.uploadProfileImage(image)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.fetchUserData()
        }
    }
}

class ProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var userPosts: [Post] = []
    @Published var friendsCount = 0
    @Published var postsCount = 0
    @Published var isLoading = false
    @Published var error: String?
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage().reference()
    private var cancellables = Set<AnyCancellable>()
    
    func fetchUserData() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        
        // Fetch user data
        db.collection("users").document(userId).addSnapshotListener { [weak self] snapshot, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.error = error.localizedDescription
                    return
                }
                
                self?.user = try? snapshot?.data(as: User.self)
                self?.fetchUserPosts(userId: userId)
                self?.fetchFriendsCount(userId: userId)
            }
        }
    }
    
    func fetchUserPosts(userId: String) {
        db.collection("posts")
            .whereField("userID", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    if let error = error {
                        self?.error = error.localizedDescription
                        return
                    }
                    
                    self?.userPosts = snapshot?.documents.compactMap { document in
                        try? document.data(as: Post.self)
                    } ?? []
                    
                    self?.postsCount = self?.userPosts.count ?? 0
                }
            }
    }
    
    func fetchFriendsCount(userId: String) {
        db.collection("friendships")
            .whereField("users", arrayContains: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.error = error.localizedDescription
                        return
                    }
                    
                    self?.friendsCount = snapshot?.documents.count ?? 0
                }
            }
    }
    
    func uploadProfileImage(_ image: UIImage) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        
        guard let imageData = image.jpegData(compressionQuality: 0.5) else {
            error = "Failed to process image"
            isLoading = false
            return
        }
        
        let imageName = UUID().uuidString
        let imageRef = storage.child("profile_images/\(userId)/\(imageName).jpg")
        
        imageRef.putData(imageData, metadata: nil) { [weak self] _, error in
            if let error = error {
                self?.error = error.localizedDescription
                self?.isLoading = false
                return
            }
            
            imageRef.downloadURL { url, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    if let error = error {
                        self?.error = error.localizedDescription
                        return
                    }
                    
                    if let url = url {
                        self?.updateUserProfileImage(url: url.absoluteString)
                    }
                }
            }
        }
    }
    
    private func updateUserProfileImage(url: String) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users").document(userId).updateData([
            "profileImageURL": url
        ]) { [weak self] error in
            if let error = error {
                self?.error = error.localizedDescription
            } else {
                self?.user?.profileImageURL = url
            }
        }
    }
}