//
//  todo_Widget_2.swift
//  todo Widget 2
//
//  TODO Widget connected to real app data
//

import WidgetKit
import SwiftUI

// MARK: - Widget Data Manager
class WidgetDataManager {
    static let shared = WidgetDataManager()
    
    private init() {}
    
    func getTodos(limit: Int = 10) -> [TodoItem] {
        let dataManager = TodoDataManager.shared
        return dataManager.fetchIncompleteTodos(limit: limit)
    }
    
    func getStatistics() -> TodoStatistics {
        let dataManager = TodoDataManager.shared
        return dataManager.getStatistics()
    }
    
    // Fallback sample data if no real data exists
    func getSampleTodos() -> [TodoItem] {
        return [
            TodoItem(
                title: "Complete project proposal",
                subtitle: "Add final sections and review",
                priority: .high,
                dueDate: Calendar.current.date(byAdding: .hour, value: 2, to: Date()),
                category: "Work"
            ),
            TodoItem(
                title: "Submit expense report",
                subtitle: "Include receipts from last month",
                priority: .critical,
                dueDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
                category: "Finance"
            ),
            TodoItem(
                title: "Buy groceries",
                subtitle: "Weekly shopping list",
                priority: .medium,
                category: "Personal"
            )
        ]
    }
    
    func getSampleStatistics() -> TodoStatistics {
        return TodoStatistics(
            totalTodos: 12,
            completedTodos: 8,
            pendingTodos: 4,
            overdueTodos: 1,
            dueTodayTodos: 2,
            completionRate: 0.67
        )
    }
}

// MARK: - Timeline Provider
struct TodoProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodoEntry {
        let widgetData = WidgetDataManager.shared
        return TodoEntry(
            date: Date(),
            todos: widgetData.getSampleTodos(),
            statistics: widgetData.getSampleStatistics()
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (TodoEntry) -> Void) {
        let widgetData = WidgetDataManager.shared
        let todos = widgetData.getTodos(limit: 10)
        let statistics = widgetData.getStatistics()
        
        let entry = TodoEntry(
            date: Date(),
            todos: todos.isEmpty ? widgetData.getSampleTodos() : todos,
            statistics: statistics
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodoEntry>) -> Void) {
        let widgetData = WidgetDataManager.shared
        let todos = widgetData.getTodos(limit: 10)
        let statistics = widgetData.getStatistics()
        
        let currentDate = Date()
        let entry = TodoEntry(
            date: currentDate,
            todos: todos.isEmpty ? widgetData.getSampleTodos() : todos,
            statistics: statistics
        )
        
        // Update more frequently if there are urgent items
        let hasUrgentItems = todos.contains { $0.isDueToday || $0.isOverdue }
        let updateInterval = hasUrgentItems ? 5 : 15
        
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: updateInterval, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
}

// MARK: - Timeline Entry
struct TodoEntry: TimelineEntry {
    let date: Date
    let todos: [TodoItem]
    let statistics: TodoStatistics
}

// MARK: - Widget Views
struct TodoWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: TodoEntry
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallTodoWidget(entry: entry)
        case .systemMedium:
            MediumTodoWidget(entry: entry)
        default:
            SmallTodoWidget(entry: entry)
        }
    }
}

