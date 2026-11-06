#!/usr/bin/env bash
# 在真機、模擬器或桌面版上跑全部 E2E 情境（integration_test/e2e_*_test.dart）。
#
#   cd app && tool/e2e.sh <device-id>        # 例如 tool/e2e.sh emulator-5554、tool/e2e.sh linux
#   cd app && tool/e2e.sh linux parent        # 只跑名字含 parent 的檔案
#
# 一次只跑一個檔案：同一次 `flutter test -d` 跑多個 integration 檔，桌面版的 log reader 會中途斷掉。
# 每個情境開始前會把裝置上的資料庫刪掉重開（等於剛安裝），結束後再清一次——別在有真實資料的裝置上跑。
# 同一份情境在 `flutter test`（test/e2e/）也會用 in-memory 資料庫跑，CI 每次都會跑到。
set -uo pipefail

device="${1:?usage: tool/e2e.sh <device-id> [name-filter]}"
filter="${2:-}"
flutter=(flutter)
command -v fvm >/dev/null 2>&1 && flutter=(fvm flutter)

cd "$(dirname "$0")/.."
failed=()
for f in integration_test/e2e_*_test.dart; do
  [[ -n "$filter" && "$f" != *"$filter"* ]] && continue
  echo "==> $f"
  if ! "${flutter[@]}" test "$f" -d "$device"; then
    failed+=("$f")
  fi
done

if ((${#failed[@]})); then
  echo "FAILED: ${failed[*]}"
  exit 1
fi
echo "All E2E scenarios passed on $device."
