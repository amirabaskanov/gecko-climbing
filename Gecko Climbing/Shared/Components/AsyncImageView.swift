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
    /// Tints the initials fallback with the climber's top-grade hold color so
    /// photo-less accounts still read as individuals instead of a wall of
    /// identical green circles. Negative means no grade yet: brand green.
    var gradeNumeric: Int = -1
    /// Optional presence ring drawn outside the avatar with a small gap, the
    /// way social apps mark "something new here". Pass `.clear` to reserve
    /// the ring's space without drawing it, so mixed rows stay aligned.
    var ring: Color? = nil

    init(url: String?, size: CGFloat = 40, name: String = "", gradeNumeric: Int = -1, ring: Color? = nil) {
        self.url = url
        self.size = size
        self.name = name
        self.gradeNumeric = gradeNumeric
        self.ring = ring
    }

    private var ringWidth: CGFloat { max(2, (size * 0.045).rounded()) }
    private var ringGap: CGFloat { max(2, (size * 0.04).rounded()) }

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
        .padding(ring == nil ? 0 : ringGap + ringWidth)
        .overlay {
            if let ring {
                Circle().strokeBorder(ring, lineWidth: ringWidth)
            }
        }
        .accessibilityHidden(true)
    }

    private var initialsView: some View {
        let fill = gradeNumeric >= 0 ? Color.gradeColor(for: gradeNumeric) : Color.geckoPrimary
        let ink = gradeNumeric >= 0 ? VGrade.textColor(for: gradeNumeric) : Color.geckoOnPrimary
        return Circle()
            .fill(fill)
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.38, weight: .heavy, design: .rounded))
                    .foregroundStyle(ink)
            )
    }

    private var initials: String {
        let components = name.split(separator: " ")
        let letters = components.prefix(2).compactMap { $0.first }.map { String($0) }
        return letters.joined().uppercased()
    }
}
