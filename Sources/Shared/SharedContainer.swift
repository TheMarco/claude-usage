import Foundation

/// Shared cache between the host app and the widget extension via the
/// `group.com.marcovhv.claudeusage` App Group container.
public enum SharedContainer {
    public static let groupID = "group.com.marcovhv.claudeusage"
    public static let widgetBundleID = "com.marcovhv.claudeusage.widget"

    public static var directory: URL {
        // Inside the sandboxed widget: its own Application Support is writable.
        if NSHomeDirectory().contains("/Containers/") {
            let dir = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        }
        // Unsandboxed host: write straight into the widget's container so
        // the widget reads its own files — no App Group provisioning dance.
        let realHome = NSHomeDirectoryForUser(NSUserName()) ?? "/Users/\(NSUserName())"
        let url = URL(fileURLWithPath: realHome).appendingPathComponent(
            "Library/Containers/\(widgetBundleID)/Data/Library/Application Support",
            isDirectory: true
        )
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    public static func write<T: Encodable>(_ value: T, key: String) {
        let url = directory.appendingPathComponent("\(key).json")
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        if let data = try? enc.encode(value) {
            try? data.write(to: url, options: .atomic)
        }
    }

    public static func read<T: Decodable>(_ type: T.Type, key: String) -> T? {
        let url = directory.appendingPathComponent("\(key).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try? dec.decode(T.self, from: data)
    }

    public static func remove(key: String) {
        try? FileManager.default.removeItem(
            at: directory.appendingPathComponent("\(key).json")
        )
    }
}
