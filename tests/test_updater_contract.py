from __future__ import annotations

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
EA = (ROOT / "MQL5" / "Experts" / "LotCraft" / "LotCraft.mq5").read_text(encoding="utf-8")
PLATFORM = (ROOT / "MQL5" / "Experts" / "LotCraft" / "PS_Platform.mqh").read_text(encoding="utf-8")
UPDATER = (ROOT / "installer" / "cmd" / "setup" / "updater_windows.go").read_text(encoding="utf-8")
PROTOCOL = (ROOT / "installer" / "internal" / "update" / "protocol.go").read_text(encoding="utf-8")


def test_ea_schedules_background_checks_after_ten_seconds_and_skips_tester():
    # The extracted scheduler behavior is executed in test_native_update_schedule.
    assert "g_update_checks_enabled=!(bool)MQLInfoInteger(MQL_TESTER)" in EA
    assert "g_next_update_check_ms=GetTickCount64()+10000" in EA
    assert "PS_CheckForUpdates(now);" in EA
    assert "PS_PlatformLaunchUpdater(update_error)" in EA
    assert 'ShellExecuteW' in PLATFORM
    assert '"-check-update"' in PLATFORM
    assert "WebRequest" not in EA
    assert "WebRequest" not in PLATFORM


def test_updater_has_signed_stable_daily_update_contract():
    assert "releases/latest" in UPDATER
    assert "updateInterval     = 24 * time.Hour" in UPDATER
    assert "acquireUpdaterMutex" in UPDATER
    assert "VerifySignedManifest" in PROTOCOL
    assert "ed25519.Verify" in PROTOCOL
    assert "ParseVersion" in PROTOCOL
    assert "release.Draft || release.Prerelease" in PROTOCOL
    assert "DownloadInstaller" in UPDATER
    assert "downloaded installer size differs" in PROTOCOL
    assert "downloaded installer SHA-256 differs" in PROTOCOL


def test_updater_runs_verified_temporary_copy_and_preserves_activation_boundary():
    assert "temporary updater worker hash" in UPDATER
    assert '"-updater-worker"' in UPDATER
    assert re.search(r'"-terminal-data-dir="\s*\+\s*installed\.SelectedTerminalDataDir', UPDATER)
    assert '"-quiet"' in UPDATER
    assert "reattached or MetaTrader 5 is next restarted" in UPDATER
    assert "os.Exit" not in UPDATER


def test_updater_state_contains_no_tokens_telemetry_or_trading_data():
    for forbidden in ["github_token", "access_token", "account_login", "trade_history", "telemetry"]:
        assert forbidden not in UPDATER.lower()
        assert forbidden not in PROTOCOL.lower()
