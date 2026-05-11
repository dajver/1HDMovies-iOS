import SwiftUI

struct SplashView: View {
    @State private var isActive = false

    var body: some View {
        if isActive {
            MainTabView()
        } else {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 16) {
                    Image(systemName: "film")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    Text("1HD Movies")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
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
