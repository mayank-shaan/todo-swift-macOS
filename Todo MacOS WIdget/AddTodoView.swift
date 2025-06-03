//
//  AddTodoView.swift
//  Todo MacOS Widget
//
//  Form for creating new TODO items - Updated for macOS compatibility
//

import SwiftUI

struct AddTodoView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dataManager = TodoDataManager.shared
    
    @State private var title = ""
    @State private var subtitle = ""
    @State private var priority: TodoPriority = .medium
    @State private var category = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    
    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var existingCategories: [String] {
        dataManager.getUniqueCategories()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Todo")
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
                    .disabled(!canSave)
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
                            }
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    
                    // Status Section (if there are errors)
                    if let error = dataManager.lastError {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Status")
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
        .frame(width: 450, height: 550)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func saveTodo() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSubtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Task { @MainActor in
            _ = dataManager.createTodo(
                title: trimmedTitle,
                subtitle: trimmedSubtitle.isEmpty ? nil : trimmedSubtitle,
                priority: priority,
                dueDate: hasDueDate ? dueDate : nil,
                category: trimmedCategory.isEmpty ? nil : trimmedCategory
            )
            
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
    AddTodoView()
}
