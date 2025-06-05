//
//  TodoDataManager.swift
//  Todo MacOS Widget - Shared
//
//  Enhanced data manager with fallback storage and permissions handling
//

import Foundation
import SwiftUI
import WidgetKit
import OSLog

// MARK: - Storage Strategy Enum
enum StorageStrategy {
    case appGroup
    case userDefaults
    case documentDirectory
    
    var displayName: String {
        switch self {
        case .appGroup: return "App Group"
        case .userDefaults: return "User Defaults"
        case .documentDirectory: return "Documents"
        }
    }
}

// MARK: - Enhanced Data Manager with Fallback Storage
@MainActor
class TodoDataManager: ObservableObject {
    static let shared = TodoDataManager()
    
    // MARK: - Configuration
    private let appGroupIdentifier = "group.msdtech.todo-macos-widget"
    private let logger = Logger(subsystem: "msdtech.todo-macos-widget", category: "DataManager")
    private let userDefaultsKey = "TodoManagerData"
    private let statisticsKey = "TodoManagerStatistics"
    
    // MARK: - Published Properties
    @Published var todos: [TodoItem] = []
    @Published var isLoading = false
    @Published var lastError: String?
    @Published var syncStatus: SyncStatus = .unknown
    @Published var storageStrategy: StorageStrategy = .appGroup
    
    // MARK: - Private Properties
    private let fileManager = FileManager.default
    private var dataDirectoryURL: URL?
    private var permissionsChecked = false
    
    // MARK: - Initialization
    private init() {
        Task {
            await initializeAsync()
        }
    }
    
    private func initializeAsync() async {
        await setupStorageStrategy()
        await loadTodos()
        setupSampleDataIfNeeded()
    }
    
    // MARK: - Storage Strategy Setup
    private func setupStorageStrategy() async {
        // Try App Group first
        if await tryAppGroupStorage() {
            storageStrategy = .appGroup
            syncStatus = .ready
            logger.info("✅ Using App Group storage")
            return
        }
        
        // Fallback to Documents directory
        if await tryDocumentDirectoryStorage() {
            storageStrategy = .documentDirectory
            syncStatus = .ready
            logger.info("📁 Using Documents directory storage")
            return
        }
        
        // Final fallback to UserDefaults
        storageStrategy = .userDefaults
        syncStatus = .ready
        logger.info("💾 Using UserDefaults storage (fallback)")
    }
    
    private func tryAppGroupStorage() async -> Bool {
        guard let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            logger.warning("❌ App Group container not accessible")
            return false
        }
        
        // Test write permissions
        let testURL = containerURL.appendingPathComponent("test_permissions.txt")
        
