import Charts
import SnapshotTesting
import UIKit
import XCTest

private enum Snapshot {
    static func identifier(_ size: CGSize) -> String {
        #if os(tvOS)
            let identifier = "tvOS"
        #elseif os(iOS)
            let identifier = "iOS"
        #elseif os(OSX)
            let identifier = "macOS"
        #else
            let identifier = ""
        #endif

        return "\(identifier)_\(size.width)_\(size.height)"
    }
}

func assertChartSnapshot<Value: ChartViewBase>(
    matching value: @autoclosure () throws -> Value,
    record recording: Bool = false,
    timeout: TimeInterval = 5,
    file: StaticString = #file,
    testName: String = #function,
    line: UInt = #line
) {
    let fileUrl = URL(fileURLWithPath: "\(file)", isDirectory: false)
    let fileName = fileUrl.deletingPathExtension().lastPathComponent

    #if arch(arm64)
    let snapshotDirectory = fileUrl.deletingLastPathComponent()
        .appendingPathComponent("__Snapshots__AppleSilicon__")
        .appendingPathComponent(fileName)
        .path
    #else
    let snapshotDirectory = fileUrl.deletingLastPathComponent()
        .appendingPathComponent("__Snapshots__x86__")
        .appendingPathComponent(fileName)
        .path
    #endif

    let failure = verifySnapshot(
        matching: try value(),
        as: .image,
        record: recording,
        snapshotDirectory: snapshotDirectory,
        timeout: timeout,
        file: file,
        testName: testName + Snapshot.identifier(UIScreen.main.bounds.size)
    )
    guard let message = failure else { return }
    XCTFail(message, file: file, line: line)
}
