#!/usr/bin/env bash

# Close System Preferences to prevent overriding changes
osascript -e 'tell application "System Preferences" to quit'

# Ask for administrator password upfront
sudo -v

# Keep-alive: update existing `sudo` time stamp until script has finished
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Create Developer folder if it doesn't exist
if [ ! -d "${HOME}/Developer" ]; then
    mkdir "${HOME}/Developer"
    echo "Created Developer folder in home directory"
fi

###############################################################################
# General UI/UX & Performance                                                 #
###############################################################################
# Disable the sound effects on boot
sudo nvram SystemAudioVolume=" "

# Disable system sound effects
defaults write "com.apple.sound.uiaudio.enabled" -int 0
defaults write com.apple.systemsound "com.apple.sound.uiaudio.enabled" -bool false

# Disable volume change feedback sound
defaults write NSGlobalDomain com.apple.sound.beep.feedback -bool false

# Use list view in all Finder windows
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
defaults write com.apple.finder FXPreferredSearchViewStyle -string "Nlsv"
defaults write com.apple.finder SearchRecentsSavedViewStyle -string "Nlsv"
defaults write com.apple.finder FXPreferredSearchViewStyleVersion -string "%00%00%00%01"
defaults write com.apple.finder SearchRecentsSavedViewStyleVersion -string "%00%00%00%01"

# Expand save panel by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

# Save to disk (not to iCloud) by default
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

# Disable automatic capitalization, smart dashes, period substitution, and auto-correct
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Hide all desktop icons while keeping files in the Desktop folder
defaults write com.apple.finder CreateDesktop false

# Restart Finder to apply changes
killall Finder >/dev/null 2>&1 || true

###############################################################################
# Trackpad, Mouse, & Input                                                    #
###############################################################################

# Set blazingly fast key repeat
defaults write NSGlobalDomain KeyRepeat -int 6
defaults write NSGlobalDomain InitialKeyRepeat -int 25

# Disable press-and-hold for keys in favor of key repeat
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Trackpad behavior
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool false
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool false
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 0
defaults write com.apple.AppleMultitouchTrackpad TrackpadRightClick -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadCornerSecondaryClick -bool false
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadCornerSecondaryClick -bool false
defaults write NSGlobalDomain com.apple.trackpad.forceClick -bool true
defaults write com.apple.AppleMultitouchTrackpad ForceSuppressed -bool false
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad ForceSuppressed -bool false

###############################################################################
# Hot Corners                                                                 #
###############################################################################

# Disable all hot corners
# Possible values:
#  0: no-op
#  2: Mission Control
#  3: Show application windows
#  4: Desktop
#  5: Start screen saver
#  6: Disable screen saver
#  7: Dashboard
# 10: Put display to sleep
# 11: Launchpad
# 12: Notification Center
# 13: Lock Screen

# Top left corner
defaults write com.apple.dock wvous-tl-corner -int 0
defaults write com.apple.dock wvous-tl-modifier -int 0

# Top right corner
defaults write com.apple.dock wvous-tr-corner -int 0
defaults write com.apple.dock wvous-tr-modifier -int 0

# Bottom left corner
defaults write com.apple.dock wvous-bl-corner -int 0
defaults write com.apple.dock wvous-bl-modifier -int 0

# Bottom right corner
defaults write com.apple.dock wvous-br-corner -int 0
defaults write com.apple.dock wvous-br-modifier -int 0

###############################################################################
# Energy & Power Management                                                   #
###############################################################################

# Enable lid wakeup
sudo pmset -a lidwake 1

# Set display sleep to 5 minutes
sudo pmset -a displaysleep 5

# Set system sleep to 20 minutes (must be significantly higher than display sleep)
sudo pmset -a sleep 20

# Disable system sleep separately for power adapter and battery
sudo pmset -c sleep 0
sudo pmset -b sleep 0

# System sleep settings
sudo pmset -a standby 1
sudo pmset -a womp 1

###############################################################################
# Screen & Security                                                           #
###############################################################################

# Set screen saver to start after 3 minutes of inactivity
defaults -currentHost write com.apple.screensaver idleTime -int 180

