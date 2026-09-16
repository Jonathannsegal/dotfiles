#!/usr/bin/env python3
"""Read-only health checks; terminal startup only reads the cached result."""
import argparse
import datetime as dt
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
HOME = Path.home()
STATE = HOME / 'Library/Caches/com.jsegal.dotfiles-health'
ENV = dict(os.environ, PATH='/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin', NODE_NO_WARNINGS='1')


def run(args, timeout=60):
    try:
        p = subprocess.run(args, capture_output=True, text=True, timeout=timeout, env=ENV)
        return p.returncode, p.stdout.strip(), p.stderr.strip()
    except (OSError, subprocess.TimeoutExpired) as e:
        return 127, '', str(e)


def save(name, data):
    STATE.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode='w', dir=STATE, delete=False) as f:
        json.dump(data, f, indent=2)
        temp = f.name
    os.replace(temp, STATE / name)


def read(name, default):
    try:
        return json.loads((STATE / name).read_text())
    except (OSError, ValueError):
        return default


def add(report, key, category, message):
    report['issues'].append(dict(id=key, category=category, message=message))


def collect():
    STATE.mkdir(parents=True, exist_ok=True)
    with (STATE / 'run.lock').open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return read('latest.json', {'issues': [], 'summary': ['Health check already running.']})
        report = {'checked_at': dt.datetime.now(dt.timezone.utc).isoformat(), 'issues': [], 'summary': [], 'details': {}}
        checks = [('Standards', ['bash', str(ROOT / 'run/.standards.sh'), 'audit']),
                  ('Johnny.Decimal', ['bash', str(ROOT / 'run/cleanup.sh'), 'lint-personal'])]
        for label, args in checks:
            code, out, err = run(args, timeout=180)
            report['details'][label] = '\n'.join(filter(None, [out, err]))
            if code:
                lines = [l.strip() for l in out.splitlines() if l.startswith(('VIOLATION', 'DIFF', 'ERROR'))]
                if not lines:
                    add(report, label, 'CHECK' if code != 127 else 'UNAVAILABLE', f'{label}: check needs review (health --details).')
                for line in lines:
                    category = 'PREFERENCE' if line.startswith('DIFF') else 'STANDARD'
                    if 'inventory' in line.lower() or 'unable to' in line.lower(): category = 'UNAVAILABLE'
                    elif 'repo-managed but not installed' in line: category = 'MISSING'
                    add(report, hashlib.sha256(line.encode()).hexdigest()[:16], category, line.split('\t', 1)[-1])
            else:
                report['summary'].append(f'{label}: OK')
        disk = shutil.disk_usage(HOME)
        report['summary'].append(f'Disk: {disk.free / 2**30:.1f} GiB free ({disk.free / disk.total:.0%})')
        if disk.free < 30 * 2**30:
            add(report, 'disk-space', 'STORAGE', 'Less than 30 GiB free.')
        # Check existing links only. Never walk cloud trees or download files.
        links = [HOME / '.zshrc', HOME / '.zprofile', HOME / '.gitconfig', HOME / '.Brewfile',
                 HOME / 'Library/Application Support/Code/User/settings.json']
        caskroom = Path('/opt/homebrew/Caskroom')
        if caskroom.exists():
            for cask in caskroom.iterdir():
                if cask.is_dir():
                    for version in cask.iterdir():
                        if version.is_dir() and not version.is_symlink() and not version.name.startswith('.'):
                            links.extend(version.iterdir())
        broken = [str(p) for p in links if p.is_symlink() and not p.exists()]
        for p in broken: add(report, 'link:' + p, 'LINK', f'Broken link: {p}')
        if broken: report['summary'].append(f'Links: {len(broken)} broken')
        # Local-only Git checks: no fetch, push, network, or recursive project search.
        repos = [ROOT]
        dev = HOME / 'Developer'
        if dev.exists(): repos += [p for p in dev.iterdir() if p.is_dir() and (p / '.git').exists()]
        protected = 0
        for p in repos:
            code, out, err = run(['git', '-C', str(p), 'status', '--porcelain', '--untracked-files=normal'], 20)
            if code:
                add(report, 'git-unavailable:' + str(p), 'UNAVAILABLE', f'{p.name}: Git status unavailable.')
                continue
            if out:
                add(report, 'git-dirty:' + str(p), 'LOCAL WORK', f'{p.name}: uncommitted or untracked work is not in GitHub yet.')
            code, upstream, _ = run(['git', '-C', str(p), 'rev-parse', '--abbrev-ref', '@{upstream}'], 10)
            if code:
                add(report, 'git-upstream:' + str(p), 'LOCAL WORK', f'{p.name}: branch has no upstream; remote copy is unverified.')
                continue
            code, ahead, _ = run(['git', '-C', str(p), 'rev-list', '--count', '@{upstream}..HEAD'], 10)
            if code:
                add(report, 'git-ahead-unavailable:' + str(p), 'UNAVAILABLE', f'{p.name}: could not compare with the last-known upstream.')
            elif int(ahead or 0):
                add(report, 'git-ahead:' + str(p), 'LOCAL WORK', f'{p.name}: local commits are ahead of the last-known upstream.')
            elif not out: protected += 1
        report['summary'].append(f'Git: {protected}/{len(repos)} repositories clean and aligned with last-known upstream (no network fetch)')
        caches = [HOME / 'Library/Caches', HOME / '.npm/_cacache', HOME / '.cache/uv', HOME / 'Library/pnpm/store']
        for p in caches:
            if not p.exists(): continue
            code, out, err = run(['du', '-sk', str(p)], 45)
            if code:
                add(report, 'cache-unavailable:' + str(p), 'UNAVAILABLE', f'Cannot fully measure {p}; some paths may be protected.')
            if not out or not out.split()[0].isdigit(): continue
            size = int(out.split()[0]) / 1024**2
            if round(size, 1) == 0: continue
            qualifier = 'at least ' if code else ''
            report['summary'].append(f'Cache {str(p).replace(str(HOME), "~")}: {qualifier}{size:.1f} GiB')
            if size >= 10:
                add(report, 'cache:' + str(p), 'CACHE', f'{str(p).replace(str(HOME), "~")} exceeds 10 GiB; review before cleaning.')
        save('latest.json', report)
        return report


