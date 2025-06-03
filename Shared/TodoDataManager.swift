//
//  TodoDataManager.swift
//  Todo MacOS Widget - Shared
//
//  Unified data manager for app and widget using file-based storage with App Groups
//

import Foundation
import SwiftUI
import WidgetKit

// MARK: - Data Manager
class TodoDataManager: ObservableObject {
    static let shared = TodoDataManager()
    
    // CRITICAL: App Group identifier must match in both targets' entitlements
    private let appGroupIdentifier = "group.msdtech.todo-macos-widget"
    
    @Published var todos: [TodoItem] = []
    @Published var isLoading = false
    @Published var lastError: String?
    
    private let fileManager = FileManager.default
    private var dataDirectoryURL: URL?
    
    private init() {
        setupDataDirectory()
        loadTodos()
        setupSampleDataIfNeeded()
    }
    
    // MARK: - File System Setup
    private func setupDataDirectory() {
        guard let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            lastError = "Unable to access App Group container. Check entitlements configuration."
            print("❌ Error: App Group container not accessible")
            return
        }
        
        dataDirectoryURL = containerURL
        print("✅ App Group container URL: \(containerURL)")
        
        // Ensure directory exists
        do {
            try fileManager.createDirectory(at: containerURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("❌ Error creating data directory: \(error)")
            lastError = "Failed to create data directory: \(error.localizedDescription)"
        }
    }
    
    // MARK: - File URLs
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
    @MainActor
    func createTodo(title: String, subtitle: String? = nil, priority: TodoPriority = .medium, dueDate: Date? = nil, category: String? = nil) -> TodoItem {
        var todo = TodoItem(title: title, subtitle: subtitle, priority: priority, dueDate: dueDate, category: category)
        todo.sortOrder = getMaxSortOrder() + 1
        
        todos.append(todo)
        saveTodos()
        
        return todo
    }
    
    @MainActor
    func updateTodo(_ todo: TodoItem) {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        
        var updatedTodo = todo
        updatedTodo.updatedAt = Date()
        todos[index] = updatedTodo
        
        saveTodos()
    }
    
    @MainActor
    func deleteTodo(_ todo: TodoItem) {
        todos.removeAll { $0.id == todo.id }
        saveTodos()
    }
    
    @MainActor
    func toggleComplete(_ todo: TodoItem) {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        
        todos[index].isCompleted.toggle()
        todos[index].updatedAt = Date()
        saveTodos()
    }
    
    @MainActor
    func bulkUpdate(_ updatedTodos: [TodoItem]) {
        for updatedTodo in updatedTodos {
            if let index = todos.firstIndex(where: { $0.id == updatedTodo.id }) {
                var todo = updatedTodo
                todo.updatedAt = Date()
                todos[index] = todo
            }
        }
        saveTodos()
    }
    
    // MARK: - Fetch Operations
    func fetchAllTodos() -> [TodoItem] {
        return todos.sorted { todo1, todo2 in
            // Incomplete todos first
            if todo1.isCompleted != todo2.isCompleted {
                return !todo1.isCompleted
            }
            // Then by priority
            if todo1.priority != todo2.priority {
                return todo1.priority.rawValue > todo2.priority.rawValue
            }
            // Finally by creation date
            return todo1.createdAt > todo2.createdAt
        }
    }
    
    func fetchIncompleteTodos(limit: Int? = nil) -> [TodoItem] {
        let incompleteTodos = todos
            .filter { !$0.isCompleted }
            .sorted { todo1, todo2 in
                // Priority first
                if todo1.priority != todo2.priority {
                    return todo1.priority.rawValue > todo2.priority.rawValue
                }
                // Overdue items first
                if todo1.isOverdue != todo2.isOverdue {
                    return todo1.isOverdue
                }
                // Due today next
                if todo1.isDueToday != todo2.isDueToday {
                    return todo1.isDueToday
                }
                // Creation date last
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
        return todos
            .filter { !$0.isCompleted && ($0.priority == .high || $0.priority == .critical) }
            .sorted { $0.priority.rawValue > $1.priority.rawValue }
            .prefix(limit)
            .map { $0 }
    }
    
    func fetchTodosByCategory(_ category: String) -> [TodoItem] {
        return todos
            .filter { $0.category?.lowercased() == category.lowercased() }
            .sorted { $0.priority.rawValue > $1.priority.rawValue }
    }
    
    func fetchRecentlyCompleted(limit: Int = 5) -> [TodoItem] {
        return todos
            .filter { $0.isCompleted }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(limit)
            .map { $0 }
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
        
        saveStatistics(stats)
        return stats
    }
    
    // MARK: - Data Persistence
    func loadTodos() {
        guard let url = todosFileURL else {
            lastError = "Unable to get todos file URL"
            return
        }
        
        isLoading = true
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            todos = try decoder.decode([TodoItem].self, from: data)
            lastError = nil
            print("✅ Loaded \(todos.count) todos from storage")
        } catch CocoaError.fileReadNoSuchFile {
            // File doesn't exist yet - this is normal for first run
            todos = []
            print("📝 No existing todos file found - starting fresh")
        } catch {
            print("❌ Error loading todos: \(error)")
            lastError = "Failed to load todos: \(error.localizedDescription)"
            
            // Try to load from backup
            loadFromBackup()
        }
        
        isLoading = false
    }
    
