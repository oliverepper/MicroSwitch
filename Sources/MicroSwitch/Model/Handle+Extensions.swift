import Files

extension Handle {
    private static let folder = "." + processName + "/var/lib"

    public static func load(_ value: String) -> Self {
        if let file = try? Folder.current
            .subfolder(named: Self.folder)
            .file(at: "Handle_\(value).json"),
           let data = try? file.read(),
           let handle = try? Handle(jsonUTF8Data: data) {
            return handle
        } else {
            return Handle.with {
                $0.value = value
            }
        }
    }

    public func save() throws {
        let data = try self.jsonUTF8Data()
        if let file = try? Folder.current
            .subfolder(named: Self.folder)
            .file(at: "Handle_\(value).json") {
            try file.write(data)
        } else {
            try Folder.current
                .createSubfolderIfNeeded(withName: Self.folder)
                .createFile(named: "Handle_\(value).json", contents: data)
        }
    }
}
