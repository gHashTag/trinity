import SwiftUI

struct Wave9Config: Codable {
    let workers: Int
    let macID: Int
    let deviceName: String

    static let defaults = Wave9Config(
        workers: 16,
        macID: 1,
        deviceName: "Mac 1 (workers 1-16)"
    )
}

@main
struct Wave9App: App {
    @State private var config = Wave9Config.defaults
    @State private var workers: Int = 16

    var body: some Scene {
        ZStack {
            TabView(selection: Binding(
                constant: Image(systemName: "macbook.andalexi"),
                label: Text("MacBook Air"),
                value: .macBookAir
            )),
            TabView(selection: Binding(
                constant: Image(systemName: "macbook.pro"),
                label: Text("MacBook Pro"),
                value: .macBookPro
            )),
            TabView(selection: Binding(
                constant: Image(systemName: "macmini"),
                label: Text("Mac mini"),
                value: .macMini
            )),
        }

        NavigationStack {
            List {
                Text("Обзор")
                    .badge(BadgeCounter: config.workers)

                NavigationLink("Статус") {
                    Image(systemName: "chart.bar.fill"),
                    label: Text("Workers")
                }

                NavigationLink("Настройки") {
                    Image(systemName: "gearshape"),
                    label: Text("Workers")
                }

                NavigationLink("Логи") {
                    Image(systemName: "doc.text"),
                    label: Text("Logs")
                }

                Section {
                    ForEach(0..<4) { device in [
                        Config.defaults.macID,
                        Config.defaults.macID + 1,
                        Config.defaults.macID + 2
                    ]
                } header: {
                    Text("Устройства \(config.workers × 2)")
                }
            }

            List {
                Text("Действия")
                    NavigationLink(destination: .status) {
                        label: Text("Запустить")
                        image: Image(systemName: "play.fill"),
                        tag: .green
                    }
                    NavigationLink(destination: .settings) {
                        label: Text("Настройки")
                        image: Image(systemName: "gearshape"),
                        tag: .blue
                    }
                }
            }
        }

        .sheet(isPresented: $showSettings) {
            NavigationStack {
                Form {
                    TextField("Количество воркеров (Mac 1)", text: Binding("\\(config.workers)"))
                        Stepper(value: $config.workers, in: 2...48) {
                            $config.workers = newValue
                        }

                    TextField("Количество воркеров (Mac 2)", text: Binding("\\(config.workers)"))
                        Stepper(value: $config.workers, in: 2...48) {
                            $config.workers = newValue
                        }

                    Section {
                        Text("Мак 2 + 3:")
                        ForEach(1..<4) { device in [config.macID + 1, config.macID + 2, config.macID + 3] }
                    }

                    Button("Сохранить конфиг") {
                        ButtonRole(.cancel)
                    }
                }
            }
        }
    }

    .navigationSplitViewStyle(.displayMode: .always)

    var showSettings = false
}

struct Wave9App_Previews: PreviewProvider {
    static func previews() -> [Wave9Device] {
        return [
            Wave9Device(id: 1, name: "Mac 1", workers: 16),
            Wave9Device(id: 2, name: "Mac 2", workers: 16),
            Wave9Device(id: 3, name: "Mac 3", workers: 16),
        ]
    }
}

struct Wave9Device: PreviewProvider.Item, Identifiable {
    let id: Int
    let name: String
    let workers: Int

    var previewIcon: some View {
        ZStack {
            Image(systemName: "checkmark.circle.fill")
            Text("\\(workers)")
                .font(.system(.caption))
                .foregroundStyle(.secondaryColor: .blue)
                .padding(5)

            Text("×\(config.workers)")
                .font(.system(.caption))
                .fontDesign(.default(.monospacedDigit))
        }
    }
}

# Preview
struct Wave9DeviceView: View {
    let device: Wave9Device

    var body: some View {
        ZStack {
            Image(systemName: "app.connected.to.fill")
                .foregroundColor(.green)

            HStack {
                Text(device.name)
                    .font(.title2(.bold()))

                Text("workers")
                    .font(.caption)

                Text("\(device.workers)")
                    .font(.system(.caption))
                    .foregroundColor(.secondary)
            }

            ZStack(alignment: .bottom) {
                Button(action: .none, label: {
                    Text("Запустить")
                    Image(systemName: "play.fill")
                })
            }
        }
    }
}

