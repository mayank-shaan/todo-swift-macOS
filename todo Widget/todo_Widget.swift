//
//  todo_Widget.swift
//  todo Widget
//  
//  Ultra-minimal widget for debugging
//

import WidgetKit
import SwiftUI

struct TestEntry: TimelineEntry {
    let date: Date
}

struct TestProvider: TimelineProvider {
    func placeholder(in context: Context) -> TestEntry {
        TestEntry(date: Date())
    }
    
    func getSnapshot(in context: Context, completion: @escaping (TestEntry) -> Void) {
        completion(TestEntry(date: Date()))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TestEntry>) -> Void) {
        let timeline = Timeline(entries: [TestEntry(date: Date())], policy: .atEnd)
        completion(timeline)
    }
}

struct TestWidgetView: View {
    var entry: TestEntry
    
    var body: some View {
        Text("Hello")
            .containerBackground(.blue, for: .widget)
    }
}

struct TodoWidget: Widget {
    let kind: String = "TodoWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TestProvider()) { entry in
            TestWidgetView(entry: entry)
        }
        .configurationDisplayName("Test Widget")
        .description("Basic test")
        .supportedFamilies([.systemSmall])
    }
}
