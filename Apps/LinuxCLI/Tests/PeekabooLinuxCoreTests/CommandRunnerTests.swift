import PeekabooLinuxCore
import Testing

@Suite("command runner")
struct CommandRunnerTests {
    @Test("times out long-running commands")
    func timesOutLongRunningCommands() throws {
        let runner = FoundationProcessRunner(timeoutSeconds: 0.05)
        var didTimeOut = false

        do {
            _ = try runner.run("sh", arguments: ["-c", "sleep 2"])
        } catch CommandError.timedOut {
            didTimeOut = true
        } catch {
            #expect(Bool(false))
        }

        #expect(didTimeOut)
    }
}
