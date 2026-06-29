# 1HD Movies — iOS app

A SwiftUI app that browses and streams movies / TV shows by **scraping the website `1hd.art`** (no official API). Content is parsed from HTML with SwiftSoup; playback streams are sniffed out of the embed pages at runtime.

## Tech stack
- **SwiftUI + MVVM**, `@Observable` view models (Observation framework). Target **iOS 26.2**, model name `onehdApp` (`@main` in `1HDMoviesApp.swift`).
- **SwiftData** for local persistence (`@Model` classes in `Database/`).
- **Firebase** (Auth + Firestore) for cross-device sync; **Google Sign-In**.
- **SwiftSoup** for HTML scraping. **AVPlayer + WKWebView** for the custom player.
- Base site URL and scraping User-Agent live in `Config.swift` (`https://1hd.art`).

## Project layout (`1HDMovies/`)
- `1HDMoviesApp.swift` — app entry. Declares the SwiftData `Schema` (every `@Model` must be listed here) and, in `SplashView().onAppear`, injects the shared `ModelContext` into each repository/service singleton. Firebase sync + new-episode check run from its `.task`.
- `Config.swift` — `baseURL`, `userAgent`.
- `Network/` — `HttpClient` (async GET with the spoofed UA), `SwiftSoupExtensions`.
- `Models/` — plain data structs (`MovieModels.swift` has `MoviesDataModel`, `MoviesDetailsDataModel`, `MovieSeasonDataModel`, `MovieEpisodesDataModel`, `MostPopularMoviesDataModel`, `MovieType`).
- `Repositories/` — one per concern. Two kinds:
  - **Scraping repos** (`MovieDetailsRepository`, `MostPopularRepository`, `SearchRepository`, …) fetch HTML and parse it.
  - **Persistence repos** (`FavoriteRepository`, `WatchedRepository`, `WatchedEpisodeRepository`) wrap SwiftData. They're `@MainActor` singletons with a `var modelContext: ModelContext?` set at launch.
- `Services/` — `AuthenticationService` (Google/Firebase auth), `FirebaseSyncService` (Firestore up/download), `NewEpisodeService` (new-episode detection + notifications).
- `Database/` — SwiftData `@Model`s: `FavoriteMovie`, `WatchedMovie` (show-level watched), `WatchedEpisode` (per-episode), `ShowEpisodeSnapshot` + `ShowNotification` (new-episode tracking). `FavoriteMigration` migrates the old UserDefaults favorites once.
- `Screens/Dashboard/` — the bulk of the UI. `DashboardView` hosts the single `NavigationStack` and the `Route` enum (all navigation goes through `navigationDestination(for: Route.self)`).

## Build / run
```bash
xcodebuild -project 1HDMovies.xcodeproj -scheme 1HDMovies \
  -destination 'generic/platform=iOS' -configuration Debug build CODE_SIGNING_ALLOWED=NO
```
- `CODE_SIGNING_ALLOWED=NO` lets it build without signing — use this to verify compilation.
- The project uses an **Xcode 16 synchronized folder group** (`PBXFileSystemSynchronizedRootGroup`). New files added under `1HDMovies/` are **auto-included** — you do **not** edit `project.pbxproj` to add files. Conversely, a stray file in that folder gets bundled automatically (this once caused a "Multiple commands produce Info.plist" error).
- Editor/SourceKit often reports spurious single-file "Cannot find type X in scope" errors because it resolves files in isolation. **Trust the `xcodebuild` result**, not those.

## Key flows
- **Browsing**: `DashboardViewModel.fetchAll()` (run during splash) loads the carousel + rows via the scraping repos. `MovieDetailsView` loads a movie/show; for TV it fetches seasons → episodes via an AJAX endpoint.
- **Playback** (`Screens/Dashboard/MovieDetails/WatchMovie/`): `WatchMovieView` loads the embed page in a hidden `StreamDetectorWebView` (WKWebView with injected JS) that intercepts `.m3u8`/subtitle URLs, then hands the detected stream to `VideoPlayerView` (a `UIViewControllerRepresentable` wrapping a custom AVPlayer controller). Server switching and prev/next-episode are callbacks back into `WatchMovieView`.
- **Favorites / Watched / Continue Watching / Notifications**: see Features below. All favorited shows' season lists are stored on `FavoriteMovie` and kept fresh via `FavoriteRepository.refreshFavoriteIfNeeded`.
- **Firebase sync**: `FirebaseSyncService.syncAll()` (launch, when signed in) reconciles favorites, watched movies, watched episodes, **playback progress**, episode snapshots, and show notifications. Each model has upload/download (and some delete) helpers; single-item uploads fire from the persistence repos on mutation. All guard on `uid` so they no-op when signed out. Playback progress (and snapshots/notifications) reconcile **last-writer-wins by a date field** (`updatedAt`/`lastCheckedAt`/`detectedAt`).

