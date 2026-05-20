import SwiftUI

struct SplashView: View {
    @State private var isActive = false
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        if isActive {
            MainTabView(viewModel: viewModel)
        } else {
            ZStack {
                Color.black.ignoresSafeArea()
                Image("SplashLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 220)
            }
            .task {
                await viewModel.fetchAll()
                withAnimation { isActive = true }
            }
        }
    }
}

struct MainTabView: View {
    var viewModel: DashboardViewModel

    var body: some View {
        DashboardView(viewModel: viewModel)
            .preferredColorScheme(.dark)
    }
}
