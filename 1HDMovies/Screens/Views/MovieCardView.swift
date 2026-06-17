import SwiftUI

struct MovieCardView: View {
    let movie: MoviesDataModel
    let width: CGFloat
    let height: CGFloat

    init(movie: MoviesDataModel, width: CGFloat = 140, height: CGFloat = 200) {
        self.movie = movie
        self.width = width
        self.height = height
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if movie.thumbnail.isEmpty {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: width, height: height)
                    .overlay {
                        Text(movie.name)
                            .font(.caption)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(8)
                    }
            } else {
                AsyncImage(url: URL(string: movie.thumbnail)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: width, height: height)
                            .clipped()
                            .cornerRadius(8)
                    case .failure:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: width, height: height)
                    default:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: width, height: height)
                            .overlay { ProgressView() }
                    }
                }
                .overlay(alignment: .topLeading) {
                    if !movie.quality.isEmpty {
                        Text(movie.quality)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .cornerRadius(4)
                            .padding(6)
                    }
                }
            }

            Text(movie.name)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(2)
                .frame(width: width, alignment: .leading)

            if !movie.other.isEmpty {
                Text(movie.other)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .frame(width: width, alignment: .leading)
            }
        }
        // Constrain the tappable area to the card's frame. Wide (backdrop) images
        // with .aspectRatio(.fill) overflow horizontally and, although clipped
        // visually, stay hit-testable — which made a card's edge open its neighbor.
        .frame(width: width)
        .contentShape(Rectangle())
    }
}
