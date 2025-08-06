import SwiftUI
import Foundation

class CrashHandler: ObservableObject {
    static let shared = CrashHandler()
    @Published var hasCrashed = false
    @Published var crashMessage = ""
    
    private init() {
        setupCrashHandler()
    }
    
    private func setupCrashHandler() {
        NSSetUncaughtExceptionHandler { exception in
            DispatchQueue.main.async {
                CrashHandler.shared.hasCrashed = true
                CrashHandler.shared.crashMessage = exception.reason ?? "idk че произошло\nПерезайди и скинь скрин из настроек (самый низ) (ну и че ты делал до краша)"
            }
        }
        
        signal(SIGABRT) { _ in
            DispatchQueue.main.async {
                CrashHandler.shared.hasCrashed = true
                CrashHandler.shared.crashMessage = "Похоже... приложение упало..? Ты попал на ТЕРРИТОРИИ SIGABRT\nПерезайди и скинь скрин из настроек (самый низ)"
            }
        }
    }
    
    func triggerTestCrash() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.hasCrashed = true
            self.crashMessage = "Похоже... приложение упало..? Ты попал на НЕИЗВЕДАННЫЕ ТЕРРИТОРИИ\nПерезайди и скинь скрин из настроек (самый низ)"
        }
    }
}

struct CrashScreen: View {
    @ObservedObject var crashHandler = CrashHandler.shared
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Произошла ошибка")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text(crashHandler.crashMessage)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 15) {
                Text("Рекомендуется:")
                    .font(.headline)
                
                Text("Закрыть приложение")
                Text("Открыть заново")
                Text("Если проблема повторяется - переустановить")
            }
            .font(.body)
            .foregroundColor(.secondary)
            
            Spacer()
            
            Button("окек") {
                exit(0)
            }
            .buttonStyle(.borderedProminent)
            .foregroundColor(.red)
        }
        .padding()
        .background(Color(.systemBackground))
    }
} 