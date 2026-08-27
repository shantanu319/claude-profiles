# Claude Profiles

Claude Profiles is an unofficial macOS launcher for running separate Claude Desktop accounts
side by side. It opens Anthropic's original, signed app with a persistent data directory for
each named profile. It never copies cookies, OAuth tokens, or other credentials.

## Use it

1. Install Claude Desktop normally.
2. Move `Claude Profiles.app` to Applications and open it.
3. Use **Existing Claude** for the account already signed into Claude Desktop.
4. Choose **New Profile**, give the other account a recognizable name, and sign in inside the
   new Claude window.
5. Verify the account name shown in Claude before starting Code or Cowork agents.
6. Open either profile from the launcher whenever you need it. Profiles can run concurrently.

During a profile's first sign-in, macOS may deliver an external sign-in callback to another
Claude window. If that happens, quit the other Claude windows, complete this profile's one-time
sign-in, and then reopen everything. Email sign-in can also present a verification code that you
enter in the initiating window.

## What is isolated

Every managed profile gets a mode-`0700` directory at:

```text
~/Library/Application Support/Claude Profiles/Profiles/<UUID>/User Data
```

That directory holds the profile's cookies, local/session storage, settings, extensions, and
Desktop-managed local agent sessions. The normal Claude profile remains untouched at:

```text
~/Library/Application Support/Claude
```

The launcher tracks only a UUID, display name, and creation date. Deleting a profile moves its
UUID directory to Trash and is blocked while that profile is running. Sign out in Claude first
if you also want to end its server session.

## Important limitations

- This relies on Chromium's `--user-data-dir` behavior. It works with Claude Desktop
  `1.37937.3` but is not a public Anthropic multi-profile API and may change.
- Managed profiles cannot use local Claude-in-Chrome pairing in the current Desktop build.
- `claude://` links and Microsoft login callbacks are global, not profile-aware.
- Quick-entry shortcuts, login items, notifications, updates, macOS privacy permissions,
  Keychain groups, and logs are shared by the app bundle. Enable global shortcuts in one
  profile only.
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
use. `Scripts/build-app.sh` writes `build/Claude Profiles.app`.

## Technical references

- [Chromium user data directories](https://chromium.googlesource.com/chromium/src/+/HEAD/docs/user_data_dir.md)
- [Electron userData and sessionData](https://www.electronjs.org/docs/latest/api/app/)
- [Claude account login](https://support.claude.com/en/articles/13189465-log-in-to-your-claude-account)
- [Claude Desktop deep links](https://support.claude.com/en/articles/14729294-open-claude-desktop-with-a-link)
- [Managing Claude sessions](https://support.claude.com/en/articles/13124001-managing-your-active-sessions)

Claude Profiles is not affiliated with or endorsed by Anthropic.
