"""Fetches or checks the development copy of oUF in Libs/oUF.

The pinned tag is read from .pkgmeta, the same pin the packager uses for releases. Files are written from
raw Git blobs of a local oUF repository, so no line-ending or keyword conversion reaches the copy, and the
check compares Git blob identities rather than hashes of the copy itself.

    python Tools/ouf.py            fetch the pinned tag into Libs/oUF, replacing what is there
    python Tools/ouf.py --check    verify Libs/oUF against the pinned tag
    --repo PATH                    the oUF Git repository (default: Reference/oUF/oUF)
"""

import argparse
import hashlib
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TARGET = ROOT / "Libs" / "oUF"
DEFAULT_REPO = Path("C:/Users/Alex/Documents/Development/Reference/oUF/oUF")


def pinned_tag():
    text = (ROOT / ".pkgmeta").read_text(encoding="utf-8")
    match = re.search(r"^\s+Libs/oUF:\s*\n\s+url:.*\n\s+tag:\s*(\S+)", text, re.MULTILINE)
    if not match:
        sys.exit("ouf: no 'Libs/oUF' external with a tag in .pkgmeta")
    return match.group(1)


def git(repo, *args):
    return subprocess.run(["git", "-C", str(repo), *args], check=True, capture_output=True).stdout


def tree(repo, tag):
    """Returns {path: blob id} for every file at the tag."""
    entries = {}
    for line in git(repo, "ls-tree", "-r", "-z", tag).split(b"\0"):
        if not line:
            continue
        meta, path = line.split(b"\t", 1)
        mode, kind, blob = meta.split(b" ")
        if kind == b"blob":
            entries[path.decode("utf-8")] = blob.decode("ascii")
    return entries


def blob_id(data):
    return hashlib.sha1(b"blob %d\0" % len(data) + data).hexdigest()


def fetch(repo, tag):
    entries = tree(repo, tag)
    if TARGET.is_symlink():
        sys.exit(f"ouf: {TARGET} is a symbolic link; remove it first")
    if TARGET.exists():
        shutil.rmtree(TARGET)
    for path, blob in entries.items():
        destination = TARGET / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(git(repo, "cat-file", "blob", blob))
    commit = git(repo, "rev-list", "-n", "1", tag).decode("ascii").strip()
    print(f"Fetched oUF {tag} ({commit}) into {TARGET}: {len(entries)} files.")


def check(repo, tag):
    entries = tree(repo, tag)
    if not TARGET.is_dir():
        sys.exit(f"ouf: {TARGET} is missing; run python Tools/ouf.py")
    present = {p.relative_to(TARGET).as_posix() for p in TARGET.rglob("*") if p.is_file()}
    problems = []
    for path in sorted(set(entries) - present):
        problems.append(f"missing {path}")
    for path in sorted(present - set(entries)):
        problems.append(f"extra {path}")
    for path in sorted(present & set(entries)):
        if blob_id((TARGET / path).read_bytes()) != entries[path]:
            problems.append(f"changed {path}")
    for problem in problems:
        print(problem)
    if problems:
        sys.exit(f"ouf: Libs/oUF does not match {tag} ({len(problems)} problem(s))")
    print(f"oUF in Libs/oUF matches {tag} ({len(entries)} files).")


def main():
    parser = argparse.ArgumentParser(description="Fetch or check Libs/oUF against the tag pinned in .pkgmeta.")
    parser.add_argument("--check", action="store_true", help="verify instead of fetching")
    parser.add_argument("--repo", type=Path, default=DEFAULT_REPO, help="the oUF Git repository")
    options = parser.parse_args()
    tag = pinned_tag()
    if options.check:
        check(options.repo, tag)
    else:
        fetch(options.repo, tag)


if __name__ == "__main__":
    main()
