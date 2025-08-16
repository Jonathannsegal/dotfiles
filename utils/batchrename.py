import os
import re
from pathlib import Path

PATTERN = re.compile(r"^(?P<prefix>\d{2}\.)\d{2}\s+(?P<label>.+)$")

def renumber_subfolders(base: Path, start: int = 11, prefix: str = "15.", dry_run: bool = True):
    if not base.exists() or not base.is_dir():
        raise ValueError(f"Error: '{base}' is not a directory.")

    # Only immediate subfolders, sorted by name
    entries = sorted([p for p in base.iterdir() if p.is_dir()], key=lambda p: p.name)

    for offset, folder in enumerate(entries, start=start):
        name = folder.name

        # Match "12.xx Something"
        m = PATTERN.match(name)
        if m:
            label = m.group("label")
        else:
            parts = name.split(" ", 1)
            label = parts[1] if len(parts) > 1 else ""

        new_name = f"{prefix}{offset:02d}" + (f" {label}" if label else "")
        new_path = folder.with_name(new_name)

        if new_path == folder:
            continue

        print(f"{folder.name}  ->  {new_name}")
        if not dry_run:
            folder.rename(new_path)


if __name__ == "__main__":
    folder_path = Path(os.path.expanduser("~/Personal/10-19 Cornell/15 Proposals"))
    renumber_subfolders(folder_path, dry_run=False)  # change dry_run=False to apply
