# xmr-pay packaging

Builds the installable Joomla packages for the xmr-pay Monero payment suite from the canonical
sources. One package per cart, each bundling the payment method plugin **and** its settlement
scheduler task — the merchant installs a single zip.

```
./build.sh
# -> dist/pkg_xmrpay_hikashop.zip      (plg_hikashoppayment_xmrpay + plg_task_xmrpaysettle)
# -> dist/pkg_xmrpay_virtuemart.zip    (plg_vmpayment_xmrpay + plg_task_xmrpaysettle_vm)
```

## What the build does

- **Re-vendors from canonical** so a package can never ship stale code:
  - the engine from `../xmr-pay-php` (`third-party/monero/*`, `src/Util.php`, `src/Scanner.php`)
  - the adapter core from `../xmr-pay-adapter-core/src` (`Gateway`, `OrderStore`, `Settler`, `ArrayOrderStore`)
  - the one canonical payment card `../xmr-pay-adapter-core/views/pay_card.php` into each plugin's `views/`
  - `templates/load.php` as each plugin's `engine/load.php`
- Drops an empty `index.html` into **every** directory (directory-listing protection / JED requirement).
- Zips each plugin, then assembles the `pkg_` package (manifest + `packages/*.zip`).

## Layout

```
build.sh                       # the builder
templates/load.php             # canonical engine bootstrap (vendored into every plugin)
manifests/
  pkg_xmrpay_hikashop.xml       # package manifest (payment + task)
  pkg_xmrpay_virtuemart.xml
dist/                          # output packages (gitignored)
```

## Single source of truth

`pay_card.php` and the engine/adapter-core live in ONE place and are copied in at build time — edit
the canonical source, never the vendored copies inside a plugin. Verified: both packages install
cleanly on Joomla 5.4.6 (HikaShop 6.5.0 / VirtueMart 4.6.4), registering both the payment plugin and
the scheduler task from one zip.

## Known follow-ups (not blocking)

- The two scheduler-task plugins are near-identical; an abstract base could collapse them.
- The payment card ships readable English; full `Text::_()` i18n is a later pass (kept English now to
  avoid front-end language-loading edge cases that would show raw keys).