# Require password after screen saver begins or display sleep
defaults write com.apple.screensaver askForPassword -int 1

# Set the delay before password is required (5 minutes = 300 seconds)
defaults write com.apple.screensaver askForPasswordDelay -int 300

# Save screenshots to Downloads and set format to PNG
defaults write com.apple.screencapture location -string "${HOME}/Downloads"
defaults write com.apple.screencapture type -string "png"

###############################################################################
# Finder Improvements                                                         #
###############################################################################

# Show path bar and status bar
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true

# Show file extensions and hidden files
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder AppleShowAllFiles -bool true

# Keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# Avoid creating .DS_Store files on network or USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Use list view in all Finder windows
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
defaults write com.apple.finder FXPreferredSearchViewStyle -string "Nlsv"
defaults write com.apple.finder SearchRecentsSavedViewStyle -string "Nlsv"
defaults write com.apple.finder FXPreferredSearchViewStyleVersion -string "%00%00%00%01"
defaults write com.apple.finder SearchRecentsSavedViewStyleVersion -string "%00%00%00%01"

# Open folders in tabs instead of new windows and use the current Finder target.
defaults write com.apple.finder FinderSpawnTab -bool true
defaults write com.apple.finder NewWindowTarget -string "PfAF"

# Show the ~/Library folder
chflags nohidden ~/Library

# Finder sidebar layout
defaults write com.apple.finder ShowRecentTags -bool true
defaults write com.apple.finder SidebarWidth -int 132
defaults write com.apple.finder SidebarWidth2 -int 160
defaults write com.apple.finder SidebarDevicesSectionDisclosedState -bool true
defaults write com.apple.finder SidebarMediaBrowserSectionDisclosedState -bool true
defaults write com.apple.finder SidebarPlacesSectionDisclosedState -bool true
defaults write com.apple.finder SidebariCloudDriveSectionDisclosedState -bool false
defaults write com.apple.finder SidebarShowingSignedIntoiCloud -bool true
defaults write com.apple.finder SidebarShowingiCloudDesktop -bool false

###############################################################################
# Dock & Mission Control                                                      #
###############################################################################

# Set Dock position to right side
defaults write com.apple.dock orientation -string right

# Set the icon size of Dock items
defaults write com.apple.dock tilesize -int 26

# Minimize windows into their application's icon
defaults write com.apple.dock minimize-to-application -bool true

# Speed up Mission Control animations
defaults write com.apple.dock expose-animation-duration -float 0.1

# Don't automatically rearrange Spaces based on most recent use
defaults write com.apple.dock mru-spaces -bool false

# Auto-hide the Dock
defaults write com.apple.dock autohide -bool false

# Make Dock icons of hidden applications translucent
defaults write com.apple.dock showhidden -bool true

# Don't show recent applications in Dock
defaults write com.apple.dock show-recents -bool false

# Disable Dock size modification
defaults write com.apple.dock size-immutable -bool true

# Lock the Dock size
defaults write com.apple.dock mouse-over-hilite-stack -bool false

# Disable magnification
defaults write com.apple.dock magnification -bool false

###############################################################################
# Dock Applications                                                           #
###############################################################################

# Add desired apps to Dock from the repo-managed list.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/apply-dock.sh"

###############################################################################
# Menu Bar & Control Center                                                    #
###############################################################################

# Show Weather in menu bar
defaults write com.apple.controlcenter "NSStatusItem Visible Weather" -bool true
defaults write ~/Library/Preferences/ByHost/com.apple.controlcenter.plist Weather -int 18

# Hide Spotlight from menu bar (but keep it accessible via cmd+space)
defaults write com.apple.Spotlight "NSStatusItem Visible Item-0" -bool false

