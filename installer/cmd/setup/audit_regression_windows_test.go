//go:build windows

package main

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"testing"
	"time"
	"unsafe"

	lotupdate "lotcraft.local/installer/internal/update"
)

func writeAuditFixture(t *testing.T, path string, raw []byte) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, raw, 0o600); err != nil {
		t.Fatal(err)
	}
}

func auditInstallFixture(t *testing.T, updaterBytes []byte) (installManifest, string) {
	t.Helper()
	terminal := t.TempDir()
	experts := filepath.Join(terminal, "MQL5", "Experts")
	product := filepath.Join(experts, productName)
	writeAuditFixture(t, filepath.Join(terminal, "origin.txt"), []byte("synthetic terminal fixture"))
	writeAuditFixture(t, filepath.Join(product, ex5Name), []byte("synthetic EX5"))
	writeAuditFixture(t, filepath.Join(product, updaterName), updaterBytes)
	writeAuditFixture(t, filepath.Join(product, uninstallName), []byte("synthetic uninstaller"))
	terminalResolved, err := resolveExistingPath(terminal)
	if err != nil {
		t.Fatal(err)
	}
	expertsResolved, err := resolveExistingPath(experts)
	if err != nil {
		t.Fatal(err)
	}
	productResolved, err := resolveExistingPath(product)
	if err != nil {
		t.Fatal(err)
	}
	ex5Hash, _ := hashFile(filepath.Join(product, ex5Name))
	updaterHash, _ := hashFile(filepath.Join(product, updaterName))
	uninstallHash, _ := hashFile(filepath.Join(product, uninstallName))
	manifest := installManifest{
		SchemaVersion: manifestSchema, Product: productName, Version: productVersion,
		SelectedTerminalDataDir: terminal, SelectedTerminalResolved: terminalResolved,
		ExpertsPath: experts, ExpertsResolved: expertsResolved,
		InstallPath: product, InstallResolved: productResolved,
		InstalledEX5SHA256: ex5Hash, UpdaterSHA256: updaterHash, InstallerSHA256: uninstallHash,
		OwnedFiles: []string{ex5Name, updaterName, uninstallName, manifestName},
	}
	raw, err := json.Marshal(manifest)
	if err != nil {
		t.Fatal(err)
	}
	writeAuditFixture(t, filepath.Join(product, manifestName), raw)
	return manifest, product
}

func TestLegacyUpgradeRejectsUnownedUpdaterCollision(t *testing.T) {
	manifest, product := auditInstallFixture(t, []byte("unrelated existing updater bytes"))
	manifest.SchemaVersion = 0
	manifest.Version = "1.0.0"
	manifest.UpdaterSHA256 = ""
	manifest.OwnedFiles = []string{ex5Name, uninstallName, manifestName}
	raw, err := json.Marshal(manifest)
	if err != nil {
		t.Fatal(err)
	}
	writeAuditFixture(t, filepath.Join(product, manifestName), raw)
	err = validateExistingInstallOwnership(product, manifest.InstallResolved, manifest.ExpertsResolved)
	if err == nil {
		t.Fatal("legacy upgrade accepted an existing updater that its manifest does not own")
	}
	remaining, err := os.ReadFile(filepath.Join(product, updaterName))
	if err != nil || string(remaining) != "unrelated existing updater bytes" {
		t.Fatalf("collision bytes were not preserved: %q, %v", remaining, err)
	}
}

func TestUpdaterRejectsTerminalRecordUnrelatedToItsProductDirectory(t *testing.T) {
	manifest, product := auditInstallFixture(t, []byte("synthetic updater"))
	other, _ := auditInstallFixture(t, []byte("other synthetic updater"))
	manifest.SelectedTerminalDataDir = other.SelectedTerminalDataDir
	manifest.SelectedTerminalResolved = other.SelectedTerminalResolved
	raw, err := json.Marshal(manifest)
	if err != nil {
		t.Fatal(err)
	}
	writeAuditFixture(t, filepath.Join(product, manifestName), raw)
	if _, _, err := readVerifiedUpdaterInstall(product); err == nil {
		t.Fatal("updater accepted a terminal record that points its installer at another product directory")
	}
}

