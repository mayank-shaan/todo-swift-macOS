//
//  Todo_MacOS_WIdgetApp.swift
//  Todo MacOS WIdget
//
//  Main application entry point with file-based data storage
//

import SwiftUI

@main
struct Todo_MacOS_WIdgetApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        
        // Settings window
        Settings {
            SettingsView()
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @StateObject private var dataManager = TodoDataManager.shared
    @State private var showingResetAlert = false
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            DataSettingsView(showingResetAlert: $showingResetAlert)
                .tabItem {
                    Label("Data", systemImage: "externaldrive")
                }
            
            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 300)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("showCompletedTodos") private var showCompletedTodos = true
    @AppStorage("defaultPriority") private var defaultPriority = 1
    @AppStorage("enableNotifications") private var enableNotifications = true
    
    var body: some View {
        Form {
            Section("Display") {
                Toggle("Show completed todos", isOn: $showCompletedTodos)
                
                Picker("Default priority for new todos", selection: $defaultPriority) {
                    ForEach(TodoPriority.allCases, id: \.rawValue) { priority in
                        Text(priority.displayName).tag(Int(priority.rawValue))
                    }
                }
            }
            
            Section("Notifications") {
                Toggle("Enable due date notifications", isOn: $enableNotifications)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
    }
}

struct DataSettingsView: View {
    @Binding var showingResetAlert: Bool
    @StateObject private var dataManager = TodoDataManager.shared
    
    var body: some View {
        Form {
            Section("Statistics") {
                let stats = dataManager.getStatistics()
                
                HStack {
                    Text("Total todos:")
                    Spacer()
                    Text("\(stats.totalTodos)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Completed:")
                    Spacer()
                    Text("\(stats.completedTodos)")
                        .foregroundColor(.green)
                }
                
                HStack {
                    Text("Pending:")
                    Spacer()
                    Text("\(stats.pendingTodos)")
                        .foregroundColor(.orange)
                }
                
                HStack {
                    Text("Completion rate:")
                    Spacer()
                    Text("\(stats.completionPercentage)%")
                        .foregroundColor(.blue)
                }
            }
            
            Section("Data Management") {
                Button("Reset All Data") {
                    showingResetAlert = true
                }
                .foregroundColor(.red)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Data")
        .alert("Reset All Data", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetAllData()
            }
        } message: {
            Text("This will permanently delete all your todos. This action cannot be undone.")
        }
    }
    
    private func resetAllData() {
        dataManager.clearAllData()
    }
}

struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "checklist")
                    .font(.largeTitle)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading) {
                    Text("TODO Manager")
                        .font(.title.bold())
                    Text("Version 1.0")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Text("A simple and elegant todo management app with widget support for macOS.")
                .font(.body)
                .foregroundColor(.secondary)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Features:")
                    .font(.headline)
                
                Text("• Create and organize todos with priorities")
                Text("• Set due dates and categories")
                Text("• View progress with statistics")
                Text("• Widget support for quick access")
                Text("• Data syncing between app and widget")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding()
        .navigationTitle("About")
    }
}
