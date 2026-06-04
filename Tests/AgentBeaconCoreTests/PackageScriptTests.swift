import Foundation
import Testing

@Test func packageScriptSignsAppBundleAfterWritingInfoPlist() throws {
    let script = try packageScript()

    let plistEnd = try #require(script.range(of: "</plist>\nPLIST"))
    let sign = try #require(script.range(of: "codesign --force --sign - --timestamp=none \"$APP_DIR\""))
    let verify = try #require(script.range(of: "codesign --verify --deep --strict --verbose=2 \"$APP_DIR\""))
    let dmgCreate = try #require(script.range(of: "hdiutil create"))

    #expect(plistEnd.upperBound < sign.lowerBound)
    #expect(sign.upperBound < verify.lowerBound)
    #expect(verify.upperBound < dmgCreate.lowerBound)
}

@Test func packageScriptVerifiesDiskImageAfterCreatingIt() throws {
    let script = try packageScript()

    let dmgCreate = try #require(script.range(of: "hdiutil create"))
    let dmgVerify = try #require(script.range(of: "hdiutil verify \"$DMG_PATH\""))
    let zipStage = try #require(script.range(of: "rm -rf \"$PACKAGE_ROOT\" \"$ZIP_PATH\""))

    #expect(dmgCreate.upperBound < dmgVerify.lowerBound)
    #expect(dmgVerify.upperBound < zipStage.lowerBound)
}

@Test func releaseInstallScriptDownloadsInstallsAndClearsQuarantine() throws {
    let script = try releaseInstallScript()

    #expect(script.contains("releases/latest/download/AgentBeacon-macOS.zip"))
    #expect(script.contains("curl --fail --location --retry 3"))
    #expect(script.contains("AGENT_BEACON_SHA256"))
    #expect(script.contains("ditto -x -k \"$ZIP_PATH\""))
    #expect(script.contains("xattr -dr com.apple.quarantine"))
    #expect(script.contains("bash \"$PACKAGE_DIR/install.sh\""))
    #expect(script.contains("open \"$APP_DEST/Agent Beacon.app\""))
}

private func packageScript() throws -> String {
    let testFileURL = URL(fileURLWithPath: #filePath)
    let rootURL = testFileURL
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let scriptURL = rootURL.appendingPathComponent("scripts/package-app.sh")
    return try String(contentsOf: scriptURL, encoding: .utf8)
}

private func releaseInstallScript() throws -> String {
    let testFileURL = URL(fileURLWithPath: #filePath)
    let rootURL = testFileURL
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let scriptURL = rootURL.appendingPathComponent("scripts/install-from-release.sh")
    return try String(contentsOf: scriptURL, encoding: .utf8)
}
