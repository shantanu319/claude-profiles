# Claude Profiles

Claude Profiles is an unofficial macOS launcher for running separate Claude Desktop accounts
side by side. Every managed profile gets its own APFS clone of Anthropic's signed app and its
own persistent Desktop data directory. Cookies, OAuth tokens, and credentials are never copied.

## Use it

1. Install Claude Desktop normally.
2. Move `Claude Profiles.app` to Applications and open it.
3. Use **Existing Claude** for the account already signed into Claude Desktop.
4. Choose **New Profile** and give the other account a recognizable name.
5. For the first sign-in, quit every other Claude app with **⌘Q**, then create and open the
   profile. Closing windows is not enough.
6. Sign in inside the new Claude window and verify the account name before starting an agent.
7. Reopen the other profiles. They can now run concurrently.

If macOS delivers an external sign-in callback to the wrong Claude app, quit every Claude app
with ⌘Q and restart that profile's sign-in. Email sign-in can also present a verification code
that you enter in the initiating window.

## What is isolated

Every managed profile gets a mode-`0700` container with two important entries:

```text
~/Library/Application Support/Claude Profiles/Profiles/<UUID>/Claude.app
~/Library/Application Support/Claude Profiles/Profiles/<UUID>/User Data
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
managed clone is refreshed the next time that profile opens.

The launcher tracks only a UUID, display name, and creation date. Deleting a profile moves its
UUID directory to Trash and is blocked while that profile is running. Sign out in Claude first
if you also want to end its server session.

## Important limitations

- This relies on Chromium's `--user-data-dir` behavior. It is not a public Anthropic
  multi-profile API and may change.
- Managed profiles cannot use local Claude-in-Chrome pairing in the current Desktop build.
- `claude://` links and Microsoft login callbacks are global, not profile-aware.
- Because every clone keeps Anthropic's bundle identity and signature, Quick Entry, login items,
  notifications, update helpers, macOS privacy permissions, Keychain groups, and logs can remain
  shared. Keep `/Applications/Claude.app` as the canonical installation and let it update normally.
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
use. `Scripts/build-app.sh` writes a universal `build/Claude Profiles.app`. The build and release
archives never contain or redistribute Anthropic's Claude app.

## Technical references

- [Chromium user data directories](https://chromium.googlesource.com/chromium/src/+/HEAD/docs/user_data_dir.md)
- [Electron userData and sessionData](https://www.electronjs.org/docs/latest/api/app/)
- [Claude account login](https://support.claude.com/en/articles/13189465-log-in-to-your-claude-account)
- [Claude Desktop deep links](https://support.claude.com/en/articles/14729294-open-claude-desktop-with-a-link)
- [Managing Claude sessions](https://support.claude.com/en/articles/13124001-managing-your-active-sessions)

Claude Profiles is not affiliated with or endorsed by Anthropic.
