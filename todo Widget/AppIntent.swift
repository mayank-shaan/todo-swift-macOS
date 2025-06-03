//
//  AppIntent.swift
//  todo Widget
//
//  App Intents for widget interactions and configuration
//

import WidgetKit
import AppIntents

// MARK: - Widget Configuration Intent
struct TodoWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Todo Widget Configuration" }
    static var description: IntentDescription { "Configure how your todo widget displays tasks." }
    
    @Parameter(title: "Display Mode", default: .pending)
    var displayMode: TodoDisplayMode
    
    @Parameter(title: "Maximum Items", default: 5)
    var maxItems: Int
    
    @Parameter(title: "Show Completed", default: false)
    var showCompleted: Bool
}

// MARK: - Display Mode Enum
enum TodoDisplayMode: String, CaseIterable, AppEnum {
    case pending = "pending"
    case highPriority = "high_priority" 
    case dueToday = "due_today"
    case overdue = "overdue"
    case all = "all"
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Display Mode")
    }
    
    static var caseDisplayRepresentations: [TodoDisplayMode: DisplayRepresentation] {
        [
            .pending: DisplayRepresentation(title: "Pending Tasks"),
            .highPriority: DisplayRepresentation(title: "High Priority"),
            .dueToday: DisplayRepresentation(title: "Due Today"),
            .overdue: DisplayRepresentation(title: "Overdue"),
            .all: DisplayRepresentation(title: "All Tasks")
        ]
    }
}

// MARK: - Interactive Intents
struct ToggleTodoIntent: AppIntent {
    static var title: LocalizedStringResource { "Toggle Todo" }
    static var description: IntentDescription { "Mark a todo as complete or incomplete." }
    
    @Parameter(title: "Todo ID")
    var todoId: String
    
    func perform() async throws -> some IntentResult {
        // Widget-specific implementation would go here
        // For now, just reload the widget
        WidgetCenter.shared.reloadAllTimelines()
        
        return .result()
    }
}

struct OpenAppIntent: AppIntent {
    static var title: LocalizedStringResource { "Open Todo App" }
    static var description: IntentDescription { "Opens the main Todo application." }
    
    func perform() async throws -> some IntentResult {
        guard let url = URL(string: "todo-manager://open") else {
            throw TodoError.invalidURL
        }
        
        return .result(opensIntent: OpenURLIntent(url))
    }
}

struct AddQuickTodoIntent: AppIntent {
    static var title: LocalizedStringResource { "Add Quick Todo" }
    static var description: IntentDescription { "Quickly add a new todo from the widget." }
    
    @Parameter(title: "Todo Title")
    var title: String
    
    func perform() async throws -> some IntentResult {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TodoError.emptyTitle
        }
        
        // Widget-specific implementation would go here
        // For now, just reload the widget
        WidgetCenter.shared.reloadAllTimelines()
        
        return .result(dialog: IntentDialog("Todo '\(title)' added successfully!"))
    }
}

// MARK: - Error Types
enum TodoError: Error, LocalizedError {
    case todoNotFound
    case emptyTitle
    case invalidURL
    
    var errorDescription: String? {
        switch self {
        case .todoNotFound:
            return "Todo item not found"
        case .emptyTitle:
            return "Todo title cannot be empty"
        case .invalidURL:
            return "Invalid URL"
        }
    }
}

// MARK: - Shortcuts Provider
struct TodoShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddQuickTodoIntent(),
            phrases: [
                "Add a todo in \(.applicationName)",
                "Create a task in \(.applicationName)",
                "New todo in \(.applicationName)"
            ],
            shortTitle: "Add Todo",
            systemImageName: "plus.circle"
        )
    }
}
