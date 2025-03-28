import SwiftUI
import SDWebImageSwiftUI
import FirebaseFirestore

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var messageText = ""
    let recipient: User
    
    var body: some View {
        VStack {
            // Messages List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(
                                message: message,
                                isCurrentUser: message.senderId == Auth.auth().currentUser?.uid
                            )
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages) { _ in
                    scrollToBottom(proxy: proxy)
                }
                .onAppear {
                    scrollToBottom(proxy: proxy)
                }
            }
            
            // Message Input
            HStack {
                TextField("Type a message...", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.leading)
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .padding()
                        .foregroundColor(.white)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
                .padding(.trailing)
                .disabled(messageText.isEmpty)
            }
            .padding(.bottom)
        }
        .navigationTitle(recipient.name)
        .onAppear {
            viewModel.fetchMessages(recipientId: recipient.id)
        }
    }
    
    private func sendMessage() {
        viewModel.sendMessage(
            text: messageText,
            recipientId: recipient.id
        )
        messageText = ""
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = viewModel.messages.last {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
}

struct MessageBubble: View {
    let message: Message
    let isCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer()
                messageContent
            } else {
                messageContent
                Spacer()
            }
        }
    }
    
    private var messageContent: some View {
        VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
            if !isCurrentUser {
                HStack {
                    WebImage(url: URL(string: message.sender?.profileImageURL ?? ""))
                        .resizable()
                        .scaledToFill()
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                    
                    Text(message.sender?.name ?? "")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Text(message.text)
                .padding(10)
                .background(isCurrentUser ? Color.blue : Color(.systemGray5))
                .foregroundColor(isCurrentUser ? .white : .primary)
                .cornerRadius(10)
            
            Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }
}

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    func fetchMessages(recipientId: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        
        // Clear existing listener
        listener?.remove()
        
        // Create conversation ID (sorted to ensure consistency)
        let conversationId = [currentUserId, recipientId].sorted().joined(separator: "_")
        
        listener = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    if let error = error {
                        self?.error = error.localizedDescription
                        return
                    }
                    
                    guard let documents = snapshot?.documents else { return }
                    
                    let messageIds = documents.map { $0.documentID }
                    let senderIds = documents.compactMap { $0.data()["senderId"] as? String }
                    
                    self?.fetchUsers(ids: senderIds) { users in
                        self?.messages = zip(messageIds, documents).map { id, document in
                            let data = document.data()
                            let sender = users.first { $0.id == data["senderId"] as? String }
                            
                            return Message(
                                id: id,
                                text: data["text"] as? String ?? "",
                                senderId: data["senderId"] as? String ?? "",
                                timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                                sender: sender
                            )
                        }
                    }
                }
            }
    }
    
    func sendMessage(text: String, recipientId: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Create conversation ID (sorted to ensure consistency)
        let conversationId = [currentUserId, recipientId].sorted().joined(separator: "_")
        
        let messageData: [String: Any] = [
            "text": text,
            "senderId": currentUserId,
            "timestamp": FieldValue.serverTimestamp(),
            "read": false
        ]
        
        db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .addDocument(data: messageData) { [weak self] error in
                if let error = error {
                    self?.error = error.localizedDescription
                }
            }
        
        // Update conversation last message timestamp
        db.collection("conversations")
            .document(conversationId)
            .setData([
                "participants": [currentUserId, recipientId],
                "lastMessage": text,
                "lastMessageTimestamp": FieldValue.serverTimestamp()
            ], merge: true)
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

struct Message: Identifiable {
    let id: String
    let text: String
    let senderId: String
    let timestamp: Date
    let sender: User?
}