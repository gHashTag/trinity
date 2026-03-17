// Modal & Alert Patterns
import SwiftUI

// MARK: - Alert Modal

struct AlertModal: View {
    let icon: String?
    let title: String
    let message: String
    let confirmTitle: String
    let cancelTitle: String?
    let isDestructive: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @State private var isVisible = false
    
    init(
        icon: String? = nil,
        title: String,
        message: String,
        confirmTitle: String = "Confirm",
        cancelTitle: String? = "Cancel",
        isDestructive: Bool = false,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.cancelTitle = cancelTitle
        self.isDestructive = isDestructive
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }
    
    var body: some View {
        ZStack {
            // Backdrop
            modalBackdrop
            
            // Content
            modalContent
        }
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                isVisible = true
            }
        }
    }
    
    private var modalBackdrop: some View {
        Color.black.opacity(0.4)
            .ignoresSafeArea()
            .opacity(isVisible ? 1 : 0)
            .onTapGesture {
                if !isDestructive {
                    dismiss()
                }
            }
    }
    
    private var modalContent: some View {
        VStack(spacing: 20) {
            // Icon
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 36))
                    .foregroundStyle(isDestructive ? TrinityTheme.statusError : TrinityTheme.accent)
            }
            
            // Title
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(TrinityTheme.textPrimary)
                .multilineTextAlignment(.center)
            
            // Message
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(TrinityTheme.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            // Buttons
            HStack(spacing: 12) {
                if let cancelTitle = cancelTitle {
                    Button(cancelTitle) {
                        dismiss()
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                }
                
                Button(confirmTitle) {
                    dismiss()
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
                .tint(isDestructive ? TrinityTheme.statusError : TrinityTheme.accent)
            }
        }
        .padding(24)
        .frame(width: 360)
        .background(TrinityTheme.bgCard)
        .cornerRadius(TrinityTheme.cornerLarge)
        .shadow(color: .black.opacity(0.2), radius: 20)
        .scaleEffect(isVisible ? 1 : 0.9)
        .opacity(isVisible ? 1 : 0)
    }
    
    private func dismiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onCancel()
        }
    }
}

// MARK: - Input Modal

struct InputModal: View {
    let title: String
    let placeholder: String
    let initialValue: String
    let isSecure: Bool
    let validation: (String) -> String?
    let onSubmit: (String) -> Void
    let onCancel: () -> Void
    
    @State private var text: String
    @State private var error: String?
    @State private var isVisible = false
    @FocusState private var isFocused: Bool
    
    init(
        title: String,
        placeholder: String = "",
        initialValue: String = "",
        isSecure: Bool = false,
        validation: @escaping (String) -> String? = { _ in nil },
        onSubmit: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.placeholder = placeholder
        self.initialValue = initialValue
        self.isSecure = isSecure
        self.validation = validation
        self.onSubmit = onSubmit
        self.onCancel = onCancel
        _text = State(initialValue: initialValue)
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
            
            VStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TrinityTheme.textPrimary)
                
                TextField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
                    .onSubmit {
                        submit()
                    }
                
                if let error = error {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text(error)
                            .font(.caption)
                    }
                    .foregroundStyle(TrinityTheme.statusError)
                }
                
                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Submit") {
                        submit()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid)
                }
            }
            .padding(20)
            .frame(width: 320)
            .background(TrinityTheme.bgCard)
            .cornerRadius(TrinityTheme.cornerLarge)
            .shadow(color: .black.opacity(0.2), radius: 20)
            .scaleEffect(isVisible ? 1 : 0.9)
            .opacity(isVisible ? 1 : 0)
        }
        .onAppear {
            isFocused = true
            withAnimation {
                isVisible = true
            }
        }
        .onKeyPress(.return) {
            submit()
            return .handled
        }
        .onKeyPress(.escape) {
            dismiss()
            onCancel()
            return .handled
        }
    }
    
    private var isValid: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func submit() {
        if let validationError = validation(text) {
            error = validationError
        } else {
            dismiss()
            onSubmit(text)
        }
    }
    
    private func dismiss() {
        withAnimation {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onCancel()
        }
    }
}

// MARK: - Selection Modal

struct SelectionModal<T: Hashable & CustomStringConvertible>: View {
    let title: String
    let options: [T]
    @Binding var selection: T?
    let allowsMultiple: Bool
    let onSubmit: () -> Void
    let onCancel: () -> Void
    
    @State private var isVisible = false
    @State private var searchText = ""
    