def notify(report):
    if not report or 'checked_at' not in report: return
    old = read('notified.json', [])
    ids = [i['id'] for i in report['issues']]
    new = [i for i in report['issues'] if i['id'] not in old]
    if new:
        print(f'Health: {len(new)} new item(s). Run health for the report.')
        for i in new[:3]: print(f"  [{i['category']}] {i['message']}")
    save('notified.json', ids)


def startup():
    """Start at most one detached check per local calendar day."""
    STATE.mkdir(parents=True, exist_ok=True)
    with (STATE / 'startup.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        report = read('latest.json', {})
        notify(report)
        today = dt.date.today().isoformat()
        if read('daily.json', {}).get('date') == today: return
        # A completed manual refresh today already satisfies today's check.
        try:
            checked = dt.datetime.fromisoformat(report['checked_at']).astimezone().date().isoformat()
        except (KeyError, TypeError, ValueError):
            checked = None
        if checked != today:
            with (STATE / 'agent.log').open('a') as log:
                subprocess.Popen(
                    ['/usr/bin/nice', '-n', '15', sys.executable, str(Path(__file__).resolve()), '--background'],
                    stdin=subprocess.DEVNULL, stdout=log, stderr=log,
                    start_new_session=True, close_fds=True, env=ENV)
        save('daily.json', {'date': today})


def show(report, details=False):
    if not report:
        print('No cached health report yet. Run health --refresh.'); return
    print('Health — ' + report.get('checked_at', 'check in progress'))
    for line in report.get('summary', []):
        if line == 'Links: 0 broken' or (line.startswith('Cache ') and line.endswith(': 0.0 GiB')): continue
        print('  ' + line)
    for i in report['issues']: print(f"[{i['category']}] {i['message']}")
    if details:
        for label, body in report.get('details', {}).items(): print(f'\n=== {label} ===\n{body}')


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--refresh', action='store_true')
    p.add_argument('--background', action='store_true')
    p.add_argument('--notify', action='store_true')
    p.add_argument('--startup', action='store_true')
    p.add_argument('--details', action='store_true')
    a = p.parse_args()
    if a.startup: startup(); return
    if a.notify: notify(read('latest.json', {})); return
    report = collect() if a.refresh or a.background else read('latest.json', {})
    if not a.background: show(report, a.details)


if __name__ == '__main__': main()