# Configure menu bar items to match this machine.
defaults write com.apple.controlcenter "NSStatusItem Visible WiFi" -bool false
defaults write com.apple.controlcenter "NSStatusItem Visible Bluetooth" -bool false
defaults write com.apple.controlcenter "NSStatusItem Visible Sound" -bool false
defaults write com.apple.controlcenter "NSStatusItem Visible Battery" -bool false
defaults write com.apple.controlcenter "NSStatusItem Visible AccessibilityShortcuts" -bool false
defaults write com.apple.controlcenter "NSStatusItem Visible BentoBox" -bool true
defaults write com.apple.controlcenter "NSStatusItem Visible MusicRecognition" -bool false
defaults write com.apple.controlcenter "NSStatusItem Visible Item-0" -bool false
defaults write com.apple.controlcenter "NSStatusItem Visible Item-1" -bool false
defaults write com.apple.controlcenter "NSStatusItem Visible Item-2" -bool false
defaults write com.apple.controlcenter "NSStatusItem Visible Item-3" -bool false
defaults write com.apple.controlcenter "NSStatusItem Visible Item-4" -bool false
defaults write com.apple.controlcenter "NSStatusItem Visible Item-5" -bool false
defaults write com.apple.controlcenter "NSStatusItem Visible Item-6" -bool false
defaults write com.apple.controlcenter "NSStatusItem Visible Item-7" -bool false
defaults write com.apple.controlcenter "NSStatusItem Visible Item-8" -bool false
defaults write com.apple.controlcenter "NSStatusItem VisibleCC Battery" -bool true
defaults write com.apple.controlcenter "NSStatusItem VisibleCC Clock" -bool true
defaults write com.apple.controlcenter "NSStatusItem VisibleCC BentoBox-0" -bool true

# Show percentage in battery indicator
defaults write com.apple.menuextra.battery ShowPercent -bool false

# Set clock format to show date and 12-hour time
defaults write com.apple.menuextra.clock DateFormat -string "EEE MMM d  h:mm a"
defaults write com.apple.menuextra.clock FlashDateSeparators -bool false
defaults write com.apple.menuextra.clock IsAnalog -bool false
defaults write com.apple.menuextra.clock Show24Hour -bool true
defaults write com.apple.menuextra.clock ShowAMPM -bool false
defaults write com.apple.menuextra.clock ShowDate -bool false
defaults write com.apple.menuextra.clock ShowDayOfWeek -bool false
defaults write com.apple.menuextra.clock ShowSeconds -bool false
defaults write com.apple.menuextra.clock TimeAnnouncementsEnabled -bool false
defaults write com.apple.menuextra.clock TimeAnnouncementsIntervalIdentifier -string EveryHourInterval

# Control Center modules configuration
defaults write com.apple.controlcenter "NSStatusItem Preferred Position BentoBox-0" -float 105
defaults write com.apple.controlcenter "NSStatusItem Preferred Position BentoBox" -float 127
defaults write com.apple.controlcenter "NSStatusItem Preferred Position Battery" -float 195
defaults write com.apple.controlcenter "NSStatusItem Preferred Position Clock" -float 200
defaults write com.apple.controlcenter "NSStatusItem Preferred Position AccessibilityShortcuts" -float 211
defaults write com.apple.controlcenter "NSStatusItem Preferred Position WiFi" -float 331

# Automatically switch between light and dark appearances.
defaults write NSGlobalDomain AppleInterfaceStyle -string "Dark"
defaults write NSGlobalDomain AppleInterfaceStyleSwitchesAutomatically -bool true

# Automatically hide and show the menu bar in full screen only
defaults write NSGlobalDomain _HIHideMenuBar -bool false
defaults write NSGlobalDomain AppleMenuBarVisibleInFullscreen -bool false

# Hide Time Machine and VPN icons if you're not actively using them
defaults write com.apple.systemuiserver "NSStatusItem Visible com.apple.menuextra.TimeMachine" -bool false
defaults write com.apple.systemuiserver "NSStatusItem Visible com.apple.menuextra.VPN" -bool false

# Remove legacy SystemUIServer menu extras; Control Center owns the visible items.
defaults write com.apple.systemuiserver menuExtras -array

killall SystemUIServer >/dev/null 2>&1 || true
killall ControlCenter >/dev/null 2>&1 || true

###############################################################################
# Safari                                                                       #
###############################################################################

# Make Safari the default browser for web links and HTML documents.
if command -v duti >/dev/null 2>&1; then
  set_default_handler() {
    local role="$1"
    local identifier="$2"

    if ! duti -s com.apple.Safari "$identifier" "$role" >/dev/null 2>&1; then
      echo "warning: could not set Safari as handler for ${identifier}; continuing"
    fi
  }

  set_default_handler all http
  set_default_handler all https
  set_default_handler all public.html
  set_default_handler all public.xhtml