func TestUpdaterRejectsChangedRecordedReparseTopology(t *testing.T) {
	manifest, product := auditInstallFixture(t, []byte("synthetic updater"))
	manifest.ReparseComponentsObserved = []string{manifest.ExpertsPath}
	raw, err := json.Marshal(manifest)
	if err != nil {
		t.Fatal(err)
	}
	writeAuditFixture(t, filepath.Join(product, manifestName), raw)
	if _, _, err := readVerifiedUpdaterInstall(product); err == nil {
		t.Fatal("updater accepted a recorded link topology that is no longer present")
	}
}

func holdAuditNamedMutex(t *testing.T, name string) {
	t.Helper()
	wide, err := syscall.UTF16PtrFromString(name)
	if err != nil {
		t.Fatal(err)
	}
	handle, _, callErr := procCreateMutexW.Call(0, 0, uintptr(unsafe.Pointer(wide)))
	if handle == 0 || errors.Is(callErr, errorAlreadyExists) {
		t.Fatalf("create isolated lifecycle mutex: %v", callErr)
	}
	t.Cleanup(func() { procCloseHandle.Call(handle) })
}

func TestLifecycleOperationsRejectContentionBeforeOwnedFileChanges(t *testing.T) {
	for _, uninstall := range []bool{false, true} {
		t.Run(map[bool]string{false: "install", true: "uninstall"}[uninstall], func(t *testing.T) {
			manifest, product := auditInstallFixture(t, []byte("synthetic updater"))
			holdAuditNamedMutex(t, "Global\\LotCraft-Install-"+updaterInstallationID(manifest.InstallResolved))
			payload := filepath.Join(t.TempDir(), ex5Name)
			writeAuditFixture(t, payload, []byte("new fixture EX5"))
			log, err := newLogger(filepath.Join(t.TempDir(), "install.log"), true)
			if err != nil {
				t.Fatal(err)
			}
			defer log.close()
			opt := options{terminalRoot: manifest.SelectedTerminalDataDir, payload: payload, quiet: true}
			if uninstall {
				err = runUninstall(opt, log)
			} else {
				err = runInstall(opt, log)
			}
			if err == nil || !strings.Contains(strings.ToLower(err.Error()), "another") {
				t.Fatalf("lifecycle operation did not reject an active mutation: %v", err)
			}
			remaining, err := os.ReadFile(filepath.Join(product, ex5Name))
			if err != nil || string(remaining) != "synthetic EX5" {
				t.Fatalf("contended lifecycle operation changed existing data: %q %v", remaining, err)
			}
		})
	}
}

func TestEmergencyUpdaterLogRotatesAndBoundsEntries(t *testing.T) {
	profile := t.TempDir()
	t.Setenv("LOCALAPPDATA", profile)
	path := filepath.Join(profile, "LotCraft", "Updater", "bootstrap.log")
	writeAuditFixture(t, path, []byte(strings.Repeat("x", updateLogLimit+1)))
	appendEmergencyUpdaterLog(errors.New("fixture failure"))
	if _, err := os.Stat(path + ".1"); err != nil {
		t.Fatalf("emergency updater log did not rotate: %v", err)
	}
	appendEmergencyUpdaterLog(errors.New(strings.Repeat("x", updateLogLimit*2)))
	info, err := os.Stat(path)
	if err != nil || info.Size() > updateLogLimit {
		t.Fatalf("emergency updater log is not bounded: %v %v", info, err)
	}
}

func TestQuietUpdateCarriesOnlyVerifiedReparseApproval(t *testing.T) {
	manifest, product := auditInstallFixture(t, []byte("synthetic updater"))
	verified, _, err := readVerifiedUpdaterInstall(product)
	if err != nil {
		t.Fatal(err)
	}
	args := updateInstallerArguments(verified, "fixture.log")
	if strings.Contains(strings.Join(args, " "), "-allow-reparse") {
		t.Fatal("ordinary installation unexpectedly bypassed reparse approval")
	}
	// The path/topology verifier is exercised separately with real directories.
	// This boundary must preserve approval from its verified result.
	manifest.ReparseComponentsObserved = []string{manifest.ExpertsPath}
	args = updateInstallerArguments(manifest, "fixture.log")
	if !strings.Contains(strings.Join(args, " "), "-allow-reparse") {
		t.Fatal("quiet update discarded previously verified reparse approval")
	}
}

