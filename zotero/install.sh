#!/usr/bin/env bash

ZOTERO_BUILD_DIR="$HOME/zotero-build"
EXTENSIONS=(
    "https://github.com/retorquere/zotero-better-bibtex"
    "https://github.com/jlegewie/zotfile"
)

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command -v node >/dev/null 2>&1; then
        missing_deps+=("node")
    fi
    
    if ! command -v npm >/dev/null 2>&1; then
        missing_deps+=("npm")
    fi
    
    if ! command -v python3 >/dev/null 2>&1; then
        missing_deps+=("python3")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        fail "Missing required dependencies: ${missing_deps[*]}"
        return 1
    fi
    
    success "All required dependencies are installed"
    return 0
}

# Main setup function
setup_zotero_standalone() {
    # Check dependencies first
    check_dependencies || return 1

    # Create build directory with proper permissions
    info "Creating build directory..."
    mkdir -p "$ZOTERO_BUILD_DIR"
    chmod 755 "$ZOTERO_BUILD_DIR"

    # Clone Zotero standalone build if needed
    info "Cloning Zotero standalone build..."
    if [ ! -d "$ZOTERO_BUILD_DIR/zotero-standalone-build" ]; then
        pushd "$ZOTERO_BUILD_DIR" > /dev/null
        git clone --recursive https://github.com/zotero/zotero-standalone-build
        popd > /dev/null
    fi
    
    # Ensure proper permissions
    chmod -R 755 "$ZOTERO_BUILD_DIR/zotero-standalone-build"

    # Create directory for extensions
    mkdir -p "$ZOTERO_BUILD_DIR/zotero-standalone-build/modules"
    chmod 755 "$ZOTERO_BUILD_DIR/zotero-standalone-build/modules"

    # Clone and build extensions
    for extension in "${EXTENSIONS[@]}"; do
        ext_name=$(basename "$extension")
        info "Processing extension: $ext_name"
        
        pushd "$ZOTERO_BUILD_DIR" > /dev/null
        
        if [ ! -d "$ext_name" ]; then
            git clone "$extension"
            if [ $? -ne 0 ]; then
                fail "Failed to clone $extension"
                popd > /dev/null
                continue
            fi
        fi
        
        if [ -d "$ext_name" ]; then
            chmod -R 755 "$ext_name"
            cp -r "$ext_name" "zotero-standalone-build/modules/"
            success "Copied $ext_name to modules directory"
        fi
        
        popd > /dev/null
    done

    # Build Zotero
    info "Building Zotero..."
    pushd "$ZOTERO_BUILD_DIR/zotero-standalone-build" > /dev/null

    # Create a local build configuration
    cat > config.sh << EOF
BUILDDIR="/tmp/zotero-build"
SOURCEDIR="$ZOTERO_BUILD_DIR/zotero-standalone-build"
EOF
    chmod +x config.sh
    
    # Run the build with proper arguments for Mac
    ./build.sh -p m || {
        fail "Build failed"
        popd > /dev/null
        return 1
    }

    # Check if build was successful
    if [ -d "staging" ]; then
        success "Zotero build completed successfully"
        
        # Start Zotero with cache purge based on platform
        if [ -f "staging/Zotero.app/Contents/MacOS/zotero" ]; then
            info "Starting Zotero..."
            ./staging/Zotero.app/Contents/MacOS/zotero -purgecaches
        fi
    else
        fail "Zotero build failed - staging directory not found"
        popd > /dev/null
        return 1
    fi
    
    popd > /dev/null
}

# Execute setup if sourced from setup.sh
setup_zotero_standalone