import SwiftUI
import SwiftData

struct WelcomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var userSettings: [UserSettings]
    @Binding var showingWelcome: Bool
    @State private var name: String = ""
    @State private var isAnimating = false
    
    private var settings: UserSettings {
        if let existingSettings = userSettings.first {
            return existingSettings
        }
        let newSettings = UserSettings()
        modelContext.insert(newSettings)
        return newSettings
    }
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)]),
                         startPoint: .topLeading,
                         endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Image(systemName: "figure.climbing")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
                
                Text("Welcome to Climbing Tracker")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Let's start by getting to know you")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                TextField("Enter your name", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal, 50)
                    .padding(.vertical, 10)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                
                Button(action: {
                    withAnimation {
                        saveUserSettings()
                    }
                }) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 200, height: 50)
                        .background(Color.blue)
                        .cornerRadius(25)
                        .shadow(radius: 5)
                }
                .disabled(name.isEmpty)
                .opacity(name.isEmpty ? 0.6 : 1.0)
            }
            .padding()
        }
        .onAppear {
            isAnimating = true
        }
    }
    
    private func saveUserSettings() {
        settings.userName = name
        settings.hasCompletedWelcome = true
        showingWelcome = false
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            Text("Home")
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            
            Text("Training")
                .tabItem {
                    Label("Training", systemImage: "figure.climbing")
                }
            
            Text("Nutrition")
                .tabItem {
                    Label("Nutrition", systemImage: "fork.knife")
                }
            
            Text("Health")
                .tabItem {
                    Label("Health", systemImage: "heart")
                }
            
            Text("Settings")
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
} 