func TestUpdaterCheckMutexDoesNotBlockInstallerChild(t *testing.T) {
	manifest, _ := auditInstallFixture(t, []byte("synthetic updater"))
	check, acquired, err := acquireUpdaterMutex(updaterInstallationID(manifest.InstallResolved))
	if err != nil || !acquired {
		t.Fatalf("check mutex: %v", err)
	}
	defer check.Close()
	mutation, err := acquireInstallationMutation(manifest.InstallResolved)
	if err != nil {
		t.Fatalf("updater's check lock blocks its installer child: %v", err)
	}
	mutation.Close()
	mutation, err = acquireInstallationMutation(manifest.InstallResolved)
	if err != nil {
		t.Fatalf("closed installation lock was not released: %v", err)
	}
	mutation.Close()
}

func auditExitedProcessID(t *testing.T) int {
	t.Helper()
	self, err := os.Executable()
	if err != nil {
		t.Fatal(err)
	}
	command := exec.Command(self, "-test.run=^$")
	command.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
	if err := command.Run(); err != nil {
		t.Fatal(err)
	}
	return command.Process.Pid
}

func TestDelayedUninstallCleanupPreservesNewInstallation(t *testing.T) {
	manifest, product := auditInstallFixture(t, []byte("synthetic updater"))
	target := filepath.Join(product, uninstallName)
	err := runCleanupHelper(options{
		cleanupTarget: target, cleanupDir: product,
		cleanupParent: auditExitedProcessID(t), cleanupHash: manifest.InstallerSHA256,
		expectedInstallResolved: manifest.InstallResolved,
	})
	if err != nil {
		t.Fatalf("cleanup should skip a newly installed manifest: %v", err)
	}
	if raw, err := os.ReadFile(target); err != nil || string(raw) != "synthetic uninstaller" {
		t.Fatalf("delayed cleanup removed a new installation's uninstaller: %q %v", raw, err)
	}
}

func TestDelayedUninstallCleanupRejectsChangedTarget(t *testing.T) {
	manifest, product := auditInstallFixture(t, []byte("synthetic updater"))
	target := filepath.Join(product, uninstallName)
	if err := os.Remove(filepath.Join(product, manifestName)); err != nil {
		t.Fatal(err)
	}
	writeAuditFixture(t, target, []byte("replacement must survive"))
	err := runCleanupHelper(options{
		cleanupTarget: target, cleanupDir: product,
		cleanupParent: auditExitedProcessID(t), cleanupHash: manifest.InstallerSHA256,
		expectedInstallResolved: manifest.InstallResolved,
	})
	if err == nil {
		t.Fatal("delayed cleanup accepted a changed target hash")
	}
	if raw, err := os.ReadFile(target); err != nil || string(raw) != "replacement must survive" {
		t.Fatalf("delayed cleanup removed a changed file: %q %v", raw, err)
	}
}

func TestDelayedUninstallCleanupRespectsMutationMutex(t *testing.T) {
	manifest, product := auditInstallFixture(t, []byte("synthetic updater"))
	if err := os.Remove(filepath.Join(product, manifestName)); err != nil {
		t.Fatal(err)
	}
	holdAuditNamedMutex(t, "Global\\LotCraft-Install-"+updaterInstallationID(manifest.InstallResolved))
	target := filepath.Join(product, uninstallName)
	err := runCleanupHelper(options{
		cleanupTarget: target, cleanupDir: product, cleanupParent: auditExitedProcessID(t),
		cleanupHash: manifest.InstallerSHA256, expectedInstallResolved: manifest.InstallResolved,
	})
	if err == nil || !strings.Contains(err.Error(), "another") {
		t.Fatalf("delayed cleanup did not respect active lifecycle lock: %v", err)
	}
	if raw, err := os.ReadFile(target); err != nil || string(raw) != "synthetic uninstaller" {
		t.Fatalf("delayed cleanup changed a contended destination: %q %v", raw, err)
	}
}

