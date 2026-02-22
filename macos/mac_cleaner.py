#!/usr/bin/env python3

import os
import sys
import shutil
import time
import subprocess
import plistlib
import re
from pathlib import Path
from difflib import SequenceMatcher

# Constants
LARGE_FILE_THRESHOLD_BYTES = 500 * 1024 * 1024  # 500 MB
UNUSED_APP_THRESHOLD_SECONDS = 6 * 30 * 24 * 60 * 60  # ~6 months

# Locations to scan for leftovers
LIBRARY_SCAN_DIRS = [
    Path.home() / "Library/Application Support",
    Path.home() / "Library/Caches",
    Path.home() / "Library/Preferences",
    Path.home() / "Library/Containers",
    Path.home() / "Library/Saved Application State",
    Path.home() / "Library/WebKit",
    Path("/Library/Application Support"),
    Path("/Library/Caches"),
]

# Folders to ignore absolutely (System / Apple)
IGNORE_NAMES = {
    "com.apple", "ContextStore", "CloudKit", "Safari", "Siri", 
    "News", "Stocks", "Weather", "Maps", "Photos", "iCloud",
    "Caches", "Cookies", "Logs"
}

def check_command_exists(cmd):
    """Check if a command-line tool exists."""
    return shutil.which(cmd) is not None

def format_size(size_bytes):
    """Format bytes to human readable string."""
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if size_bytes < 1024:
            return f"{size_bytes:.1f} {unit}"
        size_bytes /= 1024
    return f"{size_bytes:.1f} PB"

def get_directory_size(path):
    """Get directory size using du for speed."""
    if os.path.isfile(path):
        return os.path.getsize(path)
    try:
        # -sk returns size in KB
        res = subprocess.check_output(['du', '-sk', str(path)], stderr=subprocess.DEVNULL)
        return int(res.split()[0]) * 1024
    except Exception:
        return 0

def get_installed_apps_info():
    """
    Returns a dictionary of installed apps.
    Key: App Name (lowercase)
    Value: { 'path': str, 'bundle_id': str (lowercase), 'name': str }
    """
    apps = {}
    app_dirs = [
        "/Applications", 
        str(Path.home() / "Applications"),
        "/System/Applications"
    ]
    
    print("🔍 Indexing installed applications...")
    for d in app_dirs:
        if os.path.exists(d):
            try:
                for item in os.listdir(d):
                    if item.endswith(".app"):
                        app_path = os.path.join(d, item)
                        app_name = item.replace(".app", "")
                        app_name_lower = app_name.lower()
                        bundle_id = ""
                        
                        plist_path = os.path.join(app_path, "Contents", "Info.plist")
                        if os.path.exists(plist_path):
                            try:
                                with open(plist_path, 'rb') as fp:
                                    pl = plistlib.load(fp)
                                    if isinstance(pl, dict):
                                        bundle_id = pl.get("CFBundleIdentifier", "")
                            except Exception:
                                pass
                        
                        apps[app_name_lower] = {
                            'path': app_path,
                            'bundle_id': bundle_id.lower(),
                            'name': app_name
                        }
            except PermissionError:
                pass
    return apps

def get_last_used_date(app_path):
    """Gets the last used date of an application using mdls."""
    try:
        if not os.path.exists(app_path): return 0
        cmd = ["mdls", "-name", "kMDItemLastUsedDate", "-raw", app_path]
        result = subprocess.check_output(cmd, stderr=subprocess.DEVNULL)
        res_str = result.decode('utf-8').strip()
        
        if res_str and res_str != "(null)":
            # kMDItemLastUsedDate format: 2023-10-27 10:00:00 +0000
            # Simple parsing
            date_part = res_str.split(" +")[0]
            struct_time = time.strptime(date_part, "%Y-%m-%d %H:%M:%S")
            return time.mktime(struct_time)
    except:
        pass
    
    # Fallback to Access Time
    try:
        return os.path.getatime(app_path)
    except:
        return 0

def find_unused_apps(installed_apps_info):
    """Finds applications not used in a long time."""
    unused = []
    now = time.time()
    
    # System apps are usually always "used" conceptually or shouldn't be touched
    # Filter by path starting with /System to skip system apps
    
    for app_info in installed_apps_info.values():
        path = app_info['path']
        if path.startswith("/System"): continue
        
        last_used = get_last_used_date(path)
        
        if last_used > 0 and (now - last_used) > UNUSED_APP_THRESHOLD_SECONDS:
            size = get_directory_size(path)
            last_used_date = time.strftime('%Y-%m-%d', time.localtime(last_used))
            unused.append({
                'path': path,
                'name': app_info['name'],
                'size': size,
                'info': f"Last used: {last_used_date}"
            })
            
    return sorted(unused, key=lambda x: x['size'], reverse=True)

