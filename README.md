# plext-install

Public install scripts for the [Plext CLI](https://plext.com).

This repo is **deliberately separate from the CLI source**, which is private. It hosts only the install scripts and this README, so anyone can audit exactly what runs on their machine before piping into a shell.

## Install

### macOS / Linux

```sh
curl -fsSL https://get.plext.com/install.sh | sh
```

### Windows

```powershell
irm https://get.plext.com/install.ps1 | iex
```

## What these scripts do

1. Detect your OS and architecture.
2. Fetch the latest release tarball (or `.zip` on Windows) from `https://dl.plext.com/<version>/`.
3. Download `checksums.txt` and verify the SHA256 of the archive. **Refuse to install on mismatch.**
4. Extract the binary to `~/.plext/bin` (macOS/Linux) or `%LOCALAPPDATA%\Plext\bin` (Windows).
5. Add the install dir to your `PATH`.
6. Print a success message.

No data is sent anywhere. No accounts. No root/admin required.

## Environment overrides

Both scripts honor these optional variables:

| Variable | Purpose |
|---|---|
| `PLEXT_VERSION` | Pin a specific tag (e.g. `v0.1.0`). Defaults to latest. |
| `PLEXT_INSTALL` | Override install directory. |
| `PLEXT_DL_BASE` | Override download base URL (for testing). |
| `PLEXT_NO_PATH` | Skip `PATH` modification. |

## Verifying releases

Checksums are signed with [cosign](https://github.com/sigstore/cosign) keyless OIDC tied to our GitHub org. For each release:

```
https://dl.plext.com/<version>/checksums.txt
https://dl.plext.com/<version>/checksums.txt.sig
https://dl.plext.com/<version>/checksums.txt.cert
```

Verify with:

```sh
cosign verify-blob \
  --certificate-identity-regexp 'https://github.com/gpalrepo/plext-cli/.*' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com' \
  --certificate checksums.txt.cert \
  --signature  checksums.txt.sig \
  checksums.txt
```

## Uninstall

### macOS / Linux

```sh
rm -rf ~/.plext
# then remove the PATH line from your ~/.zshrc, ~/.bashrc, or ~/.profile
```

### Windows

```powershell
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\Plext"
# then remove the entry from User PATH via System Properties → Environment Variables
```

## Privacy

Plext includes **opt-in** anonymous usage telemetry. It is disabled by default and prompts on first run. See [PRIVACY.md](./PRIVACY.md) for the full policy.

## License

The install scripts in this repo are MIT-licensed. The Plext CLI binaries are distributed under the terms in the binaries themselves; the source is not public.
