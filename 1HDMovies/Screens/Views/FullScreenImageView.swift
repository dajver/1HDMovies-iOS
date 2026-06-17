import SwiftUI

struct FullScreenImageView: View {
    let imageUrl: String
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.opacity(backgroundOpacity).ignoresSafeArea()

            AsyncImage(url: URL(string: imageUrl)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(x: offset.width + dragOffset.width,
                                y: offset.height + dragOffset.height)
                        .gesture(magnification)
                        .simultaneousGesture(drag)
                        .onTapGesture(count: 2) { toggleZoom() }
                case .failure:
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                default:
                    ProgressView().tint(.white)
                }
            }

            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }

    private var magnification: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = min(max(lastScale * value.magnification, 1), 5)
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1 {
                    withAnimation { offset = .zero; lastOffset = .zero }
                }
            }
    }

    private var drag: some Gesture {
        DragGesture()
            .onChanged { value in
                if scale > 1 {
                    // Pan around the zoomed image
                    offset = CGSize(width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height)
                } else {
                    // Swipe-to-dismiss: image follows the finger
                    dragOffset = value.translation
                }
            }
            .onEnded { value in
                if scale > 1 {
                    lastOffset = offset
                } else if hypot(value.translation.width, value.translation.height) > 120 {
                    dismiss()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dragOffset = .zero
                    }
                }
            }
    }

    private var backgroundOpacity: Double {
        guard scale <= 1 else { return 1 }
        let distance = hypot(dragOffset.width, dragOffset.height)
        return max(0, 1 - distance / 300)
    }

    private func toggleZoom() {
        withAnimation {
            if scale > 1 {
                scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero
            } else {
                scale = 2.5; lastScale = 2.5
            }
        }
    }
}
