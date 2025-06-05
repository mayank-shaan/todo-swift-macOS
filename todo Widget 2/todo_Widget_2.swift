//
//  todo_Widget_2.swift  
//  todo Widget 2
//
//  Production TODO Widget - Clean interface with real data
//

import WidgetKit
import SwiftUI

// MARK: - Widget Data Manager
class WidgetDataManager {
    static let shared = WidgetDataManager()
    
    private init() {}
    
    func getTodos(limit: Int = 10) async -> [TodoItem] {
        // Ensure data manager is ready before accessing data
        await TodoDataManager.shared.waitForInitialization()
        
        // Access TodoDataManager methods from MainActor context
        return await MainActor.run {
            return TodoDataManager.shared.fetchIncompleteTodos(limit: limit)
        }
    }
    
    func getStatistics() async -> TodoStatistics {
        // Ensure data manager is ready before accessing data
        await TodoDataManager.shared.waitForInitialization()
        
        // Access TodoDataManager methods from MainActor context
        return await MainActor.run {
            return TodoDataManager.shared.getStatistics()
        }
    }
}

// MARK: - Timeline Provider
struct TodoProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodoEntry {
        return TodoEntry(
            date: Date(),
            todos: [],
            statistics: TodoStatistics(totalTodos: 0, completedTodos: 0, pendingTodos: 0, overdueTodos: 0, dueTodayTodos: 0, completionRate: 0)
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (TodoEntry) -> Void) {
        Task {
            do {
                let widgetData = WidgetDataManager.shared
                let todos = await widgetData.getTodos(limit: 10)
                let statistics = await widgetData.getStatistics()
                
                let entry = TodoEntry(
                    date: Date(),
                    todos: todos,
                    statistics: statistics
                )
                
                print("🔄 Widget snapshot: \(todos.count) todos loaded")
                completion(entry)
            } catch {
                print("❌ Widget snapshot error: \(error)")
                // Provide fallback entry
                let fallbackEntry = TodoEntry(
                    date: Date(),
                    todos: [],
                    statistics: TodoStatistics(totalTodos: 0, completedTodos: 0, pendingTodos: 0, overdueTodos: 0, dueTodayTodos: 0, completionRate: 0)
                )
                completion(fallbackEntry)
            }
        }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodoEntry>) -> Void) {
        Task {
            do {
                let widgetData = WidgetDataManager.shared
                let todos = await widgetData.getTodos(limit: 10)
                let statistics = await widgetData.getStatistics()
                
                let currentDate = Date()
                let entry = TodoEntry(
                    date: currentDate,
                    todos: todos,
                    statistics: statistics
                )
                
                // Smart update frequency based on urgency
                let hasUrgentItems = todos.contains { $0.isDueToday || $0.isOverdue }
                let updateInterval = hasUrgentItems ? 5 : 15 // minutes
                
                let nextUpdate = Calendar.current.date(byAdding: .minute, value: updateInterval, to: currentDate)!
                let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
                
                print("📊 Widget timeline: \(todos.count) todos, next update in \(updateInterval) minutes")
                completion(timeline)
            } catch {
                print("❌ Widget timeline error: \(error)")
                // Provide fallback timeline
                let fallbackEntry = TodoEntry(
                    date: Date(),
                    todos: [],
                    statistics: TodoStatistics(totalTodos: 0, completedTodos: 0, pendingTodos: 0, overdueTodos: 0, dueTodayTodos: 0, completionRate: 0)
                )
                let fallbackTimeline = Timeline(entries: [fallbackEntry], policy: .after(Calendar.current.date(byAdding: .minute, value: 15, to: Date())!))
                completion(fallbackTimeline)
            }
        }
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
        .containerBackground(.blue.gradient, for: .widget)
    }
}

// MARK: - Large Widget
struct LargeTodoWidget: View {
    let entry: TodoEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with statistics
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "checklist")
                            .foregroundColor(.white)
                            .font(.title2)
                        Text("TODO Manager")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        
                        if entry.statistics.overdueTodos > 0 {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .font(.subheadline)
                        }
                    }
                    
                    Text("Updated: \(entry.date, style: .time)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                // Circular progress with health indicator
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 4)
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
                        .foregroundColor(.white)
                }
            }
            
            // Statistics row
            HStack(spacing: 16) {
                StatCard(title: "Total", value: "\(entry.statistics.totalTodos)", color: .white)
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
                .background(.white.opacity(0.3))
            
            // Todo list
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Tasks")
                    .font(.headline.bold())
                    .foregroundColor(.white)
                
                if entry.todos.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.green)
                        Text("All caught up!")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        Text("You have no pending tasks")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    ForEach(Array(entry.todos.prefix(6).enumerated()), id: \.element.id) { index, todo in
                        TodoRowView(todo: todo, isCompact: false)
                        if index < min(5, entry.todos.count - 1) {
                            Divider()
                                .background(.white.opacity(0.2))
                        }
                    }
                    
                    if entry.todos.count > 6 {
                        HStack {
                            Spacer()
                            Text("+ \(entry.todos.count - 6) more tasks")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                        }
                        .padding(.top, 4)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
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
                .foregroundColor(.white.opacity(0.8))
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
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Previews
#Preview("Small", as: .systemSmall) {
    TestWidget()
} timeline: {
    TodoEntry(date: Date(), todos: [], statistics: TodoStatistics(totalTodos: 0, completedTodos: 0, pendingTodos: 0, overdueTodos: 0, dueTodayTodos: 0, completionRate: 0))
}

#Preview("Medium", as: .systemMedium) {
    TestWidget()
} timeline: {
    TodoEntry(date: Date(), todos: [], statistics: TodoStatistics(totalTodos: 0, completedTodos: 0, pendingTodos: 0, overdueTodos: 0, dueTodayTodos: 0, completionRate: 0))
}

#Preview("Large", as: .systemLarge) {
    TestWidget()
} timeline: {
    TodoEntry(date: Date(), todos: [], statistics: TodoStatistics(totalTodos: 0, completedTodos: 0, pendingTodos: 0, overdueTodos: 0, dueTodayTodos: 0, completionRate: 0))
}
