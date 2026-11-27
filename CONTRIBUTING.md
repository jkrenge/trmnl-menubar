# Contributing

Thanks for helping out. Bug reports, ideas and pull requests are all welcome.

## Reporting a bug

Open an issue with your macOS version, what you expected and what happened. A screenshot of the popover helps. Never paste your device API key into an issue.

## Making a change

1. Fork the repo and create a branch.
2. Make your change in [TRMNL.swift](TRMNL.swift). Keep it to one file unless there is a good reason not to.
3. Run `make test` and try the app with `make run`.
4. Open a pull request that says what changed and why. Add a screenshot for anything visible.

## Guidelines

- Keep the app small. It does one thing: show the current TRMNL screen.
- No new dependencies. The app uses only Apple frameworks.
- Credentials belong in the Keychain, never in files, logs or the repo.
- Use `local.mk` for your signing identity; it is gitignored.
- Keep it accessible: every control needs a label that VoiceOver can read.

By contributing you agree that your contribution is licensed under the [MIT License](LICENSE).
