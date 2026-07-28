import SwiftUI

/// Task tracker panel with right sidebar for task details
/// Used in ChatScreen to show extracted tasks from conversation
struct TaskTrackerPanelView: View {
    @Binding var tasks: [TaskItem]
    @State private var selectedTaskIndex: Int?
    @State private var showRightSidebar = true
    
    private var selectedTask: TaskItem? {
        guard let idx = selectedTaskIndex else { return nil }
        guard idx >= 0, idx < tasks.count else { return nil }
        return tasks[idx]
    }
    
    private var doneCount: Int { tasks.filter(\.isDone).count }
    private var pendingCount: Int { tasks.count - doneCount }
    private var progress: Double { tasks.isEmpty ? 0.0 : Double(doneCount) / Double(tasks.count) }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider().background(V4Color.border)
            
            HStack(spacing: 0) {
                // Main task list
                taskListView
                    .frame(maxWidth: .infinity)
                
                // Right sidebar for details
                if showRightSidebar, let task = selectedTask {
                    Divider().background(V4Color.border)
                    taskDetailView(task: task)
                        .frame(width: 240)
                        .transition(.move(edge: .trailing))
                }
            }
            
            Divider().background(V4Color.border)
            
            // Footer with progress
            footerView
        }
        .padding(ParietalSpacing.sm)
        .background(V4Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            HStack(spacing: ParietalSpacing.xs) {
                Image(systemName: "checklist")
                    .font(WernickeTypography.size11)
                    .foregroundStyle(V4Color.accent)
                Text("TASKS")
                    .font(WernickeTypography.caption2Bold)
                    .foregroundStyle(V4Color.accent)
            }
            
            Spacer()
            
            // Progress indicator
            if !tasks.isEmpty {
                HStack(spacing: ParietalSpacing.xxs) {
                    Text("\(doneCount)/\(tasks.count)")
                        .font(WernickeTypography.size10Mono)
                        .foregroundStyle(V4Color.textSecondary)
                    
                    // Mini progress ring
                    ZStack {
                        Circle()
                            .stroke(V4Color.border.opacity(0.5), lineWidth: 2)
                            .frame(width: 20, height: 20)
                        
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(V4Color.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .frame(width: 20, height: 20)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.3), value: progress)
                    }
                }
            }
            
            // Toggle sidebar
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showRightSidebar.toggle()
                }
            } label: {
                Image(systemName: showRightSidebar ? "sidebar.right" : "sidebar.right.closed")
                    .font(WernickeTypography.size9)
                    .foregroundStyle(V4Color.textSecondary)
                    .frame(width: 24, height: 24)
                    .background(V4Color.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help("Toggle details sidebar")
            
            // Clear all
            Button {
                withAnimation {
                    tasks.removeAll()
                    selectedTaskIndex = nil
                }
            } label: {
                Image(systemName: "trash")
                    .font(WernickeTypography.size9)
                    .foregroundStyle(V4Color.textSecondary)
                    .frame(width: 24, height: 24)
                    .background(V4Color.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help("Clear all tasks")
        }
        .padding(.horizontal, ParietalSpacing.sm)
        .padding(.vertical, ParietalSpacing.xs)
    }
    
    // MARK: - Task List
    
    private var taskListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(tasks.indices, id: \.self) { idx in
                    taskRow(idx: idx)
                }
            }
            .padding(.vertical, ParietalSpacing.xs)
        }
    }
    
    private func taskRow(idx: Int) -> some View {
        let task = tasks[idx]
        let isSelected = selectedTaskIndex == idx
        
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if selectedTaskIndex == idx {
                    selectedTaskIndex = nil
                } else {
                    selectedTaskIndex = idx
                }
            }
        } label: {
            HStack(spacing: ParietalSpacing.sm) {
                // Checkbox
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(WernickeTypography.size11)
                    .foregroundStyle(task.isDone ? V4Color.success : V4Color.textSecondary)
                    .frame(width: 16)
                
                // Title
                Text(task.title)
                    .font(WernickeTypography.size11)
                    .foregroundStyle(task.isDone ? V4Color.textSecondary : V4Color.textPrimary)
                    .strikethrough(task.isDone, color: V4Color.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                // Selected indicator
                if isSelected {
                    Image(systemName: "chevron.right")
                        .font(WernickeTypography.size8)
                        .foregroundStyle(V4Color.golden)
                }
            }
            .padding(.horizontal, ParietalSpacing.sm)
            .padding(.vertical, ParietalSpacing.xxs)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? V4Color.golden.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? V4Color.golden.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                withAnimation {
                    tasks[idx].isDone.toggle()
                }
            } label: {
                Label(task.isDone ? "Mark as Pending" : "Mark as Done", systemImage: task.isDone ? "arrow.uturn.backward" : "checkmark")
            }
            
            Divider()
            
            Button(role: .destructive) {
                withAnimation {
                    tasks.remove(at: idx)
                    if selectedTaskIndex == idx {
                        selectedTaskIndex = nil
                    }
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Footer
    
    private var footerView: some View {
        HStack {
            // Stats
            HStack(spacing: ParietalSpacing.sm) {
                statBadge(label: "Total", value: "\(tasks.count)", color: V4Color.textPrimary)
                statBadge(label: "Pending", value: "\(pendingCount)", color: V4Color.accent)
                statBadge(label: "Done", value: "\(doneCount)", color: V4Color.success)
            }
            
            Spacer()
            
            // Progress bar
            if !tasks.isEmpty {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(V4Color.border)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(progress >= 1.0 ? V4Color.success : V4Color.accent)
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(width: 100, height: 4)
            }
        }
        .padding(.horizontal, ParietalSpacing.sm)
        .padding(.vertical, ParietalSpacing.xs)
    }
    
    private func statBadge(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(WernickeTypography.tiny8)
                .foregroundStyle(V4Color.textSecondary)
            Text(value)
                .font(WernickeTypography.mini.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
        }
    }
    
    // MARK: - Right Sidebar (Details)
    
    private func taskDetailView(task: TaskItem) -> some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
            // Header
            HStack {
                Text("DETAILS")
                    .font(WernickeTypography.caption2Bold)
                    .foregroundStyle(V4Color.golden)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTaskIndex = nil
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(WernickeTypography.size9)
                        .foregroundStyle(V4Color.textSecondary)
                }
                .buttonStyle(.plain)
            }
            
            Divider().background(V4Color.border)
            
            // Status
            statusSection(task: task)
            
            Divider().background(V4Color.border)
            
            // Actions
            actionsSection(task: task)
            
            Spacer()
        }
        .padding(ParietalSpacing.sm)
        .background(V4Color.surfaceElevated)
    }
    
    private func statusSection(task: TaskItem) -> some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
            Text("STATUS")
                .font(WernickeTypography.tiny8.weight(.bold))
                .foregroundStyle(V4Color.textSecondary)
            
            HStack(spacing: ParietalSpacing.sm) {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(WernickeTypography.size14)
                    .foregroundStyle(task.isDone ? V4Color.success : V4Color.accent)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.isDone ? "Completed" : "In Progress")
                        .font(WernickeTypography.captionBold)
                        .foregroundStyle(task.isDone ? V4Color.success : V4Color.accent)
                    Text(task.isDone ? "Task finished" : "Task pending")
                        .font(WernickeTypography.size8)
                        .foregroundStyle(V4Color.textSecondary)
                }
                
                Spacer()
            }
            .padding(ParietalSpacing.xs)
            .background(V4Color.background)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
    
    private func actionsSection(task: TaskItem) -> some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
            Text("ACTIONS")
                .font(WernickeTypography.tiny8.weight(.bold))
                .foregroundStyle(V4Color.textSecondary)
            
            VStack(spacing: ParietalSpacing.xxs) {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        if let idx = selectedTaskIndex {
                            tasks[idx].isDone.toggle()
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: task.isDone ? "arrow.uturn.backward" : "checkmark")
                            .font(WernickeTypography.size9)
                        Text(task.isDone ? "Mark Pending" : "Mark Done")
                            .font(WernickeTypography.size9)
                        Spacer()
                    }
                    .padding(.horizontal, ParietalSpacing.xs)
                    .padding(.vertical, ParietalSpacing.xxs)
                    .background(task.isDone ? V4Color.accent.opacity(0.1) : V4Color.success.opacity(0.1))
                    .foregroundStyle(task.isDone ? V4Color.accent : V4Color.success)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                
                Button {
                    if let idx = selectedTaskIndex {
                        withAnimation {
                            tasks.remove(at: idx)
                            selectedTaskIndex = nil
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "trash")
                            .font(WernickeTypography.size9)
                        Text("Delete")
                            .font(WernickeTypography.size9)
                        Spacer()
                    }
                    .padding(.horizontal, ParietalSpacing.xs)
                    .padding(.vertical, ParietalSpacing.xxs)
                    .background(V4Color.error.opacity(0.1))
                    .foregroundStyle(V4Color.error)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