fi

# Keep browser downloads in the same inbox as screenshots and temporary files.
defaults write com.apple.Safari DownloadsPath -string "${HOME}/Downloads"
defaults write com.apple.Safari.SandboxBroker DidMigrateDownloadFolderToSandbox -bool true
defaults write com.apple.Safari.SandboxBroker DidMigrateDownloadMetadataToSandboxGroupContainer -bool true

# Chrome-like browsing ergonomics.
defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true
defaults write com.apple.Safari AutoOpenSafeDownloads -bool false
defaults write com.apple.Safari AlwaysRestoreSessionAtLaunch -bool true
defaults write com.apple.Safari ShowFavoritesBar -bool true
defaults write com.apple.Safari ShowSidebarInNewWindows -bool false
defaults write com.apple.Safari ShowSidebarInNewTabs -bool false
defaults write com.apple.Safari UniversalSearchEnabled -bool true
defaults write com.apple.Safari SuppressSearchSuggestions -bool false

# Developer tools, matching the existing local Safari setup.
defaults write com.apple.Safari ShowDevelopMenu -bool true
defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true
defaults write NSGlobalDomain WebKitDeveloperExtras -bool true

killall Safari >/dev/null 2>&1 || true

###############################################################################
# Launchpad                                                                   #
###############################################################################

# Set the number of columns in Launchpad
defaults write com.apple.dock springboard-columns -int 8

# Set the number of rows in Launchpad
defaults write com.apple.dock springboard-rows -int 7

# Enable automatic alphabetical ordering
defaults write com.apple.dock ResetLaunchPadOptions -bool true
defaults write com.apple.dock springboard-sort-alphabetically -bool true

# Reset Launchpad layout
defaults write com.apple.dock ResetLaunchPad -bool true

# Make icons smaller/larger (0.8 is smaller, 1.0 is default)
defaults write com.apple.dock springboard-item-size -float 0.8

# Make the Launchpad minimize motion
defaults write com.apple.dock springboard-minimize-motion -bool true

# Reset Dock for changes to take effect
killall Dock >/dev/null 2>&1 || true

###############################################################################
# Terminal                                                                    #
###############################################################################

# Only use UTF-8 in Terminal.app
defaults write com.apple.terminal StringEncodings -array 4

# Enable Secure Keyboard Entry in Terminal.app
defaults write com.apple.terminal SecureKeyboardEntry -bool true

# Don't display the annoying prompt when quitting iTerm
defaults write com.googlecode.iterm2 PromptOnQuit -bool false

# Turn off automatic brightness adjustments
defaults write /Library/Preferences/com.apple.iokit.AmbientLightSensor "Automatic Display Enabled" -bool false

###############################################################################
# Activity Monitor                                                            #
###############################################################################

# Show all processes in Activity Monitor
defaults write com.apple.ActivityMonitor ShowCategory -int 0

# Sort Activity Monitor results by CPU usage
defaults write com.apple.ActivityMonitor SortColumn -string "CPUUsage"
defaults write com.apple.ActivityMonitor SortDirection -int 0

###############################################################################
# Mac App Store                                                               #
###############################################################################

# Enable the automatic update check
defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true
defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1

# Download newly available updates in background
defaults write com.apple.SoftwareUpdate AutomaticDownload -int 1

# Install System data files & security updates
defaults write com.apple.SoftwareUpdate CriticalUpdateInstall -int 1

###############################################################################
# Photos                                                                      #
###############################################################################

# Prevent Photos from opening automatically when devices are plugged in
defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true

###############################################################################
# Kill affected applications                                                  #
###############################################################################

# Do not kill Terminal here; this script is commonly run from Terminal.
for app in "Activity Monitor" "Dock" "Finder" "Photos" "Safari" "SystemUIServer"; do
    killall "${app}" >/dev/null 2>&1 || true
done

echo "Done! Open a new Terminal tab/window for Terminal profile changes; some settings require logout/restart."
