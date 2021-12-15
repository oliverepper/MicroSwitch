import Files

extension ServerInfo {
    private static let folder = "." + processName + "/var/run"
    private static let filename = "ServerInfo.json"


    public static func load() -> ServerInfo {
        if let file = try? Folder.current
            .subfolder(named: Self.folder)
            .file(at: Self.filename),
           let data = try? file.read(),
           let info = try? ServerInfo(jsonUTF8Data: data) {
            return info
        } else {
            return ServerInfo()
        }
    }

    public func save() throws {
        let data = try self.jsonUTF8Data()
        if let file = try? Folder.current
            .subfolder(named: Self.folder)
            .file(at: Self.filename) {
            try file.write(data)
        } else {
            try Folder.current
                .createSubfolderIfNeeded(withName: Self.folder)
                .createFile(at: Self.filename, contents: data)
        }
    }
}
