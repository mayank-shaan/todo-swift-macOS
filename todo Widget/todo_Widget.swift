//
//  todo_Widget.swift
//  todo Widget
//
//  Enhanced TODO Widget with simplified data access using shared data manager
//

import WidgetKit
import SwiftUI
import Foundation

// MARK: - Widget Data Manager (Widget-specific)
class WidgetDataManager {
    static let shared = WidgetDataManager()
    private let dataManager = TodoDataManager.shared
    
    private init() {}
    
    func fetchIncompleteTodos(limit: Int = 10) -> [TodoItem] {
        // Access the shared data manager
        return dataManager.fetchIncompleteTodos(limit: limit)
    }
    
    func getStatistics() -> TodoStatistics {
        return dataManager.getStatistics()
    }
    
    // For widget previews and fallback data
    func getSampleTodos() -> [TodoItem] {
        return [
            TodoItem(
                title: "Complete project proposal",
                subtitle: "Add final sections and review with team",
                priority: .high,
                dueDate: Calendar.current.date(byAdding: .hour, value: 2, to: Date()),
                category: "Work"
            ),
            TodoItem(
                title: "Buy groceries",
                subtitle: "Milk, bread, eggs, vegetables",
                priority: .medium,
                category: "Personal"
            ),
            TodoItem(
                title: "Submit expense report",
                subtitle: "Include receipts from last month",
                priority: .critical,
                dueDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
                category: "Finance"
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
struct TodoTimelineProvider: TimelineProvider {
    typealias Entry = TodoEntry
    
    func placeholder(in context: Context) -> TodoEntry {
        TodoEntry(
            date: Date(),
            todos: WidgetDataManager.shared.getSampleTodos(),
            statistics: WidgetDataManager.shared.getSampleStatistics()
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (TodoEntry) -> Void) {
        let widgetDataManager = WidgetDataManager.shared
        let todos = widgetDataManager.fetchIncompleteTodos(limit: 10)
        let statistics = widgetDataManager.getStatistics()
        
        let entry = TodoEntry(
            date: Date(),
            todos: todos.isEmpty ? widgetDataManager.getSampleTodos() : todos,
            statistics: statistics
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodoEntry>) -> Void) {
        let widgetDataManager = WidgetDataManager.shared
        let todos = widgetDataManager.fetchIncompleteTodos(limit: 10)
        let statistics = widgetDataManager.getStatistics()
        
        let currentDate = Date()
        let entry = TodoEntry(
            date: currentDate,
            todos: todos.isEmpty ? widgetDataManager.getSampleTodos() : todos,
            statistics: statistics
        )
        
        // Update every 15 minutes, or sooner if there are due items
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

// MARK: - Widget Entry View
struct TodoWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: TodoEntry
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallTodoWidget(entry: entry)
        case .systemMedium:
            MediumTodoWidget(entry: entry)
        case .systemLarge:
            LargeTodoWidget(entry: entry)
        default:
            SmallTodoWidget(entry: entry)
        }
    }
}

// MARK: - Small Widget (2x2)
struct SmallTodoWidget: View {
    let entry: TodoEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "checklist")
                    .foregroundColor(.blue)
                    .font(.headline)
                Text("TODO")
                    .font(.headline.bold())
                    .foregroundColor(.primary)
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
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(entry.statistics.completionPercentage)%")
                        .font(.title2.bold())
                        .foregroundColor(.green)
                    Text("Done")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Quick preview of top priority todo
            if let firstTodo = entry.todos.prefix(1).first {
                VStack(alignment: .leading, spacing: 2) {
                    Text(firstTodo.title)
                        .font(.caption.bold())
                        .lineLimit(2)
                        .foregroundColor(.primary)
                    
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
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                VStack(spacing: 4) {
                    Text("All caught up! 🎉")
                        .font(.caption.bold())
                        .foregroundColor(.green)
                    Text("No pending tasks")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Medium Widget (4x2)
struct MediumTodoWidget: View {
    let entry: TodoEntry
    
    var body: some View {
        HStack(spacing: 12) {
            // Left side - Statistics and overview
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "checklist")
                        .foregroundColor(.blue)
                        .font(.headline)
                    Text("TODO")
                        .font(.headline.bold())
                        .foregroundColor(.primary)
                    
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
                        .foregroundColor(.secondary)
                    
                    ProgressView(value: entry.statistics.completionRate)
                        .progressViewStyle(LinearProgressViewStyle(tint: entry.statistics.isHealthy ? .green : .orange))
                        .scaleEffect(y: 0.5)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            // Right side - Todo list
            VStack(alignment: .leading, spacing: 6) {
                Text("Up Next")
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                
                if entry.todos.isEmpty {
                    Spacer()
                    VStack(spacing: 4) {
                        Text("All caught up! 🎉")
                            .font(.caption.bold())
                            .foregroundColor(.green)
                        Text("No pending tasks")
                            .font(.caption2)
                            .foregroundColor(.secondary)
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
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Large Widget (4x4)
struct LargeTodoWidget: View {
    let entry: TodoEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with statistics
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "checklist")
                            .foregroundColor(.blue)
                            .font(.title2)
                        Text("TODO Manager")
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                        
                        if entry.statistics.overdueTodos > 0 {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .font(.subheadline)
                        }
                    }
                    
                    Text("Updated: \(entry.date, style: .time)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Circular progress with health indicator
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                        .frame(width: 50, height: 50)
                    
                    Circle()
                        .trim(from: 0, to: entry.statistics.completionRate)
                        .stroke(entry.statistics.isHealthy ? Color.green : Color.orange, 
                                style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 1.0), value: entry.statistics.completionRate)
                    
                    Text("\(entry.statistics.completionPercentage)%")
                        .font(.caption.bold())
                        .foregroundColor(.primary)
                }
            }
            
            // Statistics row
            HStack(spacing: 16) {
                StatCard(title: "Total", value: "\(entry.statistics.totalTodos)", color: .blue)
                StatCard(title: "Pending", value: "\(entry.statistics.pendingTodos)", color: .orange)
                StatCard(title: "Done", value: "\(entry.statistics.completedTodos)", color: .green)
                if entry.statistics.overdueTodos > 0 {
                    StatCard(title: "Overdue", value: "\(entry.statistics.overdueTodos)", color: .red)
                }
                if entry.statistics.dueTodayTodos > 0 {
                    StatCard(title: "Due Today", value: "\(entry.statistics.dueTodayTodos)", color: .purple)
                }
            }
            
            Divider()
            
            // Todo list
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Tasks")
                    .font(.headline.bold())
                    .foregroundColor(.primary)
                
                if entry.todos.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.green)
                        Text("All caught up!")
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                        Text("You have no pending tasks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    ForEach(Array(entry.todos.prefix(6).enumerated()), id: \.element.id) { index, todo in
                        TodoRowView(todo: todo, isCompact: false)
                        if index < min(5, entry.todos.count - 1) {
                            Divider()
                                .opacity(0.5)
                        }
                    }
                    
                    if entry.todos.count > 6 {
                        HStack {
                            Spacer()
                            Text("+ \(entry.todos.count - 6) more tasks")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.top, 4)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
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
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption.bold())
                .foregroundColor(color)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.bold())
                .foregroundColor(color)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
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
                    .font(isCompact ? .caption : .caption.bold())
                    .lineLimit(isCompact ? 1 : 2)
                    .foregroundColor(.primary)
                
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
                                .foregroundColor(.secondary)
                        }
                        
                        if let category = todo.category, !category.isEmpty {
                            Label(category, systemImage: "tag")
                                .font(.caption2)
                                .foregroundColor(.secondary)
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
struct TodoWidget: Widget {
    let kind: String = "TodoWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodoTimelineProvider()) { entry in
            TodoWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("TODO Manager")
        .description("Stay on top of your tasks with a quick overview of your todos, progress, and priorities.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Previews
#Preview("Small", as: .systemSmall) {
    TodoWidget()
} timeline: {
    let sampleTodos = WidgetDataManager.shared.getSampleTodos()
    let sampleStats = WidgetDataManager.shared.getSampleStatistics()
    TodoEntry(date: Date(), todos: sampleTodos, statistics: sampleStats)
}

#Preview("Medium", as: .systemMedium) {
    TodoWidget()
} timeline: {
    let sampleTodos = WidgetDataManager.shared.getSampleTodos()
    let sampleStats = WidgetDataManager.shared.getSampleStatistics()
    TodoEntry(date: Date(), todos: sampleTodos, statistics: sampleStats)
}

#Preview("Large", as: .systemLarge) {
    TodoWidget()
} timeline: {
    let sampleTodos = WidgetDataManager.shared.getSampleTodos()
    let sampleStats = WidgetDataManager.shared.getSampleStatistics()
    TodoEntry(date: Date(), todos: sampleTodos, statistics: sampleStats)
}