## Implemented features (so future sessions know they exist)
- Per-**episode** watched tracking; an episode is marked watched only after **5 minutes of playback** (threshold in `VideoPlayerView`/`CustomPlayerViewController`, fired via `onWatchedReached`). **Long-press an episode** → context menu to mark watched/unwatched.
- **Favorites** screen excludes show-level-watched items; a separate **Watched** screen shows them (reachable via the eye icon in Favorites).
- **Continue Watching** row on the dashboard: favorited TV shows with unwatched episodes, proposing the episode **after the furthest one watched** (never an earlier season). Logic in `ContinueWatchingViewModel`.
- **New Releases** row: same content as the top slider but cards open *details* (`Route.movieDetails`), not playback.
- **Notifications** (bell icon + badge): one `ShowNotification` per favorited show with a count of new episodes since last read; detected by diffing current episodes against `ShowEpisodeSnapshot` on launch (6-hour throttle, pull-to-refresh bypasses it).
- **Player controls layout** (`CustomPlayerViewController` in `VideoPlayerView.swift`): the **−10s / +10s seek buttons are pinned to the far left/right screen edges** (not in the center cluster, which holds only prev / play-pause / next) with a large tap target. **Double-tap left 40% / right 40%** seeks −10/+10 YouTube-style (middle reserved for play-pause), with a brief "−10s"/"+10s" feedback pill; single-tap toggles controls (it `require(toFail:)`s the double-tap). All control glyphs **scale 1.6× on iPad** via the `scaled()` helper (`isPad`); iPhone unchanged. Seek logic shared via `seekBy(_:)`. Edge buttons live inside the auto-hiding controls overlay (no always-on floating buttons — a standing user preference).
- **Animation** dashboard row + a generic `GenresEnum` case (`/genre/animation`). Adding a genre = add the enum case (+`path`), a `…Movies` array + fetch task + switch arm in `DashboardViewModel`, and a `movieRow(seeAllRoute: .tag(GenresEnum.x.ref))` in `DashboardView`.
- **Clickable detail tags**: genres, **cast**, **country**, **production**, **year** on `MovieDetailsView` are tappable chips that open the matching listing. All are parsed in `MovieDetailsRepository` via `tags(in:label:)` (reads the `<a>`s inside each `div.item` by its `div.name` label — cast→`/actor/`, country→`/country/`, year→`/year/` (relative), production→`/production/`). Each is a `TagRef {name,url}` (generic, since genres are arbitrary: music, sci-fi-fantasy, …) and navigates via `Route.tag(TagRef)` → the shared `GenreMoviesView` (URL-driven via `GenresRepository.fetchMoviesByGenre(genreUrl:)`). Rendered in a small `FlowLayout` (wrapping `Layout`). Plain-text `genre`/`cast`/… strings are kept for favorites/Firebase; `MoviesDetailsDataModel.genres/casts/...` arrays are **omitted from `CodingKeys`** so persistence is unaffected.
- **Trailer button** (`MovieDetailsView`): the site has **no trailer data**, so it opens a YouTube *search* for "`<title> <year> trailer`" via `openURL` (YouTube universal link → app if installed, else Safari; no Info.plist scheme needed).
- **Favorite / Watched toggles live in the nav-bar toolbar** (top-trailing) of `MovieDetailsView`, driven by local `@State` (`isFavorite`/`isWatched`) so the icons re-render on tap. The old bottom action-button row was removed.
- **Resume playback**: `PlaybackProgress` `@Model` (keyed by the stable content link — episode link / movie watch URL, **not** the per-session `.m3u8`) + `PlaybackProgressRepository`. The player seeks to `resumeAt` once on first ready (`resumePlaybackIfNeeded`), saves throttled every 10s + on `viewWillDisappear`. **Per-episode**: each episode resumes from its own saved position; unwatched → starts at 0. Saving near the end clears the record (don't resume into credits). **Synced cross-device** via Firestore `playbackProgress` collection — last-writer-wins by `updatedAt`; the repo's cloud upload is **throttled to 15s** (local save stays 10s) so it doesn't write every tick, and `clear()` deletes the cloud doc. Cross-device download happens on **launch** (`syncAll`), so handoff is: stop on device A → open app on device B → resumes. Buffering shows a center **spinner** in place of the play button (`updateLoadingState`, driven by `timeControlStatus`/item status).

## Gotchas learned the hard way
- **Never read the host View's `@State` inside escaping closures captured by the UIKit player** (`CustomPlayerViewController`'s `onEpisodeChange`/`onWatchedReached`/`onProgress`). Those reads return stale/capture-time values and caused episode-nav to stall and progress to save under the wrong episode. Instead pass the needed values in as immutable `let`s (e.g. `contentLink`, `currentEpisodeIndex`) and **hand them back through the callback** (`onProgress(link, …)`, absolute target index for prev/next). @State *writes* from closures are fine.
- **Episode prev/next "opens the previous/same episode"** was a **stream-detector reuse** bug, not an index bug: the hidden `StreamDetectorWebView` had no stable identity, so SwiftUI reused the prior episode's `WKWebView` (whose `updateUIView` only loads when `url == nil`, and whose coordinator already had `hasDetectedStream`). Fix: `.id(streamKey)` on the detector (and the player), `streamKey` regenerated every `loadEpisode`.
- **Scraping selectors are fragile** — the site changes its markup. Past breakages: the details title moved `h3.heading-xl` → `h2.heading-xl` (now selected by class only, `.heading-xl`); the home carousel must be parsed **per `swiper-slide`** (the page's parallel name/thumb/link lists don't align — clones + cover-less slides). When something shows blank or "wrong movie", **fetch the live page with `curl` + the Config UA and re-check the selectors** before touching Swift.
- **Wide images overflow hit-testing**: `MovieCardView` uses `.aspectRatio(.fill)`; with wide (backdrop) thumbnails the clipped overflow stayed tappable and opened the neighbor card. Fixed with `.frame(width:) + .contentShape(Rectangle())`. Keep that when editing cards.
- **SwiftUI `.toolbar`/`.navigationTitle` from `@Observable`**: prefer a value the body reads directly; toolbar content doesn't always re-render on observable changes.
- **SwiftData schema changes** (adding/renaming a `@Model`) migrate the store and can drop a renamed entity's rows once — expect that during model changes; signed-in users are restored from Firestore.
- Favorites saved during a scraping-breakage can carry **empty name / stale episode links**; `refreshFavoriteIfNeeded` repairs name/thumbnail/episodes from fresh data (and the new-episode check bypasses the throttle for empty-name favorites).
