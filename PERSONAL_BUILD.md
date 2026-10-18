# Build your personal EnviousWispr fork on a Mac

The trailing-whitespace fix is merged into this fork's `main` branch. Clone this fork, not the upstream repository. The optional recording-pill work is kept on a separate, unmerged branch.

This playbook follows the repository's existing local-build path. The resulting application is **EnviousWispr Local.app**, with bundle ID `com.enviouswispr.app.dev`. Its update feed is blank, so an automatic upstream update will not replace your modification.

## 1. Install and initialize Xcode

Install the full **Xcode 26 or later** from the Mac App Store (or Apple's developer downloads). Command Line Tools alone are insufficient. Open Xcode once and finish its component installation.

In Terminal, run:

```sh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
xcodebuild -version
```

Adjust the application path if you installed Xcode under a different name. Accept the license if Xcode asks.

Your Apple Silicon Mac is supported. The app requires macOS 14 or later; the Xcode version you install may require a newer macOS.

## 2. Install the supporting tools

Install Homebrew from https://brew.sh if you do not already have it. Follow the installer's instructions to put `brew` on your PATH, then open a new Terminal window.

```sh
brew install mise python git
mise install tuist@4.195.11
mise x tuist@4.195.11 -- tuist version
python3 --version
git --version
```

**mise** manages development tools. **Tuist** generates the Xcode project. Both are available through Homebrew (`brew install mise`, `brew install --cask tuist`), but use **mise for Tuist here**: the build script explicitly invokes `tuist@4.195.11`, rather than whatever version Homebrew currently supplies. No global mise activation or Tuist account is required for these commands.

## 3. Create the local signing identity once

The local build expects a self-signed identity named **EnviousWispr Dev**. Your paid Apple Developer membership is not required for this build path, and an Apple-issued certificate with another name will not satisfy its preflight check.

1. Open **Keychain Access** (Spotlight can find it).
2. Choose **Keychain Access > Certificate Assistant > Create a Certificate…**
3. Enter the name **EnviousWispr Dev** exactly.
4. Set **Identity Type** to **Self Signed Root**.
5. Set **Certificate Type** to **Code Signing**.
6. Create it and store it in your **login** keychain.

Verify that the identity includes its private key:

```sh
security find-identity -p codesigning
```

The output must include `EnviousWispr Dev`. The build deliberately uses this command without `-v`: a self-signed certificate may be listed with `CSSMERR_TP_NOT_TRUSTED` and still be usable for local signing. If signing specifically reports a trust failure, open this certificate in Keychain Access, expand **Trust**, and set **Code Signing** to **Always Trust**, then close and authenticate. Do not change trust for unrelated certificates.

If macOS asks whether `codesign` can use this private key during the build, allow it. An expired certificate will eventually need renewal.

## 4. Clone and build

Choose a normal local folder, such as `~/Developer`:

```sh
mkdir -p ~/Developer
cd ~/Developer
git clone --depth 1 https://github.com/ericnchen/EnviousWispr.git
cd EnviousWispr
git switch main
./scripts/build-dev-app.sh
```

The script generates the Xcode project, resolves the pinned dependencies, builds and signs the application, verifies its signature, copies it to the path below, and launches it:

```text
~/Developer/EnviousWispr/build/EnviousWispr Local.app
```

The first build downloads dependencies and compiles model resources; allow time and disk space for Xcode, the checkout, dependencies, and build products. `swift build` alone does **not** assemble the runnable Mac app.

This is the repository's **Dev** configuration, with debug logging and debug compiler settings. A distribution DMG, notarization, and production signing are not needed to use this local copy.

## 5. Set up and check your copy

Quit the regular EnviousWispr application before using the local copy, so only one app handles the dictation shortcut.

Complete setup in **EnviousWispr Local**. Because it has a separate application identity, expect to grant Microphone and Accessibility access again and configure its settings. If a permission request does not appear, check **System Settings > Privacy & Security**.

To check the whitespace fix:

1. Open TextEdit and choose **Format > Make Plain Text**.
2. Dictate a short sentence.
3. Select and copy the inserted text.
4. Run the following command in Terminal. It reads the clipboard; it does not dictate into or execute the sentence.

```sh
pbpaste | python3 -c 'import sys; s = sys.stdin.read(); print("Last character:", repr(s[-1:])); print("Ends in whitespace:", bool(s) and s[-1].isspace())'
```

Expect a real final character and **Ends in whitespace: False**. Repeat with **Smart insertion** on and off under **Dictation > Clipboard**. Try your usual transcription and polish configuration too.

The fix trims whitespace only at the end of the outgoing dictation. Leading spaces, internal spaces, and internal line breaks are retained. Trailing tabs and line breaks are trimmed as well as spaces. Text already present after the cursor is not removed. In terminals, consecutive dictations may need an explicit separating space because terminal cursor context cannot always supply one.

## 6. Launch or rebuild later

Launch your built copy with:

```sh
open "$HOME/Developer/EnviousWispr/build/EnviousWispr Local.app"
```

Keep the application at a consistent path, especially after granting Accessibility access.

To rebuild from your fork's current main branch:

```sh
cd ~/Developer/EnviousWispr
git switch main
git pull --ff-only origin main
./scripts/build-dev-app.sh
```

The script stops an existing **local dev** app before replacing it. You do not need to recreate the certificate or reinstall the tools on every build.

## If something fails

- **Xcode tools unavailable:** check `xcode-select -p` points inside the full Xcode application, then complete Xcode's first launch.
- **mise or brew not found:** follow Homebrew's shell setup instructions and reopen Terminal.
- **Tuist missing:** run `mise install tuist@4.195.11`; installing only the latest Homebrew cask does not install the pinned mise version.
- **Signing identity missing:** check the certificate's exact name and that its private key is present in the login keychain.
- **Dev app lock refusal:** run `python3 scripts/lib/dev-app-lock.py status`. If it is your own finished session's hold, run `python3 scripts/lib/dev-app-lock.py release`, then retry.
- **Build or dependency failure:** save the first actual error from the Terminal output. Do not start by changing package versions or using the production release-signing script.

## Verification record

The whitespace change was reviewed and statically checked before merging. Both fallback and smart-insertion payloads are trimmed at their shared construction boundary, preserving a nil candidate. The remote diff contains only that source change.

No macOS compilation or live dictation was possible in the Linux editing environment. The commands above follow the repository's checked-in build configuration; the first Mac build and the TextEdit check remain the runtime verification. Some upstream tests explicitly require the old trailing space and therefore need different expectations for this personal preference; a full upstream test-suite pass is not claimed.
