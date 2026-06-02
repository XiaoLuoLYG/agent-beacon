import Foundation

public enum TaskAggregator {
    public static func counts(for tasks: [AgentTask]) -> AggregateCounts {
        tasks.reduce(into: AggregateCounts()) { counts, task in
            switch task.status {
            case .needsReview:
                counts.needsReview += 1
            case .failed:
                counts.failed += 1
            case .running:
                counts.running += 1
            case .completed:
                counts.completed += 1
            }
        }
    }

    public static func sortedForDisplay(_ tasks: [AgentTask]) -> [AgentTask] {
        tasks.sorted { lhs, rhs in
            if lhs.status.attentionRank != rhs.status.attentionRank {
                return lhs.status.attentionRank < rhs.status.attentionRank
            }

            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }

            return lhs.threadName.localizedCaseInsensitiveCompare(rhs.threadName) == .orderedAscending
        }
    }
}
