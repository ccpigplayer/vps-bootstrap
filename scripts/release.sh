#!/usr/bin/env bash
set -euo pipefail

LEVEL="${1:-patch}"
MSG="${2:-release}"

if [[ ! -f VERSION ]]; then
  echo "VERSION not found" >&2
  exit 1
fi

old="$(cat VERSION | tr -d '[:space:]')"
IFS='.' read -r major minor patch <<<"$old"

case "$LEVEL" in
  patch) patch=$((patch+1)) ;;
  minor) minor=$((minor+1)); patch=0 ;;
  major) major=$((major+1)); minor=0; patch=0 ;;
  *) echo "Usage: $0 [patch|minor|major] [message]"; exit 1 ;;
esac

new="${major}.${minor}.${patch}"
echo "$new" > VERSION

# CHANGELOG 顶部插入简短记录
if [[ -f CHANGELOG.md ]]; then
  tmp=$(mktemp)
  {
    echo "# Changelog"
    echo
    echo "## v${new}"
    echo "- ${MSG}"
    echo
    # 去掉旧标题重复
    awk 'BEGIN{skip=0} {if(NR==1 && $0=="# Changelog"){skip=1; next} print}' CHANGELOG.md
  } > "$tmp"
  mv "$tmp" CHANGELOG.md
else
  cat > CHANGELOG.md <<EOF
# Changelog

## v${new}
- ${MSG}
EOF
fi

git add VERSION CHANGELOG.md
if ! git diff --cached --quiet; then
  git commit -m "chore(release): v${new}"
fi

git tag -a "v${new}" -m "Release v${new}"

echo "Release prepared: v${new}"
echo "Next: git push origin main --tags"
