# Release Signing and Notarization

Agent Beacon's public macOS release should be distributed as a Developer ID signed and notarized DMG. This lets a new user download the DMG in Safari, drag `Agent Beacon.app` to Applications, and launch it without Gatekeeper's unverified-developer warning.

## Apple Requirements

You need:

- Apple Developer Program membership.
- A `Developer ID Application` certificate with its private key.
- Apple ID notarization credentials:
  - Apple ID email.
  - Team ID.
  - App-specific password.

Apple references:

- Developer ID overview: https://developer.apple.com/support/developer-id/
- Notarizing macOS software: https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution
- Custom notarization workflow: https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution/customizing_the_notarization_workflow

## Export the Developer ID Certificate

On the Mac that has the Developer ID certificate and private key:

1. Open Keychain Access.
2. Select `My Certificates`.
3. Find `Developer ID Application: <Name> (<TEAMID>)`.
4. Export it as `DeveloperIDApplication.p12`.
5. Set a strong p12 password.

Convert the p12 to base64 for GitHub Actions:

```bash
base64 -i DeveloperIDApplication.p12 | pbcopy
```

## GitHub Secrets

Create these repository secrets:

```text
DEVELOPER_ID_APPLICATION_CERTIFICATE_BASE64
DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD
DEVELOPER_ID_APPLICATION_IDENTITY
APPLE_ID
APPLE_TEAM_ID
APPLE_APP_SPECIFIC_PASSWORD
```

Example `DEVELOPER_ID_APPLICATION_IDENTITY` value:

```text
Developer ID Application: Xiao Luo (ABCDE12345)
```

## Manual Signed Release Workflow

Run the `Signed Release` workflow from GitHub Actions, or trigger it with the GitHub CLI:

```bash
gh workflow run release.yml \
  --repo XiaoLuoLYG/agent-beacon \
  -f tag=v0.1.0 \
  -f upload=true
```

Watch the run:

```bash
gh run list --repo XiaoLuoLYG/agent-beacon --workflow "Signed Release" --limit 1
gh run watch <run-id> --repo XiaoLuoLYG/agent-beacon --exit-status
```

The workflow:

1. Imports the p12 certificate into a temporary keychain.
2. Runs `swift test`.
3. Builds the app.
4. Signs helper binaries and the app with hardened runtime.
5. Submits the app archive to Apple's notary service.
6. Staples and validates the app ticket.
7. Builds the DMG and ZIP.
8. Submits, staples, and validates the DMG.
9. Uploads `AgentBeacon-macOS.dmg` and `AgentBeacon-macOS.zip` to the selected GitHub Release.

## Local Signed Build

For local signing and notarization:

```bash
AGENTBEACON_CODESIGN_IDENTITY="Developer ID Application: Xiao Luo (ABCDE12345)" \
AGENTBEACON_NOTARIZE=1 \
AGENTBEACON_NOTARY_APPLE_ID="you@example.com" \
AGENTBEACON_NOTARY_TEAM_ID="ABCDE12345" \
AGENTBEACON_NOTARY_PASSWORD="app-specific-password" \
make package
```

Without those variables, `make package` still produces an ad-hoc signed preview build for local development and CI smoke checks.

## Verification

After a signed build:

```bash
codesign --verify --deep --strict --verbose=4 "dist/Agent Beacon.app"
xcrun stapler validate "dist/Agent Beacon.app"
xcrun stapler validate "dist/AgentBeacon-macOS.dmg"
hdiutil verify "dist/AgentBeacon-macOS.dmg"
spctl -a -vv --type execute "dist/Agent Beacon.app"
```

For the true new-user path, download the DMG from GitHub Release in Safari on a Gatekeeper-enabled Mac, drag the app to Applications, and open it from Launchpad.
