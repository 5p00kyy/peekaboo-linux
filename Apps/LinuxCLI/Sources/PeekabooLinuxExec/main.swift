import PeekabooLinuxCLI

#if os(Linux)
import Glibc
#else
import Darwin
#endif

let cli = PeekabooLinuxCLI()
let exitCode = cli.run(arguments: Array(CommandLine.arguments.dropFirst()))
exit(exitCode)
