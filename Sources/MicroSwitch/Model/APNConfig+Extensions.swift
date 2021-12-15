import Files

extension APNConfig {
    private static let folder = "." + processName + "/etc"

    enum Error: Swift.Error {
        case missing(Config)
    }

    enum Config: String {
        case `default` = "APNConfig_default"
    }

    public static func load(_ config: Config) throws -> Self {
        if let file = try? Folder.current
            .subfolder(named: Self.folder)
            .file(at: Config.default.rawValue + ".json"),
           let data = try? file.read() {
            return try APNConfig(jsonUTF8Data: data)
        } else {
            throw Error.missing(config)
        }
    }
}
