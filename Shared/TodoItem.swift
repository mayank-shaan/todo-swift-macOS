//
//  TodoItem.swift
//  Todo MacOS Widget - Shared
//
//  Unified data model for TODO items - File-based approach for better widget compatibility
//

import Foundation

// MARK: - Priority Enum
public enum TodoPriority: Int16, CaseIterable, Codable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
    
    var iconName: String {
        switch self {
        case .low: return "chevron.down"
        case .medium: return "minus"
        case .high: return "chevron.up"
        case .critical: return "exclamationmark.triangle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "systemGreen"
        case .medium: return "systemBlue"
        case .high: return "systemOrange"
        case .critical: return "systemRed"
        }
    }
}

// MARK: - Todo Item Model
public struct TodoItem: Codable, Identifiable, Hashable {
    public let id: UUID
    var title: String
    var subtitle: String?
    var isCompleted: Bool
    var priority: TodoPriority
    var createdAt: Date
    var updatedAt: Date
    var dueDate: Date?
    var category: String?
    var sortOrder: Int32
    
    init(title: String, subtitle: String? = nil, priority: TodoPriority = .medium, dueDate: Date? = nil, category: String? = nil) {
        self.id = UUID()
        self.title = title
        self.subtitle = subtitle
        self.isCompleted = false
        self.priority = priority
        self.createdAt = Date()
        self.updatedAt = Date()
        self.dueDate = dueDate
        self.category = category
        self.sortOrder = 0
    }
    
    // MARK: - Computed Properties
    var isOverdue: Bool {
        guard let dueDate = dueDate else { return false }
        return !isCompleted && dueDate < Date()
    }
    
    var isDueToday: Bool {
        guard let dueDate = dueDate else { return false }
        return Calendar.current.isDateInToday(dueDate)
    }
    
    var isDueTomorrow: Bool {
        guard let dueDate = dueDate else { return false }
        return Calendar.current.isDateInTomorrow(dueDate)
    }
    
    var dueDateFormatted: String? {
        guard let dueDate = dueDate else { return nil }
        let formatter = DateFormatter()
        
        if Calendar.current.isDateInToday(dueDate) {
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return "Today \(formatter.string(from: dueDate))"
        } else if Calendar.current.isDateInTomorrow(dueDate) {
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return "Tomorrow \(formatter.string(from: dueDate))"
        } else {
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: dueDate)
        }
    }
    
    var timeUntilDue: String? {
        guard let dueDate = dueDate, !isCompleted else { return nil }
        
        let now = Date()
        let timeInterval = dueDate.timeIntervalSince(now)
        
        if timeInterval < 0 {
            let overdue = abs(timeInterval)
            if overdue < 3600 { // Less than 1 hour
                return "Overdue by \(Int(overdue / 60))min"
            } else if overdue < 86400 { // Less than 1 day
                return "Overdue by \(Int(overdue / 3600))h"
            } else {
                return "Overdue by \(Int(overdue / 86400))d"
            }
        } else {
            if timeInterval < 3600 { // Less than 1 hour
                return "Due in \(Int(timeInterval / 60))min"
            } else if timeInterval < 86400 { // Less than 1 day
                return "Due in \(Int(timeInterval / 3600))h"
            } else {
                return "Due in \(Int(timeInterval / 86400))d"
            }
        }
    }
    
    // MARK: - Hashable Conformance
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: TodoItem, rhs: TodoItem) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Statistics Model
public struct TodoStatistics: Codable {
    let totalTodos: Int
    let completedTodos: Int
    let pendingTodos: Int
    let overdueTodos: Int
    let dueTodayTodos: Int
    let completionRate: Double
    
    var completionPercentage: Int {
        return Int((completionRate * 100).rounded())
    }
    
    var isHealthy: Bool {
        return overdueTodos == 0 && completionRate > 0.7
    }
}
