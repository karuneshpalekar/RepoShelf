import Foundation

struct ShellResult {
    var status: Int32
    var stdout: String
    var stderr: String

    var ok: Bool { status == 0 }
    var trimmedOut: String { stdout.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedErr: String { stderr.trimmingCharacters(in: .whitespacesAndNewlines) }
}

enum ShellError: LocalizedError {
    case toolNotFound(String)
    case failed(command: String, status: Int32, message: String)

    var errorDescription: String? {
        switch self {
        case .toolNotFound(let name):
            return "\(name) not found. Install it and try again."
        case .failed(let command, let status, let message):
            let msg = message.isEmpty ? "exit \(status)" : message
            return "\(command) failed: \(msg)"
        }
    }
}

/// Runs command-line tools. A GUI app doesn't inherit the shell's PATH, so
/// tools are located explicitly and children get a PATH that includes the
/// usual Homebrew locations.
enum Shell {
    static let searchPaths = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/usr/bin",
        "/bin",
    ]

    static var childPATH: String {
        (searchPaths + ["/usr/sbin", "/sbin"]).joined(separator: ":")
    }

    private static var locatorCache: [String: String] = [:]

    /// Absolute path to a tool, searching fixed locations then a login shell.
    static func locate(_ tool: String) -> String? {
        if let hit = locatorCache[tool] { return hit }

        for dir in searchPaths {
            let candidate = "\(dir)/\(tool)"
            if FileManager.default.isExecutableFile(atPath: candidate) {
                locatorCache[tool] = candidate
                return candidate
            }
        }

        // Fall back to asking a login shell (picks up custom PATH entries).
        let probe = Process()
        probe.executableURL = URL(fileURLWithPath: "/bin/zsh")
        probe.arguments = ["-lc", "command -v \(tool)"]
        let pipe = Pipe()
        probe.standardOutput = pipe
        probe.standardError = Pipe()
        do {
            try probe.run()
            probe.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            if !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) {
                locatorCache[tool] = path
                return path
            }
        } catch {
            // ignore — reported as not found below
        }
        return nil
    }

    @discardableResult
    static func run(
        _ executablePath: String,
        _ arguments: [String],
        env extraEnv: [String: String] = [:],
        cwd: URL? = nil
    ) async throws -> ShellResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executablePath)
                process.arguments = arguments
                if let cwd { process.currentDirectoryURL = cwd }

                var environment = ProcessInfo.processInfo.environment
                environment["PATH"] = childPATH
                environment["GIT_TERMINAL_PROMPT"] = "0"
                for (key, value) in extraEnv { environment[key] = value }
                process.environment = environment

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                    return
                }

                let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                continuation.resume(returning: ShellResult(
                    status: process.terminationStatus,
                    stdout: String(decoding: outData, as: UTF8.self),
                    stderr: String(decoding: errData, as: UTF8.self)
                ))
            }
        }
    }

    /// Runs a located tool by name, throwing if it isn't installed or exits non-zero.
    @discardableResult
    static func require(
        _ tool: String,
        _ arguments: [String],
        env: [String: String] = [:],
        cwd: URL? = nil
    ) async throws -> ShellResult {
        guard let path = locate(tool) else { throw ShellError.toolNotFound(tool) }
        let result = try await run(path, arguments, env: env, cwd: cwd)
        guard result.ok else {
            throw ShellError.failed(
                command: "\(tool) \(arguments.joined(separator: " "))",
                status: result.status,
                message: result.trimmedErr.isEmpty ? result.trimmedOut : result.trimmedErr
            )
        }
        return result
    }
}
