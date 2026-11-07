import Foundation

struct Display: Encodable, Equatable {
    let id: UInt32
    let name: String
    let builtin: Bool
    let wired: Bool
    let active: Bool
    let online: Bool
    let mirrored: Bool
    let main: Bool
    let identity: String?

    enum CodingKeys: String, CodingKey {
        case id, name, builtin, wired, active, online, mirrored, main
    }

    init(id: UInt32, name: String, builtin: Bool, wired: Bool, active: Bool, online: Bool, mirrored: Bool, main: Bool, identity: String? = nil) {
        self.id = id
        self.name = name
        self.builtin = builtin
        self.wired = wired
        self.active = active
        self.online = online
        self.mirrored = mirrored
        self.main = main
        self.identity = identity
    }
}

enum Decision: Equatable {
    case wait(String)
    case admit(UInt32)
    case externalOnly(UInt32, [UInt32])
    case ready
}

struct Policy {
    static func sameConnections(_ lhs: [Display], _ rhs: [Display]) -> Bool {
        lhs.sorted { $0.id < $1.id }.elementsEqual(rhs.sorted { $0.id < $1.id }) {
            $0.id == $1.id && $0.builtin == $1.builtin && $0.wired == $1.wired && $0.identity == $1.identity
        }
    }

    static func decide(_ displays: [Display], preferredMainID: UInt32? = nil) -> Decision {
        let external = displays.filter { !$0.builtin && $0.wired }.sorted { $0.id < $1.id }
        guard !external.isEmpty else { return .wait("Connect a wired monitor or TV.") }
        guard !displays.contains(where: { !$0.builtin && !$0.wired && ($0.active || $0.online) }) else {
            return .wait("Another display is in use. Disconnect it before applying external-only mode.")
        }
        if let pending = external.first(where: { !$0.active || !$0.online || $0.mirrored }) { return .admit(pending.id) }
        let main = external.first(where: { $0.id == preferredMainID }) ?? external.first(where: \.main) ?? external[0]
        let internalIDs = displays.filter { $0.builtin && ($0.active || $0.online) }.map(\.id).sorted()
        if !internalIDs.isEmpty || !main.main || external.filter(\.main).count != 1 { return .externalOnly(main.id, internalIDs) }
        return .ready
    }
}
