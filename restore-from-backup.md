# Restoring the cluster from the S3 backups

When restoring the cluster from the S3 backups you should follow the
README, like during the initial setup of the cluster, but skipping
some of the already done steps.

The rest of this document describes some of the problems that you may
encounter when trying to restore your cluster from the S3 backups.

## Exporting a password-protected SOPS key for FluxCD does not work

Because the README generates the cluster's SOPS PGP key with
`%no-protection`, exports it, and then adds passwords to the private
key. That order matters:

```bash
gpg --export-secret-keys --armor "${KEY_FP}" > "$GIT_INSTALL_DIR/secret-files/sops.asc"
```

When restoring the cluster from the S3 backups, the old cluster's SOPS
key (restored from your backup) will be **already
password-protected**, the above command still exports it, but
preserves its password protection. `--armor` changes only the
encoding. The resulting file is unsuitable for FluxCD's unattended
SOPS decryption and can cause errors such as `gpg: decryption failed:
Not a tty`.

The procedure described bellow removes the passwords from a temporary
copy; the key in your normal GnuPG keyring remains protected. The
fingerprint is unchanged, so existing SOPS files do not need to be
re-encrypted:

Run this from the **repository root**, with `GIT_INSTALL_DIR` and
`KEY_FP` set as in the README. For example, `GIT_INSTALL_DIR` is
`simple-git-server/dev`. The corresponding private key must already be
in your GnuPG keyring; import your password-protected backup first if
needed:

```bash
(
  set -eu
  : "${GIT_INSTALL_DIR:?Set GIT_INSTALL_DIR as described in the README}"
  : "${KEY_FP:?Set KEY_FP to the existing cluster key fingerprint}"
  umask 077
  export GPG_TTY=$(tty)

  SOPS_GPG_TMP=$(mktemp -d)
  trap 'gpgconf --homedir "$SOPS_GPG_TMP" --kill gpg-agent; rm -rf -- "$SOPS_GPG_TMP"' EXIT

  # Export and import a protected copy into an isolated keyring.
  gpg --armor --export-secret-keys "$KEY_FP" > "$SOPS_GPG_TMP/protected.asc"
  gpg --homedir "$SOPS_GPG_TMP" --import "$SOPS_GPG_TMP/protected.asc"

  # Interactively remove the passwords from this copy only.
  gpg --homedir "$SOPS_GPG_TMP" --passwd "$KEY_FP"

  # Replace sops.asc only after the export succeeds.
  gpg --homedir "$SOPS_GPG_TMP" --armor \
    --output "$SOPS_GPG_TMP/sops.asc" --export-secret-keys "$KEY_FP"
  mkdir -p "$GIT_INSTALL_DIR/secret-files"
  install -m 600 "$SOPS_GPG_TMP/sops.asc" "$GIT_INSTALL_DIR/secret-files/sops.asc"
)
```

When `gpg --passwd` prompts you, enter the existing password, then
leave the **new password empty** and confirm that you want no password
protection. Repeat for the primary key and subkey if prompted; the
README allows them to have different passwords. Do not cancel these
prompts.

The parentheses keep shell settings local to these commands. The
temporary keyring is removed automatically when the block exits. The
resulting `sops.asc` is unprotected and readable and writable only by
your user.
