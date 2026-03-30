import Foundation

struct RulesSummary: Decodable, Equatable {
    static let retainedRuleLimit = 100

    let rules: [RuleItem]
    let totalCount: Int

    private enum CodingKeys: String, CodingKey {
        case rules
    }

    private struct RawRuleItem: Decodable {
        let type: String?
        let payload: String?
        let proxy: String?
    }

    init(rules: [RuleItem], totalCount: Int? = nil) {
        self.rules = rules
        self.totalCount = totalCount ?? rules.count
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard var rulesContainer = try? container.nestedUnkeyedContainer(forKey: .rules) else {
            self.rules = []
            self.totalCount = 0
            return
        }

        var retained: [RuleItem] = []
        retained.reserveCapacity(min(Self.retainedRuleLimit, rulesContainer.count ?? Self.retainedRuleLimit))

        var totalCount = 0
        while !rulesContainer.isAtEnd {
            let raw = try rulesContainer.decode(RawRuleItem.self)
            if retained.count < Self.retainedRuleLimit {
                retained.append(RuleItem(type: raw.type, payload: raw.payload, proxy: raw.proxy, index: totalCount))
            }
            totalCount += 1
        }

        self.rules = retained
        self.totalCount = totalCount
    }
}

struct RuleItem: Equatable, Identifiable {
    let rowID: String
    let type: String?
    let payload: String?
    let proxy: String?

    var id: String {
        self.rowID
    }

    static func == (lhs: RuleItem, rhs: RuleItem) -> Bool {
        lhs.rowID == rhs.rowID
    }

    /// Deterministic ID that includes the list position so duplicates stay unique.
    init(type: String?, payload: String?, proxy: String?, index: Int) {
        self.type = type
        self.payload = payload
        self.proxy = proxy
        self.rowID = "\(index):\(type ?? ""):\(payload ?? ""):\(proxy ?? "")"
    }
}
