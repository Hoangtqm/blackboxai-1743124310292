import SwiftUI
import SDWebImageSwiftUI
import FirebaseFirestore

struct NotificationsView: View {
    @StateObject private var viewModel = NotificationsViewModel()
    
    var body: some View {
        List {
            ForEach(viewModel.notifications) { notification in
                NotificationRow(notification: notification)
                    .swipeActions {
                        if !notification.isRead {
                            Button("Mark as read") {
                                viewModel.markAsRead(notification: notification)
                            }
                            .tint(.blue)
                        }
                    }
            }
        }
        .listStyle(PlainListStyle())
        .navigationTitle("Notifications")
        .onAppear {
            viewModel.fetchNotifications()
        }
    }
}

struct NotificationRow: View {
    let notification: Notification
    
    var body: some View {
        HStack(spacing: 12) {
            WebImage(url: URL(string: notification.sender?.profileImageURL ?? ""))
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.message)
                    .font(.subheadline)
                    .foregroundColor(notification.isRead ? .gray : .primary)
                
                Text(notification.timestamp.formatted())
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            if !notification.isRead {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

class NotificationsViewModel: ObservableObject {
    @Published var notifications: [Notification] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    
    func fetchNotifications() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        
        db.collection("notifications")
            .whereField("receiverId", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    if let error = error {
                        self?.error = error.localizedDescription
                        return
                    }
                    
                    guard let documents = snapshot?.documents else { return }
                    
                    let notificationIds = documents.map { $0.documentID }
                    let senderIds = documents.compactMap { $0.data()["senderId"] as? String }
                    
                    self?.fetchUsers(ids: senderIds) { users in
                        self?.notifications = zip(notificationIds, documents).map { id, document in
                            let data = document.data()
                            let sender = users.first { $0.id == data["senderId"] as? String }
                            
                            return Notification(
                                id: id,
                                type: data["type"] as? String ?? "",
                                message: data["message"] as? String ?? "",
                                isRead: data["isRead"] as? Bool ?? false,
                                timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                                sender: sender
                            )
                        }
                    }
                }
            }
    }
    
    func markAsRead(notification: Notification) {
        db.collection("notifications").document(notification.id).updateData([
            "isRead": true,
            "readAt": FieldValue.serverTimestamp()
        ]) { [weak self] error in
            if let error = error {
                self?.error = error.localizedDescription
            }
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

struct Notification: Identifiable {
    let id: String
    let type: String
    let message: String
    let isRead: Bool
    let timestamp: Date
    let sender: User?
}