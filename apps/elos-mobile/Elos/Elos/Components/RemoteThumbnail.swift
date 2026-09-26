import SwiftUI

/// Shared thumbnail for Discover creators/machines: loads a remote photo via native `AsyncImage`,
/// showing a themed placeholder icon while loading and a graceful fallback icon if the URL is
/// empty, malformed, or the load fails. Drop-in replacement for the `ZStack { shape.fill(...);
/// Image(systemName:...) }` pattern every call site used before photos were wired up — same size,
/// same tint, same shape, just backed by a real image when one is available.
struct RemoteThumbnail: View {
    enum Shape {
        case circle
        case rounded(CGFloat)
    }

    let urlString: String?
    var shape: Shape = .rounded(8)
    var size: CGFloat = 44
    var tint: Color = .tint
    var fallbackSystemImage: String = "photo"

    var body: some View {
        Group {
            if let url = URL(string: urlString ?? ""), urlString?.isEmpty == false {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .empty:
                        placeholder
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .background(tint.opacity(0.12))
        .clipShape(clipShape)
    }

    private var placeholder: some View {
        Image(systemName: fallbackSystemImage)
            .font(.system(size: size * 0.4))
            .foregroundStyle(tint)
    }

    private var clipShape: AnyShape {
        switch shape {
        case .circle:
            return AnyShape(Circle())
        case .rounded(let radius):
            return AnyShape(RoundedRectangle(cornerRadius: radius))
        }
    }
}
