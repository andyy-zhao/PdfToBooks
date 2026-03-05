import SwiftUI

@main
struct BookReaderApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Edit") {
                Button("Find...") {
                    appState.showFindBar = true
                }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(appState.document == nil)
            }
            CommandMenu("File") {
                Button("Open PDF...") {
                    appState.showOpenPanel = true
                }
                .keyboardShortcut("o", modifiers: .command)
                
                Button("Save") {
                    appState.saveDocument()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(appState.documentURL == nil)
                
                Divider()
                
                Button("Close") {
                    appState.closeDocument()
                }
                .keyboardShortcut("w", modifiers: .command)
                .disabled(appState.documentURL == nil)
            }
        }
        
        Settings {
            EmptyView()
        }
    }
}
