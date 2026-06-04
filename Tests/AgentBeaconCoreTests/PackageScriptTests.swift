import Foundation
import Testing

@Test func packageScriptSignsAppBundleAfterWritingInfoPlist() throws {
    let script = try packageScript()

    let plistEnd = try #require(script.range(of: "</plist>\nPLIST"))
    let signHelper = try #require(script.range(of: "sign_code \"$APP_RESOURCES/AgentBeaconStatus\""))
    let sign = try #require(script.range(of: "sign_code \"$APP_DIR\""))
    let verify = try #require(script.range(of: "codesign --verify --deep --strict --verbose=2 \"$APP_DIR\""))
    let dmgCreate = try #require(script.range(of: "hdiutil create"))

    #expect(plistEnd.upperBound < signHelper.lowerBound)
    #expect(signHelper.upperBound < sign.lowerBound)
    #expect(sign.upperBound < verify.lowerBound)
    #expect(verify.upperBound < dmgCreate.lowerBound)
}

@Test func packageScriptCanNotarizeAndStapleDeveloperIDBuilds() throws {
    let script = try packageScript()

    let identityEnv = try #require(script.range(of: "AGENTBEACON_CODESIGN_IDENTITY"))
    let notarizeFlag = try #require(script.range(of: "AGENTBEACON_NOTARIZE"))
    let hardenedRuntime = try #require(script.range(of: "--options runtime"))
    let appZip = try #require(script.range(of: "APP_NOTARY_ZIP"))
    let notarizeApp = try #require(script.range(of: "notarize_file \"$APP_NOTARY_ZIP\""))
    let stapleApp = try #require(script.range(of: "xcrun stapler staple \"$APP_DIR\""))
    let validateApp = try #require(script.range(of: "xcrun stapler validate \"$APP_DIR\""))
    let dmgCreate = try #require(script.range(of: "hdiutil create"))
    let notarizeDmg = try #require(script.range(of: "notarize_file \"$DMG_PATH\""))
    let stapleDmg = try #require(script.range(of: "xcrun stapler staple \"$DMG_PATH\""))
    let validateDmg = try #require(script.range(of: "xcrun stapler validate \"$DMG_PATH\""))
    let zipStage = try #require(script.range(of: "rm -rf \"$PACKAGE_ROOT\" \"$ZIP_PATH\""))

    #expect(identityEnv.lowerBound < hardenedRuntime.lowerBound)
    #expect(notarizeFlag.lowerBound < notarizeApp.lowerBound)
    #expect(appZip.lowerBound < notarizeApp.lowerBound)
    #expect(notarizeApp.upperBound < stapleApp.lowerBound)
    #expect(stapleApp.upperBound < validateApp.lowerBound)
    #expect(validateApp.upperBound < dmgCreate.lowerBound)
    #expect(dmgCreate.upperBound < notarizeDmg.lowerBound)
    #expect(notarizeDmg.upperBound < stapleDmg.lowerBound)
    #expect(stapleDmg.upperBound < validateDmg.lowerBound)
    #expect(validateDmg.upperBound < zipStage.lowerBound)
}

@Test func packageScriptVerifiesDiskImageAfterCreatingIt() throws {
    let script = try packageScript()

    let dmgCreate = try #require(script.range(of: "hdiutil create"))
    let dmgVerify = try #require(script.range(of: "hdiutil verify \"$DMG_PATH\""))
    let zipStage = try #require(script.range(of: "rm -rf \"$PACKAGE_ROOT\" \"$ZIP_PATH\""))

    #expect(dmgCreate.upperBound < dmgVerify.lowerBound)
    #expect(dmgVerify.upperBound < zipStage.lowerBound)
}

@Test func releaseWorkflowImportsDeveloperIDCertificateAndUploadsNotarizedAssets() throws {
    let workflow = try releaseWorkflow()

    #expect(workflow.contains("DEVELOPER_ID_APPLICATION_CERTIFICATE_BASE64"))
    #expect(workflow.contains("DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD"))
    #expect(workflow.contains("DEVELOPER_ID_APPLICATION_IDENTITY"))
    #expect(workflow.contains("APPLE_ID"))
    #expect(workflow.contains("APPLE_TEAM_ID"))
    #expect(workflow.contains("APPLE_APP_SPECIFIC_PASSWORD"))
    #expect(workflow.contains("security import \"$CERTIFICATE_PATH\""))
    #expect(workflow.contains("security set-key-partition-list"))
    #expect(workflow.contains("AGENTBEACON_NOTARIZE: \"1\""))
    #expect(workflow.contains("gh release upload"))
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

private func releaseWorkflow() throws -> String {
    let testFileURL = URL(fileURLWithPath: #filePath)
    let rootURL = testFileURL
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let workflowURL = rootURL
        .appendingPathComponent(".github")
        .appendingPathComponent("workflows")
        .appendingPathComponent("release.yml")
    return try String(contentsOf: workflowURL, encoding: .utf8)
}
