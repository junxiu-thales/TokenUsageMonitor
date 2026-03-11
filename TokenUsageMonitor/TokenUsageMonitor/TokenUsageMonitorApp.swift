//
//  TokenUsageMonitorApp.swift
//  TokenUsageMonitor
//
//  Created by Chan Jun Xiu on 10/3/26.
//

import SwiftUI

struct APIResponse: Decodable {
    let info: APIInfo
}

struct APIInfo: Decodable {
    let spend: Double
    let max_budget: Double
}

enum DisplayMode: String, CaseIterable, Identifiable {
    case spentTotal = "Spent / Total"
    case remainingTotal = "Remaining"
    case percentage = "Percentage"
    case emoji = "Emoji Status"
    
    var id: String { rawValue }
    
    func format(spend: Double, budget: Double) -> String {
        let remaining = max(budget - spend, 0)
        let ratio = budget > 0 ? (spend / budget) : 0
        
        switch self {
        case .spentTotal:
            return String(format: "$%.2f / $%.2f", spend, budget)
            
        case .remainingTotal:
            return String(format: "$%.2f Left", remaining)
            
        case .percentage:
            return String(format: "%.1f%% Used", ratio * 100)
            
        case .emoji:
            let indicator: String
            switch ratio {
            case 0..<0.5: indicator = "🟢"
            case 0.5..<0.8: indicator = "🟡"
            case 0.8...1.0: indicator = "🔴"
            default: indicator = "💀"
            }
            return String(format: "%@", indicator)
        }
    }
}

enum RefreshInterval: Int, CaseIterable, Identifiable {
    case oneSec = 1
    case fiveSec = 5
    case thirtySec = 30
    case oneMin = 60
    case none = 0
    
    var id: Int { rawValue }
    
    var label: String {
        switch self {
        case .oneSec: return "1 second"
        case .fiveSec: return "5 seconds"
        case .thirtySec: return "30 seconds"
        case .oneMin: return "1 minute"
        case .none: return "No auto refresh"
        }
    }
}

class TokenManager: ObservableObject {
    @Published var spend: Double = 0.0
    @Published var budget: Double = 0.0
    @Published var isLoaded: Bool = false
    @Published var isError: Bool = false
    @Published var isLoading: Bool = false
    @Published var lastUpdated: Date? = nil
    
    private var timer: Timer?
    private var currentInterval: Double = 0
    
    init() {
        let savedInterval = UserDefaults.standard.object(forKey: "refreshInterval") as? Int ?? 30
        currentInterval = Double(savedInterval)
        
        fetchUsage()
        startTimer(interval: currentInterval)
        
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            let newSaved = UserDefaults.standard.object(forKey: "refreshInterval") as? Int ?? 30
            let newInterval = Double(newSaved)
            
            if newInterval != self?.currentInterval {
                self?.currentInterval = newInterval
                self?.startTimer(interval: newInterval)
            }
        }
    }
    
    func startTimer(interval: Double) {
        timer?.invalidate()
        if interval > 0 {
            timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                self?.fetchUsage()
            }
        }
    }
    
    func fetchUsage() {
        guard !isLoading else { return }
        
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        let urlString = UserDefaults.standard.string(forKey: "apiUrl") ?? ""
        let token = UserDefaults.standard.string(forKey: "apiToken") ?? ""
        
        guard let url = URL(string: urlString), !token.isEmpty else {
            DispatchQueue.main.async {
                self.isError = true
                self.isLoading = false
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let data = data, let decoded = try? JSONDecoder().decode(APIResponse.self, from: data) {
                    self.spend = decoded.info.spend
                    self.budget = decoded.info.max_budget
                    self.isLoaded = true
                    self.isError = false
                    self.lastUpdated = Date()
                } else {
                    self.isError = true
                }
            }
        }.resume()
    }
}

struct SettingsView: View {
    @AppStorage("apiUrl") private var apiUrl: String = ""
    @AppStorage("apiToken") private var apiToken: String = ""
    @AppStorage("displayMode") private var displayMode: DisplayMode = .spentTotal
    @AppStorage("refreshInterval") private var refreshInterval: RefreshInterval = .thirtySec
    
    var body: some View {
        TabView {
            Form {
                TextField("API URL:", text: $apiUrl)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                SecureField("Bearer Token:", text: $apiToken)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Text("Changes are saved automatically.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 10)
            }
            .padding(30)
            .tabItem {
                Label("Credentials", systemImage: "key")
            }
            
            Form {
                Picker("Menu Bar Format:", selection: $displayMode) {
                    ForEach(DisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
            }
            .padding(30)
            .tabItem {
                Label("Display", systemImage: "macwindow")
            }
            
            Form {
                Picker("Update Frequency:", selection: $refreshInterval) {
                    ForEach(RefreshInterval.allCases) { interval in
                        Text(interval.label).tag(interval)
                    }
                }
                .pickerStyle(.radioGroup)
            }
            .padding(30)
            .tabItem {
                Label("Refresh", systemImage: "arrow.triangle.2.circlepath")
            }
        }
        .frame(width: 450, height: 150)
    }
}

// MARK: - 6. Main App
@main
struct TokenUsageApp: App {
    @StateObject private var manager = TokenManager()
    
    @AppStorage("displayMode") private var displayMode: DisplayMode = .spentTotal
    @AppStorage("refreshInterval") private var refreshInterval: RefreshInterval = .thirtySec
    
    init() {
        if UserDefaults.standard.string(forKey: "apiUrl")?.isEmpty ?? true ||
            UserDefaults.standard.string(forKey: "apiToken")?.isEmpty ?? true {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSMenu.didSendActionNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let menuItem = notification.userInfo?["MenuItem"] as? NSMenuItem {
                if menuItem.title == "Settings..." || menuItem.title == "Settings" {
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
    }
    
    var body: some Scene {
        MenuBarExtra {
            if let lastUpdated = manager.lastUpdated {
                Text("Last updated: \(lastUpdated.formatted(date: .omitted, time: .complete))")
                    .foregroundColor(.secondary)
            } else {
                Text("Last updated: Never")
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            Picker("Display Format", selection: $displayMode) {
                ForEach(DisplayMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.menu)
            
            Picker("Refresh Interval", selection: $refreshInterval) {
                ForEach(RefreshInterval.allCases) { interval in
                    Text(interval.label).tag(interval)
                }
            }
            .pickerStyle(.menu)
            
            Divider()
            
            Button(action: {
                manager.fetchUsage()
            }) {
                HStack {
                    Text(manager.isLoading ? "Refreshing..." : "Refresh Now")
                    
                    if manager.isLoading {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                }
            }
            .keyboardShortcut("r")
            .disabled(manager.isLoading)
            
            SettingsLink()
            
            Divider()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
            
        } label: {
            Group {
                if manager.isError {
                    Image(systemName: "network.slash")
                } else if manager.isLoading && !manager.isLoaded {
                    Image(systemName: "arrow.triangle.2.circlepath")
                } else if manager.isLoaded {
                    Text(displayMode.format(spend: manager.spend, budget: manager.budget)).monospacedDigit()
                } else {
                    Image(systemName: "ellipsis")
                }
            }
        }
        
        Settings {
            SettingsView()
                .onDisappear {
                    manager.fetchUsage()
                }
        }
    }
}