def find_leftover_files(installed_apps_info):
    """
    Scans Library folders for directories that do NOT match installed apps.
    """
    print("\n🔍 Scanning for leftover app data...")
    leftovers = []
    
    installed_ids = set()
    installed_names = set()
    
    for info in installed_apps_info.values():
        if info['bundle_id']: installed_ids.add(info['bundle_id'])
        installed_names.add(info['name'].lower())
        # Also add sanitized name (no spaces)
        installed_names.add(info['name'].lower().replace(" ", ""))


    # Common development tools/commands to check for if folder matches
    CLI_TOOLS_TO_CHECK = {"node", "npm", "pnpm", "yarn", "python", "pip", "git", "docker", "cargo", "go", "code", "nvm"}

    for lib_dir in LIBRARY_SCAN_DIRS:
        if not os.path.exists(lib_dir): continue
            
        try:
            for item in os.listdir(lib_dir):
                if item.startswith('.'): continue
                if item in IGNORE_NAMES: continue
                
                # Check 0: Can we find this command in PATH?
                if item.lower() in CLI_TOOLS_TO_CHECK:
                    if shutil.which(item.lower()):
                        continue 

                full_path = os.path.join(lib_dir, item)
                if not os.path.isdir(full_path): continue
                
                name_lower = item.lower()
                
                # Check 1: Vendor Specific / Heuristic Checks
                # If ANY "adobe" string in installed apps, keep "Adobe" folder
                # (Simple containment check across all installed names)
                is_vendor_safe = False
                
                if "adobe" in name_lower:
                    if any("adobe" in n for n in installed_names): is_vendor_safe = True
                elif "steam" in name_lower or "valve" in name_lower:
                    if any("steam" in n for n in installed_names): is_vendor_safe = True
                elif "unity" in name_lower:
                    if any("unity" in n for n in installed_names): is_vendor_safe = True
                    # Check common manual install paths for Unity
                    if os.path.exists("/Applications/Unity Hub.app"): is_vendor_safe = True
                elif "blackmagic" in name_lower or "davinci" in name_lower:
                    if any("blackmagic" in n or "davinci" in n for n in installed_names): is_vendor_safe = True
                elif "microsoft" in name_lower: 
                     # Check commonly installed Office apps individually if "Microsoft" folder found
                     if any("microsoft" in n or "office" in n or "word" in n or "excel" in n for n in installed_names): is_vendor_safe = True
                elif "google" in name_lower:
                     if any("google" in n or "chrome" in n for n in installed_names): is_vendor_safe = True
                
                if is_vendor_safe: continue

                # Normal Exclusion Logic
                is_known = False
                
                # Check 1: Bundle ID match
                # If folder looks like "com.google.Chrome"
                if "." in name_lower:
                    # Check if exact match
                    if name_lower in installed_ids:
                        is_known = True
                    else:
                        # Check partial group match (e.g. com.adobe.*)
                        # This is risky. "com.adobe.reader" folder vs "com.adobe.photoshop" app?
                        # If ANY app has this prefix? No, too loose.
                        pass
                
                # Check 2: Name match
                if not is_known:
                    if name_lower in installed_names:
                        is_known = True
                    else:
                        # Check "Adobe" vs "Adobe Photoshop"
                        # If folder name is a prefix of an installed app name?
                        # e.g. "Microsoft" folder, "Microsoft Word" app installed -> Keep
                        for app_name in installed_names:
                            if name_lower in app_name: # Folder "zoom" in App "zoom.us"
                                is_known = True; break
                            if app_name in name_lower: # App "Slack" in Folder "Slack"
                                is_known = True; break
                
                if not is_known:
                    # Heuristic: verify against system prefixes again to be safe
                    if name_lower.startswith("com.apple."): continue
                    
                    size = get_directory_size(full_path)
                    if size > 10 * 1024 * 1024:  # Only suggest significant leftovers (>10MB)
                        leftovers.append({
                            'path': full_path,
                            'name': item,
                            'size': size,
                            'info': "No matching app found"
                        })
                        
        except PermissionError:
            pass
            
    return sorted(leftovers, key=lambda x: x['size'], reverse=True)


