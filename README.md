# Claude Profiles

Claude Profiles is an unofficial macOS launcher for running separate Claude Desktop accounts
side by side. Every managed profile gets its own APFS clone of Anthropic's signed app and its
own persistent Desktop data directory. Cookies, OAuth tokens, and credentials are never copied.

## Use it

1. Install Claude Desktop normally.
2. Move `Claude Profiles.app` to Applications. The local build is ad-hoc signed, not notarized:
   Control-click it, choose **Open**, then choose **Open** again. If macOS still blocks it, use
   **System Settings → Privacy & Security → Open Anyway**.
3. Use **Existing Claude** for the account already signed into Claude Desktop.
4. Choose **New Profile** and give the other account a recognizable name.
5. For the first sign-in, quit every other Claude app with **⌘Q**, then create and open the
   profile. Closing windows is not enough.
6. Sign in inside the new Claude window and verify the account name before starting an agent.
7. Reopen the other profiles. They can now run concurrently.

Profiles made by an earlier build can show **Restart needed**. Quit that Claude copy with **⌘Q**,
then choose **Fix**. This migrates its launcher without removing its account data.

To delete a managed profile, quit its Claude app with **⌘Q**, choose the red trash button on
that profile's row, and confirm **Move Profile to Trash**. The cloned app and its local Desktop
data remain recoverable in Trash; the Claude account itself is not deleted.

If macOS delivers an external sign-in callback to the wrong Claude app, quit every Claude app
with ⌘Q and restart that profile's sign-in. Email sign-in can also present a verification code
that you enter in the initiating window.

## What is isolated

Every managed profile gets a mode-`0700` container with three important entries:

```text
~/Library/Application Support/Claude Profiles/Profiles/<UUID>/Claude.app
~/Library/Application Support/Claude Profiles/Profiles/<UUID>/User Data
~/Library/Application Support/Claude Profiles/Profiles/<UUID>/profile.json
```

`Claude.app` is a byte-identical clone whose Anthropic signature is verified before launch.
`User Data` holds that profile's cookies, local/session storage, settings, extensions, and
Desktop-managed local agent sessions. The normal Claude installation and profile remain at:

```text
/Applications/Claude.app
~/Library/Application Support/Claude
```

On APFS, the clone initially shares disk blocks with the installed app, so its physical cost is
normally small even though Finder reports the full logical size. `ditto` can fall back to a full
copy on filesystems that do not support cloning. When the installed Claude version changes, the
managed clone is refreshed the next time that profile opens—but only after that exact signed
build has been validated for safe update isolation. An unknown build is blocked rather than
risking one clone changing the shared Claude updater state.

Managed copies have automatic updating disabled before launch. Keep `/Applications/Claude.app`
as the canonical installation and let it update normally. Claude Profiles currently validates
Claude Desktop `1.37937.3`; a newer signed build requires an updated Claude Profiles release.

The launcher tracks only a UUID, display name, and creation date. Metadata is stored inside each
profile folder, so a damaged index cannot hide intact profile data. Deleting a profile moves its
UUID directory to Trash and is blocked while that profile is running. Sign out in Claude first
if you also want to end its server session.

## Important limitations

- This relies on Chromium's `--user-data-dir` behavior. It is not a public Anthropic
  multi-profile API and may change.
- Managed profiles cannot use local Claude-in-Chrome pairing in the current Desktop build.
- `claude://` links and Microsoft login callbacks are global, not profile-aware.
- Because every clone keeps Anthropic's bundle identity and signature, Quick Entry, login items,
  notifications, macOS privacy permissions, Keychain groups, and logs can remain shared. Clone
  windows also keep the same Claude name and icon in the Dock and app switcher; use the launcher
  labels and verify the signed-in account inside each window.
- Some project and standalone Claude Code configuration under `~/.claude` can remain shared.
- This separates everyday account state; it is not a security boundary. Use separate macOS
  users or VMs for accounts that must not trust each other.

## Build and test

Requirements: macOS 13+, Xcode Command Line Tools, and Swift 6.

```sh
swift test
Scripts/build-app.sh
```

The app is written in SwiftUI, has no third-party dependencies, and is ad-hoc signed for local
use. It is not notarized, so the first-open steps above are required. `Scripts/build-app.sh`
writes a universal `build/Claude Profiles.app`. The build and release archives never contain or
redistribute Anthropic's Claude app.

## Technical references

- [Chromium user data directories](https://chromium.googlesource.com/chromium/src/+/HEAD/docs/user_data_dir.md)
- [Electron userData and sessionData](https://www.electronjs.org/docs/latest/api/app/)
- [Claude account login](https://support.claude.com/en/articles/13189465-log-in-to-your-claude-account)
- [Claude Desktop deep links](https://support.claude.com/en/articles/14729294-open-claude-desktop-with-a-link)
- [Managing Claude sessions](https://support.claude.com/en/articles/13124001-managing-your-active-sessions)

Claude Profiles is not affiliated with or endorsed by Anthropic.
