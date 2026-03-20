import SwiftUI

/// Editable plan (Windsurf/Cursor pattern)
/// Reads watcher.todos, click to toggle status, writes back to todos.json.
struct MemoryTodoView: View {
    @EnvironmentObject var watcher: StateWatcher

    private var pendingCount: Int { watcher.todos.filter { $0.status == "pending" }.count }
    private var doneCount: Int { watcher.todos.filter { $0.status == "done" }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
            HStack {
                Text("\u{1F4CB} PLAN")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(V4Color.golden)
                Spacer()
                if !watcher.todos.isEmpty {
                    Text("\(doneCount)/\(watcher.todos.count)")
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundStyle(V4Color.accent)
                }
            }

            // Mini progress bar
            if !watcher.todos.isEmpty {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(V4Color.border)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(V4Color.accent)
                            .frame(width: geo.size.width * CGFloat(doneCount) / CGFloat(max(watcher.todos.count, 1)))
                    }
                }
                .frame(height: ParietalSpacing.xxxs)
            }

            if watcher.todos.isEmpty {
                Text("No todos — Queen daemon writes .trinity/queen/todos.json")
                    .font(.caption)
                    .foregroundStyle(V4Color.textSecondary)
                    .padding(.vertical, ParietalSpacing.xs)
            } else {
                ForEach(watcher.todos) { todo in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            watcher.toggleTodo(todo.id)
                        }
                    } label: {
                        HStack(spacing: ParietalSpacing.sm) {
                            Image(systemName: todo.status == "done" ? "checkmark.circle.fill" : "circle")
                                .font(.body)
                                .foregroundStyle(todo.status == "done" ? V4Color.success : V4Color.textSecondary)
                            Text(todo.text)
                                .font(.caption)
                                .foregroundStyle(todo.status == "done" ? V4Color.textSecondary : V4Color.textPrimary)
                                .strikethrough(todo.status == "done", color: V4Color.textSecondary)
                                .lineLimit(2)
                            Spacer()
                            Text(todo.source)
                                .font(.caption2)
                                .foregroundStyle(V4Color.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(ParietalSpacing.md)
        .background(V4Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
    }
}
