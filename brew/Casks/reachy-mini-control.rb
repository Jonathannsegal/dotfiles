cask "reachy-mini-control" do
  version "0.9.34"
  sha256 "f8476211f7a6b362b433d4b407c9f23423f6f86934b7658d902cf72725141f32"

  url "https://github.com/pollen-robotics/reachy-mini-desktop-app/releases/download/v#{version}/Reachy.Mini.Control_#{version}_arm64.dmg"
  name "Reachy Mini Control"
  desc "Desktop controller and application manager for Reachy Mini"
  homepage "https://pollen-robotics.com/reachy-mini/download/"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on arch: :arm64
  # The app supports 10.15+, older than Homebrew's supported macOS versions.

  app "Reachy Mini Control.app"
end
