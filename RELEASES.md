# Signed APK releases

Every push to `main` builds and verifies a signed release APK, creates a unique
`v1.0.<workflow run number>` tag at that exact commit, and publishes a GitHub
Release containing the APK, its SHA-256 checksum, and the public signing certificate details.
A manual run is also available on `main`. Rerunning a published run does not replace its APK.

Version codes start at 1001 and increase with the workflow run number.
Actions are pinned to full commit hashes. Signing passwords are supplied only to the
signing steps, and the temporary key is removed even if the build fails.
The workflow does not run on pull requests.

## Repository Actions secrets

- `ANDROID_KEYSTORE_BASE64`: base64-encoded release JKS keystore
- `ANDROID_KEYSTORE_PASSWORD`: keystore password
- `ANDROID_KEY_ALIAS`: signing-key alias
- `ANDROID_KEY_PASSWORD`: signing-key password

Reuse this release key for all updates. Never commit keys or passwords.
Local signing materials are kept in the ignored `.signing/` directory. Back up the
keystore and `credentials.dpapi` securely. The credential backup is encrypted with
Windows DPAPI and can only be decrypted by this Windows user profile.
`tools/release-signing.ps1` can reuse the key to build or upload the secrets without
printing their values.

The existing development APK uses a debug certificate. Users must remove that
debug installation before installing a release-signed APK with the same package name.
That first transition resets the watch face's saved customization. Subsequent
release-signed APKs can update one another normally.

## Local signed build

Supply the four signing environment variables (`ANDROID_KEYSTORE_PATH` replaces
the base64 secret locally), then run:

```sh
./gradlew --no-configuration-cache :watchface:assembleRelease \
  -PreleaseVersionCode=1001 -PreleaseVersionName=1.0.1
```

The watch requires Android 16 / API 36 or newer.
