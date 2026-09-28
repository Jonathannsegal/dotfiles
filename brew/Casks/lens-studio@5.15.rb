cask "lens-studio@5.15" do
  version "5.15.4"
  sha256 :no_check

  url "https://ar-web-api.snapchat.com/api/ls-download/",
      using: :post,
      data:  {
        "eula"     => "true",
        "platform" => "MAC_OS_ARM",
        "version"  => version.to_s,
      }
  name "Lens Studio"
  desc "AR development platform pinned for Spectacles (2024)"
  homepage "https://ar.snap.com/spectacles"

  depends_on arch: :arm64
  depends_on macos: :monterey
  container type: :naked

  app "Lens Studio.app"

  # Snap returns short-lived signed URLs. Resolve a fresh URL at install time,
  # while keeping the Spectacles-compatible version pinned.
  preflight_steps do
    run "/bin/bash",
        args: ["-c", <<~'SHELL', "--", "{{staged_path}}", "{{appdir}}", "{{version}}"],
          set -euo pipefail
          stage="$1"
          apps="$2"
          version="$3"
          installed="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$apps/Lens Studio.app/Contents/Info.plist" 2>/dev/null || true)"
          if [[ "$installed" == "$version" || "$installed" == "$version".* ]]; then
            /bin/cp -cR "$apps/Lens Studio.app" "$stage/Lens Studio.app"
            exit 0
          fi
          /usr/bin/curl --fail --location --retry 5 \
            -H 'Content-Type: application/json' \
            --data "{\"eula\":true,\"platform\":\"MAC_OS_ARM\",\"version\":\"$version\"}" \
            https://ar-web-api.snapchat.com/api/ls-download/ -o "$stage/download.json"
          url="$(/usr/bin/plutil -extract url raw -o - "$stage/download.json")"
          [[ "$url" == https://* ]]
          /usr/bin/curl --fail --location --retry 5 "$url" -o "$stage/lens.dmg"
          /bin/mkdir -p "$stage/mount"
          /usr/bin/hdiutil attach "$stage/lens.dmg" -nobrowse -readonly -mountpoint "$stage/mount"
          trap '/usr/bin/hdiutil detach "$stage/mount" -quiet' EXIT
          /usr/bin/ditto "$stage/mount/Lens Studio.app" "$stage/Lens Studio.app"
        SHELL
        network_access: true
  end
end
