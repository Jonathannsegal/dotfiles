#!/usr/bin/env python3
"""Provision native profiles through the supported CLI, then install the local detector."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import zipfile

ROOT = Path(__file__).resolve().parent
HOME = Path.home()
USER = HOME / 'Library/Application Support/Code/User'
CLI = '/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code'
SPEC = json.loads((ROOT / 'profiles.json').read_text())
ENV = dict(os.environ, NODE_NO_WARNINGS='1')

def code(*args):
    subprocess.run([CLI, *args], check=True, env=ENV, timeout=180)

def profile_map():
    storage = json.loads((USER / 'globalStorage/storage.json').read_text())
    return {p['name']: p['location'] for p in storage.get('userDataProfiles', [])}

mapping = profile_map()
for name in SPEC['profiles']:
    if name not in mapping:
        code('--new-window', '--profile', name)
        for _ in range(30):
            time.sleep(0.2)
            mapping = profile_map()
            if name in mapping: break
        if name not in mapping: raise RuntimeError(f'Profile creation failed: {name}')

base = json.loads((ROOT / 'settings.json').read_text())
base['window.newWindowProfile'] = 'Lightweight'
base['search.followSymlinks'] = False
# Keep profile UI/settings reproducible from dotfiles; do not copy credentials or storage.
for name, spec in SPEC['profiles'].items():
    target = USER / 'profiles' / mapping[name] / 'settings.json'
    target.parent.mkdir(parents=True, exist_ok=True)
    settings = dict(base)
    settings.update(spec['settings'])
    target.write_text(json.dumps(settings, indent=2) + '\n')
    extensions = SPEC['common'] + spec['extensions']
    args = ['--profile', name]
    for extension in extensions: args += ['--install-extension', extension]
    code(*args)

# VSIX archive with no build dependencies or downloaded code.
package = json.loads((ROOT / 'auto-profiles/package.json').read_text())
identity = f"{package['publisher']}.{package['name']}"
with tempfile.TemporaryDirectory(prefix='dotfiles-profiles-') as temp:
    vsix = Path(temp) / 'dotfiles-profiles.vsix'
    with zipfile.ZipFile(vsix, 'w', zipfile.ZIP_DEFLATED) as z:
        z.writestr('[Content_Types].xml', '''<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="json" ContentType="application/json"/><Default Extension="js" ContentType="application/javascript"/><Default Extension="vsixmanifest" ContentType="text/xml"/></Types>''')
        z.writestr('extension.vsixmanifest', f'''<?xml version="1.0"?><PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011"><Metadata><Identity Language="en-US" Id="{package['name']}" Version="{package['version']}" Publisher="{package['publisher']}"/><DisplayName>{package['displayName']}</DisplayName><Description xml:space="preserve">{package['description']}</Description><Properties><Property Id="Microsoft.VisualStudio.Code.Engine" Value="^1.100.0"/></Properties></Metadata><Installation><InstallationTarget Id="Microsoft.VisualStudio.Code"/></Installation><Dependencies/><Assets><Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true"/></Assets></PackageManifest>''')
        for name in ['package.json', 'extension.js', 'detect.js']:
            z.write(ROOT / 'auto-profiles' / name, 'extension/' + name)
        z.writestr('extension/profile-map.json', json.dumps({n:mapping[n] for n in SPEC['profiles']}))
        z.writestr('extension/installed.json', json.dumps({'time': time.time() * 1000}))
    # Default stays available for legacy/specialized projects; every profile can detect new clones.
    code('--install-extension', str(vsix), '--force')
    for name in SPEC['profiles']:
        code('--profile', name, '--install-extension', str(vsix), '--force')
print('Profiles installed. Existing windows are left alone; detection applies on next open/reload.')
