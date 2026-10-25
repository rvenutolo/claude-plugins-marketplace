# rvenutolo Claude Code marketplace

A [Claude Code](https://claude.com/claude-code) plugin marketplace. Each
plugin lives in its own repository; the catalogue in
[`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json) pins each
one to a release tag and the commit that tag points at.

## Plugins

<!-- plugins:start -->
<!-- The table is single-space cells under the prettier-ignore marker below, so a version of a different length does not make the formatter rewrite it. -->
<!-- prettier-ignore -->
| Plugin | Version | Description |
| --- | --- | --- |
| [pgrep-pkill-guard](https://github.com/rvenutolo/claude-pgrep-pkill-guard) | v1.2.0 | Blocks pgrep/pkill commands that match the agent's own process or poll in a loop. |

<!-- plugins:end -->

## Install

```text
/plugin marketplace add rvenutolo/claude-plugins-marketplace
/plugin install <plugin>@rvenutolo
/reload-plugins
```

Replace `<plugin>` with a name from the table above. The last line activates
the newly installed plugin in the running session.

The same steps from the CLI, for scripting a machine or a dotfiles bootstrap:

```console
claude plugin marketplace add rvenutolo/claude-plugins-marketplace
claude plugin install <plugin>@rvenutolo
```

Plugins are fetched over SSH from GitHub. Without a GitHub SSH key, set
`CLAUDE_CODE_PLUGIN_PREFER_HTTPS=1` first. Only `claude plugin install` from
the shell falls back to HTTPS on its own; installs and updates through
`/plugin` do not.

## Updates

Each pin follows its plugin's release tags and is bumped by Renovate. Pick up
new pins with `/plugin marketplace update rvenutolo`, or let auto-update do it.

## Uninstall

```text
/plugin uninstall <plugin>@rvenutolo
/plugin marketplace remove rvenutolo
```

From the CLI:

```console
claude plugin uninstall <plugin>@rvenutolo
claude plugin marketplace remove rvenutolo
```

## Development

`./run-all-checks` runs the whole gate: formatting, the governance checks, the
lints and the test suite. The governance checks include `.ci/check-pins`, which
verifies every pin against its remote tag and so needs network access, and
`.ci/check-readme-sync`, which holds the plugin table to the manifest. The
shortcut for the whole gate is `just check`.
