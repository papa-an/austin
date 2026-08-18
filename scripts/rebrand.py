#!/usr/bin/env python3
"""Re-apply the AUSTIN rebrand on top of upstream code.

Why a script instead of a commit: upstream (pewdiepie-archdaemon/odysseus) keeps
shipping code that says "Odysseus". A frozen rename commit re-conflicts on every
pull; regenerating the rename against whatever upstream just shipped does not.

The whole update workflow becomes::

    git pull upstream dev
    python scripts/rebrand.py
    git commit -am "Re-apply AUSTIN rebrand"

Scope is deliberately narrow -- only user-visible strings. Internal identifiers,
module names, and directory names stay "odysseus" so the merge surface against
upstream stays as small as possible. Comment-only lines are skipped for the same
reason: renaming them costs merge conflicts and changes nothing a user sees.

Works on bytes rather than text so CRLF line endings survive untouched. (sed and
awk under Git Bash on Windows silently rewrite CRLF to LF, which turns a 40-line
rebrand into a whole-repo whitespace diff.)
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Presentation layer -- everything here is what a user actually looks at.
FRONTEND_GLOBS = [
    "static/*.html",
    "static/*.js",
    "static/manifest.json",
    "static/js/*.js",
]

# Server-side files that emit user-visible text (page titles, email subjects,
# setup banner, report headers, OAuth screens), plus the docs a reader lands on.
#
# Note: docs/odysseus-wordmark.png renders the old name as pixels, so the README
# header image still reads "Odysseus" until that PNG is replaced by hand.
SERVER_FILES = [
    "README.md",
    "docs/setup.md",
    "setup.py",
    "src/visual_report.py",
    "companion/routes.py",
    "routes/email_pollers.py",
    "routes/email_routes.py",
    "routes/mcp/mcp_routes.py",
    "routes/note/note_routes.py",
    "src/builtin_actions.py",
]

REPLACEMENTS = [(b"Odysseus", b"AUSTIN"), (b"ODYSSEUS", b"AUSTIN")]

COMMENT_PREFIXES = (b"#", b"//", b"*", b"<!--")


def is_comment_only(line: bytes) -> bool:
    """True for lines that are purely a comment (leading whitespace allowed)."""
    return line.lstrip().startswith(COMMENT_PREFIXES)


def rebrand(path: Path, check: bool) -> int:
    """Rewrite user-visible occurrences in *path*. Returns lines changed."""
    original = path.read_bytes()
    if not any(needle in original for needle, _ in REPLACEMENTS):
        return 0

    # splitlines(keepends=True) preserves \r\n, \n, and a missing final newline.
    out, changed = [], 0
    for line in original.splitlines(keepends=True):
        if is_comment_only(line):
            out.append(line)
            continue
        new = line
        for needle, sub in REPLACEMENTS:
            new = new.replace(needle, sub)
        if new != line:
            changed += 1
        out.append(new)

    if changed and not check:
        path.write_bytes(b"".join(out))
    return changed


def collect() -> list[Path]:
    paths: list[Path] = []
    for pattern in FRONTEND_GLOBS:
        paths.extend(sorted(ROOT.glob(pattern)))
    for rel in SERVER_FILES:
        candidate = ROOT / rel
        if candidate.is_file():
            paths.append(candidate)
    # Deduplicate while keeping order.
    seen, unique = set(), []
    for p in paths:
        if p not in seen:
            seen.add(p)
            unique.append(p)
    return unique


def main() -> int:
    check = "--check" in sys.argv
    files = lines = 0

    for path in collect():
        n = rebrand(path, check)
        if n:
            files += 1
            lines += n
            verb = "would change" if check else "rebranded"
            print(f"  {verb}  {path.relative_to(ROOT).as_posix()}  ({n} lines)")

    if not files:
        print("Nothing to rebrand -- already clean.")
        return 0

    tail = " Nothing written." if check else ""
    print(f"\n{files} file(s), {lines} line(s).{tail}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
