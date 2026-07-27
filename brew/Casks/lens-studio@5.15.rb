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

  preflight do
    staged_app = staged_path/"Lens Studio.app"
    installed_app = Pathname("/Applications/Lens Studio.app")
    installed_plist = installed_app/"Contents/Info.plist"

    installed_version = if installed_plist.exist?
      system_command(
        "/usr/libexec/PlistBuddy",
        args: ["-c", "Print :CFBundleShortVersionString", installed_plist],
      ).stdout.strip
    end

    if installed_version&.start_with?("#{version}.")
      system_command "/bin/cp",
                     args: ["-cR", installed_app, staged_app]
      next
    end

    response_file = staged_path.children.find do |path|
      path.file? && path.read.start_with?("{")
    rescue ArgumentError
      false
    end
    raise "Lens Studio download API did not return JSON" if response_file.nil?

    download_url = JSON.parse(response_file.read).fetch("url")
    disk_image = staged_path/"Lens_Studio_#{version}_mac_arm64.dmg"
    mount_point = staged_path/"mount"
    mount_point.mkpath

    system_command "/usr/bin/curl",
                   args: [
                     "--fail",
                     "--location",
                     "--retry", "5",
                     download_url,
                     "--output", disk_image
                   ]
    system_command "/usr/bin/hdiutil",
                   args: [
                     "attach",
                     disk_image,
                     "-nobrowse",
                     "-readonly",
                     "-mountpoint", mount_point
                   ]
    begin
      source_app = mount_point/"Lens Studio.app"
      raise "Lens Studio.app was not found in the downloaded disk image" unless source_app.directory?

      system_command "/usr/bin/ditto",
                     args: [source_app, staged_app]
    ensure
      system_command "/usr/bin/hdiutil",
                     args: ["detach", mount_point, "-quiet"]
    end
  end
end
