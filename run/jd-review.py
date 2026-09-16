#!/usr/bin/env python3
"""Read-only filename review. Never move files, allocate IDs, or follow symlinks."""
import argparse
from collections import defaultdict
from pathlib import Path
import re

ID = re.compile(r'^(\d{2}\.\d{2})(?:\+)?(?:\s|$)')
REFERENCE = re.compile(r'(?<![\d.])(\d{2}\.\d{2})(?![\d.])')
IGNORE = {'.DS_Store', '.localized', '.tmp.drivedownload', '.tmp.driveupload', 'Icon\r'}
STOP = {'the', 'and', 'for', 'with', 'from', 'new', 'copy', 'final', 'draft', 'document', 'index', 'archive'}


def children(path, issues):
    try:
        return sorted((p for p in path.iterdir() if p.name not in IGNORE), key=lambda p: p.name.casefold())
    except OSError as e:
        issues.append(('UNAVAILABLE', f'{path}: {e.strerror}'))
        return []


def words(name):
    return {w for w in re.findall(r'[^\W_]+', name.casefold()) if len(w) > 2 and not w.isdigit() and w not in STOP}


def destinations(item, ids):
    refs = set(REFERENCE.findall(item.name))
    if refs:
        return [(p, 'explicit ID in name') for ref in sorted(refs) for p in ids.get(ref, []) if not ref.endswith('.01')]
    candidates = []
    for ref, paths in ids.items():
        if ref.endswith(('.00', '.01', '.09')): continue
        for p in paths:
            title = ID.sub('', p.name)
            shared = words(item.stem) & words(title)
            # Names alone cannot establish purpose; lexical matches are only review hints.
            if len(shared) >= 2 or (words(title) and words(title) <= words(item.stem)):
                candidates.append((p, 'title hint only: ' + ', '.join(sorted(shared))))
    return candidates


def review(root, inboxes, index, complete=False):
    issues, items = [], []
    ids = defaultdict(list)
    def structural(parent, depth):
        for p in children(parent, issues):
            if p.is_symlink():
                issues.append(('SKIPPED_LINK', str(p))); continue
            if not p.is_dir():
                issues.append(('FILE_OUTSIDE_ID', str(p))); items.append(p); continue
            m = ID.match(p.name)
            if m:
                ref = m[1]; ids[ref].append(p)
                if ref.endswith('.01'):
                    entries = children(p, issues)
                    if entries: issues.append(('NONEMPTY_INBOX', str(p)))
                    items.extend(entries)
                if depth != 2 or not parent.name.startswith(ref[:2] + ' ') or not p.parent.parent.name.startswith(ref[0]):
                    issues.append(('ID_IN_WRONG_CATEGORY', str(p)))
            elif depth < 2:
                structural(p, depth + 1)
            else:
                issues.append(('UNRECOGNIZED_STRUCTURE', str(p)))
    structural(root, 0)
    for ref, paths in sorted(ids.items()):
        if len(paths) > 1: issues.append(('DUPLICATE_ID', ref + ': ' + ' | '.join(map(str, paths))))
    indexed = set()
    if index and index.exists():
        # Only entry headings count, never related-ID references in prose.
        for line in index.read_text().splitlines():
            m = re.match(r'^#{1,6}\s+(\d{2}\.\d{2})\b', line)
            if m: indexed.add(m[1])
    else:
        issues.append(('INDEX_UNAVAILABLE', str(index)))
    missing = sorted(set(ids) - indexed)
    for inbox in inboxes:
        if inbox.exists() and not inbox.is_symlink(): items.extend(children(inbox, issues))
    items = sorted(set(items), key=str)
    names = defaultdict(list)
    proposals = []
    for item in items:
        names[item.name.casefold()].append(item)
        if item.is_symlink():
            proposals.append((item, [])); continue
        proposals.append((item, destinations(item, ids)))
    for name, paths in names.items():
        if len(paths) > 1:
            issues.append(('POSSIBLE_DUPLICATE_NAME', ' | '.join(map(str, paths)) + ' (contents not compared)'))
    for ref in missing:
        issues.append(('MISSING_INDEX_ENTRY' if complete else 'INDEX_UNVERIFIED', ref + ': ' + str(ids[ref][0])))
    return ids, issues, proposals


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--root', type=Path, default=Path.home() / 'Personal')
    ap.add_argument('--inbox', type=Path, action='append', help='Additional staging folder (repeatable); defaults to Downloads and Desktop')
    ap.add_argument('--index', type=Path, help='Markdown JDex with headings such as ## 17.11 Title')
    ap.add_argument('--index-complete', action='store_true', help='Only use if the supplied index is a complete authoritative register')
    ap.add_argument('--details', action='store_true', help='List each unverified index entry')
    a = ap.parse_args()
    index = a.index or a.root / '00-09 Index/00 Index/00.00 Dashboard/00.00 JDex.md'
    if a.index_complete and not a.index: ap.error('--index-complete requires an explicitly supplied --index')
    if not a.root.is_dir() or a.root.is_symlink(): ap.error('--root must be an existing directory, not a symlink')
    ids, issues, proposals = review(a.root, a.inbox if a.inbox is not None else [Path.home() / 'Downloads', Path.home() / 'Desktop'], index, a.index_complete)
    print(f'JD review — {len(ids)} existing IDs; {len(proposals)} items to review. No changes made.')
    print('Scope: local Personal hierarchy and inbox filenames; no document contents or cloud-only inventory.')
    unverified = sum(code == 'INDEX_UNVERIFIED' for code, _ in issues)
    if unverified: print(f'Index coverage: {unverified} IDs absent from the partial register; completeness unverified, not confirmed missing. Use --details to list.')
    visible = [(c, m) for c, m in issues if c != 'INDEX_UNVERIFIED' or a.details]
    for code, message in visible: print(f'[{code}] {message}')
    for item, candidates in proposals:
        print(f'\nREVIEW {item}')
        if not candidates: print('  Destination unresolved; inspect purpose before choosing an existing ID.')
        for dest, reason in candidates: print(f'  Candidate: {dest / item.name}\n  Reason: {reason}; review required' + ('; destination already exists' if (dest / item.name).exists() else ''))
    if not visible and not proposals: print('No inbox items or duplicate-ID issues found in this scope.')


if __name__ == '__main__': main()
