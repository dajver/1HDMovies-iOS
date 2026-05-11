import SwiftUI
import AVKit
import AVFoundation

struct VideoPlayerView: View {
    let url: String
    let referer: String
    let onClose: () -> Void

    @State private var presented = false

    var body: some View {
        Color.black.ignoresSafeArea()
            .onAppear {
                guard !presented else { return }
                presented = true
                presentPlayer()
            }
    }

    private func presentPlayer() {
        guard let videoURL = URL(string: url) else { return }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}

        let headers = [
            "Referer": referer,
            "Origin": referer.hasSuffix("/") ? String(referer.dropLast()) : referer,
            "User-Agent": Config.userAgent
        ]

        let asset = AVURLAsset(url: videoURL, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)

        let playerVC = AVPlayerViewController()
        playerVC.player = player
        playerVC.showsPlaybackControls = true
        playerVC.allowsPictureInPicturePlayback = true

        let coordinator = DismissCoordinator(onClose: onClose)
        playerVC.delegate = coordinator

        // Hold coordinator reference so it isn't deallocated
        objc_setAssociatedObject(playerVC, "coordinator", coordinator, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }

        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        topVC.present(playerVC, animated: true) {
            player.play()
        }
    }
}

class DismissCoordinator: NSObject, AVPlayerViewControllerDelegate {
    let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func playerViewController(_ playerViewController: AVPlayerViewController, willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(alongsideTransition: nil) { _ in
            self.onClose()
        }
    }

    func playerViewControllerDidDismiss(_ playerViewController: AVPlayerViewController) {
        playerViewController.player?.pause()
        onClose()
    }

}
