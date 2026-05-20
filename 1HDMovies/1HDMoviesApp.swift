import SwiftUI
import SwiftData
import FirebaseCore
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }

    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}

@main
struct onehdApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([FavoriteMovie.self, WatchedMovie.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            SplashView()
                .onAppear {
                    let context = sharedModelContainer.mainContext
                    FavoriteRepository.shared.modelContext = context
                    WatchedRepository.shared.modelContext = context
                    FavoriteMigration.migrateIfNeeded(modelContext: context)
                }
                .task {
                    if AuthenticationService.shared.isSignedIn {
                        await FirebaseSyncService.shared.syncAll()
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