def find_large_files():
    """Finds large files using mdfind (Spotlight) for speed."""
    print(f"\n🔍 Scanning for large files (> {format_size(LARGE_FILE_THRESHOLD_BYTES)})...")
    large_files = []
    
    # mdfind "kMDItemFSSize > 500000000"
    cmd = ["mdfind", f"kMDItemFSSize > {LARGE_FILE_THRESHOLD_BYTES}"]
    try:
        output = subprocess.check_output(cmd, text=True)
        paths = output.strip().split('\n')
        
        for p in paths:
            if not p: continue
            if not os.path.exists(p): continue
            
            # Filter out system paths usually not touchable
            if p.startswith("/System") or "/Library/Containers/com.docker" in p: 
                # Docker containers are huge files, handled by Docker cleanups usually
                continue 

            # Filter out Cloud Storage placeholders (Box, Dropbox, OneDrive, Drive, iCloud)
            # If the file is in CloudStorage, check if it's downloaded.
            # On macOS APFS, sparse files or dataless files have fewer blocks allocated than size implies.
            is_cloud_placeholder = False
            if "Library/CloudStorage" in p or "Library/Mobile Documents" in p or ".tmp.driveupload" in p:
                try:
                    stats = os.stat(p)
                    # st_blocks is number of 512-byte blocks. 
                    physical_size = stats.st_blocks * 512
                    logical_size = stats.st_size
                    # If physical size is significantly smaller (< 50%) than logical size, it's likely not fully downloaded
                    if logical_size > 0 and physical_size < (logical_size * 0.5):
                        is_cloud_placeholder = True
                except:
                    pass
            
            if is_cloud_placeholder:
                continue
                
            try:
                size = os.path.getsize(p)
                large_files.append({
                    'path': p,
                    'name': os.path.basename(p),
                    'size': size,
                    'info': "Large file"
                })
            except:
                pass
    except subprocess.CalledProcessError:
        print("mdfind failed. Skipping Spotlight search.")
        
    return sorted(large_files, key=lambda x: x['size'], reverse=True)


