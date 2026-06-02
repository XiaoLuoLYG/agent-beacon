import Foundation

public enum AgentBeaconStatusFileResolver {
    public static func resolve(
        arguments: [String] = CommandLine.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        currentDirectoryURL: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ) -> URL {
        if let index = arguments.firstIndex(of: "--status-file"), arguments.indices.contains(index + 1) {
            return URL(fileURLWithPath: arguments[index + 1]).standardizedFileURL
        }

        if let envPath = environment["AGENT_BEACON_STATUS_FILE"], !envPath.isEmpty {
            return URL(fileURLWithPath: envPath).standardizedFileURL
        }

        return GenericStatusFileStore.defaultFileURL().standardizedFileURL
    }
}
