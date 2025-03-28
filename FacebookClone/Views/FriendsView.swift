import SwiftUI
import SDWebImageSwiftUI
import FirebaseFirestore

struct FriendsView: View {
    @StateObject private var viewModel = FriendsViewModel()
    @State private var searchText = ""
    
    var body: some View {
        VStack {
            SearchBar(text: $searchText, placeholder: "Search friends")
                .padding(.horizontal)
            
            List {
                Section(header: Text("Friend Requests")) {
                    ForEach(viewModel.friendRequests) { request in
                        FriendRequestRow(request: request) {
                            viewModel.acceptFriendRequest(request)
                        } onDecline: {
                            viewModel.declineFriendRequest(request)
                        }
                    }
                }
                
                Section(header: Text("Friends (\(viewModel.friends.count))")) {
                    ForEach(filteredFriends) { friend in
                        FriendRow(friend: friend)
                    }
                }
            }
            .listStyle(PlainListStyle())
        }
        .navigationTitle("Friends")
        .onAppear {
            viewModel.fetchFriends()
            viewModel.fetchFriendRequests()
        }
    }
    
    var filteredFriends: [User] {
        if searchText.isEmpty {
            return viewModel.friends
        } else {
            return viewModel.friends.filter {
                $0.name.lowercased().contains(searchText.lowercased())
            }
        }
    }
}

struct FriendRow: View {
    let friend: User
    
    var body: some View {
        HStack(spacing: 12) {
            WebImage(url: URL(string: friend.profileImageURL ?? ""))
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            
            Text(friend.name)
                .font(.headline)
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

struct FriendRequestRow: View {
    let request: FriendRequest
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            WebImage(url: URL(string: request.sender.profileImageURL ?? ""))
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(request.sender.name)
                    .font(.headline)
                Text("Sent you a friend request")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: onAccept) {
                    Image(systemName: "checkmark")
                        .padding(8)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                
                Button(action: onDecline) {
                    Image(systemName: "xmark")
                        .padding(8)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct SearchBar: View {
    @Binding var text: String
    var placeholder: String
    
    var body: some View {
        HStack {
            TextField(placeholder, text: $text)
                .padding(8)
                .padding(.horizontal, 24)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 8)
                    }
                )
        }
    }
}

class FriendsViewModel: ObservableObject {
    @Published var friends: [User] = []
    @Published var friendRequests: [FriendRequest] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    
    func fetchFriends() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        
        db.collection("friendships")
            .whereField("users", arrayContains: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    if let error = error {
                        self?.error = error.localizedDescription
                        return
                    }
                    
                    guard let documents = snapshot?.documents else { return }
                    
                    let friendIds = documents.flatMap { doc -> [String] in
                        let data = doc.data()
                        let users = data["users"] as? [String] ?? []
                        return users.filter { $0 != userId }
                    }
                    
                    self?.fetchUsers(ids: friendIds) { users in
                        self?.friends = users
                    }
                }
            }
    }
    
    func fetchFriendRequests() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("friend_requests")
            .whereField("receiverId", isEqualTo: userId)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.error = error.localizedDescription
                        return
                    }
                    
                    guard let documents = snapshot?.documents else { return }
                    
                    let requestIds = documents.map { $0.documentID }
                    let senderIds = documents.compactMap { $0.data()["senderId"] as? String }
                    
                    self?.fetchUsers(ids: senderIds) { users in
                        self?.friendRequests = zip(requestIds, users).map { id, user in
                            FriendRequest(id: id, sender: user, status: "pending")
                        }
                    }
                }
            }
    }
    
    func acceptFriendRequest(_ request: FriendRequest) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Update request status
        db.collection("friend_requests").document(request.id).updateData([
            "status": "accepted",
            "updatedAt": FieldValue.serverTimestamp()
        ]) { [weak self] error in
            if let error = error {
                self?.error = error.localizedDescription
                return
            }
            
            // Create friendship
            self?.db.collection("friendships").addDocument(data: [
                "users": [userId, request.sender.id],
                "createdAt": FieldValue.serverTimestamp()
            ])
            
            // Remove from pending requests
            self?.friendRequests.removeAll { $0.id == request.id }
        }
    }
    
    func declineFriendRequest(_ request: FriendRequest) {
        db.collection("friend_requests").document(request.id).updateData([
            "status": "declined",
            "updatedAt": FieldValue.serverTimestamp()
        ]) { [weak self] error in
            if let error = error {
                self?.error = error.localizedDescription
                return
            }
            
            self?.friendRequests.removeAll { $0.id == request.id }
        }
    }
    
    private func fetchUsers(ids: [String], completion: @escaping ([User]) -> Void) {
        guard !ids.isEmpty else {
            completion([])
            return
        }
        
        db.collection("users")
            .whereField(FieldPath.documentID(), in: ids)
            .getDocuments { snapshot, error in
                if let error = error {
                    self.error = error.localizedDescription
                    completion([])
                    return
                }
                
                let users = snapshot?.documents.compactMap { document in
                    try? document.data(as: User.self)
                } ?? []
                
                completion(users)
            }
    }
}

struct FriendRequest: Identifiable {
    let id: String
    let sender: User
    let status: String
}