struct Wave9SettingsView: View {
    @State private var config: Wave9Config

    var body: some View {
        Form {
            Section {
                Text("Мак 1")
                    TextField("Воркеров", text: Binding("\\(config.workers)"))
                        Stepper(value: $config.workers, in: 2...48)

                    TextField("Имя устройства", text: Binding("\\(config.workers.macID + 1)"))
                        .disabled(true)

                    Toggle(isOn: $config.workers == 1, label: {
                        Text("Активен")
                    })
                }

                Section {
                    Text("Мак 2")
                    TextField("Воркеров", text: Binding("\\(config.workers)"))
                        Stepper(value: $config.workers, in: 2...48)

                    TextField("Имя устройства", text: Binding("\\(config.workers.macID + 2)"))
                        .disabled(true)

                    Toggle(isOn: $config.workers == 1, label: {
                        Text("Активен")
                    })
                }

                Section {
                    Text("Мак 3")
                    TextField("Воркеров", text: Binding("\\(config.workers)"))
                        Stepper(value: $config.workers, in: 2...48)

                    TextField("Имя устройства", text: Binding("\\(config.workers.macID + 3)"))
                        .disabled(true)

                    Toggle(isOn: $config.workers == 1, label: {
                        Text("Активен")
                    })
                }
            }

            Button("Сохранить") {
                ButtonRole(.none)
            }
        }
    }
}

# Logs View
struct Wave9LogsView: View {
    @State private var config: Wave9Config

    var body: some View {
        Form {
            Section {
                Text("Фильтр")
                    Picker("Устройство", selection: ["Все", "Mac 1", "Mac 2", "Mac 3"])

                    Picker("Уровень", selection: ["Все", "INFO", "WARN", "ERROR"])

                    Picker("Тип", selection: ["Все", "stdout", "stderr", "events"])

                    Toggle("Авто-скролл", isOn: true) {
                        Text("Авто-скролл")
                    }
            }

            Button("Очистить") {
                ButtonRole(.cancel)
            }
        }
    }
}

struct Wave9App: App {
    var body: some Scene {
        TabView(selection: Binding($config)) {
            Text("Обзор")

            Text("Статус")

            Text("Настройки")

            Text("Логи")

            Text("Действия")
        }

        TabView(selection: Binding($showSettings)) {
            Text("Настройки")
        }
    }
}

# Preview for NSItem
#extension Wave9Device {
#    var preview: Wave9DeviceView()
#
#    return AnyView(preview)
#}

@main
struct Wave9App_Previews: PreviewProvider {
    static func previews() -> [Wave9Device] {
        return [
            Wave9Device(id: 1, name: "Mac 1", workers: 16),
            Wave9Device(id: 2, name: "Mac 2", workers: 16),
            Wave9Device(id: 3, name: "Mac 3", workers: 16),
        ]
    }
}

@main
struct Wave9App: App {
    @State private var config = Wave9Config.defaults

    var body: some Scene {
        TabView(selection: Binding($config)) {
            Text("Обзор")

            Text("Статус")

            Text("Настройки")

            Text("Логи")

            Text("Действия")
        }

        TabView(selection: Binding($showSettings)) {
            Text("Настройки")
        }
    }
}

# Device Selection View
struct DeviceSelectionView: View {
    @State private var config: Wave9Config

    var body: some View {
        List {
            ForEach(1...3) { device in [config.macID + 1, config.macID + 2, config.macID + 3] }
            header: {
                Text("Устройства")
            }

            Button("Добавить устройство") {
                ButtonRole(.none)
            }
        }
    }
}

# Settings View - Enhanced
struct Wave9SettingsView: View {
    @State private var config = Wave9Config