    private func loadFromBackup() {
        guard let backupURL = backupFileURL else { return }
        
        do {
            let data = try Data(contentsOf: backupURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            todos = try decoder.decode([TodoItem].self, from: data)
            print("✅ Restored \(todos.count) todos from backup")
            
            // Save the restored data as current
            saveTodos()
        } catch {
            print("❌ Error loading backup: \(error)")
            todos = []
        }
    }
    
    private func saveTodos() {
        guard let url = todosFileURL else {
            lastError = "Unable to get todos file URL"
            return
        }
        
        do {
            // Create backup first
            createBackup()
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let data = try encoder.encode(todos)
            try data.write(to: url, options: .atomic)
            
            lastError = nil
            print("✅ Saved \(todos.count) todos to storage")
            
            // Update statistics
            let _ = getStatistics()
            
            // Trigger widget reload
            WidgetCenter.shared.reloadAllTimelines()
            
        } catch {
            print("❌ Error saving todos: \(error)")
            lastError = "Failed to save todos: \(error.localizedDescription)"
        }
    }
    
    private func createBackup() {
        guard let url = todosFileURL,
              let backupURL = backupFileURL,
              fileManager.fileExists(atPath: url.path) else { return }
        
        do {
            if fileManager.fileExists(atPath: backupURL.path) {
                try fileManager.removeItem(at: backupURL)
            }
            try fileManager.copyItem(at: url, to: backupURL)
        } catch {
            print("⚠️ Warning: Could not create backup: \(error)")
        }
    }
    
    private func saveStatistics(_ stats: TodoStatistics) {
        guard let url = statsFileURL else { return }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let data = try encoder.encode(stats)
            try data.write(to: url, options: .atomic)
        } catch {
            print("❌ Error saving statistics: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    private func getMaxSortOrder() -> Int32 {
        return todos.map { $0.sortOrder }.max() ?? 0
    }
    
    @MainActor
    func clearAllData() {
        todos.removeAll()
        saveTodos()
    }
    
    func refreshData() {
        loadTodos()
    }
    
    // MARK: - Categories
    func getUniqueCategories() -> [String] {
        return Array(Set(todos.compactMap { $0.category })).sorted()
    }
    
    // MARK: - Sample Data
    private func setupSampleDataIfNeeded() {
        if todos.isEmpty {
            createSampleData()
        }
    }
    
    private func createSampleData() {
        print("📝 Creating sample data...")
        
        // High priority tasks
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
            title: "Submit tax documents",
            subtitle: "Gather all receipts and financial statements",
            priority: .critical,
            dueDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()),
            category: "Finance"
        )
        todo3.sortOrder = 3
        sampleTodos.append(todo3)
        
        // Medium priority tasks
        var todo4 = TodoItem(
            title: "Update API documentation",
            subtitle: "Add new endpoints and authentication examples",
            priority: .medium,
            dueDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()),
            category: "Development"
        )
        todo4.sortOrder = 4
        sampleTodos.append(todo4)
        
        var todo5 = TodoItem(
            title: "Plan team building event",
            subtitle: "Research venues and activities for Q1 team retreat",
            priority: .medium,
            dueDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()),
            category: "HR"
        )
        todo5.sortOrder = 5
        sampleTodos.append(todo5)
        
        var todo6 = TodoItem(
            title: "Grocery shopping",
            subtitle: "Weekly groceries: milk, bread, eggs, vegetables, fruits",
            priority: .medium,
            category: "Personal"
        )
        todo6.sortOrder = 6
        sampleTodos.append(todo6)
        
        // Low priority tasks
        var todo7 = TodoItem(
            title: "Organize digital photo library",
            subtitle: "Sort and tag photos from recent vacation",
            priority: .low,
            category: "Personal"
        )
        todo7.sortOrder = 7
        sampleTodos.append(todo7)
        
        var todo8 = TodoItem(
            title: "Read 'Advanced SwiftUI' book",
            subtitle: "Learn about the latest iOS 17 SwiftUI features",
            priority: .low,
            category: "Learning"
        )
        todo8.sortOrder = 8
        sampleTodos.append(todo8)
        
        // Overdue task
        var todo9 = TodoItem(
            title: "Submit monthly expense report",
            subtitle: "Include receipts from business trips and client meetings",
            priority: .high,
            dueDate: Calendar.current.date(byAdding: .day, value: -2, to: Date()),
            category: "Finance"
        )
        todo9.sortOrder = 9
        sampleTodos.append(todo9)
        
        // Completed tasks
        var completedTodo1 = TodoItem(
            title: "Complete client project proposal",
            subtitle: "Delivered comprehensive proposal with timeline and budget",
            priority: .medium,
            category: "Client Work"
        )
        completedTodo1.isCompleted = true
        completedTodo1.updatedAt = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
        completedTodo1.sortOrder = 10
        sampleTodos.append(completedTodo1)
        
        var completedTodo2 = TodoItem(
            title: "Buy birthday gift for mom",
            subtitle: "Found perfect jewelry set at local boutique",
            priority: .medium,
            category: "Personal"
        )
        completedTodo2.isCompleted = true
        completedTodo2.updatedAt = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        completedTodo2.sortOrder = 11
        sampleTodos.append(completedTodo2)
        
        todos = sampleTodos
        saveTodos()
        
        print("✅ Created \(sampleTodos.count) sample todos")
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
            print("❌ Error exporting todos: \(error)")
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
            saveTodos()
            return true
        } catch {
            print("❌ Error importing todos: \(error)")
            return false
        }
    }
}
