import SwiftUI

extension Image {
    /// `bundle:asset-name` URLs are an in-app convention for screenshot-mode
    /// mocks: instead of fetching a Firebase Storage HTTPS URL, render an
    /// image bundled in the app's asset catalog. Returns nil for normal URLs.
    static func bundled(from urlString: String?) -> Image? {
        guard let urlString, urlString.hasPrefix("bundle:") else { return nil }
        let name = String(urlString.dropFirst("bundle:".count))
        return Image(name)
    }
}

struct AsyncImageView: View {
    let url: String?
    var contentMode: ContentMode = .fill

    var body: some View {
        if let bundleImage = Image.bundled(from: url) {
            bundleImage
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } else if let urlString = url, let imageURL = URL(string: urlString) {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                case .failure:
                    placeholderView
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.geckoInputBackground)
                @unknown default:
                    placeholderView
                }
            }
        } else {
            placeholderView
        }
    }

    private var placeholderView: some View {
        Rectangle()
            .fill(Color.geckoInputBackground)
            .overlay(
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
                    .font(.title2)
            )
    }
}

struct AvatarView: View {
    let url: String?
    let size: CGFloat
    let name: String

    init(url: String?, size: CGFloat = 40, name: String = "") {
        self.url = url
        self.size = size
        self.name = name
    }

    var body: some View {
        Group {
            if let bundleImage = Image.bundled(from: url) {
                bundleImage.resizable().aspectRatio(contentMode: .fill)
            } else if let urlString = url, !urlString.isEmpty, let imageURL = URL(string: urlString) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        initialsView
                    }
                }
            } else {
                initialsView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var initialsView: some View {
        Circle()
            .fill(Color.geckoPrimary.opacity(0.15))
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.35, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.geckoPrimaryDark)
            )
    }

    private var initials: String {
        let components = name.split(separator: " ")
        let letters = components.prefix(2).compactMap { $0.first }.map { String($0) }
        return letters.joined().uppercased()
    }
}