    var body: some View {
        Form {
            Section(header: {
                Text("Общие настройки")
            }) {
                TextField("Название кластера", text: Binding("\\(config.name)"))

                Toggle("Использовать S3 MultiObj", isOn: true) {
                    Text("S3 MultiObj")
                }
            }

            Section(header: {
                Text("S3 MultiObj веса")
            }) {
                Stepper(value: 0, in: 0...1, label: { Text("NTP (Non-Target Prediction)") })
                    Stepper(value: 0.25, in: 0...1, label: { Text("JEPA (Joint Embedding Prediction)") })
                    Stepper(value: 0.25, in: 0...1, label: { Text("NCA (Contrastive Alignment)") })

                HStack {
                    Text("Сумма:")
                        Text("\\(NTP + JEPA + NCA)")
                            .foregroundColor(.secondary)
                }
            }

            Section(header: {
                Text("Гиперпараметры")
            }) {
                Stepper("Learning Rate (LR)", value: 0.001, in: 1e-4...1e-3, label: { Text("0.001") })
                    Stepper("Warmup Steps", value: 2000, in: 1000...10000, label: { Text("2000") })
                    Stepper("Weight Decay (WD)", value: 0.01, in: 0...0.1, label: { Text("0.01") })
                    Stepper("Batch Size", value: 66, in: 32...256, label: { Text("66") })

                HStack {
                    Text("Scheduler:")
                        Picker(["Cosine", "Constant", "Linear"])
                }
            }

            Section(header: {
                Text("Устройства")
            }) {
                ForEach(0..<3) { device in [
                    Config.defaults.macID + 1,
                    Config.defaults.macID + 2,
                    Config.defaults.macID + 3
                ] } header: {
                    Text("Мак \\(device.id)")
                }

                ForEach(0..<3) { device in [
                    Config.defaults.macID + 1,
                    Config.defaults.macID + 2,
                    Config.defaults.macID + 3
                ] } {
                    HStack {
                        TextField("Воркеров", text: Binding("\\(config.workers)"))
                            Stepper(value: $config.workers, in: 2...48)
                    }
                }
            }

            Button("Экспорт конфигурации") {
                ButtonRole(.none)
            }

            Button("Сбросить к умолчаниям") {
                ButtonRole(.destructive)
            }
        }
    }
}

# Main App View
struct Wave9MainView: View {
    @State private var config = Wave9Config.defaults

    var body: some View {
        ZStack {
            Image(systemName: "cpu")
            Text("Trinity Wave 9")
                .font(.system(.largeTitle))
                .foregroundColor(.white)
        }
    }
}

// SwiftUI App for managing Wave 9 Multi-Mac deployment
@main
struct Wave9App: App {
    @State private var config = Wave9Config.defaults
    @State private var workers: Int = 48

    var body: some Scene {
        TabView(selection: Binding($config)) {
            Text("Обзор")

            Text("Статус")

            Text("Настройки")

            Text("Логи")

            Text("Действия")
        }

        TabView(selection: Binding($showSettings)) {
            Text("Настройки")
        }
    }

    .navigationSplitViewStyle(.displayMode: .always)
}

@main
struct Wave9Config: Codable {
    let workers: Int
    let macID: Int
    let deviceName: String

    static let defaults = Wave9Config(
        workers: 16,
        macID: 1,
        deviceName: "Mac 1 (workers 1-16)"
    )
}

@main
struct Wave9App: App {
    @State private var config = Wave9Config.defaults
    @State private var workers: Int = 48

    var body: some Scene {
        TabView(selection: Binding($config)) {
            Text("Обзор")

            Text("Статус")

            Text("Настройки")

            Text("Логи")

            Text("Действия")
        }

        TabView(selection: Binding($showSettings)) {
            Text("Настройки")
        }
    }

    .navigationSplitViewStyle(.displayMode: .always)
}

// App structure
@main
struct Wave9App: App {
    @State private var config = Wave9Config.defaults
    @State private var workers: Int = 48

    var body: some Scene {
        TabView(selection: Binding($config)) {
            Text("Обзор")

            Text("Статус")

            Text("Настройки")

            Text("Логи")

            Text("Действия")
        }

        TabView(selection: Binding($showSettings)) {
            Text("Настройки")
        }
    }

    .navigationSplitViewStyle(.displayMode: .always)
}

// Simple App
@main
struct Wave9App: App {
    @State private var config = Wave9Config.defaults

