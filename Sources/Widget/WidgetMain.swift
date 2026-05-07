import WidgetKit
import SwiftUI

struct ClaudeTokenWidget: Widget {
    let kind: String = "ClaudeTokenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ClaudeUsageProvider()) { entry in
            ClaudeTokenWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Claude Tokens")
        .description("Aktuelle Session, Heute / Woche / Monat — direkt aus den lokalen Claude-Code-Logs.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

struct ClaudeTokenWidgetEntryView: View {
    var entry: ClaudeUsageEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:  SmallView(entry: entry)
        case .systemMedium: MediumView(entry: entry)
        case .systemLarge:  LargeView(entry: entry)
        default:            SmallView(entry: entry)
        }
    }
}

@main
struct ClaudeTokenWidgetBundle: WidgetBundle {
    var body: some Widget {
        ClaudeTokenWidget()
    }
}
