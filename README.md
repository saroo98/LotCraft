# LotCraft: MT5 Position Sizer and Risk Calculator

LotCraft is a Windows Expert Advisor for **MetaTrader 5 (MT5)**. Calculate position size from your risk budget and stop loss, compare target risk with actual SL loss, and inspect chart-wide and account-wide exposure before you place a trade.

[![Latest stable release](https://img.shields.io/github/v/release/saroo98/LotCraft?style=flat-square)](https://github.com/saroo98/LotCraft/releases/latest)
![Platform: Windows x64](https://img.shields.io/badge/platform-Windows%20x64-0078d4?style=flat-square)
![Language: MQL5 and Go](https://img.shields.io/badge/source-MQL5%20%2B%20Go-59636e?style=flat-square)

**[Download the latest installer](https://github.com/saroo98/LotCraft/releases/latest)** · [Installation](#install-lotcraft) · [Update alerts](#automatic-updates-and-release-alerts) · [Build and test](#build-and-test)

LotCraft is a discretionary trading tool, not a trading strategy. It does not generate signals or send autonomous orders. Start on a demo account.

## Position sizing and stop-loss exposure

| Feature | What it does |
|---|---|
| Risk-based lot sizing | Uses Equity, Balance or a Manual amount, your risk budget, Entry and SL, and the broker's symbol specifications. |
| Target risk / Actual SL loss | Separates the requested budget from the estimated loss at the final valid volume, in the account currency. |
| Current chart / Whole account | Shows protected downside exposure as a percentage of equity and a money amount. Missing SLs and unavailable projections stay visible as incomplete data. |
| Individual results | Provides position and pending-order details, plus chart labels for open positions when a safe label lane fits. |
| Instant / Pending | Supports market entry and supported Buy/Sell Limit or Stop orders with explicit submission. |
| Saved planning levels | Remembers each symbol's plan on the same chart. Mode changes do not move the SL or TP. |
| Chart controls | Provides draggable Entry, SL and TP handles, price steppers, copy feedback and a line-visibility toggle. |
| Adaptive panel | Offers Full, Compact and Mini layouts with light and dark themes and DPI-scaled geometry. |
| Confirmation and SL batches | Offers one risk-only confirmation for new orders and a separate validated action to move eligible current-symbol SLs to the line. |

The calculator uses broker profit conversion for account-currency values. It can work with available forex, index, metal and other broker symbols when their data and order rules pass validation. Symbol names, contract specifications and available order types vary by broker.

### Understand the two risk values

- **Target risk** is the budget you request.
- **Actual SL loss** is the estimated loss for the final position size at your SL.

If the budget is below the broker's minimum lot size, LotCraft can use the minimum valid volume when capacity permits. Actual SL loss can then exceed Target risk. Always check the actual amount before confirming.

Chart/account exposure uses current **equity**, even when new-trade sizing uses Balance or Manual. It sums downside only; profitable stops do not cancel other positions' losses. Projections include known accrued swap for positions, but cannot guarantee fills or predict gaps, slippage, future swap or unknown closing fees. A missing SL is not zero risk.

## What's new in 1.2.2

- Copy selected numeric text with **Ctrl+C**, including SL, risk percentage, Target risk and Manual account fields.
- Keep C-button prices consistent with the displayed planning value instead of normalizing them again.
- Reject unavailable clipboard owners before clearing existing clipboard contents.
- Clear stale success feedback after failed copies and log generic failure reasons without financial values.

The [copy audit](docs/COPY_AUDIT_2026-10-01.md) records the fixes and proof boundaries. The [1.2.2 release report](docs/RELEASE_1.2.2.md) records build and publication evidence. The [1.2.1 report](docs/RELEASE_1.2.1.md) retains the earlier planning, layout and updater improvements. Offline verification is not native MT5 visual or broker certification.

## Install LotCraft

Requirements: **Windows x64, MetaTrader 5, and permission to enable DLL imports for LotCraft**.

1. Open the [latest stable GitHub release](https://github.com/saroo98/LotCraft/releases/latest).
2. Download `LotCraft-1.2.2-Setup.exe` and its `LotCraft-1.2.2-SHA256.txt` checksum.
3. Compare the installer SHA-256 with the published checksum:
   ```powershell
   Get-FileHash .\LotCraft-1.2.2-Setup.exe -Algorithm SHA256
   ```
4. Run the installer and confirm the intended MT5 terminal data directory. No separate EX5 download or manual folder copying is needed.
5. In MT5, refresh **Navigator → Expert Advisors**, then attach **LotCraft → LotCraft** to a chart.
6. Enable **Allow DLL imports** for this EA. Enable **Algo Trading** before submitting an order.

If MT5 is already open during installation, reattach LotCraft or restart MT5 later to activate the new EA. The installer does not force a terminal restart.

The installer is not Authenticode-signed. A filename or checksum from an untrusted source does not establish publisher identity. Download from this repository's release page before deciding whether to accept a Windows security warning. Ed25519 verification protects subsequent automatic updates, not an independently trusted first installation.

For terminal selection, source compilation, release signing and recovery limits, see [Build and installation](docs/BUILD_AND_INSTALL.md).

## Automatic updates and release alerts

### Inside MT5

Starting with **1.2.1**, LotCraft launches its separate updater ten seconds after initialization and then offers another background launch opportunity each hour while attached. The updater allows a network attempt only after **24 hours** since the previous attempt for that installation, including failed attempts. Its mutex prevents overlapping checks.

When a newer stable signed release is available, the updater asks **Yes / No**. Yes downloads and verifies the signed metadata, installer byte size and SHA-256 before installation. No defers that version for 24 hours. The new EA activates after reattachment or a later MT5 restart.

**Updating from 1.2.0:** reattach LotCraft or restart MT5 for the next eligible check, or install the latest version manually. The old EA only launches its updater after initialization; publishing a release cannot remotely add a scheduler to that old binary.

Check timing is not a universal notification deadline. MT5 must be running, the EA must be attached, DLL imports must be allowed, the installation must verify, and the network must be available. A due daily attempt may wait for the next hourly opportunity. Strategy Tester never launches update checks. Updates never restart MT5 or place trades.

### On GitHub

Select **Watch → Custom → Releases** on [this repository](https://github.com/saroo98/LotCraft) to subscribe to release announcements. Delivery depends on your GitHub notification settings; repository owners cannot force notifications for every installer user. See [GitHub notification guidance](https://docs.github.com/en/subscriptions-and-notifications/get-started/configuring-notifications#configuring-your-watch-settings-for-an-individual-repository).

## Common questions

**Why is the trade button disabled?**

LotCraft retains planning with usable cached data, but submission still requires current quotes, permissions, supported order/filling types, valid protection prices, volume capacity and broker preflight. A closed market or invalid SL must remain a block. Record the exact message, symbol suffix, mode and version when reporting a rejection.

**Why did a saved SL become invalid?**

The market can move past a fixed planning level. LotCraft keeps the saved price instead of silently moving it. Correct the level before trading.

**How long are plans retained?**

Plans are scoped to the current account, server and chart. MT5 terminal globals expire after four weeks without access. A new chart ID is a different namespace, and the store is not an indefinite archive or a crash-atomic transaction. See [known limitations](docs/KNOWN_LIMITATIONS.md).

**How do I remove LotCraft?**

Run `LotCraft-Uninstall.exe` in `MQL5\Experts\LotCraft` under the chosen terminal data directory. It verifies the installation manifest and removes only the four owned files. It preserves unrelated files.

## Build and test

Source requirements: Windows x64, MetaEditor, Go 1.23+, Python 3.11+, pytest, Git Bash and a C++17 `g++` compiler. Signed release creation additionally requires the existing Ed25519 private key outside the repository.

From the repository root:

```powershell
py -3.11 -m pytest -q
Set-Location installer
go test -count=1 ./...
go test -race -count=1 ./...
go vet ./...
Set-Location ..
```

To build a signed release without installing into a terminal:

```powershell
.\scripts\build_release.ps1 -MetaEditorPath "C:\Program Files\MetaTrader 5\MetaEditor64.exe"
```

The tests include executed production-function fixtures and disposable Windows installer tests. Platform stubs do not reproduce MT5's event queue, native drawing or real broker execution. Do not treat skipped native-function tests as equivalent coverage.

[Architecture](docs/ARCHITECTURE.md) · [Test plan](docs/TEST_PLAN.md) · [Traceability](docs/TRACEABILITY.md) · [Known limitations](docs/KNOWN_LIMITATIONS.md)

## Privacy and safety

Position sizing, trading and exposure data stay local. The updater uses GitHub's public release API without a GitHub token. It records check times, deferral and an installation identifier locally; it does not collect account values, trades or telemetry.

Private keys, credentials, terminal identifiers, production logs and local build output are excluded from commits and release assets. Current release evidence uses artifact names and hashes, not local installation paths. The v1.2.0 verification report was separately path-redacted with owner approval; its installer and signed update assets are unchanged. Ignore rules do not sanitize previously published material or remove cached copies.

Trading can lose money. Risk estimates are not guaranteed outcomes. LotCraft enforces validation, but it cannot eliminate execution failures, slippage or market loss.
