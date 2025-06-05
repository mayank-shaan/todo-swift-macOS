//
//  ContentView.swift
//  Todo MacOS Widget
//
//  Main application interface for TODO management - Updated to use shared data model
//

import SwiftUI
import WidgetKit

struct ContentView: View {
    @StateObject private var dataManager = TodoDataManager.shared
    @State private var showingAddTodo = false
    @State private var selectedFilter: TodoFilter = .all
    @State private var searchText = ""
    @State private var selectedTodo: TodoItem?
    @State private var showingEditTodo = false
    
    private var filteredTodos: [TodoItem] {
        let todos = dataManager.fetchAllTodos()
        var filtered = todos
        
        // Apply filter
        switch selectedFilter {
        case .all:
            break
        case .pending:
            filtered = filtered.filter { !$0.isCompleted }
        case .completed:
            filtered = filtered.filter { $0.isCompleted }
        case .overdue:
            filtered = filtered.filter { $0.isOverdue }
        case .dueToday:
            filtered = filtered.filter { $0.isDueToday }
        case .highPriority:
            filtered = filtered.filter { $0.priority == .high || $0.priority == .critical }
        }
        
        // Apply search
        if !searchText.isEmpty {
            filtered = filtered.filter { 
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                ($0.subtitle?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                ($0.category?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationView {
            // Sidebar
            VStack(alignment: .leading, spacing: 0) {
                // Statistics Card
                StatisticsCardView()
                    .padding()
                
                Divider()
                
                // Filters
                List(TodoFilter.allCases, id: \.self, selection: $selectedFilter) { filter in
                    FilterRowView(filter: filter, count: getCount(for: filter))
                }
                .listStyle(SidebarListStyle())
                .navigationTitle("Filters")
            }
            .frame(minWidth: 200, maxWidth: 250)
            
            // Main Content
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text(selectedFilter.displayName)
                        .font(.largeTitle.bold())
                    
                    Spacer()
                    
                    Button(action: { showingAddTodo = true }) {
                        Label("Add Todo", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search todos...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)
                
                Divider()
                
                // Todo List
                if filteredTodos.isEmpty {
                    EmptyStateView(filter: selectedFilter, hasSearchText: !searchText.isEmpty)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(filteredTodos, id: \.id) { todo in
                                TodoCardView(
                                    todo: todo,
                                    onToggleComplete: { dataManager.toggleComplete(todo) },
                                    onEdit: { 
                                        selectedTodo = todo
                                        showingEditTodo = true
                                    },
                                    onDelete: { dataManager.deleteTodo(todo) }
                                )
                            }
                        }
                        .padding()
                    }
                }
                
                Spacer()
            }
            .frame(minWidth: 400)
            .sheet(isPresented: $showingAddTodo) {
                AddTodoView()
            }
            .sheet(isPresented: $showingEditTodo) {
                if let todo = selectedTodo {
                    EditTodoView(todo: todo)
                }
            }
        }
        .navigationTitle("TODO Manager")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Todo") {
                    showingAddTodo = true
                }
            }
            
            #if DEBUG
            ToolbarItem(placement: .secondaryAction) {
                Menu("Debug") {
                    Button("Clear All Data") {
                        dataManager.clearAllData()
                    }
                    
                    Button("Refresh Data") {
                        dataManager.refreshData()
                    }
                    
                    Button("Export Data") {
                        if let exportData = dataManager.exportTodos() {
                            print("Export data: \(exportData)")
                        }
                    }
                    
                    Divider()
                    
                    Button("Test Widget Sync") {
                        let diagnostics = dataManager.testWidgetSync()
                        for result in diagnostics {
                            print(result)
                        }
                    }
                    
                    Button("Force Widget Reload") {
                        WidgetKit.WidgetCenter.shared.reloadAllTimelines()
                        print("🔄 Forced widget timeline reload")
                    }
                }
            }
            #endif
        }
    }
    
    private func getCount(for filter: TodoFilter) -> Int {
        switch filter {
        case .all:
            return dataManager.fetchAllTodos().count
        case .pending:
            return dataManager.fetchIncompleteTodos().count
        case .completed:
            return dataManager.fetchAllTodos().filter { $0.isCompleted }.count
        case .overdue:
            return dataManager.fetchOverdueTodos().count
        case .dueToday:
            return dataManager.fetchTodosDueToday().count
        case .highPriority:
            return dataManager.fetchHighPriorityTodos(limit: 100).count
        }
    }
}

// MARK: - Supporting Views
struct StatisticsCardView: View {
    @StateObject private var dataManager = TodoDataManager.shared
    
    var body: some View {
        let stats = dataManager.getStatistics()
        
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                Text("Overview")
                    .font(.headline.bold())
                
                if let error = dataManager.lastError {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .help("Error: \(error)")
                }
            }
            