        do {
            // Ensure directory exists
            try fileManager.createDirectory(at: containerURL, withIntermediateDirectories: true, attributes: nil)
            
            // Test write
            try "test".write(to: testURL, atomically: true, encoding: .utf8)
            
            // Test read
            let _ = try String(contentsOf: testURL)
            
            // Clean up test file
            try? fileManager.removeItem(at: testURL)
            
            dataDirectoryURL = containerURL
            logger.info("✅ App Group storage verified: \(containerURL.path)")
            return true
            
        } catch {
            logger.error("❌ App Group storage failed: \(error.localizedDescription)")
            lastError = "App Group permissions issue: \(error.localizedDescription)"
            return false
        }
    }
    
    private func tryDocumentDirectoryStorage() async -> Bool {
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return false
        }
        
        let todoDirectoryURL = documentsURL.appendingPathComponent("TodoManager")
        let testURL = todoDirectoryURL.appendingPathComponent("test_permissions.txt")
        
        do {
            // Create directory
            try fileManager.createDirectory(at: todoDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            
            // Test write
            try "test".write(to: testURL, atomically: true, encoding: .utf8)
            
            // Test read
            let _ = try String(contentsOf: testURL)
            
            // Clean up test file
            try? fileManager.removeItem(at: testURL)
            
            dataDirectoryURL = todoDirectoryURL
            logger.info("✅ Documents directory storage verified: \(todoDirectoryURL.path)")
            return true
            
        } catch {
            logger.error("❌ Documents directory storage failed: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - File URLs (App Group or Documents Directory)
    private var todosFileURL: URL? {
        return dataDirectoryURL?.appendingPathComponent("todos.json")
    }
    
    private var statsFileURL: URL? {
        return dataDirectoryURL?.appendingPathComponent("stats.json")
    }
    
    private var backupFileURL: URL? {
        return dataDirectoryURL?.appendingPathComponent("todos_backup.json")
    }
    
    // MARK: - CRUD Operations
    func createTodo(
        title: String,
        subtitle: String? = nil,
        priority: TodoPriority = .medium,
        dueDate: Date? = nil,
        category: String? = nil
    ) -> TodoItem {
        var todo = TodoItem(
            title: title,
            subtitle: subtitle,
            priority: priority,
            dueDate: dueDate,
            category: category
        )
        todo.sortOrder = getMaxSortOrder() + 1
        
        todos.append(todo)
        Task {
            await saveTodos()
        }
        
        logger.info("➕ Created todo: \(title)")
        return todo
    }
    
    func updateTodo(_ todo: TodoItem) {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else {
            logger.warning("⚠️ Attempted to update non-existent todo: \(todo.id)")
            return
        }
        
        var updatedTodo = todo
        updatedTodo.updatedAt = Date()
        todos[index] = updatedTodo
        
        Task {
            await saveTodos()
        }
        
        logger.info("✏️ Updated todo: \(todo.title)")
    }
    
    func deleteTodo(_ todo: TodoItem) {
        let oldCount = todos.count
        todos.removeAll { $0.id == todo.id }
        
        if todos.count < oldCount {
            Task {
                await saveTodos()
            }
            logger.info("🗑️ Deleted todo: \(todo.title)")
        }
    }
    
    func toggleComplete(_ todo: TodoItem) {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        
        todos[index].isCompleted.toggle()
        todos[index].updatedAt = Date()
        
        Task {
            await saveTodos()
        }
        
        let status = todos[index].isCompleted ? "completed" : "reopened"
        logger.info("✅ Todo \(status): \(todo.title)")
    }
    
    func bulkUpdate(_ updatedTodos: [TodoItem]) {
        for updatedTodo in updatedTodos {
            if let index = todos.firstIndex(where: { $0.id == updatedTodo.id }) {
                var todo = updatedTodo
                todo.updatedAt = Date()
                todos[index] = todo
            }
        }
        
        Task {
            await saveTodos()
        }
        
        logger.info("📦 Bulk updated \(updatedTodos.count) todos")
    }
    
    // MARK: - Fetch Operations
    func fetchAllTodos() -> [TodoItem] {
        return todos.sorted { todo1, todo2 in
            if todo1.isCompleted != todo2.isCompleted {
                return !todo1.isCompleted
            }
            if todo1.priority != todo2.priority {
                return todo1.priority.rawValue > todo2.priority.rawValue
            }
            return todo1.createdAt > todo2.createdAt
        }
    }
    
    func fetchIncompleteTodos(limit: Int? = nil) -> [TodoItem] {
        let incompleteTodos = todos
            .filter { !$0.isCompleted }
            .sorted { todo1, todo2 in
                if todo1.priority != todo2.priority {
                    return todo1.priority.rawValue > todo2.priority.rawValue
                }
                if todo1.isOverdue != todo2.isOverdue {
                    return todo1.isOverdue
                }
                if todo1.isDueToday != todo2.isDueToday {
                    return todo1.isDueToday
                }
                return todo1.createdAt > todo2.createdAt
            }
        
        if let limit = limit {
            return Array(incompleteTodos.prefix(limit))
        }
        return incompleteTodos
    }
    
    func fetchTodosDueToday() -> [TodoItem] {
        return todos.filter { $0.isDueToday && !$0.isCompleted }
            .sorted { $0.priority.rawValue > $1.priority.rawValue }
    }
    
    func fetchOverdueTodos() -> [TodoItem] {
        return todos.filter { $0.isOverdue }
            .sorted { todo1, todo2 in
                if todo1.priority != todo2.priority {
                    return todo1.priority.rawValue > todo2.priority.rawValue
                }
                return (todo1.dueDate ?? Date.distantPast) < (todo2.dueDate ?? Date.distantPast)
            }
    }
    
    func fetchHighPriorityTodos(limit: Int = 5) -> [TodoItem] {
        return Array(todos
            .filter { !$0.isCompleted && ($0.priority == .high || $0.priority == .critical) }
            .sorted { $0.priority.rawValue > $1.priority.rawValue }
            .prefix(limit))
    }
    
    func fetchTodosByCategory(_ category: String) -> [TodoItem] {
        return todos
            .filter { $0.category?.lowercased() == category.lowercased() }
            .sorted { $0.priority.rawValue > $1.priority.rawValue }
    }
    
    func fetchRecentlyCompleted(limit: Int = 5) -> [TodoItem] {
        return Array(todos
            .filter { $0.isCompleted }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(limit))
    }
    
    // MARK: - Statistics
    func getStatistics() -> TodoStatistics {
        let totalCount = todos.count
        let completedCount = todos.filter { $0.isCompleted }.count
        let overdueCount = todos.filter { $0.isOverdue }.count
        let dueTodayCount = todos.filter { $0.isDueToday && !$0.isCompleted }.count
        
        let stats = TodoStatistics(
            totalTodos: totalCount,
            completedTodos: completedCount,
            pendingTodos: totalCount - completedCount,
            overdueTodos: overdueCount,
            dueTodayTodos: dueTodayCount,
            completionRate: totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0.0
        )
        
        Task {
            await saveStatistics(stats)
        }
        return stats
    }
    
    // MARK: - Data Persistence
    func loadTodos() async {
        isLoading = true
        syncStatus = .syncing
        
        switch storageStrategy {
        case .appGroup, .documentDirectory:
            await loadTodosFromFile()
        case .userDefaults:
            await loadTodosFromUserDefaults()
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    private func loadTodosFromFile() async {
        guard let url = todosFileURL else {
            await MainActor.run {
                lastError = "Unable to get todos file URL"
                syncStatus = .failed
            }
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let loadedTodos = try decoder.decode([TodoItem].self, from: data)
            
            await MainActor.run {
                self.todos = loadedTodos
                lastError = nil
                syncStatus = .synced
                logger.info("✅ Loaded \(loadedTodos.count) todos from \(self.storageStrategy.displayName)")
            }
            
        } catch CocoaError.fileReadNoSuchFile {
            await MainActor.run {
                self.todos = []
                syncStatus = .synced
                logger.info("📝 No existing todos file found - starting fresh")
            }
        } catch {
            logger.error("❌ Error loading todos from file: \(error)")
            await loadFromBackup()
        }
    }
    
    private func loadTodosFromUserDefaults() async {
        do {
            if let data = UserDefaults.standard.data(forKey: userDefaultsKey) {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                let loadedTodos = try decoder.decode([TodoItem].self, from: data)
                
                await MainActor.run {
                    self.todos = loadedTodos
                    lastError = nil
                    syncStatus = .synced
                    logger.info("✅ Loaded \(loadedTodos.count) todos from UserDefaults")
                }
            } else {
                await MainActor.run {
                    self.todos = []
                    syncStatus = .synced
                    logger.info("📝 No existing todos in UserDefaults - starting fresh")
                }
            }
        } catch {
            logger.error("❌ Error loading todos from UserDefaults: \(error)")
            await MainActor.run {
                self.todos = []
                lastError = "Failed to load data: \(error.localizedDescription)"
                syncStatus = .failed
            }
        }
    }
    
    private func loadFromBackup() async {
        guard storageStrategy != .userDefaults,
              let backupURL = backupFileURL else {
            await MainActor.run {
                self.todos = []
                lastError = "Failed to load data and no backup available"
                syncStatus = .failed
            }
            return
        }
        
        do {
            let data = try Data(contentsOf: backupURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let backupTodos = try decoder.decode([TodoItem].self, from: data)
            
            await MainActor.run {
                self.todos = backupTodos
                lastError = "Restored from backup"
                syncStatus = .synced
                logger.info("✅ Restored \(backupTodos.count) todos from backup")
            }
            
            await saveTodos()
            
        } catch {
            logger.error("❌ Error loading backup: \(error)")
            await MainActor.run {
                self.todos = []
                lastError = "Failed to load data and backup: \(error.localizedDescription)"
                syncStatus = .failed
            }
        }
    }
    
    private func saveTodos() async {
        switch storageStrategy {
        case .appGroup, .documentDirectory:
            await saveTodosToFile()
        case .userDefaults:
            await saveTodosToUserDefaults()
        }
    }
    
    private func saveTodosToFile() async {
        guard let url = todosFileURL else {
            await MainActor.run {
                lastError = "Unable to get todos file URL"
                syncStatus = .failed
            }
            return
        }
        
        do {
            // Create backup first
            await createBackup()
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let data = try encoder.encode(self.todos)
            try data.write(to: url, options: .atomic)
            
            await MainActor.run {
                lastError = nil
                syncStatus = .synced
                logger.info("✅ Saved \(self.todos.count) todos to \(self.storageStrategy.displayName)")
            }
            
            let _ = getStatistics()
            WidgetCenter.shared.reloadAllTimelines()
            
        } catch {
            logger.error("❌ Error saving todos to file: \(error)")
            await MainActor.run {
                lastError = "Failed to save todos: \(error.localizedDescription)"
                syncStatus = .failed
            }
        }
    }
    
    private func saveTodosToUserDefaults() async {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            let data = try encoder.encode(self.todos)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            
            await MainActor.run {
                lastError = nil
                syncStatus = .synced
                logger.info("✅ Saved \(self.todos.count) todos to UserDefaults")
            }
            
            let _ = getStatistics()
            WidgetCenter.shared.reloadAllTimelines()
            
        } catch {
            logger.error("❌ Error saving todos to UserDefaults: \(error)")
            await MainActor.run {
                lastError = "Failed to save todos: \(error.localizedDescription)"
                syncStatus = .failed
            }
        }
    }
    
    private func createBackup() async {
        guard storageStrategy != .userDefaults,
              let url = todosFileURL,
              let backupURL = backupFileURL,
              fileManager.fileExists(atPath: url.path) else { return }
        
        do {
            if fileManager.fileExists(atPath: backupURL.path) {
                try fileManager.removeItem(at: backupURL)
            }
            try fileManager.copyItem(at: url, to: backupURL)
        } catch {
            logger.warning("⚠️ Could not create backup: \(error)")
        }
    }
    
    private func saveStatistics(_ stats: TodoStatistics) async {
        switch storageStrategy {
        case .appGroup, .documentDirectory:
            await saveStatisticsToFile(stats)
        case .userDefaults:
            await saveStatisticsToUserDefaults(stats)
        }
    }
    
    private func saveStatisticsToFile(_ stats: TodoStatistics) async {
        guard let url = statsFileURL else { return }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let data = try encoder.encode(stats)
            try data.write(to: url, options: .atomic)
        } catch {
            // Don't fail the whole save operation for statistics
            logger.warning("⚠️ Could not save statistics to file: \(error)")
        }
    }
    
    private func saveStatisticsToUserDefaults(_ stats: TodoStatistics) async {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            let data = try encoder.encode(stats)
            UserDefaults.standard.set(data, forKey: statisticsKey)
        } catch {
            logger.warning("⚠️ Could not save statistics to UserDefaults: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    private func getMaxSortOrder() -> Int32 {
        return todos.map { $0.sortOrder }.max() ?? 0
    }
    
    func clearAllData() {
        todos.removeAll()
        Task {
            await saveTodos()
        }
        logger.info("🗑️ Cleared all data")
    }
    
    func refreshData() {
        Task {
            await loadTodos()
        }
        logger.info("🔄 Manual data refresh triggered")
    }
    
    func getUniqueCategories() -> [String] {
        return Array(Set(todos.compactMap { $0.category })).sorted()
    }
    
    // MARK: - Storage Strategy Management
    func getStorageInfo() -> String {
        switch storageStrategy {
        case .appGroup:
            return "App Group (Shared with Widget)"
        case .documentDirectory:
            return "Documents Directory (App Only)"
        case .userDefaults:
            return "UserDefaults (Limited Sync)"
        }
    }
    
    func canSyncWithWidget() -> Bool {
        return storageStrategy == .appGroup
    }
    
    // MARK: - Diagnostic Methods
    func runDiagnostics() -> [String] {
        var diagnostics: [String] = []
        
        diagnostics.append("Storage Strategy: \(storageStrategy.displayName)")
        diagnostics.append("Sync Status: \(syncStatus.displayName)")
        diagnostics.append("Can Sync with Widget: \(canSyncWithWidget() ? "Yes" : "No")")
        diagnostics.append("Total Todos: \(todos.count)")
        
        if let error = lastError {
            diagnostics.append("Last Error: \(error)")
        }
        
        if let dataURL = dataDirectoryURL {
            diagnostics.append("Data Directory: \(dataURL.path)")
        }
        
        return diagnostics
    }
    
    // MARK: - Sample Data
    private func setupSampleDataIfNeeded() {
        if todos.isEmpty {
            createSampleData()
        }
    }
    
    private func createSampleData() {
        logger.info("📝 Creating sample data...")
        
        var sampleTodos: [TodoItem] = []
        
        var todo1 = TodoItem(
            title: "Fix critical payment processing bug",
            subtitle: "Users unable to complete checkout - immediate attention required",
            priority: .critical,
            dueDate: Calendar.current.date(byAdding: .hour, value: 2, to: Date()),
            category: "Bug Fix"
        )
        todo1.sortOrder = 1
        sampleTodos.append(todo1)
        
        var todo2 = TodoItem(
            title: "Prepare quarterly board presentation",
            subtitle: "Include Q4 metrics, growth projections, and 2025 roadmap",
            priority: .high,
            dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
            category: "Executive"
        )
        todo2.sortOrder = 2
        sampleTodos.append(todo2)
        
        var todo3 = TodoItem(
            title: "Update API documentation",
            subtitle: "Add new endpoints and authentication examples",
            priority: .medium,
            dueDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()),
            category: "Development"
        )
        todo3.sortOrder = 3
        sampleTodos.append(todo3)
        
        var completedTodo = TodoItem(
            title: "Complete client project proposal",
            subtitle: "Delivered comprehensive proposal with timeline and budget",
            priority: .medium,
            category: "Client Work"
        )
        completedTodo.isCompleted = true
        completedTodo.updatedAt = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
        completedTodo.sortOrder = 4
        sampleTodos.append(completedTodo)
        
        todos = sampleTodos
        Task {
            await saveTodos()
        }
        
        logger.info("✅ Created \(sampleTodos.count) sample todos")
    }
    
    // MARK: - Widget Data Access
    func getWidgetTodos(limit: Int = 10) -> [TodoItem] {
        return fetchIncompleteTodos(limit: limit)
    }
    
    // MARK: - Data Export/Import
    func exportTodos() -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(todos)
            return String(data: data, encoding: .utf8)
        } catch {
            logger.error("❌ Error exporting todos: \(error)")
            return nil
        }
    }
    
    func importTodos(from jsonString: String) -> Bool {
        guard let data = jsonString.data(using: .utf8) else { return false }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let importedTodos = try decoder.decode([TodoItem].self, from: data)
            todos.append(contentsOf: importedTodos)
            Task {
                await saveTodos()
            }
            logger.info("📥 Imported \(importedTodos.count) todos")
            return true
        } catch {
            logger.error("❌ Error importing todos: \(error)")
            return false
        }
    }
}

// MARK: - Supporting Types
enum SyncStatus {
    case unknown
    case ready
    case syncing
    case synced
    case failed
    
    var displayName: String {
        switch self {
        case .unknown: return "Unknown"
        case .ready: return "Ready"
        case .syncing: return "Syncing..."
        case .synced: return "Synced"
        case .failed: return "Failed"
        }
    }
    
    var color: Color {
        switch self {
        case .unknown: return .gray
        case .ready: return .blue
        case .syncing: return .orange
        case .synced: return .green
        case .failed: return .red
        }
    }
}
