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

# Folders to ignore absolutely
IGNORE_NAMES = {
    "com.apple", "ContextStore", "CloudKit", "Safari", "Siri", 
    "News", "Stocks", "Weather", "Maps", "Photos", "iCloud"
}

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

    for lib_dir in LIBRARY_SCAN_DIRS:
        if not os.path.exists(lib_dir): continue
            
        try:
            for item in os.listdir(lib_dir):
                if item.startswith('.'): continue
                if item in IGNORE_NAMES: continue
                
                full_path = os.path.join(lib_dir, item)
                if not os.path.isdir(full_path): continue
                
                name_lower = item.lower()
                
                # Exclusion Logic
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


def list_and_delete(items, title):
    if not items:
        return

    print(f"\n⚠️  {title} ({len(items)} found):")
    
    # Show top 10
    display_count = min(len(items), 10)
    for i in range(display_count):
        item = items[i]
        print(f"  [{i+1}]\t{item['path']} ({format_size(item['size'])}) - {item['info']}")
        
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
        path = item['path']
        try:
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
                print(f"  {label:<20}: {res}")
            except:
                print(f"  {label:<20}: (access denied)")

def main():
    if os.geteuid() != 0:
        print("⚠️  Warning: script running without sudo/root privileges.")
        print("    System-wide cleanup will be limited.")
        time.sleep(1)

    get_disk_usage_summary()

    apps_info = get_installed_apps_info()
    
    # 1. Unused Apps
    unused = find_unused_apps(apps)
    list_and_delete(unused, "Unused Applications (Verified via LastUsedDate)")
    
    # 2. Leftovers
    leftovers = find_leftover_files(apps)
    list_and_delete(leftovers, "Potential Leftover App Data in Library")
    
    # 3. Large Files
    large = find_large_files()
    list_and_delete(large, "Large Files")
    
    print("\nDone. Consider empty Trash manually.")

if __name__ == "__main__":
    main()
