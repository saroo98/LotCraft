//go:build windows

package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	lotupdate "lotcraft.local/installer/internal/update"
)

func TestUpdaterInstallationIDIsStableAndPathScoped(t *testing.T) {
	first := updaterInstallationID(`C:\Users\Example\AppData\Roaming\MetaQuotes\Terminal\ABC\MQL5\Experts\LotCraft`)
	same := updaterInstallationID(`c:\users\example\appdata\roaming\metaquotes\terminal\abc\mql5\experts\lotcraft`)
	other := updaterInstallationID(`C:\Users\Example\AppData\Roaming\MetaQuotes\Terminal\XYZ\MQL5\Experts\LotCraft`)
	if first != same {
		t.Fatalf("case-only path change changed installation ID: %s != %s", first, same)
	}
	if first == other || len(first) != 32 {
		t.Fatalf("installation ID is not path-scoped: first=%s other=%s", first, other)
	}
}

func TestUpdaterMutexAllowsOnlyOneWorkerPerInstallation(t *testing.T) {
	id := updaterInstallationID(t.TempDir())
	first, acquired, err := acquireUpdaterMutex(id)
	if err != nil || !acquired {
		t.Fatalf("first mutex acquisition: acquired=%v err=%v", acquired, err)
	}
	defer first.Close()
	second, acquired, err := acquireUpdaterMutex(id)
	if err != nil {
		t.Fatal(err)
	}
	if acquired || second != nil {
		t.Fatal("second updater worker acquired the same installation mutex")
	}
}

func TestUpdaterStateRoundTripAndIdentityCheck(t *testing.T) {
	path := filepath.Join(t.TempDir(), "state.json")
	now := time.Date(2026, 7, 28, 12, 0, 0, 0, time.UTC)
	state := lotupdate.State{
		SchemaVersion:          updateStateSchema,
		InstallationID:         "installation-a",
		LastAttemptUTC:         now,
		LastSuccessfulCheckUTC: now,
		DeferredVersion:        "1.1.0",
		DeferredUntilUTC:       now.Add(updateInterval),
	}
	if err := saveUpdaterState(path, state); err != nil {
		t.Fatal(err)
	}
	loaded, err := loadUpdaterState(path, "installation-a")
	if err != nil {
		t.Fatal(err)
	}
	if loaded.InstallationID != state.InstallationID || loaded.DeferredVersion != state.DeferredVersion {
		t.Fatalf("unexpected state %#v", loaded)
	}
	if _, err := loadUpdaterState(path, "installation-b"); err == nil {
		t.Fatal("state from another installation was accepted")
	}
}

func TestLegacyThreeFileManifestCanUpgradeToUpdaterSchema(t *testing.T) {
	experts := t.TempDir()
	installPath := filepath.Join(experts, productName)
	if err := os.Mkdir(installPath, 0o755); err != nil {
		t.Fatal(err)
	}
	ex5Path := filepath.Join(installPath, ex5Name)
	uninstallerPath := filepath.Join(installPath, uninstallName)
	if err := os.WriteFile(ex5Path, []byte("legacy-ex5"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(uninstallerPath, []byte("legacy-uninstaller"), 0o600); err != nil {
		t.Fatal(err)
	}
	ex5Hash, _ := hashFile(ex5Path)
	uninstallerHash, _ := hashFile(uninstallerPath)
	expertsResolved, err := resolveExistingPath(experts)
	if err != nil {
		t.Fatal(err)
	}
	installResolved, err := resolveExistingPath(installPath)
	if err != nil {
		t.Fatal(err)
	}
	legacy := installManifest{
		Product:            productName,
		Version:            productVersion,
		ExpertsPath:        experts,
		ExpertsResolved:    expertsResolved,
		InstallPath:        installPath,
		InstallResolved:    installResolved,
		InstalledEX5SHA256: ex5Hash,
		InstallerSHA256:    uninstallerHash,
		OwnedFiles:         []string{ex5Name, uninstallName, manifestName},
	}
	raw, _ := json.Marshal(legacy)
	if err := os.WriteFile(filepath.Join(installPath, manifestName), raw, 0o600); err != nil {
		t.Fatal(err)
	}
	if err := validateExistingInstallOwnership(installPath, installResolved, expertsResolved); err != nil {
		t.Fatalf("legacy manifest migration was rejected: %v", err)
	}
}

func TestLegacyManifestTamperingIsRejected(t *testing.T) {
	experts := t.TempDir()
	installPath := filepath.Join(experts, productName)
	if err := os.Mkdir(installPath, 0o755); err != nil {
		t.Fatal(err)
	}
	ex5Path := filepath.Join(installPath, ex5Name)
	uninstallerPath := filepath.Join(installPath, uninstallName)
	_ = os.WriteFile(ex5Path, []byte("tampered-ex5"), 0o600)
	_ = os.WriteFile(uninstallerPath, []byte("legacy-uninstaller"), 0o600)
	uninstallerHash, _ := hashFile(uninstallerPath)
	expertsResolved, _ := resolveExistingPath(experts)
	installResolved, _ := resolveExistingPath(installPath)
	legacy := installManifest{
		Product:            productName,
		Version:            productVersion,
		ExpertsPath:        experts,
		ExpertsResolved:    expertsResolved,
		InstallPath:        installPath,
		InstallResolved:    installResolved,
		InstalledEX5SHA256: strings.Repeat("0", 64),
		InstallerSHA256:    uninstallerHash,
		OwnedFiles:         []string{ex5Name, uninstallName, manifestName},
	}
	raw, _ := json.Marshal(legacy)
	_ = os.WriteFile(filepath.Join(installPath, manifestName), raw, 0o600)
	if err := validateExistingInstallOwnership(installPath, installResolved, expertsResolved); err == nil {
		t.Fatal("tampered legacy installation was accepted")
	}
}

func TestAtomicCommitRollsBackEveryFailurePosition(t *testing.T) {
	for failAt := 0; failAt < 4; failAt++ {
		t.Run(string(rune('0'+failAt)), func(t *testing.T) {
			directory := t.TempDir()
			files := make([]*preparedFile, 0, 4)
			for index := 0; index < 4; index++ {
				final := filepath.Join(directory, "owned-"+string(rune('0'+index)))
				temp := filepath.Join(directory, "staged-"+string(rune('0'+index)))
				if err := os.WriteFile(final, []byte("old"), 0o600); err != nil {
					t.Fatal(err)
				}
				if index != failAt {
					if err := os.WriteFile(temp, []byte("new"), 0o600); err != nil {
						t.Fatal(err)
					}
				}
				files = append(files, &preparedFile{temp: temp, final: final})
			}
			if err := commitPrepared(files); err == nil {
				t.Fatal("commit unexpectedly succeeded")
			}
			for _, file := range files {
				raw, err := os.ReadFile(file.final)
				if err != nil {
					t.Fatalf("rollback did not restore %s: %v", file.final, err)
				}
				if string(raw) != "old" {
					t.Fatalf("rollback changed prior installation at %s", file.final)
				}
			}
		})
	}
}