// MARK: - Small Widget
struct SmallTodoWidget: View {
    let entry: TodoEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "checklist")
                    .foregroundColor(.white)
                    .font(.headline)
                Text("TODO")
                    .font(.headline.bold())
                    .foregroundColor(.white)
                Spacer()
                
                // Urgent indicator
                if entry.todos.contains(where: { $0.isOverdue }) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            
            // Statistics
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(entry.statistics.pendingTodos)")
                        .font(.title2.bold())
                        .foregroundColor(.orange)
                    Text("Pending")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(entry.statistics.completionPercentage)%")
                        .font(.title2.bold())
                        .foregroundColor(.green)
                    Text("Done")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            Spacer()
            
            // Top priority todo
            if let firstTodo = entry.todos.first {
                VStack(alignment: .leading, spacing: 2) {
                    Text(firstTodo.title)
                        .font(.caption.bold())
                        .lineLimit(2)
                        .foregroundColor(.white)
                    
                    if firstTodo.isOverdue {
                        Label("Overdue", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundColor(.red)
                    } else if firstTodo.isDueToday {
                        Label("Due Today", systemImage: "calendar")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    } else if let timeUntilDue = firstTodo.timeUntilDue {
                        Text(timeUntilDue)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            } else {
                VStack(spacing: 4) {
                    Text("All caught up! 🎉")
                        .font(.caption.bold())
                        .foregroundColor(.green)
                    Text("No pending tasks")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.blue.gradient, for: .widget)
    }
}

// MARK: - Medium Widget
struct MediumTodoWidget: View {
    let entry: TodoEntry
    
    var body: some View {
        HStack(spacing: 12) {
            // Left side - Statistics
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "checklist")
                        .foregroundColor(.white)
                        .font(.headline)
                    Text("TODO")
                        .font(.headline.bold())
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if entry.statistics.overdueTodos > 0 {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    StatRow(title: "Pending", value: "\(entry.statistics.pendingTodos)", color: .orange)
                    StatRow(title: "Completed", value: "\(entry.statistics.completedTodos)", color: .green)
                    if entry.statistics.overdueTodos > 0 {
                        StatRow(title: "Overdue", value: "\(entry.statistics.overdueTodos)", color: .red)
                    }
                    if entry.statistics.dueTodayTodos > 0 {
                        StatRow(title: "Due Today", value: "\(entry.statistics.dueTodayTodos)", color: .orange)
                    }
                }
                
                Spacer()
                
                // Progress indicator
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(entry.statistics.completionPercentage)% Complete")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.8))
                    
                    ProgressView(value: entry.statistics.completionRate)
                        .progressViewStyle(LinearProgressViewStyle(tint: entry.statistics.isHealthy ? .green : .orange))
                        .scaleEffect(y: 0.5)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Right side - Todo list
            VStack(alignment: .leading, spacing: 6) {
                Text("Up Next")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                
                if entry.todos.isEmpty {
                    Spacer()
                    VStack(spacing: 4) {
                        Text("All caught up! 🎉")
                            .font(.caption.bold())
                            .foregroundColor(.green)
                        Text("No pending tasks")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    Spacer()
                } else {
                    ForEach(Array(entry.todos.prefix(4).enumerated()), id: \.element.id) { index, todo in
                        TodoRowView(todo: todo, isCompact: true)
                    }
                    
                    if entry.todos.count > 4 {
                        Text("+ \(entry.todos.count - 4) more")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.top, 2)
                    }
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.blue.gradient, for: .widget)
    }
}

// MARK: - Supporting Views
struct StatRow: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
            Spacer()
            Text(value)
                .font(.caption.bold())
                .foregroundColor(color)
        }
    }
}

struct TodoRowView: View {
    let todo: TodoItem
    let isCompact: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            // Priority indicator
            Circle()
                .fill(priorityColor)
                .frame(width: 6, height: 6)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(todo.title)
                    .font(.caption.bold())
                    .lineLimit(isCompact ? 1 : 2)
                    .foregroundColor(.white)
                
                if !isCompact {
                    HStack(spacing: 12) {
                        if todo.isOverdue {
                            Label("Overdue", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundColor(.red)
                        } else if todo.isDueToday {
                            Label("Due Today", systemImage: "calendar")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        } else if let timeUntilDue = todo.timeUntilDue {
                            Text(timeUntilDue)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        if let category = todo.category, !category.isEmpty {
                            Label(category, systemImage: "tag")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
            }
            
            Spacer()
            
            // Priority icon for high/critical items
            if todo.priority == .critical || todo.priority == .high {
                Image(systemName: todo.priority.iconName)
                    .font(.caption2)
                    .foregroundColor(priorityColor)
            }
        }
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

// MARK: - Widget Configuration
struct TestWidget: Widget {
    let kind: String = "TodoWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodoProvider()) { entry in
            TodoWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("TODO Manager")
        .description("Stay on top of your tasks with real-time progress and priority items")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Previews
#Preview("Small", as: .systemSmall) {
    TestWidget()
} timeline: {
    let sampleTodos = WidgetDataManager.shared.getSampleTodos()
    let sampleStats = WidgetDataManager.shared.getSampleStatistics()
    TodoEntry(date: Date(), todos: sampleTodos, statistics: sampleStats)
}

#Preview("Medium", as: .systemMedium) {
    TestWidget()
} timeline: {
    let sampleTodos = WidgetDataManager.shared.getSampleTodos()
    let sampleStats = WidgetDataManager.shared.getSampleStatistics()
    TodoEntry(date: Date(), todos: sampleTodos, statistics: sampleStats)
}
