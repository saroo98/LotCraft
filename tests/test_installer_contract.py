from __future__ import annotations

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
WINDOWS = ROOT / "installer" / "cmd" / "setup" / "main_windows.go"
POLICY = ROOT / "installer" / "internal" / "policy" / "windowspath.go"
RELEASE_SCRIPT = ROOT / "scripts" / "build_release.ps1"
SOURCE = WINDOWS.read_text(encoding="utf-8")
POLICY_SOURCE = POLICY.read_text(encoding="utf-8")
RELEASE_SOURCE = RELEASE_SCRIPT.read_text(encoding="utf-8")


def test_installer_identity_and_dedicated_destination_are_exact():
    assert 'productName       = "LotCraft"' in SOURCE
    assert 'productVersion    = "1.0.0"' in SOURCE
    assert 'setupTitle        = "LotCraft 1.0.0 Setup"' in SOURCE
    assert 'ex5Name           = "LotCraft.ex5"' in SOURCE
    assert 'defaultInstallRel = `MQL5\\Experts\\LotCraft`' in SOURCE
    assert r"\LotCraft" in POLICY_SOURCE


def test_installer_payload_is_exactly_named_and_source_is_not_owned():
    assert "//go:embed embedded_payload.txt" in SOURCE
    assert "materializeEmbeddedPayload()" in SOURCE
    assert "len(embeddedEX5) < 1024" in SOURCE
    assert "strings.EqualFold(filepath.Base(payloadPath), ex5Name)" in SOURCE
    owned = re.search(r"OwnedFiles:\s*\[\]string\{([^}]*)\}", SOURCE).group(1)
    assert "ex5Name" in owned
    assert "uninstallName" in owned
    assert "manifestName" in owned
    for forbidden in [".mq5", ".mqh", "Pasted text", "Position Sizer", "PositionSizer"]:
        assert forbidden not in owned


def test_installer_resolves_reparse_paths_before_containment_checks():
    for api in ["GetFileAttributesW", "CreateFileW", "GetFinalPathNameByHandleW"]:
        assert api in SOURCE
    assert "fileAttributeReparsePoint" in SOURCE
    assert "reparseComponents" in SOURCE
    assert "resolveExistingPath(expertsPath)" in SOURCE
    assert "resolveExistingPath(installPath)" in SOURCE
    assert "policy.Within(expertsResolved, installResolved)" in SOURCE
    assert "--allow-reparse" in SOURCE


def test_installer_validates_all_required_sha256_copies():
    for field in [
        "CanonicalEX5SHA256", "StagedEX5SHA256", "InstalledEX5SHA256", "InstallerSHA256",
    ]:
        assert field in SOURCE
    assert "stagedHash != canonicalHash" in SOURCE
    assert "installedHash != canonicalHash" in SOURCE
    assert "uninstallHash != installerHash" in SOURCE
    assert "installed uninstaller SHA-256 mismatch" in SOURCE
    assert 'sha256.New()' in SOURCE


def test_install_commit_has_backup_and_rollback_paths():
    for function in ["commitPrepared", "rollbackPrepared", "finalizePrepared", "moveFile"]:
        assert f"func {function}" in SOURCE
    assert "MoveFileExW" in SOURCE
    assert "moveFileWriteThrough" in SOURCE
    assert "moveFileReplaceExisting" in SOURCE


def test_upgrade_preflights_existing_destination_ownership_before_staging():
    run_install = re.search(r"func runInstall\(.*?\n\}", SOURCE, re.S).group(0)
    ownership_check = run_install.index("validateExistingInstallOwnership")
    first_stage = run_install.index("copyToTempAndHash")
    assert ownership_check < first_stage
    assert "an installer-owned filename already exists without a LotCraft install manifest" in SOURCE
    assert "existing manifest identity mismatch" in SOURCE
    assert "existing manifest owned-file inventory is not exact" in SOURCE
    assert "verify existing EX5 ownership" in SOURCE
    assert "verify existing uninstaller ownership" in SOURCE


