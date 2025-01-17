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
killall Finder

###############################################################################
# Trackpad, Mouse, & Input                                                    #
###############################################################################

# Set blazingly fast key repeat
defaults write NSGlobalDomain KeyRepeat -int 6
defaults write NSGlobalDomain InitialKeyRepeat -int 25

# Disable press-and-hold for keys in favor of key repeat
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

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

# Save screenshots to Documents and set format to PNG
defaults write com.apple.screencapture location -string "${HOME}/Documents"
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

# Show the ~/Library folder
chflags nohidden ~/Library

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

# Remove all apps from Dock
defaults write com.apple.dock persistent-apps -array

# Add desired apps to Dock
defaults write com.apple.dock persistent-apps -array-add '<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>/Applications/Slack.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>'
defaults write com.apple.dock persistent-apps -array-add '<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>/Applications/iTerm.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>'
defaults write com.apple.dock persistent-apps -array-add '<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>/Applications/Visual Studio Code.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>'
defaults write com.apple.dock persistent-apps -array-add '<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>/Applications/Google Chrome.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>'
defaults write com.apple.dock persistent-apps -array-add '<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>/Applications/Notion.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>'
defaults write com.apple.dock persistent-apps -array-add '<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>/Applications/Unity Hub.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>'
defaults write com.apple.dock persistent-apps -array-add '<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>/Applications/Adobe Lightroom Classic/Adobe Lightroom Classic.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>'
defaults write com.apple.dock persistent-apps -array-add '<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>/Applications/Adobe Illustrator 2025/Adobe Illustrator.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>'

###############################################################################
# Menu Bar & Control Center                                                    #
###############################################################################

# Show Weather in menu bar
defaults write com.apple.controlcenter "NSStatusItem Visible Weather" -bool true
defaults write ~/Library/Preferences/ByHost/com.apple.controlcenter.plist Weather -int 18

# Hide Spotlight from menu bar (but keep it accessible via cmd+space)
defaults write com.apple.Spotlight "NSStatusItem Visible Item-0" -bool false

# Configure other menu bar items
defaults write com.apple.controlcenter "NSStatusItem Visible WiFi" -bool false
defaults write com.apple.controlcenter "NSStatusItem Visible Bluetooth" -bool false
defaults write com.apple.controlcenter "NSStatusItem Visible Sound" -bool false
defaults write com.apple.controlcenter "NSStatusItem Visible Battery" -bool false
defaults write com.apple.controlcenter "NSStatusItem Visible Clock" -bool true

# Show percentage in battery indicator
defaults write com.apple.menuextra.battery ShowPercent -bool false

# Set clock format to show date and 12-hour time
defaults write com.apple.menuextra.clock DateFormat -string "EEE MMM d  h:mm a"

# Control Center modules configuration
defaults write com.apple.controlcenter "NSStatusItem Preferred Position Battery" -float 100
defaults write com.apple.controlcenter "NSStatusItem Preferred Position Clock" -float 200

# Automatically hide and show the menu bar in full screen only
defaults write NSGlobalDomain _HIHideMenuBar -bool false
defaults write NSGlobalDomain AppleMenuBarVisibleInFullscreen -bool false

# Hide Time Machine and VPN icons if you're not actively using them
defaults write com.apple.systemuiserver "NSStatusItem Visible com.apple.menuextra.TimeMachine" -bool false
defaults write com.apple.systemuiserver "NSStatusItem Visible com.apple.menuextra.VPN" -bool false

# Remove unnecessary menu extras
defaults write com.apple.systemuiserver menuExtras -array \
  "/System/Library/CoreServices/Menu Extras/Clock.menu" \
  "/System/Library/CoreServices/Menu Extras/Battery.menu"

killall SystemUIServer
killall ControlCenter

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
killall Dock

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

for app in "Activity Monitor" "Dock" "Finder" "Photos" "Safari" "SystemUIServer" "Terminal"; do
    killall "${app}" &> /dev/null
done

echo "Done! Note that some of these changes require a logout/restart to take effect."