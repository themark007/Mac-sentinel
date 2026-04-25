import Foundation

struct ContainerScanResult {
    var runtimes: [ContainerRuntime]
    var containers: [ContainerItem]
}

enum ContainerScanner {
    static func scan() async -> ContainerScanResult {
        async let docker = dockerContainers()
        async let podman = podmanContainers()
        async let colima = commandStatus(name: "Colima", command: "command -v colima >/dev/null && colima status 2>/dev/null | head -1")
        async let lima = commandStatus(name: "Lima", command: "command -v limactl >/dev/null && limactl list 2>/dev/null | tail -n +2 | wc -l | tr -d ' '")
        async let orb = commandStatus(name: "OrbStack", command: "command -v orb >/dev/null && orb list 2>/dev/null | head -1")

        let dockerResult = await docker
        let podmanResult = await podman
        let runtimeStatuses = await [
            dockerResult.runtime,
            podmanResult.runtime,
            colima,
            lima,
            orb
        ]

        return ContainerScanResult(
            runtimes: runtimeStatuses,
            containers: (dockerResult.containers + podmanResult.containers).sorted { $0.name < $1.name }
        )
    }

    private static func dockerContainers() async -> (runtime: ContainerRuntime, containers: [ContainerItem]) {
        let installed = await commandExists("docker")
        guard installed else {
            return (ContainerRuntime(name: "Docker", status: "Not installed", installed: false), [])
        }

        let command = #"""
        docker ps -a --size --format '{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Size}}' 2>/dev/null
        """#
        let result = await Shell.run(command, timeout: 8)
        let containers = parseContainerRows(result.stdout, runtime: "Docker")
        let status = containers.isEmpty ? "Installed, no containers" : "\(containers.count) containers"
        return (ContainerRuntime(name: "Docker", status: status, installed: true), containers)
    }

    private static func podmanContainers() async -> (runtime: ContainerRuntime, containers: [ContainerItem]) {
        let installed = await commandExists("podman")
        guard installed else {
            return (ContainerRuntime(name: "Podman", status: "Not installed", installed: false), [])
        }

        let command = #"""
        podman ps -a --size --format '{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Size}}' 2>/dev/null
        """#
        let result = await Shell.run(command, timeout: 8)
        let containers = parseContainerRows(result.stdout, runtime: "Podman")
        let status = containers.isEmpty ? "Installed, no containers" : "\(containers.count) containers"
        return (ContainerRuntime(name: "Podman", status: status, installed: true), containers)
    }

    private static func parseContainerRows(_ text: String, runtime: String) -> [ContainerItem] {
        text
            .split(whereSeparator: \.isNewline)
            .compactMap { row -> ContainerItem? in
                let parts = row.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
                guard parts.count >= 5 else { return nil }
                return ContainerItem(
                    id: "\(runtime)-\(parts[0])",
                    runtime: runtime,
                    name: parts[1],
                    image: parts[2],
                    status: parts[3],
                    size: parts[4]
                )
            }
    }

    private static func commandExists(_ name: String) async -> Bool {
        let result = await Shell.run("command -v \(name.shellEscaped) >/dev/null", timeout: 3)
        return result.exitCode == 0
    }

    private static func commandStatus(name: String, command: String) async -> ContainerRuntime {
        let binary: String
        switch name {
        case "OrbStack": binary = "orb"
        case "Lima": binary = "limactl"
        default: binary = name.lowercased()
        }

        let installed = await commandExists(binary)
        guard installed else {
            return ContainerRuntime(name: name, status: "Not installed", installed: false)
        }

        let result = await Shell.run(command, timeout: 5)
        let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return ContainerRuntime(
            name: name,
            status: output.isEmpty ? "Installed" : output,
            installed: true
        )
    }
}