func TestDetachedCleanupPreservesChangedAndAdditionalFiles(t *testing.T) {
	for _, changed := range []bool{false, true} {
		t.Run(map[bool]string{false: "additional", true: "changed"}[changed], func(t *testing.T) {
			profile := t.TempDir()
			t.Setenv("LOCALAPPDATA", profile)
			directory, err := os.MkdirTemp("", "LotCraft-Updater-fixture-")
			if err != nil {
				t.Fatal(err)
			}
			target := filepath.Join(directory, "LotCraft-Updater-Worker-fixture.exe")
			extra := filepath.Join(directory, "not-owned.txt")
			writeAuditFixture(t, target, []byte("original temporary fixture"))
			writeAuditFixture(t, extra, []byte("preserve extra"))
			t.Cleanup(func() { _ = os.Remove(target); _ = os.Remove(extra); _ = os.Remove(directory) })
			self, err := os.Executable()
			if err != nil {
				t.Fatal(err)
			}
			command := exec.Command(self, "-test.run=^TestAuditCleanupWaitHelper$")
			command.Env = append(os.Environ(), "LOTCRAFT_TEST_CLEANUP_WAIT=1")
			command.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
			if err := command.Start(); err != nil {
				t.Fatal(err)
			}
			if err := scheduleDetachedExecutableCleanup(target, command.Process.Pid); err != nil {
				t.Fatal(err)
			}
			if changed {
				writeAuditFixture(t, target, []byte("replacement must survive"))
			}
			if err := command.Wait(); err != nil {
				t.Fatal(err)
			}
			deadline := time.Now().Add(8 * time.Second)
			for time.Now().Before(deadline) {
				_, targetErr := os.Stat(target)
				_, logErr := os.Stat(filepath.Join(profile, "LotCraft", "Updater", "cleanup.log"))
				if (!changed && os.IsNotExist(targetErr)) || (changed && logErr == nil) {
					break
				}
				time.Sleep(25 * time.Millisecond)
			}
			if raw, err := os.ReadFile(extra); err != nil || string(raw) != "preserve extra" {
				t.Fatal("cleanup removed an unrelated file")
			}
			raw, err := os.ReadFile(target)
			if changed {
				if err != nil || string(raw) != "replacement must survive" {
					t.Fatal("cleanup removed a changed target")
				}
				if _, err := os.Stat(filepath.Join(profile, "LotCraft", "Updater", "cleanup.log")); err != nil {
					t.Fatal("cleanup failure was not logged")
				}
			} else if !os.IsNotExist(err) {
				t.Fatalf("verified owned temporary file was not removed: %v", err)
			}
		})
	}
}

func TestAuditCleanupWaitHelper(t *testing.T) {
	if os.Getenv("LOTCRAFT_TEST_CLEANUP_WAIT") != "1" {
		t.Skip("isolated cleanup wait helper")
	}
	time.Sleep(750 * time.Millisecond)
}

func TestRollbackReportsLockedDestinationAndPreservesRecoveryBackup(t *testing.T) {
	directory := t.TempDir()
	final := filepath.Join(directory, "owned")
	backup := filepath.Join(directory, "recovery-backup")
	writeAuditFixture(t, final, []byte("new"))
	writeAuditFixture(t, backup, []byte("old"))
	path, err := syscall.UTF16PtrFromString(final)
	if err != nil {
		t.Fatal(err)
	}
	handle, err := syscall.CreateFile(path, syscall.GENERIC_READ, syscall.FILE_SHARE_READ, nil, syscall.OPEN_EXISTING, 0, 0)
	if err != nil {
		t.Fatal(err)
	}
	defer syscall.CloseHandle(handle)
	files := []*preparedFile{{final: final, backup: backup, hadOld: true, committed: true}}
	rollbackErr := rollbackPrepared(files)
	if rollbackErr == nil {
		t.Fatal("rollback suppressed a failed restoration instead of returning its recovery error")
	}
	if !strings.Contains(rollbackErr.Error(), backup) {
		t.Fatalf("rollback error does not identify the preserved backup: %v", rollbackErr)
	}
	remaining, err := os.ReadFile(backup)
	if err != nil || string(remaining) != "old" {
		t.Fatalf("recovery backup was lost: %q, %v", remaining, err)
	}
}