def find_system_junk():
    """
    Finds common system junk locations that contribute to 'System Data'.
    Includes Caches, Logs, Xcode DerivedData, iOS Backups, etc.
    """
    print("\n🔍 Scanning for System Junk (Caches, Logs, Developer Data)...")
    junk_items = []

    # 1. Generic Cache/Log Locations
    # These are generally safe to delete, they will be regenerated.
    common_locations = [
        {"path": Path.home() / "Library/Caches", "name": "User Caches"},
        {"path": Path.home() / "Library/Logs", "name": "User Logs"},
        {"path": "/Library/Caches", "name": "System Caches"},
        {"path": "/Library/Logs", "name": "System Logs"},
    ]

    for loc in common_locations:
        p = loc["path"]
        if os.path.exists(p):
            try:
                size = get_directory_size(p)
                if size > 100 * 1024 * 1024: # > 100MB
                    junk_items.append({
                        'path': str(p),
                        'name': loc["name"],
                        'size': size,
                        'info': "Cache/Log files (Safe to clear, will regenerate)"
                    })
            except: pass

    # 2. Developer Specifics (Xcode, etc)
    xcode_derived = Path.home() / "Library/Developer/Xcode/DerivedData"
    if os.path.exists(xcode_derived):
        size = get_directory_size(xcode_derived)
        if size > 100 * 1024 * 1024:
            junk_items.append({
                'path': str(xcode_derived),
                'name': "Xcode Derived Data",
                'size': size,
                'info': "Build artifacts (Safe to delete, will rebuild)"
            })
            
    xcode_archives = Path.home() / "Library/Developer/Xcode/Archives"
    if os.path.exists(xcode_archives):
        size = get_directory_size(xcode_archives)
        if size > 500 * 1024 * 1024: # > 500MB
             junk_items.append({
                'path': str(xcode_archives),
                'name': "Xcode Archives",
                'size': size,
                'info': "Old App Builds (Delete old ones manually inside)"
            })
            
    # 3. iOS Backups
    ios_backups = Path.home() / "Library/Application Support/MobileSync/Backup"
    if os.path.exists(ios_backups):
        size = get_directory_size(ios_backups)
        if size > 1 * 1024 * 1024 * 1024: # > 1GB
             junk_items.append({
                'path': str(ios_backups),
                'name': "iOS Backups",
                'size': size,
                'info': "Old Device Backups (Check before deleting)"
            })

    # 4. Docker
    # Check if docker is running or substantial
    docker_containers = Path.home() / "Library/Containers/com.docker.docker"
    if os.path.exists(docker_containers):
         size = get_directory_size(docker_containers)
         if size > 2 * 1024 * 1024 * 1024: # > 2GB
             # We don't delete the folder, but we warn the user
             junk_items.append({
                'path': "(Manual Action Required)",
                'name': "Docker VM Disk",
                'size': size,
                'info': "Run 'docker system prune' or 'docker system prune -a'"
             })
             
    # 5. Adobe Media Cache (Common culprit for huge System Data)
    adobe_common = Path.home() / "Library/Application Support/Adobe/Common"
    if os.path.exists(adobe_common):
        # Scan subdirs specifically
        for subdir in ["Media Cache Files", "Media Cache", "Disk Cache"]:
            p = adobe_common / subdir
            if os.path.exists(p):
                size = get_directory_size(p)
                if size > 500 * 1024 * 1024:
                    junk_items.append({
                        'path': str(p),
                        'name': f"Adobe {subdir}",
                        'size': size,
                        'info': "Video editing cache. Safe to delete."
                    })

    # 6. Package Manager Caches (Homebrew, Yarn, npm, pip, pnpm)
    # Homebrew
    brew_cache = Path.home() / "Library/Caches/Homebrew"
    if os.path.exists(brew_cache):
         size = get_directory_size(brew_cache)
         if size > 1 * 1024 * 1024 * 1024:
             junk_items.append({
                 'path': "(Manual Action Required)",
                 'name': "Homebrew Cache",
                 'size': size,
                 'info': "Run 'brew cleanup -s' in terminal"
             })

    # pnpm / npm / yarn
    pkg_caches = [
        (Path.home() / "Library/Caches/pnpm", "pnpm store"),
        (Path.home() / ".npm/_cacache", "npm cache"),
        (Path.home() / "Library/Caches/Yarn", "Yarn cache"),
        (Path.home() / ".gradle/caches", "Gradle cache"),
        (Path.home() / ".m2/repository", "Maven repo"),
        (Path.home() / "Library/Caches/pip", "pip cache"),
    ]
    for p, label in pkg_caches:
        if os.path.exists(p):
            size = get_directory_size(p)
            if size > 1 * 1024 * 1024 * 1024:
                junk_items.append({
                    'path': str(p),
                    'name': label,
                    'size': size,
                    'info': "Dev package cache. Delete if you need space (will re-download)."
                })

    # 7. Time Machine Local Snapshots (Often the hidden 'System Data' giant)
    if os.geteuid() == 0:
        try:
            # Check roughly how many snapshots exist
            tm_out = subprocess.check_output(["tmutil", "listlocalsnapshots", "/"], stderr=subprocess.DEVNULL)
            snapshot_lines = tm_out.decode('utf-8').strip().split('\n')
            snapshot_count = len([l for l in snapshot_lines if "com.apple.TimeMachine" in l])
            
            if snapshot_count > 0:
                 # Give it a fake heavy size so it floats to top of list
                 junk_items.append({
                    'path': "(Manual Action Required)",
                    'name': f"Time Machine Snapshots ({snapshot_count} found)",
                    'size': 999999999999, # Fake entry to ensure visibility at top
                    'info': f"System Data often grows after deletion due to snapshots. Run 'tmutil deletelocalsnapshots /' manually."
                 })
        except:
            pass
            
    # 8. System Diagnostic Reports / Core Dumps
    sys_diag = Path("/Library/Logs/DiagnosticReports")
    if os.path.exists(sys_diag):
        size = get_directory_size(sys_diag)
        if size > 500 * 1024 * 1024:
            junk_items.append({
                'path': str(sys_diag),
                'name': "System Diagnostic Reports",
                'size': size,
                'info': "Crash reports. Safe to delete."
            })

    return sorted(junk_items, key=lambda x: x['size'], reverse=True)