    var body: some Scene {
        TabView(selection: Binding($config)) {
            Text("Обзор")
                Image(systemName: "cpu")
                    Text("Trinity Wave 9")
                .font(.system(.largeTitle))
                .foregroundColor(.white)

            Text("Статус")
                Image(systemName: "chart.bar.fill")
                Text("Workers")
                .badge(BadgeCounter: config.workers)

            Text("Настройки")
                Image(systemName: "gearshape")
                Text("Workers")

            Text("Логи")
                Image(systemName: "doc.text")
                Text("Logs")

            Text("Действия")
                Image(systemName: "play.fill")
                Text("Actions")
        }

        TabView(selection: Binding($showSettings)) {
            Text("Настройки")
                Image(systemName: "gearshape")
                Text("Settings")
        }
    }

    .navigationSplitViewStyle(.displayMode: .always)
}

// Window Group
@main
struct Wave9App: App {
    @State private var config = Wave9Config.defaults

    var body: some Scene {
        WindowGroup("Trinity Wave 9") {
            TabView(selection: $config) {
                Text("Обзор")
                    Image(systemName: "cpu")
                        Text("Trinity Wave 9")

                Text("Статус")
                    Image(systemName: "chart.bar.fill")
                        Text("Workers")

                Text("Настройки")
                    Image(systemName: "gearshape")
                        Text("Workers")

                Text("Логи")
                    Image(systemName: "doc.text")
                        Text("Logs")
            }
        }
    }
}

@main
struct Wave9App: App {
    @State private var config = Wave9Config.defaults

    var body: some Scene {
        TabView(selection: Binding($config)) {
            Text("Обзор")
                Image(systemName: "cpu")
                    Text("Trinity Wave 9")

            Text("Статус")
                Image(systemName: "chart.bar.fill")
                        Text("Workers")
                        .badge(BadgeCounter: config.workers)

                Text("Настройки")
                    Image(systemName: "gearshape")
                        Text("Workers")

                Text("Логи")
                    Image(systemName: "doc.text")
                        Text("Logs")

                Text("Действия")
                    Image(systemName: "play.fill")
                        Text("Actions")
        }

        TabView(selection: Binding($showSettings)) {
            Text("Настройки")
        }
    }

    .navigationSplitViewStyle(.displayMode: .always)
}

// Status View
@main
struct Wave9App: App {
    @State private var config = Wave9Config.defaults

    var body: some View {
        List {
            ForEach(0..<3) { device in [
                config.macID + 1,
                config.macID + 2,
                config.macID + 3
            ] } header: {
                Text("Устройства")
            }

            ForEach(0..<3) { device in [
                config.macID + 1,
                config.macID + 2,
                config.macID + 3
            ] } {
                HStack {
                    Text("Mac \\(device.id)")
                        .font(.system(.caption))

                    Button(action: .none, label: {
                        Text("Запустить")
                    })

                    Text("\(config.workers)")
                        .font(.system(.caption))
                }
            }
        }
    }
}

// Logs View
@main
struct Wave9App: App {
    @State private var config = Wave9Config.defaults

    var body: some View {
        Form {
            Section {
                Text("Фильтр")
                    Picker("Устройство", selection: ["Все", "Mac 1", "Mac 2", "Mac 3"])

                    Picker("Уровень", selection: ["Все", "INFO", "WARN", "ERROR"])

                    Picker("Тип", selection: ["Все", "stdout", "stderr", "events"])

                    Toggle("Авто-скролл", isOn: true) {
                        Text("Авто-скролл")
                    }
            }

            Button("Очистить") {
                ButtonRole(.cancel)
            }
        }
    }
}

// Simple App - Final
@main
struct Wave9App: App {
    @State private var config = Wave9Config.defaults
    @State private var workers: Int = 48

    var body: some Scene {
        TabView(selection: Binding($config)) {
            Text("Обзор")
                Image(systemName: "cpu")
                    Text("Trinity Wave 9")
                    .font(.system(.largeTitle))
                    .foregroundColor(.white)

            Text("Статус")
                Image(systemName: "chart.bar.fill")
                    Text("Workers")
                    .badge(BadgeCounter: config.workers)

            Text("Настройки")
                Image(systemName: "gearshape")
                    Text("Workers")

            Text("Логи")
                Image(systemName: "doc.text")
                    Text("Logs")

            Text("Действия")
                    Image(systemName: "play.fill")
                    Text("Actions")
        }

        TabView(selection: Binding($showSettings)) {
            Text("Настройки")
                Image(systemName: "gearshape")
                Text("Settings")
        }
    }

