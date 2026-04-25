import AppKit
import SwiftUI
import UserNotifications

@main
struct MacSentinelApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var sampler = SystemSampler()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sampler)
                .frame(minWidth: 1160, minHeight: 740)
                .preferredColorScheme(.dark)
                .task { sampler.start() }
        }
        .windowStyle(.hiddenTitleBar)

        MenuBarExtra {
            MenuBarMonitorView()
                .environmentObject(sampler)
                .task { sampler.start() }
        } label: {
            Label("\(Int(sampler.cpu.usage))%", systemImage: sampler.health == .good ? "gauge.with.dots.needle.bottom.50percent" : "exclamationmark.triangle.fill")
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Refresh All") {
                    Task {
                        await sampler.refreshFast()
                        await sampler.refreshStorage()
                        await sampler.refreshContainers()
                        await sampler.refreshApps()
                    }
                }
                .keyboardShortcut("r", modifiers: [.command])
                Button("Request Notification Permission") {
                    NotificationService.requestAuthorization()
                }
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
        NSApp.applicationIconImage = SentinelIcon.make(size: 512)
        UNUserNotificationCenter.current().delegate = self
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
