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
        let schema = Schema([FavoriteMovie.self, WatchedMovie.self, WatchedEpisode.self,
                             ShowEpisodeSnapshot.self, ShowNotification.self, PlaybackProgress.self])
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
                    WatchedEpisodeRepository.shared.modelContext = context
                    PlaybackProgressRepository.shared.modelContext = context
                    NewEpisodeService.shared.modelContext = context
                    FavoriteMigration.migrateIfNeeded(modelContext: context)
                    // Re-key stored records saved under a previous site domain so
                    // they match freshly-scraped links on the live one.
                    LinkMigration.run(modelContext: context)
                }
                .task {
                    if AuthenticationService.shared.isSignedIn {
                        // syncAll migrates old-host links (local + cloud) itself
                        // before reconciling.
                        await FirebaseSyncService.shared.syncAll()
                        // Anything the download passes still handed us under an
                        // old host (e.g. written by a device on an older build)
                        // gets re-keyed on the spot.
                        LinkMigration.run(modelContext: sharedModelContainer.mainContext)
                    }
                    await NewEpisodeService.shared.checkForNewEpisodes()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