def list_and_delete(items, title):
    if not items:
        return

    print(f"\n⚠️  {title} ({len(items)} found):")
    
    # Show top 10
    display_count = min(len(items), 15)
    for i in range(display_count):
        item = items[i]
        path_name = item.get('path', 'Unknown')
        name_only = item.get('name', '')
        info_txt = item.get('info', '')
        size_txt = format_size(item['size'])
        
        # Nicer formatting
        if path_name == "(Manual Action Required)":
             print(f"  [{i+1}]\t{name_only}: {path_name} ({size_txt}) - {info_txt}")
        else:
             print(f"  [{i+1}]\t{path_name} ({size_txt}) - {info_txt}")
        
    if len(items) > display_count:
        print(f"  ... and {len(items) - display_count} more (hidden).")

    print("\n---------------------------------------------------------")
    print("Options: [s]elect numbers to delete, [a]ll shown, [n]one")
    choice = input("Your choice: ").strip().lower()

    to_delete = []
    if choice == 'a':
        to_delete = items[:display_count]
    elif choice == 's':
        nums = input("Enter numbers (e.g. 1 3): ").split()
        for n in nums:
            try:
                idx = int(n) - 1
                if 0 <= idx < display_count:
                    to_delete.append(items[idx])
            except ValueError:
                pass
    
    if not to_delete:
        print("No actions taken.")
        return

    print(f"Deleting {len(to_delete)} items...")
    for item in to_delete:
        path = item.get('path', '')
        # Check for Manual Action flags
        if path == "(Manual Action Required)":
            print(f"  Skipped {item.get('name', 'item')} (Requires manual action)")
            continue
            
        try:
            if os.path.exists(path):
                if os.path.isdir(path):
                    shutil.rmtree(path)
                else:
                    os.remove(path)
                print(f"  Deleted: {path}")
        except Exception as e:
            print(f"  Error: {e}")

def get_disk_usage_summary():
    """Print disk usage for major categories."""
    print("\n📊 Disk Usage Summary:")
    
    # Simple df output for main volume
    try:
        df = subprocess.check_output("df -h /", shell=True).decode('utf-8').split('\n')[1]
        print(f"  Volume /: {df}")
    except:
        pass

    dirs_to_check = {
        "Applications": "/Applications",
        "User Applications": str(Path.home() / "Applications"),
        "Library": "/Library",
        "User Library": str(Path.home() / "Library"),
        "System": "/System",
        "Users": "/Users",
        "Home": str(Path.home())
    }
    
    for label, path in dirs_to_check.items():
        if os.path.exists(path):
            try:
                # du -sh is fast enough for top level
                res = subprocess.check_output(['du', '-sh', path], stderr=subprocess.DEVNULL).decode('utf-8').split()[0]
                # If du returns empty or weird output, skip
                if not res: continue
                print(f"  {label:<20}: {res}")
            except:
                # Permission denied or other error -> Skip silently
                pass

def suggest_snapshot_cleanup():
    """
    After deleting files, macOS often moves the data to 'System Data' (Local Snapshots).
    This function offers to clean them up to reclaim space immediately.
    """
    if os.geteuid() != 0:
        return

    print("\n---------------------------------------------------------")
    print("🧹 Post-Cleanup: Reclaim 'System Data' Space")
    print("Files you deleted may still be taking up space as Time Machine Local Snapshots.")
    print("Deleting these snapshots will free up space immediately but remove recent local history.")
    
    try:
        # Check count
        tm_out = subprocess.check_output(["tmutil", "listlocalsnapshots", "/"], stderr=subprocess.DEVNULL)
        lines = tm_out.decode('utf-8').strip().split('\n')
        snapshots = [l.strip() for l in lines if "com.apple.TimeMachine" in l]
        count = len(snapshots)
        
        if count == 0:
            print("✅ No local snapshots found. You are good.")
            return
            
        print(f"⚠️  Found {count} local Time Machine snapshots.")
        choice = input("Do you want to delete these snapshots to reclaim space? (y/n): ").strip().lower()
        
        if choice == 'y':
            print("Deleting snapshots (this may take a moment)...")
            count_deleted = 0
            for snap in snapshots:
                # Extract date part
                # com.apple.TimeMachine.2023-10-25-100000 -> 2023-10-25-100000
                if "com.apple.TimeMachine." in snap:
                    try:
                        date_str = snap.split("com.apple.TimeMachine.")[1]
                        print(f"  Deleting snapshot {date_str}...")
                        subprocess.run(["tmutil", "deletelocalsnapshots", date_str], stderr=subprocess.DEVNULL)
                        count_deleted += 1
                    except IndexError:
                        pass
            
            print(f"✅ {count_deleted} Snapshots cleared.")
        else:
             print("Skipped snapshot cleanup.")
            
    except Exception as e:
        print(f"Error checking snapshots: {e}")

