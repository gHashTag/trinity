import SwiftUI

/// Full-screen Todo Panel with right sidebar for details
struct TodoPanelView: View {
    @EnvironmentObject var watcher: StateWatcher
    @State private var selectedTodoId: String?
    @State private var showRightSidebar = true
    
    private var selectedTodo: QueenTodo? {
        guard let id = selectedTodoId else { return nil }
        return watcher.todos.first(where: { $0.id == id })
    }
    
    private var pendingCount: Int { watcher.todos.filter { $0.status == "pending" }.count }
    private var doneCount: Int { watcher.todos.filter { $0.status == "done" }.count }
    private var totalCount: Int { watcher.todos.count }
    
    var body: some View {
        HStack(spacing: 0) {
            // Main todo list
            VStack(spacing: 0) {
                // Header
                headerView
                
                Divider().background(V4Color.border)
                
                // Todo list
                todoListView
                
                Divider().background(V4Color.border)
                
                // Footer with stats
                footerView
            }
            .frame(maxWidth: .infinity)
            
            // Right sidebar for details
            if showRightSidebar, let todo = selectedTodo {
                Divider().background(V4Color.border)
                todoDetailView(todo: todo)
                    .frame(width: 280)
                    .transition(.move(edge: .trailing))
            }
        }
        .background(V4Color.background)
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\u{1F4CB} TO-DO LIST")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(V4Color.golden)
                Text("\(pendingCount) pending, \(doneCount) done")
                    .font(.caption2)
                    .foregroundStyle(V4Color.textSecondary)
            }
            
            Spacer()
            
            // Progress ring
            progressRing
            