    var filteredOptions: [T] {
        if searchText.isEmpty {
            return options
        }
        return options.filter { "\($0)".localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
            
            VStack(spacing: 0) {
                // Header
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TrinityTheme.textPrimary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(TrinityTheme.bgCard)
                
                Divider()
                
                // Search
                if options.count > 10 {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(TrinityTheme.textMuted)
                        TextField("Search...", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                
                // Options
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(filteredOptions, id: \.self) { option in
                            optionRow(option)
                            if option != filteredOptions.last {
                                Divider()
                                    .background(TrinityTheme.bgCardBorder)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Footer
                HStack {
                    Button("Cancel") {
                        dismiss()
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Done") {
                        dismiss()
                        onSubmit()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .frame(width: 360, height: 480)
            .background(TrinityTheme.bgCard)
            .cornerRadius(TrinityTheme.cornerLarge)
            .shadow(color: .black.opacity(0.2), radius: 20)
            .scaleEffect(isVisible ? 1 : 0.9)
            .opacity(isVisible ? 1 : 0)
        }
        .onAppear {
            withAnimation {
                isVisible = true
            }
        }
        .onKeyPress(.escape) {
            dismiss()
            onCancel()
            return .handled
        }
    }
    
    private func optionRow(_ option: T) -> some View {
        let isSelected = allowsMultiple 
            ? false  // TODO: implement multi-select
            : selection == option
        
        return Button {
            selection = option
        } label: {
            HStack {
                Text("\(option)")
                    .foregroundStyle(isSelected ? TrinityTheme.accent : TrinityTheme.textPrimary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(TrinityTheme.accent)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func dismiss() {
        withAnimation {
            isVisible = false
        }
    }
}

// MARK: - Progress Modal

struct ProgressModal: View {
    let title: String
    let message: String?
    let progress: Double?
    let canCancel: Bool
    let onCancel: () -> Void
    
    @State private var isVisible = false
    @State private var rotation: Double = 0
    
    init(
        title: String,
        message: String? = nil,
        progress: Double? = nil,
        canCancel: Bool = true,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.progress = progress
        self.canCancel = canCancel
        self.onCancel = onCancel
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Spinner or progress
                ZStack {
                    if let progress = progress {
                        // Progress ring
                        Circle()
                            .stroke(TrinityTheme.bgCardBorder, lineWidth: 4)
                            .frame(width: 60, height: 60)
                        
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(TrinityTheme.accent, lineWidth: 4)
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(TrinityTheme.textPrimary)
                    } else {
                        // Spinning indicator
                        Circle()
                            .trim(from: 0.2, to: 1)
                            .stroke(TrinityTheme.accent, lineWidth: 4)
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(rotation))
                            .onAppear {
                                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                                    rotation = 360
                                }
                            }
                    }
                }
                
                // Title
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TrinityTheme.textPrimary)
                
                // Message
                if let message = message {
                    Text(message)
                        .font(.system(size: 14))
                        .foregroundStyle(TrinityTheme.textMuted)
                        .multilineTextAlignment(.center)
                }
                
                // Cancel button
                if canCancel {
                    Button("Cancel") {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(24)
            .frame(width: 320)
            .background(TrinityTheme.bgCard)
            .cornerRadius(TrinityTheme.cornerLarge)
            .shadow(color: .black.opacity(0.2), radius: 20)
            .scaleEffect(isVisible ? 1 : 0.9)
            .opacity(isVisible ? 1 : 0)
        }
        .onAppear {
            withAnimation {
                isVisible = true
            }
        }
    }
}

// MARK: - Modal Manager

@MainActor
class ModalManager: ObservableObject {
    @Published var activeModal: (any View)?
    private var modalStack: [(any View)] = []
    
    func present<T: View>(_ modal: T) {
        modalStack.append(modal)
        updateActiveModal()
    }
    
    func dismiss() {
        if !modalStack.isEmpty {
            modalStack.removeLast()
        }
        updateActiveModal()
    }
    
    func dismissAll() {
        modalStack.removeAll()
        updateActiveModal()
    }
    
    private func updateActiveModal() {
        activeModal = modalStack.last
    }
}

// MARK: - Preview

struct ModalPatternsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AlertModal(
                icon: "exclamationmark.triangle.fill",
                title: "Delete Thread?",
                message: "This action cannot be undone. All messages in this thread will be permanently deleted.",
                isDestructive: true,
                onConfirm: {},
                onCancel: {}
            )
            .frame(width: 500, height: 400)
            .previewDisplayName("Alert Modal")
            
            InputModal(
                title: "Rename Thread",
                placeholder: "Enter new name",
                initialValue: "My Thread",
                onSubmit: { _ in },
                onCancel: {}
            )
            .frame(width: 500, height: 400)
            .previewDisplayName("Input Modal")
            
            ProgressModal(
                title: "Uploading Files",
                message: "Please wait while we upload your files...",
                progress: 0.65,
                onCancel: {}
            )
            .frame(width: 500, height: 400)
            .previewDisplayName("Progress Modal")
        }
        .background(TrinityTheme.bgWindow)
    }
}
