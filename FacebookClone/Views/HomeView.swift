import SwiftUI
import SDWebImageSwiftUI

struct HomeView: View {
    @StateObject private var postViewModel = PostViewModel()
    @State private var newPostText = ""
    @State private var showImagePicker = false
    @State private var postImage: UIImage?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Create Post Section
                VStack {
                    HStack {
                        WebImage(url: URL(string: "https://example.com/profile.jpg"))
                            .resizable()
                            .scaledToFill()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                        
                        TextField("What's on your mind?", text: $newPostText)
                            .padding(10)
                            .background(Color(.systemGray6))
                            .cornerRadius(20)
                    }
                    .padding()
                    
                    Divider()
                    
                    HStack {
                        Button(action: {
                            showImagePicker = true
                        }) {
                            HStack {
                                Image(systemName: "photo")
                                Text("Photo")
                            }
                            .foregroundColor(.black)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            postViewModel.createPost(text: newPostText, image: postImage)
                            newPostText = ""
                            postImage = nil
                        }) {
                            Text("Post")
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .background(Color.white)
                
                // Posts List
                LazyVStack(spacing: 0) {
                    ForEach(postViewModel.posts) { post in
                        PostView(post: post)
                            .padding(.bottom, 8)
                    }
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $postImage)
        }
        .navigationTitle("Facebook Clone")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PostView: View {
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                WebImage(url: URL(string: post.user?.profileImageURL ?? ""))
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                
                VStack(alignment: .leading) {
                    Text(post.user?.name ?? "")
                        .fontWeight(.semibold)
                    Text(post.timestamp.formatted())
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            
            Text(post.text)
            
            if let imageURL = post.imageURL {
                WebImage(url: URL(string: imageURL))
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
            }
            
            HStack {
                Button(action: {}) {
                    Image(systemName: "hand.thumbsup")
                    Text("Like")
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "bubble.right")
                    Text("Comment")
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "arrowshape.turn.up.right")
                    Text("Share")
                }
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color.white)
    }
}