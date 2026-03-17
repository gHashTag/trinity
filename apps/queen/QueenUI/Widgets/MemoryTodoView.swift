import SwiftUI

/// Editable plan (Windsurf/Cursor pattern)
/// Reads watcher.todos, click to toggle status, writes back to todos.json.
struct MemoryTodoView: View {
    @EnvironmentObject var watcher: StateWatcher

    private var pendingCount: Int { watcher.todos.filter { $0.status == "pending" }.count }
    private var doneCount: Int { watcher.todos.filter { $0.status == "done" }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\u{1F4CB} PLAN")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(TrinityTheme.golden)
                Spacer()
                if !watcher.todos.isEmpty {
                    Text("\(doneCount)/\(watcher.todos.count)")
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundStyle(TrinityTheme.accent)
                }
            }

            // Mini progress bar
            if !watcher.todos.isEmpty {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(TrinityTheme.bgCardBorder)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(TrinityTheme.accent)
                            .frame(width: geo.size.width * CGFloat(doneCount) / CGFloat(max(watcher.todos.count, 1)))
                    }
                }
                .frame(height: 3)
            }

            if watcher.todos.isEmpty {
                Text("No todos — Queen daemon writes .trinity/queen/todos.json")
                    .font(.caption)
                    .foregroundStyle(TrinityTheme.textMuted)
                    .padding(.vertical, 4)
            } else {
                ForEach(watcher.todos) { todo in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            watcher.toggleTodo(todo.id)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: todo.status == "done" ? "checkmark.circle.fill" : "circle")
                                .font(.body)
                                .foregroundStyle(todo.status == "done" ? TrinityTheme.statusOK : TrinityTheme.textMuted)
                            Text(todo.text)
                                .font(.caption)
                                .foregroundStyle(todo.status == "done" ? TrinityTheme.textMuted : TrinityTheme.textPrimary)
                                .strikethrough(todo.status == "done", color: TrinityTheme.textMuted)
                                .lineLimit(2)
                            Spacer()
                            Text(todo.source)
                                .font(.caption2)
                                .foregroundStyle(TrinityTheme.textMuted)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(TrinityTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cardCorner))
    }
}
