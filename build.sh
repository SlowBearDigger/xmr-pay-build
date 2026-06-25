#!/usr/bin/env bash
# Build the xmr-pay installable packages from canonical sources.
#  - re-vendors the engine (xmr-pay-php) + adapter core (xmr-pay-adapter-core/src) + the canonical
#    pay_card view into each plugin, so a package can never ship stale vendored code
#  - drops an index.html into every directory (directory-listing protection / JED requirement)
#  - zips each plugin and assembles one Joomla package (pkg_) per cart: payment plugin + scheduler task
# Output: dist/pkg_xmrpay_hikashop.zip and dist/pkg_xmrpay_virtuemart.zip
set -euo pipefail

# source checkouts default to siblings of this repo; override via env if your layout differs.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS="$(dirname "$HERE")"
ENGINE="${XMRPAY_ENGINE:-$DOCS/xmr-pay-php}"
CORE="${XMRPAY_CORE:-$DOCS/xmr-pay-adapter-core}"
DIST="$HERE/dist"
WORK="$HERE/.work"
INDEX='<!DOCTYPE html><title></title>'   # empty directory-listing guard

rm -rf "$WORK" "$DIST"; mkdir -p "$WORK" "$DIST"

vendor_engine() {           # $1 = plugin dir that contains engine/
  local plg="$1" eng="$1/engine"
  rm -rf "$eng"; mkdir -p "$eng/third-party/monero" "$eng/src" "$eng/adapter"
  cp "$ENGINE"/third-party/monero/{base58.php,Varint.php,Keccak.php,ed25519.php,Cryptonote.php} "$eng/third-party/monero/"
  cp "$ENGINE"/third-party/monero/ATTRIBUTION.md "$eng/third-party/monero/" 2>/dev/null || true
  cp "$ENGINE"/src/{Util.php,Scanner.php} "$eng/src/"
  cp "$CORE"/src/{Gateway.php,OrderStore.php,Settler.php,ArrayOrderStore.php} "$eng/adapter/"
  cp "$HERE/templates/load.php" "$eng/load.php"
}

add_index_html() {          # $1 = root dir; index.html in every subdir that lacks one
  find "$1" -type d -exec sh -c 'for d; do [ -f "$d/index.html" ] || printf "%s" "$0" > "$d/index.html"; done' "$INDEX" {} +
}

zip_dir() {                 # $1 = dir, $2 = output zip ; zips the CONTENTS (manifest at zip root)
  ( cd "$1" && zip -rq "$2" . -x '.*' '*/.*' )
}

build_cart() {              # $1 = cart key, $2 = payment plugin src, $3 = task plugin src, $4 = pkg manifest
  local cart="$1" pay_src="$2" task_src="$3" pkg_xml="$4"
  local stage="$WORK/$cart"; mkdir -p "$stage/packages"
  local pay="$stage/pay" task="$stage/task"

  cp -r "$pay_src" "$pay"; cp -r "$task_src" "$task"
  # vendor canonical engine + pay card into the payment plugin
  vendor_engine "$pay"
  mkdir -p "$pay/views"; cp "$CORE/views/pay_card.php" "$pay/views/pay_card.php"
  add_index_html "$pay"; add_index_html "$task"

  local pay_zip task_zip
  pay_zip="$(basename "$pay_src").zip"; task_zip="$(basename "$task_src").zip"
  zip_dir "$pay"  "$stage/packages/$pay_zip"
  zip_dir "$task" "$stage/packages/$task_zip"
  cp "$pkg_xml" "$stage/$(basename "$pkg_xml")"

  ( cd "$stage" && zip -rq "$DIST/pkg_xmrpay_${cart}.zip" "$(basename "$pkg_xml")" packages )
  echo "  built dist/pkg_xmrpay_${cart}.zip  (payment=$pay_zip + task=$task_zip)"
}

echo "Building xmr-pay packages..."
build_cart hikashop \
  "$DOCS/xmr-pay-hikashop/plg_hikashoppayment_xmrpay" \
  "$DOCS/xmr-pay-hikashop/plg_task_xmrpaysettle" \
  "$HERE/manifests/pkg_xmrpay_hikashop.xml"
build_cart virtuemart \
  "$DOCS/xmr-pay-virtuemart/plg_vmpayment_xmrpay" \
  "$DOCS/xmr-pay-virtuemart/plg_task_xmrpaysettle_vm" \
  "$HERE/manifests/pkg_xmrpay_virtuemart.xml"

rm -rf "$WORK"
echo "Done. Packages in $DIST"
ls -lh "$DIST"
