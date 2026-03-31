#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: $0 <tag> <version> [output_path]" >&2
  exit 1
fi

tag="$1"
version="$2"
output_path="${3:-release.md}"
changelog_path="CHANGELOG.md"

if [[ ! -f "$changelog_path" ]]; then
  echo "Missing $changelog_path" >&2
  exit 1
fi

changelog_section="$(
  python3 - "$changelog_path" "$version" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
version = sys.argv[2]
text = path.read_text(encoding="utf-8")
pattern = re.compile(
    rf"^##\s+v?{re.escape(version)}\s*$\n(.*?)(?=^##\s+|\Z)",
    re.MULTILINE | re.DOTALL,
)
match = pattern.search(text)
if not match:
    sys.exit(1)
section = match.group(1).strip()
sys.stdout.write(section)
PY
)" || {
  previous_tag="$(
    git tag -l 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname \
      | grep -Fxv "$tag" \
      | head -n 1 || true
  )"

  python3 Scripts/update_changelog.py \
    --version "$version" \
    --from-ref "$previous_tag" \
    --to-ref "$tag" \
    --mode body
}

repo_url="https://github.com/${GITHUB_REPOSITORY}"
download_base="${repo_url}/releases/download/${tag}"

cat >"$output_path" <<EOF
## 更新内容

${changelog_section}

### 📥 下载地址 (Downloads)

请根据您的 Mac 处理器芯片选择对应的版本下载。当前发布仅提供无内核安装包，首次启动后可在 ClashBar 设置页打开内核目录并放入 \`mihomo\`。

| 🖥 平台架构 (Architecture) | 🛠️ 无内核安装包 |
| :--- | :--- |
| ![Apple Silicon](https://img.shields.io/badge/Apple_Silicon-M系列芯片-0071E3?style=flat-square&logo=apple&logoColor=white) | [ClashBar-${version}-apple-silicon-no-core.dmg](${download_base}/ClashBar-${version}-apple-silicon-no-core.dmg) |
| ![Intel](https://img.shields.io/badge/Intel-x86__64-0071C5?style=flat-square&logo=intel&logoColor=white) | [ClashBar-${version}-intel-no-core.dmg](${download_base}/ClashBar-${version}-intel-no-core.dmg) |

EOF
