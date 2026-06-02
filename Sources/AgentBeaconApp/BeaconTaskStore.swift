import AgentBeaconCore
import Foundation

@MainActor
final class BeaconTaskStore: ObservableObject {
    @Published private(set) var tasks: [AgentTask] = []
    @Published private(set) var diagnostic: String = "Starting Agent Beacon."

    var counts: AggregateCounts {
        TaskAggregator.counts(for: tasks)
    }

    var sortedTasks: [AgentTask] {
        TaskAggregator.sortedForDisplay(tasks)
    }

    func replaceTasks(_ tasks: [AgentTask], diagnostic: String) {
        guard self.tasks != tasks || self.diagnostic != diagnostic else {
            return
        }

        self.tasks = tasks
        self.diagnostic = diagnostic
    }
}
