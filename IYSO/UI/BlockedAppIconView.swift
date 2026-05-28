import SwiftUI

struct BlockedAppIconView: View {
    let app: BlockedApp
    @State private var resolvedIconURL: URL?
    @State private var didResolveIcon = false

    var body: some View {
        Group {
            if let assetName = builtInAssetName {
                assetIcon(assetName)
            } else if let symbolName = app.symbolName {
                symbolIcon(symbolName)
            } else if let url = resolvedIconURL {
                remoteIcon(url)
            } else {
                fallbackIcon
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .task(id: app.id) {
            await resolveIconURLIfNeeded()
        }
    }

    private var builtInAssetName: String? {
        switch app.id.lowercased() {
        case "com.apple.mobilesms":
            return "MessagesAppIcon"
        case "com.apple.mobilesafari":
            return "SafariAppIcon"
        default:
            break
        }

        switch app.name.lowercased() {
        case "messages":
            return "MessagesAppIcon"
        case "safari":
            return "SafariAppIcon"
        default:
            return nil
        }
    }

    private func assetIcon(_ assetName: String) -> some View {
        Image(assetName)
            .resizable()
            .scaledToFill()
    }

    private func symbolIcon(_ symbolName: String) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(white: 0.14))
            .overlay(
                Image(systemName: symbolName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            )
    }

    private func remoteIcon(_ url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            default:
                fallbackIcon
            }
        }
    }

    private var fallbackIcon: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(white: 0.15))
            .overlay(
                Text(String(app.name.prefix(1)))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(white: 0.55))
            )
    }

    private func resolveIconURLIfNeeded() async {
        guard !didResolveIcon else { return }
        didResolveIcon = true
        resolvedIconURL = await AppIconResolver.shared.resolveURL(for: app)
    }
}

actor AppIconResolver {
    static let shared = AppIconResolver()

    private var cache: [String: URL] = [:]

    func resolveURL(for app: BlockedApp) async -> URL? {
        if let cachedURL = cache[app.id] {
            return cachedURL
        }

        guard let escapedBundleID = app.id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let lookupURL = URL(string: "https://itunes.apple.com/lookup?bundleId=\(escapedBundleID)") else {
            return fallbackURL(for: app)
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: lookupURL)
            let response = try JSONDecoder().decode(AppLookupResponse.self, from: data)
            if let result = response.results.first {
                if let art512 = result.artworkUrl512, let iconURL = URL(string: art512) {
                    cache[app.id] = iconURL
                    return iconURL
                }
                if let art100 = result.artworkUrl100, let iconURL = URL(string: art100) {
                    cache[app.id] = iconURL
                    return iconURL
                }
            }
        } catch {
            // Fall through to fallback URL path.
        }

        return fallbackURL(for: app)
    }

    func prefetch(apps: [BlockedApp]) async {
        for app in apps where app.symbolName == nil {
            _ = await resolveURL(for: app)
        }
    }

    private func fallbackURL(for app: BlockedApp) -> URL? {
        guard let iconURLString = app.iconURLString,
              let iconURL = URL(string: iconURLString) else {
            return nil
        }
        cache[app.id] = iconURL
        return iconURL
    }
}

private struct AppLookupResponse: Decodable {
    let results: [AppLookupResult]
}

private struct AppLookupResult: Decodable {
    let artworkUrl100: String?
    let artworkUrl512: String?
}

