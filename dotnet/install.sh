#!/bin/bash

# Check if running on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    # Install .NET SDK via Homebrew
    brew install dotnet
else
    # For Linux, follow Microsoft's repository setup and installation
    # Add Microsoft package signing key and repository
    wget https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
    sudo dpkg -i packages-microsoft-prod.deb
    rm packages-microsoft-prod.deb
    
    # Install .NET SDK
    sudo apt-get update
    sudo apt-get install -y dotnet-sdk
fi

# Create .NET directories if they don't exist
mkdir -p "$HOME/.dotnet"
mkdir -p "$HOME/.dotnet/tools"

# Verify installation
dotnet --version