            VStack(spacing: 8) {
                HStack {
                    Text("Completion Rate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(stats.completionPercentage)%")
                        .font(.caption.bold())
                        .foregroundColor(stats.isHealthy ? .green : .orange)
                }
                
                ProgressView(value: stats.completionRate)
                    .progressViewStyle(LinearProgressViewStyle(tint: stats.isHealthy ? .green : .orange))
                    .scaleEffect(y: 0.5)
                
                HStack(spacing: 16) {
                    StatItem(title: "Total", value: stats.totalTodos, color: .blue)
                    StatItem(title: "Pending", value: stats.pendingTodos, color: .orange)
                    StatItem(title: "Done", value: stats.completedTodos, color: .green)
                }
                
                if stats.overdueTodos > 0 {
                    HStack {
                        Text("⚠️ \(stats.overdueTodos) overdue task\(stats.overdueTodos == 1 ? "" : "s")")
                            .font(.caption.bold())
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct StatItem: View {
    let title: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title3.bold())
                .foregroundColor(color)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct FilterRowView: View {
    let filter: TodoFilter
    let count: Int
    
    var body: some View {
        HStack {
            Image(systemName: filter.iconName)
                .foregroundColor(filter.color)
                .frame(width: 20)
            
            Text(filter.displayName)
                .font(.subheadline)
            
            Spacer()
            
            if count > 0 {
                Text("\(count)")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(8)
            }
        }
    }
}

struct TodoCardView: View {
    let todo: TodoItem
    let onToggleComplete: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Complete button
            Button(action: onToggleComplete) {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(todo.isCompleted ? .green : .gray)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 6) {
                // Title and priority
                HStack {
                    Text(todo.title)
                        .font(.headline)
                        .strikethrough(todo.isCompleted)
                        .foregroundColor(todo.isCompleted ? .secondary : .primary)
                    
                    Spacer()
                    
                    // Priority indicator
                    if todo.priority != .medium {
                        Label(todo.priority.displayName, systemImage: todo.priority.iconName)
                            .font(.caption.bold())
                            .foregroundColor(priorityColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(priorityColor.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
                
                // Subtitle
                if let subtitle = todo.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // Tags and due date
                HStack(spacing: 12) {
                    if let category = todo.category, !category.isEmpty {
                        Label(category, systemImage: "tag")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let dueDateText = todo.dueDateFormatted {
                        Label(dueDateText, systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(todo.isOverdue ? .red : (todo.isDueToday ? .orange : .secondary))
                    }
                    
                    Spacer()
                    
                    // Action buttons
                    HStack(spacing: 8) {
                        Button("Edit", action: onEdit)
                            .font(.caption)
                            .buttonStyle(.borderless)
                        
                        Button("Delete", action: onDelete)
                            .font(.caption)
                            .foregroundColor(.red)
                            .buttonStyle(.borderless)
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var priorityColor: Color {
        switch todo.priority {
        case .low: return .green
        case .medium: return .blue
        case .high: return .orange
        case .critical: return .red
        }
    }
}

struct EmptyStateView: View {
    let filter: TodoFilter
    let hasSearchText: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: emptyStateIcon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(emptyStateTitle)
                .font(.title2.bold())
                .foregroundColor(.primary)
            
            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var emptyStateIcon: String {
        if hasSearchText {
            return "magnifyingglass"
        }
        
        switch filter {
        case .all: return "checkmark.circle"
        case .pending: return "clock"
        case .completed: return "checkmark.circle.fill"
        case .overdue: return "exclamationmark.triangle"
        case .dueToday: return "calendar"
        case .highPriority: return "exclamationmark.circle"
        }
    }
    
    private var emptyStateTitle: String {
        if hasSearchText {
            return "No Results Found"
        }
        
        switch filter {
        case .all: return "No Todos Yet"
        case .pending: return "All Caught Up!"
        case .completed: return "No Completed Todos"
        case .overdue: return "No Overdue Todos"
        case .dueToday: return "Nothing Due Today"
        case .highPriority: return "No High Priority Todos"
        }
    }
    
    private var emptyStateMessage: String {
        if hasSearchText {
            return "Try adjusting your search terms or check a different filter."
        }
        
        switch filter {
        case .all: return "Create your first todo to get started with managing your tasks."
        case .pending: return "Great job! You have no pending tasks."
        case .completed: return "Complete some todos to see them here."
        case .overdue: return "Excellent! You're staying on top of your deadlines."
        case .dueToday: return "You have a clear schedule for today."
        case .highPriority: return "No urgent tasks require your immediate attention."
        }
    }
}

// MARK: - Filter Enum
enum TodoFilter: CaseIterable {
    case all, pending, completed, overdue, dueToday, highPriority
    
    var displayName: String {
        switch self {
        case .all: return "All Todos"
        case .pending: return "Pending"
        case .completed: return "Completed"
        case .overdue: return "Overdue"
        case .dueToday: return "Due Today"
        case .highPriority: return "High Priority"
        }
    }
    
    var iconName: String {
        switch self {
        case .all: return "list.bullet"
        case .pending: return "clock"
        case .completed: return "checkmark.circle.fill"
        case .overdue: return "exclamationmark.triangle.fill"
        case .dueToday: return "calendar"
        case .highPriority: return "exclamationmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .all: return .blue
        case .pending: return .orange
        case .completed: return .green
        case .overdue: return .red
        case .dueToday: return .purple
        case .highPriority: return .red
        }
    }
}

#Preview {
    ContentView()
}
