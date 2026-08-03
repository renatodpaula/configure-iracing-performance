#!/usr/bin/env bash
# Install this repository as a Claude skill.
#
# Default: create a symlink so the installed skill always tracks the repository.
# Use --copy for an independent snapshot, and --user/--project to choose the scope.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
skill_name="$(basename "$repo_root")"
mode="symlink"
scope="user"
target_root=""
force="false"

usage() {
    cat <<'EOF'
Usage: install-claude-skill.sh [options]

  --user             Install into ~/.claude/skills (default).
  --project PATH     Install into PATH/.claude/skills.
  --target PATH      Install into an explicit skills directory.
  --copy             Copy the files instead of creating a symlink.
  --force            Replace an existing installation.
  -h, --help         Show this help.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --user) scope="user"; shift ;;
        --project)
            [ $# -ge 2 ] || { echo "--project requires a path" >&2; exit 2; }
            scope="project"; target_root="$2/.claude/skills"; shift 2 ;;
        --target)
            [ $# -ge 2 ] || { echo "--target requires a path" >&2; exit 2; }
            scope="explicit"; target_root="$2"; shift 2 ;;
        --copy) mode="copy"; shift ;;
        --force) force="true"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
done

if [ "$scope" = "user" ]; then
    target_root="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills"
fi

if [ ! -f "$repo_root/SKILL.md" ]; then
    echo "SKILL.md not found in $repo_root" >&2
    exit 1
fi

target="$target_root/$skill_name"

if [ -e "$target" ] || [ -L "$target" ]; then
    if [ "$force" != "true" ]; then
        echo "Already installed at $target. Re-run with --force to replace it." >&2
        exit 1
    fi
    rm -rf "$target"
fi

mkdir -p "$target_root"

if [ "$mode" = "symlink" ]; then
    ln -s "$repo_root" "$target"
    echo "Linked $target -> $repo_root"
else
    mkdir -p "$target"
    for item in SKILL.md references scripts; do
        cp -R "$repo_root/$item" "$target/"
    done
    echo "Copied SKILL.md, references/ and scripts/ to $target"
fi

echo "Invoke it in Claude Code with /$skill_name"
