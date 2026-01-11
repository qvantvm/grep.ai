import SwiftUI

struct ContentView: View {
    @StateObject private var vm = LogFilterViewModel()

    var body: some View {
        VStack(spacing: 0) {
            promptBar
                .padding()
                .background(.ultraThinMaterial)

            Divider()

            modeBar
                .padding(.horizontal)
                .padding(.vertical, 8)

            Divider()

            logViewer
        }
        .frame(minWidth: 900, minHeight: 600)
        .toolbar {
            ToolbarItemGroup {
                Button("New") { vm.newFile() }
                Button("Open…") { vm.openFile() }
                Button("Save") { vm.save() }
                Button("Save As…") { vm.saveAs() }

                Divider()

                Button("Set API Key…") { vm.showApiKeySheet = true }
            }
        }
        .sheet(isPresented: $vm.showApiKeySheet) {
            ApiKeySheet(apiKey: vm.apiKey) { vm.apiKey = $0 }
        }
        .alert("Error", isPresented: $vm.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.lastError ?? "")
        }
    }

    private var promptBar: some View {
        HStack(spacing: 12) {
            TextField("Describe the filter in plain English",
                      text: $vm.prompt)
                .textFieldStyle(.roundedBorder)
                .onSubmit { vm.applyFilter() }

            Button("Apply") { vm.applyFilter() }

            if vm.isApplying {
                ProgressView().controlSize(.small)
            }

            if let regex = vm.regexPattern {
                Text("Regex: \(regex)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var modeBar: some View {
        HStack {
            Picker("Display", selection: $vm.displayMode) {
                Text("Filtered Only").tag(DisplayMode.filteredOnly)
                Text("Full File + Highlights").tag(DisplayMode.highlighted)
                Text("Excluded Only").tag(DisplayMode.excludedOnly)
            }
            .pickerStyle(.segmented)
            .onChange(of: vm.displayMode) { _, _ in
                vm.updateVisibleLines()
            }

            Spacer()

            Toggle("Watch file", isOn: $vm.isWatching)
                .onChange(of: vm.isWatching) { _, _ in
                    vm.updateWatcher()
                }
        }
    }

    private var logViewer: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(Array(vm.visibleLines.enumerated()), id: \.offset) { _, line in
                    Text(line.text)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(color(for: line))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
            .padding()
        }
    }

    private func color(for line: FilteredLine) -> Color {
        switch vm.displayMode {
        case .highlighted:
            return line.isMatch ? .red : .secondary
        default:
            return .primary
        }
    }
}

struct ApiKeySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var value: String
    let onSave: (String) -> Void

    init(apiKey: String, onSave: @escaping (String) -> Void) {
        _value = State(initialValue: apiKey)
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("OpenAI API Key").font(.headline)
            SecureField("sk-…", text: $value)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    onSave(value.trimmingCharacters(in: .whitespacesAndNewlines))
                    dismiss()
                }
            }
        }
        .padding()
        .frame(width: 500)
    }
}
