import Foundation

struct ShellResult {
    var stdout: String
    var stderr: String
    var exitCode: Int32
    var timedOut: Bool
}

enum Shell {
    static func run(_ command: String, timeout: TimeInterval = 12) async -> ShellResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-lc", command]

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: ShellResult(
                        stdout: "",
                        stderr: error.localizedDescription,
                        exitCode: -1,
                        timedOut: false
                    ))
                    return
                }

                let group = DispatchGroup()
                group.enter()
                DispatchQueue.global(qos: .utility).async {
                    process.waitUntilExit()
                    group.leave()
                }

                let timedOut = group.wait(timeout: .now() + timeout) == .timedOut
                if timedOut {
                    process.terminate()
                    _ = group.wait(timeout: .now() + 1)
                }

                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""

                continuation.resume(returning: ShellResult(
                    stdout: stdout,
                    stderr: stderr,
                    exitCode: timedOut ? -9 : process.terminationStatus,
                    timedOut: timedOut
                ))
            }
        }
    }
}

extension String {
    var shellEscaped: String {
        "'" + replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