            // Toggle sidebar button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showRightSidebar.toggle()
                }
            } label: {
                Image(systemName: showRightSidebar ? "sidebar.right" : "sidebar.right.closed")
                    .font(.caption)
                    .foregroundStyle(V4Color.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(V4Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("Toggle details sidebar")
        }
        .padding(ParietalSpacing.md)
        .background(V4Color.surface)
    }
    
    private var progressRing: some View {
        let progress = totalCount > 0 ? Double(doneCount) / Double(totalCount) : 0.0
        
        return ZStack {
            Circle()
                .stroke(V4Color.border.opacity(0.5), lineWidth: 3)
                .frame(width: 32, height: 32)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(V4Color.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 32, height: 32)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)
            
            Text("\(Int(progress * 100))%")
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundStyle(V4Color.accent)
        }
    }
    
    // MARK: - Todo List
    
    private var todoListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                if watcher.todos.isEmpty {
                    emptyStateView
                } else {
                    ForEach(watcher.todos) { todo in
                        todoRow(todo: todo)
                    }
                }
            }
            .padding(ParietalSpacing.md)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: ParietalSpacing.sm) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 32))
                .foregroundStyle(V4Color.textSecondary.opacity(0.5))
            Text("No todos yet")
                .font(.caption)
                .foregroundStyle(V4Color.textSecondary)
            Text("Queen daemon writes .trinity/queen/todos.json")
                .font(.caption2)
                .foregroundStyle(V4Color.textSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ParietalSpacing.xl)
    }
    
    private func todoRow(todo: QueenTodo) -> some View {
        let isSelected = selectedTodoId == todo.id
        
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTodoId = todo.id
            }
        } label: {
            HStack(spacing: ParietalSpacing.sm) {
                // Checkbox
                Image(systemName: todo.status == "done" ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(todo.status == "done" ? V4Color.success : V4Color.textSecondary)
                    .frame(width: 18)
                
                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(todo.text)
                        .font(.caption)
                        .foregroundStyle(todo.status == "done" ? V4Color.textSecondary : V4Color.textPrimary)
                        .strikethrough(todo.status == "done", color: V4Color.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: ParietalSpacing.xxs) {
                        Text(todo.source)
                            .font(.caption2)
                            .foregroundStyle(V4Color.textSecondary)
                        
                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(V4Color.textSecondary.opacity(0.5))
                        
                        Text(todo.status)
                            .font(.caption2)
                            .foregroundStyle(todo.status == "done" ? V4Color.success : V4Color.accent)
                    }
                }
                
                Spacer()
                
                // Selected indicator
                if isSelected {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(V4Color.golden)
                }
            }
            .padding(.horizontal, ParietalSpacing.sm)
            .padding(.vertical, ParietalSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? V4Color.golden.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? V4Color.golden.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Footer
    
    private var footerView: some View {
        HStack {
            // Quick stats
            HStack(spacing: ParietalSpacing.sm) {
                statBadge(label: "Total", value: "\(totalCount)", color: V4Color.textPrimary)
                statBadge(label: "Pending", value: "\(pendingCount)", color: V4Color.accent)
                statBadge(label: "Done", value: "\(doneCount)", color: V4Color.success)
            }
            
            Spacer()
            
            // Refresh button
            Button {
                watcher.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
                    .foregroundStyle(V4Color.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(V4Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("Refresh todos")
        }
        .padding(ParietalSpacing.md)
        .background(V4Color.surface)
    }
    
    private func statBadge(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(V4Color.textSecondary)
            Text(value)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
        }
    }
    
    // MARK: - Right Sidebar (Details)
    
    private func todoDetailView(todo: QueenTodo) -> some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.md) {
            // Header
            HStack {
                Text("DETAILS")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(V4Color.golden)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTodoId = nil
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(V4Color.textSecondary)
                }
                .buttonStyle(.plain)
            }
            
            Divider().background(V4Color.border)
            
            // Status
            statusSection(todo: todo)
            
            Divider().background(V4Color.border)
            
            // Source info
            sourceSection(todo: todo)
            
            Divider().background(V4Color.border)
            
            // Actions
            actionsSection(todo: todo)
            
            Spacer()
        }
        .padding(ParietalSpacing.md)
        .background(V4Color.surface)
    }
    
    private func statusSection(todo: QueenTodo) -> some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
            Text("STATUS")
                .font(.caption2.weight(.bold))
                .foregroundStyle(V4Color.textSecondary)
            
            HStack(spacing: ParietalSpacing.sm) {
                Image(systemName: todo.status == "done" ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(todo.status == "done" ? V4Color.success : V4Color.accent)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(todo.status.capitalized)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(todo.status == "done" ? V4Color.success : V4Color.accent)
                    Text(todo.status == "done" ? "Completed" : "In progress")
                        .font(.caption2)
                        .foregroundStyle(V4Color.textSecondary)
                }
                
                Spacer()
            }
            .padding(ParietalSpacing.sm)
            .background(V4Color.background)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
    
    private func sourceSection(todo: QueenTodo) -> some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
            Text("SOURCE")
                .font(.caption2.weight(.bold))
                .foregroundStyle(V4Color.textSecondary)
            
            HStack {
                Image(systemName: "folder.fill")
                    .font(.caption)
                    .foregroundStyle(V4Color.golden)
                Text(todo.source)
                    .font(.caption)
                    .foregroundStyle(V4Color.textPrimary)
                Spacer()
            }
            .padding(ParietalSpacing.sm)
            .background(V4Color.background)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
    
    private func actionsSection(todo: QueenTodo) -> some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
            Text("ACTIONS")
                .font(.caption2.weight(.bold))
                .foregroundStyle(V4Color.textSecondary)
            
            VStack(spacing: ParietalSpacing.xs) {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        watcher.toggleTodo(todo.id)
                    }
                } label: {
                    HStack {
                        Image(systemName: todo.status == "done" ? "arrow.uturn.backward" : "checkmark")
                            .font(.caption)
                        Text(todo.status == "done" ? "Mark as Pending" : "Mark as Done")
                            .font(.caption)
                        Spacer()
                    }
                    .padding(.horizontal, ParietalSpacing.sm)
                    .padding(.vertical, ParietalSpacing.xs)
                    .background(todo.status == "done" ? V4Color.accent.opacity(0.1) : V4Color.success.opacity(0.1))
                    .foregroundStyle(todo.status == "done" ? V4Color.accent : V4Color.success)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                
                Button {
                    // Future: delete todo
                } label: {
                    HStack {
                        Image(systemName: "trash")
                            .font(.caption)
                        Text("Delete")
                            .font(.caption)
                        Spacer()
                    }
                    .padding(.horizontal, ParietalSpacing.sm)
                    .padding(.vertical, ParietalSpacing.xs)
                    .background(V4Color.error.opacity(0.1))
                    .foregroundStyle(V4Color.error)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(true) // TODO: implement delete
            }
        }
    }
}
