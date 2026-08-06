import Foundation

/// Loads and saves `AppConfig` as JSON on disk.
///
/// Default location is `~/Library/Application Support/PhonkJazz/config.json`. A
/// custom directory can be injected for tests. Missing or corrupt config falls
/// back to `AppConfig.defaults` rather than crashing.
public final class ConfigStore {
    /// Full path of the config file this store reads and writes.
    public let configURL: URL

    /// Creates a store. Pass `directory` to override the default location (tests).
    public init(directory: URL? = nil) {
        let dir =
            directory
            ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PhonkJazz", isDirectory: true)
        configURL = dir.appendingPathComponent("config.json", isDirectory: false)
    }

    /// Returns the persisted config, or `AppConfig.defaults` if none/invalid.
    public func load() -> AppConfig {
        guard let data = try? Data(contentsOf: configURL),
            let config = try? JSONDecoder().decode(AppConfig.self, from: data)
        else {
            return .defaults
        }
        return config
    }

    /// Persists `config`, creating the containing directory if needed.
    public func save(_ config: AppConfig) throws {
        let dir = configURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(config).write(to: configURL, options: .atomic)
    }
}