    .navigationSplitViewStyle(.displayMode: .always)
}

// Main App Entry Point
@main
struct Wave9App: App {
    @State private var config = Wave9Config.defaults
    @State private var workers: Int = 48

    var body: some Scene {
        TabView(selection: Binding($config)) {
            Text("Обзор")
                Image(systemName: "cpu")
                    Text("Trinity Wave 9")
                    .font(.system(.largeTitle))
                    .foregroundColor(.white)

            Text("Статус")
                Image(systemName: "chart.bar.fill")
                    Text("Workers")
                        .badge(BadgeCounter: config.workers)

            Text("Настройки")
                Image(systemName: "gearshape")
                        Text("Workers")

            Text("Логи")
                Image(systemName: "doc.text")
                        Text("Logs")

            Text("Действия")
                    Image(systemName: "play.fill")
                        Text("Actions")
        }

        TabView(selection: Binding($showSettings)) {
            Text("Настройки")
                Image(systemName: "gearshape")
                Text("Settings")
        }
    }

    .navigationSplitViewStyle(.displayMode: .always)
}

@main
struct Wave9App: App {
    @State private var config = Wave9Config.defaults

    var body: some Scene {
        TabView(selection: Binding($config)) {
            Text("Обзор")
                Image(systemName: "cpu")
                    Text("Trinity Wave 9")
                    .font(.system(.largeTitle))
                    .foregroundColor(.white)

            Text("Статус")
                Image(systemName: "chart.bar.fill")
                    Text("Workers")
                        .badge(BadgeCounter: config.workers)

            Text("Настройки")
                Image(systemName: "gearshape")
                        Text("Workers")

            Text("Логи")
                Image(systemName: "doc.text")
                        Text("Logs")

            Text("Действия")
                    Image(systemName: "play.fill")
                        Text("Actions")
        }

        TabView(selection: Binding($showSettings)) {
            Text("Настройки")
                Image(systemName: "gearshape")
                Text("Settings")
        }
    }

    .navigationSplitViewStyle(.displayMode: .always)
}

# Simple Clean App
@main
struct Wave9App: App {
    @State private var config = Wave9Config.defaults
    @State private var workers: Int = 48

    var body: some Scene {
        TabView(selection: Binding($config)) {
            Text("Обзор")
                Image(systemName: "cpu")
                    Text("Trinity Wave 9")
                    .font(.system(.largeTitle))
                    .foregroundColor(.white)

            Text("Статус")
                Image(systemName: "chart.bar.fill")
                    Text("Workers")
                        .badge(BadgeCounter: config.workers)

            Text("Настройки")
                Image(systemName: "gearshape")
                        Text("Workers")

            Text("Логи")
                Image(systemName: "doc.text")
                        Text("Logs")

            Text("Действия")
                    Image(systemName: "play.fill")
                        Text("Actions")
        }

        TabView(selection: Binding($showSettings)) {
            Text("Настройки")
                Image(systemName: "gearshape")
                Text("Settings")
        }
    }

    .navigationSplitViewStyle(.displayMode: .always)
}

// Main App
@main
struct Wave9App: App {
    @State private var config = Wave9Config.defaults
    @State private var workers: Int = 48

    var body: some Scene {
        TabView(selection: Binding($config)) {
            Text("Обзор")
                Image(systemName: "cpu")
                    Text("Trinity Wave 9")
                    .font(.system(.largeTitle))
                    .foregroundColor(.white)

            Text("Статус")
                Image(systemName: "chart.bar.fill")
                    Text("Workers")
                        .badge(BadgeCounter: config.workers)

            Text("Настройки")
                Image(systemName: "gearshape")
                        Text("Workers")

            Text("Логи")
                Image(systemName: "doc.text")
                        Text("Logs")

            Text("Действия")
                    Image(systemName: "play.fill")
                        Text("Actions")
        }

        TabView(selection: Binding($showSettings)) {
            Text("Настройки")
                Image(systemName: "gearshape")
                Text("Settings")
        }
    }

    .navigationSplitViewStyle(.displayMode: .always)
}