func TestDetachedUpdaterRemovesOnlyItsOwnTemporaryCopyAfterExit(t *testing.T) {
	for _, invalid := range []bool{false, true} {
		t.Run(map[bool]string{false: "throttled-check", true: "invalid-install"}[invalid], func(t *testing.T) {
			exerciseDetachedUpdaterCleanup(t, invalid)
		})
	}
}

func exerciseDetachedUpdaterCleanup(t *testing.T, invalid bool) {
	t.Helper()
	self, err := os.Executable()
	if err != nil {
		t.Fatal(err)
	}
	workerBytes, err := os.ReadFile(self)
	if err != nil {
		t.Fatal(err)
	}
	manifest, product := auditInstallFixture(t, workerBytes)
	workerDir, err := os.MkdirTemp("", "LotCraft-Updater-test-")
	if err != nil {
		t.Fatal(err)
	}
	worker := filepath.Join(workerDir, "LotCraft-Updater-Worker-test.exe")
	writeAuditFixture(t, worker, workerBytes)
	t.Cleanup(func() {
		_ = os.Remove(worker)
		_ = os.Remove(workerDir)
	})
	profile := t.TempDir()
	id := updaterInstallationID(manifest.InstallResolved)
	statePath := filepath.Join(profile, "LotCraft", "Updater", id, "state.json")
	stateRaw, err := json.Marshal(lotupdate.State{
		SchemaVersion: updateStateSchema, InstallationID: id, LastAttemptUTC: time.Now().UTC(),
	})
	if err != nil {
		t.Fatal(err)
	}
	writeAuditFixture(t, statePath, stateRaw)
	neighbor := filepath.Join(t.TempDir(), "not-owned.txt")
	writeAuditFixture(t, neighbor, []byte("preserve"))

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	command := exec.CommandContext(ctx, worker, "-test.run=^TestAuditUpdaterWorkerHelper$")
	command.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
	command.Env = append(os.Environ(), "LOTCRAFT_TEST_WORKER_PRODUCT="+product, "LOCALAPPDATA="+profile)
	if invalid {
		writeAuditFixture(t, filepath.Join(product, manifestName), []byte("invalid synthetic manifest"))
		command.Env = append(command.Env, "LOTCRAFT_TEST_EXPECT_WORKER_FAILURE=1")
	}
	if output, err := command.CombinedOutput(); err != nil {
		t.Fatalf("isolated updater worker failed: %v\n%s", err, output)
	}
	deadline := time.Now().Add(8 * time.Second)
	for time.Now().Before(deadline) {
		if _, err := os.Stat(workerDir); os.IsNotExist(err) {
			if raw, err := os.ReadFile(neighbor); err != nil || string(raw) != "preserve" {
				t.Fatalf("cleanup affected unrelated data: %q, %v", raw, err)
			}
			return
		}
		time.Sleep(25 * time.Millisecond)
	}
	for _, name := range []string{"bootstrap.log", "cleanup.log"} {
		if raw, err := os.ReadFile(filepath.Join(profile, "LotCraft", "Updater", name)); err == nil {
			t.Logf("isolated %s: %s", name, raw)
		}
	}
	t.Fatal("detached updater left its temporary executable/directory after process exit")
}

func TestAuditUpdaterWorkerHelper(t *testing.T) {
	product := os.Getenv("LOTCRAFT_TEST_WORKER_PRODUCT")
	if product == "" {
		t.Skip("isolated child-process helper")
	}
	err := runUpdaterWorker(options{updaterWorker: true, productDir: product, quiet: true})
	if os.Getenv("LOTCRAFT_TEST_EXPECT_WORKER_FAILURE") == "1" {
		if err == nil {
			t.Fatal("invalid worker installation was accepted")
		}
		return
	}
	if err != nil {
		t.Fatal(err)
	}
}
