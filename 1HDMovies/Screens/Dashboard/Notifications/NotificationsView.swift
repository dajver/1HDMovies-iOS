import SwiftUI

struct NotificationsView: View {
    private var service = NewEpisodeService.shared

    var body: some View {
        ScrollView {
            if service.notifications.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No new episodes")
                        .foregroundColor(.gray)
                    Text("Pull down to check now")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.7))
                }
                .frame(maxWidth: .infinity, minHeight: 500)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(service.notifications) { notification in
                        NavigationLink(value: Route.movieDetails(url: notification.showLinkToDetails)) {
                            NotificationRow(notification: notification)
                        }
                        .buttonStyle(.plain)
                        Divider().background(Color.gray.opacity(0.3))
                    }
                }
            }
        }
        .refreshable {
            await service.checkForNewEpisodes(force: true)
        }
        .background(Color.black)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            service.refresh()
            service.markAllRead()
        }
    }
}

private struct NotificationRow: View {
    let notification: ShowNotification

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: notification.showThumbnail)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    Rectangle().fill(Color.gray.opacity(0.3))
                }
            }
            .frame(width: 50, height: 70)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(notification.showName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(countText)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                if !latestText.isEmpty {
                    Text(latestText)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
                Text(notification.detectedAt, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            Spacer()

            if !notification.isRead {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var countText: String {
        notification.newEpisodeCount == 1 ? "1 new episode" : "\(notification.newEpisodeCount) new episodes"
    }

    private var latestText: String {
        let parts = [notification.latestEpisodeNumber, notification.latestEpisodeName]
            .filter { !$0.isEmpty }
        return parts.isEmpty ? "" : "Latest: " + parts.joined(separator: " · ")
    }
}
