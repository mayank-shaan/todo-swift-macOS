//
//  EditTodoView.swift
//  Todo MacOS Widget
//
//  Form for editing existing TODO items - Updated for macOS compatibility
//

import SwiftUI

struct EditTodoView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dataManager = TodoDataManager.shared
    
    let originalTodo: TodoItem
    
    @State private var title = ""
    @State private var subtitle = ""
    @State private var priority: TodoPriority = .medium
    @State private var category = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var isCompleted = false
    
    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var hasChanges: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSubtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return trimmedTitle != originalTodo.title ||
               (trimmedSubtitle.isEmpty ? nil : trimmedSubtitle) != originalTodo.subtitle ||
               priority != originalTodo.priority ||
               (trimmedCategory.isEmpty ? nil : trimmedCategory) != originalTodo.category ||
               (hasDueDate ? dueDate : nil) != originalTodo.dueDate ||
               isCompleted != originalTodo.isCompleted
    }
    
    private var existingCategories: [String] {
        dataManager.getUniqueCategories()
    }
    
    init(todo: TodoItem) {
        self.originalTodo = todo
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Todo")
                    .font(.title2.bold())
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                    
                    Button("Save") {
                        saveTodo()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave || !hasChanges)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Form Content
            ScrollView {
                VStack(spacing: 20) {
                    // Task Details Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Task Details")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Title")
                                .font(.subheadline.bold())
                            TextField("Enter task title", text: $title)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description (optional)")
                                .font(.subheadline.bold())
                            TextField("Enter task description", text: $subtitle, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(3...6)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    
                    // Status Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Status")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Toggle("Completed", isOn: $isCompleted)
                            .toggleStyle(.checkbox)
                        
                        if isCompleted && !originalTodo.isCompleted {
                            Label("Task will be marked as completed", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else if !isCompleted && originalTodo.isCompleted {
                            Label("Task will be reopened", systemImage: "arrow.clockwise.circle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    
                    // Organization Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Organization")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Priority")
                                .font(.subheadline.bold())
                            Picker("Priority", selection: $priority) {
                                ForEach(TodoPriority.allCases, id: \.self) { priority in
                                    HStack {
                                        Image(systemName: priority.iconName)
                                            .foregroundColor(priorityColor(for: priority))
                                        Text(priority.displayName)
                                    }
                                    .tag(priority)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Category (optional)")
                                .font(.subheadline.bold())
                            HStack {
                                TextField("Enter category", text: $category)
                                    .textFieldStyle(.roundedBorder)
                                
                                if !existingCategories.isEmpty {
                                    Menu("Recent") {
                                        ForEach(existingCategories, id: \.self) { existingCategory in
                                            Button(existingCategory) {
                                                category = existingCategory
                                            }
                                        }
                                    }
                                    .menuStyle(.borderlessButton)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    
                    // Schedule Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Schedule")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Toggle("Set Due Date", isOn: $hasDueDate)
                            .toggleStyle(.checkbox)
                        
                        if hasDueDate {
                            VStack(alignment: .leading, spacing: 8) {
                                DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.field)
                                
                                // Quick date options
                                HStack {
                                    Button("Today 5 PM") {
                                        dueDate = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    
                                    Button("Tomorrow 9 AM") {
                                        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                                        dueDate = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? Date()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    
                                    Button("Next Week") {
                                        let nextWeek = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date()) ?? Date()
                                        dueDate = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: nextWeek) ?? Date()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                                
                                // Due date status
                                if let originalDueDate = originalTodo.dueDate {
                                    if originalTodo.isOverdue {
                                        Label("Currently overdue", systemImage: "exclamationmark.triangle.fill")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    } else if originalTodo.isDueToday {
                                        Label("Due today", systemImage: "calendar")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    
                    // Metadata Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Metadata")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Created:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(originalTodo.createdAt, style: .date)
                                    .font(.subheadline)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Last Updated:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(originalTodo.updatedAt, style: .date)
                                    .font(.subheadline)
                            }
                        }
                        
                        if hasChanges {
                            Label("Unsaved changes", systemImage: "pencil.circle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    
                    // Error Status Section (if there are errors)
                    if let error = dataManager.lastError {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Sync Status")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                VStack(alignment: .leading) {
                                    Text("Data sync issue detected")
                                        .foregroundColor(.red)
                                        .font(.subheadline.bold())
                                    Text(error)
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                                Spacer()
                                Button("Retry") {
                                    dataManager.refreshData()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
        }
        .frame(width: 450, height: 650)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            loadTodoData()
        }
    }
    
    private func loadTodoData() {
        title = originalTodo.title
        subtitle = originalTodo.subtitle ?? ""
        priority = originalTodo.priority
        category = originalTodo.category ?? ""
        hasDueDate = originalTodo.dueDate != nil
        dueDate = originalTodo.dueDate ?? Date()
        isCompleted = originalTodo.isCompleted
    }
    
    private func saveTodo() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSubtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        
        var updatedTodo = originalTodo
        updatedTodo.title = trimmedTitle
        updatedTodo.subtitle = trimmedSubtitle.isEmpty ? nil : trimmedSubtitle
        updatedTodo.priority = priority
        updatedTodo.category = trimmedCategory.isEmpty ? nil : trimmedCategory
        updatedTodo.dueDate = hasDueDate ? dueDate : nil
        updatedTodo.isCompleted = isCompleted
        
        Task { @MainActor in
            dataManager.updateTodo(updatedTodo)
            dismiss()
        }
    }
    
    private func priorityColor(for priority: TodoPriority) -> Color {
        switch priority {
        case .low: return .green
        case .medium: return .blue
        case .high: return .orange
        case .critical: return .red
        }
    }
}

#Preview {
    EditTodoView(todo: TodoItem(
        title: "Sample Todo",
        subtitle: "This is a sample todo for preview",
        priority: .high,
        dueDate: Date(),
        category: "Work"
    ))
}