def analyze_library_bloat():
    """
    Deep scan of ~/Library and /Library to find what is actually taking up space.
    This is often where 'System Data' lives.
    """
    print("\n---------------------------------------------------------")
    print("🕵️  Deep Scan: Analyzing 'System Data' locations...")
    
    # Locations to analyze (Where System Data Hides)
    scan_roots = [
        Path.home() / "Library",
        Path.home() / "Library/Application Support",
        Path.home() / "Library/Containers",
        Path.home() / "Library/Group Containers",
        Path.home() / "Library/Caches",
        Path.home() / "Library/Developer",
        Path("/Library"),
        Path("/Library/Application Support"),
        Path("/Users/Shared")
    ]
    
    bloat_items = []
    
    for root in scan_roots:
        if not os.path.exists(root): continue
        if not os.access(root, os.R_OK): continue
        
        try:
            # Check immediate children size
            for item in os.listdir(root):
                full_path = os.path.join(root, item)
                if not os.path.isdir(full_path): continue
                if item.startswith('.'): continue
                
                # Skip if size calculation fails (permission)
                try:
                    size = get_directory_size(full_path)
                    # Filter: Only show "Big" folders > 1GB
                    if size > 1 * 1024 * 1024 * 1024:
                        bloat_items.append({
                            'path': full_path,
                            'name': item,
                            'size': size,
                            'info': f"Large Folder in {os.path.basename(root)}"
                        })
                except:
                    pass
        except:
             pass
             
    # Sort by size descending
    bloat_items.sort(key=lambda x: x['size'], reverse=True)
    
    # Deduplication logic
    # If we have:
    # 1. ~/Library/Application Support (5GB)
    # 2. ~/Library/Application Support/Steam (4GB)
    # The parent (1) includes the child (2). 
    # We prefer seeing the specific child (2) if it explains most of the parent's size.
    # But seeing both confusingly implies 9GB total.
    
    # Simple Dedupe: Remove parent if child is present? 
    # Or just list top items and let user see.
    # Let's clean up by removing duplicates if path is exact same (not happening due to scan roots)
    # But if path A is inside path B, maybe flag it?
    
    final_list = []
    for i, item in enumerate(bloat_items):
        is_child = False
        # Check if this item is a parent of another item higher up? No, smaller children.
        # Check if this item is a child of another item in the list
        # If so, keep it, but maybe mark parent as "Contains..."
        final_list.append(item)
        
    # Take top 20 unique paths
    # Use a dictionary to avoid exact duplicates
    unique_paths = {}
    for item in final_list:
        if item['path'] not in unique_paths:
             unique_paths[item['path']] = item
             
    top_items = sorted(unique_paths.values(), key=lambda x: x['size'], reverse=True)[:20]
    
    if top_items:
        print(f"\n📦 Top 20 Largest 'System Data' Folders:")
        for i, item in enumerate(top_items):
            print(f"  [{i+1}] {item['path']} ({format_size(item['size'])})")
            
        print("\nNOTE: These folders are the biggest contributors to storage usage.")
        print("      Some are system critical, others are app data you might not need.")
        
        # Interactive delete option
        choice = input("\nDo you want to manage these folders? (y/n): ").strip().lower()
        if choice == 'y':
            list_and_delete(top_items, "Large System Data Folders (DELETE CAREFULLY)")
            
def main():
    if os.geteuid() != 0:
        print("⚠️  Warning: script running without sudo/root privileges.")
        print("    System-wide cleanup will be limited.")
        time.sleep(1)

    get_disk_usage_summary()

    apps = get_installed_apps_info()
    
    # 1. Unused Apps
    unused = find_unused_apps(apps)
    list_and_delete(unused, "Unused Applications (Verified via LastUsedDate)")
    
    # 2. Leftovers
    leftovers = find_leftover_files(apps)
    list_and_delete(leftovers, "Potential Leftover App Data in Library")
    
    # 3. Large Files
    large = find_large_files()
    list_and_delete(large, "Large Files")
    
    # 4. System Junk (Caches, Xcode, etc)
    junk = find_system_junk()
    list_and_delete(junk, "System Junk (Caches, Logs, Developer Data)")
    
    # 5. Snapshots
    suggest_snapshot_cleanup()
    
    # 6. Deep Analysis
    # analyze_library_bloat() # We replaced the old function with the logic inside main or called here
    # Since I overwrote the function definition, just calling it is fine.
    analyze_library_bloat()
    
    print("\nDone. Consider empty Trash manually.")

if __name__ == "__main__":
    main()