def test_uninstall_is_manifest_scoped_and_preserves_unrelated_files():
    assert "manifest.Product != productName || manifest.Version != productVersion" in SOURCE
    assert "manifest.InstallResolved" in SOURCE
    assert "manifest.ExpertsResolved" in SOURCE
    assert "policy.Within(currentExpertsResolved, currentProductResolved)" in SOURCE
    assert "Only the three installer-owned files will be removed" in SOURCE
    assert "Any unrelated files in that directory were preserved" in SOURCE
    assert "os.RemoveAll(" not in SOURCE


def test_terminal_selection_requires_real_mt5_data_markers():
    assert 'filepath.Join(root, "MQL5")' in SOURCE
    for marker in ["config", "bases", "history", "logs", "origin.txt"]:
        assert f'"{marker}"' in SOURCE
    assert "discoverTerminalDataDirs" in SOURCE
    assert "browseForFolder" in SOURCE


def test_installer_logs_exact_final_destination_and_hashes():
    assert "selected_resolved=%s experts_resolved=%s final=%s" in SOURCE
    assert "canonical_ex5=%s staged_ex5=%s installed_ex5=%s installer=%s" in SOURCE
    assert "Final destination:" in SOURCE


def test_release_script_preserves_installer_path_arguments_with_spaces():
    assert '"`"-terminal-data-dir=$TerminalDataDir`""' in RELEASE_SOURCE
    assert '"`"-payload=$StagedEx5`""' in RELEASE_SOURCE
    assert '"`"-log=$InstallLog`""' in RELEASE_SOURCE
    assert '"-terminal-data-dir", $TerminalDataDir' not in RELEASE_SOURCE


def test_installer_has_no_old_product_or_broad_delete_reference():
    assert "Position Sizer" not in SOURCE
    assert "PositionSizer" not in SOURCE
    assert "os.RemoveAll" not in SOURCE


def test_uninstall_preflights_all_hash_protected_files_before_first_delete():
    run_uninstall = re.search(r"func runUninstall\(.*?\n\}", SOURCE, re.S).group(0)
    first_remove = run_uninstall.index("removeOwnedFile(ex5Path")
    ex5_verify = run_uninstall.index("verifyOwnedFileHashIfPresent(ex5Path")
    uninstaller_verify = run_uninstall.index("verifyOwnedFileHashIfPresent(uninstallerPath")
    manifest_verify = run_uninstall.index("validateRegularNonReparseFile(manifestPath)")
    assert ex5_verify < first_remove
    assert uninstaller_verify < first_remove
    assert manifest_verify < first_remove
    assert "preserving all owned files" in SOURCE


def test_uninstall_keeps_manifest_until_other_owned_removals_are_safe():
    run_uninstall = re.search(r"func runUninstall\(.*?\n\}", SOURCE, re.S).group(0)
    remove_ex5 = run_uninstall.index("removeOwnedFile(ex5Path")
    schedule_self = run_uninstall.index("scheduleSelfDelete")
    remove_uninstaller = run_uninstall.index("removeOwnedFile(uninstallerPath")
    remove_manifest = run_uninstall.index("os.Remove(manifestPath)")
    assert remove_ex5 < remove_manifest
    assert schedule_self < remove_manifest
    assert remove_uninstaller < remove_manifest


def test_self_delete_uses_product_scoped_native_cleanup_helper():
    assert "func runCleanupHelper" in SOURCE
    assert '"-cleanup-target", self' in SOURCE
    assert "filepath.Base(target), uninstallName" in SOURCE
    assert "sameWindowsPath(filepath.Dir(target), productDir)" in SOURCE
    assert "cleanup helper SHA-256 differs from the installed uninstaller" in SOURCE
    assert "os.Remove(productDir)" in SOURCE
    assert "os.RemoveAll" not in SOURCE
    assert "cmd.exe" not in SOURCE
