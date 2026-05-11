import SwiftUI

struct SplashView: View {
    @State private var isActive = false

    var body: some View {
        if isActive {
            MainTabView()
        } else {
            ZStack {
                Color.black.ignoresSafeArea()
                Image("SplashLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 220)
            }
            .task {
                try? await Task.sleep(for: .seconds(2))
                withAnimation { isActive = true }
            }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        DashboardView()
            .preferredColorScheme(.dark)
    }
}
