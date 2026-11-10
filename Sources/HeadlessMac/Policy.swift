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
    case builtinOff([UInt32])
    case ready
}

struct Policy {
    static func sameConnections(_ lhs: [Display], _ rhs: [Display]) -> Bool {
        lhs.sorted { $0.id < $1.id }.elementsEqual(rhs.sorted { $0.id < $1.id }) {
            $0.id == $1.id && $0.builtin == $1.builtin && $0.wired == $1.wired && $0.identity == $1.identity
        }
    }

    /// Wired and built-in displays only. Virtual screens come and go on their own and are not Slabtop's to track.
    static func physical(_ displays: [Display]) -> [Display] {
        displays.filter { $0.builtin || $0.wired }
    }

    static func decide(_ displays: [Display], preferredMainID: UInt32? = nil, allowVirtual: Bool = false) -> Decision {
        let external = displays.filter { !$0.builtin && $0.wired }.sorted { $0.id < $1.id }
        guard !external.isEmpty else { return .wait("Connect a wired monitor or TV.") }
        let internalIDs = displays.filter { $0.builtin && ($0.active || $0.online) }.map(\.id).sorted()
        if displays.contains(where: { !$0.builtin && !$0.wired && ($0.active || $0.online) }) {
            guard allowVirtual else {
                return .wait("Another display is in use. Disconnect it before applying external-only mode.")
            }
            // Another app owns these screens and their layout. Only turn the built-in display off, and leave mirroring alone.
            guard !external.contains(where: \.mirrored) else {
                return .wait("A wired screen is mirroring while virtual screens are in use. Slabtop leaves it alone.")
            }
            if let pending = external.first(where: { !$0.active || !$0.online }) { return .admit(pending.id) }
            return internalIDs.isEmpty ? .ready : .builtinOff(internalIDs)
        }
        if let pending = external.first(where: { !$0.active || !$0.online || $0.mirrored }) { return .admit(pending.id) }
        let main = external.first(where: { $0.id == preferredMainID }) ?? external.first(where: \.main) ?? external[0]
        if !internalIDs.isEmpty || !main.main || external.filter(\.main).count != 1 { return .externalOnly(main.id, internalIDs) }
        return .ready
    }
}
