import Darwin
import Foundation

public enum CanonicalFilePath {
    public static func existing(_ url: URL) -> String? {
        url.path.withCString { path in
            guard let resolved = Darwin.realpath(path, nil) else { return nil }
            defer { free(resolved) }
            return String(cString: resolved)
        }
    }

    public static func resolve(_ url: URL) -> String {
        existing(url) ?? url.standardizedFileURL.path
    }

    public static func resolve(_ path: String) -> String {
        resolve(URL(fileURLWithPath: path))
    }
}
