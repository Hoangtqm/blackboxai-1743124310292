import SwiftUI
import FirebaseCore

@main
struct FacebookCloneApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                if authViewModel.user != nil {
                    HomeView()
                } else {
                    LoginView(authViewModel: authViewModel)
                }
            }
        }
    }
}