//go:build windows

package main

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"time"
	"unsafe"

	"lotcraft.local/installer/internal/policy"
	lotupdate "lotcraft.local/installer/internal/update"
)

const (
	updateLatestURL    = "https://api.github.com/repos/saroo98/LotCraft/releases/latest"
	updateInterval     = 24 * time.Hour
	updateStateSchema  = 1
	updateLogLimit     = 1 << 20
	errorAlreadyExists = syscall.Errno(183)
)

var procCreateMutexW = kernel32.NewProc("CreateMutexW")

type namedMutex struct {
	handle uintptr
}

func runUpdaterMode(opt options) error {
	var err error
	if opt.updaterWorker {
		err = runUpdaterWorker(opt)
	} else {
		err = launchUpdaterWorker()
	}
	if err != nil {
		appendEmergencyUpdaterLog(err)
	}
	return err
}

// launchUpdaterWorker runs only from the installed updater. It verifies that
// copy against the signed installation record, then starts the network-facing
// work from an equally verified temporary copy. The installed updater is never
// running while a newer installer replaces it.
func launchUpdaterWorker() error {
	self := executablePath()
	if !strings.EqualFold(filepath.Base(self), updaterName) {
		return fmt.Errorf("updater bootstrap must be named %s", updaterName)
	}
	productDir := filepath.Dir(self)
	manifest, _, err := readVerifiedUpdaterInstall(productDir)
	if err != nil {
		return err
	}
	selfHash, err := hashFile(self)
	if err != nil {
		return fmt.Errorf("hash installed updater: %w", err)
	}
	if !strings.EqualFold(selfHash, manifest.UpdaterSHA256) {
		return errors.New("installed updater does not match the verified installation manifest")
	}

	workerDir, err := os.MkdirTemp("", "LotCraft-Updater-")
	if err != nil {
		return fmt.Errorf("create temporary updater directory: %w", err)
	}
	worker, workerHash, err := copyToTempAndHash(self, workerDir, "LotCraft-Updater-Worker-*.exe")
	if err != nil {
		_ = os.Remove(workerDir)
		return fmt.Errorf("stage temporary updater worker: %w", err)
	}
	if !strings.EqualFold(workerHash, manifest.UpdaterSHA256) {
		_ = os.Remove(worker)
		_ = os.Remove(workerDir)
		return errors.New("temporary updater worker hash does not match the verified installation manifest")
	}

	process, err := os.StartProcess(
		worker,
		[]string{
			worker,
			"-updater-worker",
			"-product-dir=" + productDir,
			"-quiet",
		},
		&os.ProcAttr{Files: []*os.File{nil, nil, nil}},
	)
	if err != nil {
		_ = os.Remove(worker)
		_ = os.Remove(workerDir)
		return fmt.Errorf("start temporary updater worker: %w", err)
	}
	return process.Release()
}

func runUpdaterWorker(opt options) error {
	if opt.productDir == "" {
		return errors.New("temporary updater worker did not receive a product directory")
	}
	productDir, err := filepath.Abs(opt.productDir)
	if err != nil {
		return fmt.Errorf("resolve updater product directory: %w", err)
	}
	productDir = filepath.Clean(productDir)

	manifest, installResolved, err := readVerifiedUpdaterInstall(productDir)
	if err != nil {
		return err
	}
	workerPath := executablePath()
	workerName := strings.ToLower(filepath.Base(workerPath))
	if !strings.HasPrefix(workerName, "lotcraft-updater-worker-") ||
		filepath.Ext(workerName) != ".exe" ||
		sameWindowsPath(filepath.Dir(workerPath), productDir) {
		return errors.New("updater worker is not a detached temporary copy")
	}
	workerHash, err := hashFile(workerPath)
	if err != nil {
		return fmt.Errorf("hash temporary updater worker: %w", err)
	}
	if !strings.EqualFold(workerHash, manifest.UpdaterSHA256) {
		return errors.New("temporary updater worker does not match the verified installed updater")
	}
	defer scheduleUpdaterWorkerDeletion()

	installationID := updaterInstallationID(installResolved)
	mutex, acquired, err := acquireUpdaterMutex(installationID)
	if err != nil {
		return err
	}
	if !acquired {
		return nil
	}
	defer mutex.Close()

	stateDir, err := updaterStateDirectory(installationID)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(stateDir, 0o700); err != nil {
		return fmt.Errorf("create updater state directory: %w", err)
	}
	logPath := filepath.Join(stateDir, "updater.log")
	if err := rotateUpdaterLog(logPath); err != nil {
		return err
	}
	log, err := newLogger(logPath, true)
	if err != nil {
		return fmt.Errorf("open updater log: %w", err)
	}
	defer log.close()
	log.printf("check start installation_id=%s installed_version=%s", installationID, manifest.Version)

	statePath := filepath.Join(stateDir, "state.json")
	state, err := loadUpdaterState(statePath, installationID)
	if err != nil {
		log.printf("state reset: %v", err)
		state = lotupdate.State{SchemaVersion: updateStateSchema, InstallationID: installationID}
	}
	now := time.Now().UTC()
	if !state.ShouldAttempt(now, updateInterval) {
		log.printf("check skipped daily_interval next_eligible=%s", state.LastAttemptUTC.Add(updateInterval).Format(time.RFC3339))
		return nil
	}
	state.SchemaVersion = updateStateSchema
	state.InstallationID = installationID
	state.LastAttemptUTC = now
	if err := saveUpdaterState(statePath, state); err != nil {
		return fmt.Errorf("record updater attempt: %w", err)
	}

	publicKey, err := lotupdate.DecodePublicKey(lotupdate.TrustedPublicKeyBase64)
	if err != nil {
		log.printf("check failed: %v", err)
		return err
	}
	allowedHosts := map[string]bool{
		"api.github.com":                        true,
		"github.com":                            true,
		"release-assets.githubusercontent.com":  true,
		"objects.githubusercontent.com":         true,
		"github-releases.githubusercontent.com": true,
	}
	client := lotupdate.NewHTTPClient(allowedHosts)
	checker := lotupdate.Checker{
		Client:         client,
		LatestURL:      updateLatestURL,
		PublicKey:      publicKey,
		AllowedHosts:   allowedHosts,
		CurrentVersion: manifest.Version,
	}
	ctx, cancel := context.WithTimeout(context.Background(), 45*time.Second)
	candidate, err := checker.Check(ctx)
	cancel()
	if err != nil {
		log.printf("check failed: %v", err)
		return err
	}
	state.LastSuccessfulCheckUTC = time.Now().UTC()
	if candidate == nil {
		state.DeferredVersion = ""
		state.DeferredUntilUTC = time.Time{}
		if err := saveUpdaterState(statePath, state); err != nil {
			return err
		}
		log.printf("check complete no_update")
		return nil
	}
	if state.IsDeferred(candidate.Manifest.Version, now) {
		if err := saveUpdaterState(statePath, state); err != nil {
			return err
		}
		log.printf("check complete deferred version=%s until=%s", candidate.Manifest.Version, state.DeferredUntilUTC.Format(time.RFC3339))
		return nil
	}
	if err := saveUpdaterState(statePath, state); err != nil {
		return err
	}

	prompt := fmt.Sprintf(
		"LotCraft %s is available.\n\nInstalled version: %s\n\nInstall this signed update now?",
		candidate.Manifest.Version,
		manifest.Version,
	)
	if showMessage("LotCraft update available", prompt, mbYesNo|mbIconQuestion|mbSetForeground) != idYes {
		state.DeferredVersion = candidate.Manifest.Version
		state.DeferredUntilUTC = time.Now().UTC().Add(updateInterval)
		if err := saveUpdaterState(statePath, state); err != nil {
			log.printf("save deferral failed: %v", err)
			return err
		}
		log.printf("update deferred version=%s until=%s", candidate.Manifest.Version, state.DeferredUntilUTC.Format(time.RFC3339))
		return nil
	}

	if err := downloadAndInstallUpdate(checker, *candidate, manifest, stateDir, log); err != nil {
		log.printf("update failed after approval version=%s: %v", candidate.Manifest.Version, err)
		showMessage(
			"LotCraft update failed",
			"The update was not installed. Your existing LotCraft installation was preserved.\n\n"+
				err.Error()+"\n\nDetails were recorded in:\n"+logPath,
			mbOK|mbIconError|mbSetForeground,
		)
		return err
	}
	state.DeferredVersion = ""
	state.DeferredUntilUTC = time.Time{}
	_ = saveUpdaterState(statePath, state)
	log.printf("update installed version=%s", candidate.Manifest.Version)
	showMessage(
		"LotCraft update installed",
		fmt.Sprintf(
			"LotCraft %s was installed successfully.\n\nThe new version becomes active when LotCraft is reattached or MetaTrader 5 is next restarted.",
			candidate.Manifest.Version,
		),
		mbOK|mbIconInformation|mbSetForeground,
	)
	return nil
}

func downloadAndInstallUpdate(
	checker lotupdate.Checker,
	candidate lotupdate.Candidate,
	installed installManifest,
	stateDir string,
	log *logger,
) error {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	installerBytes, err := checker.DownloadInstaller(ctx, candidate)
	cancel()
	if err != nil {
		return fmt.Errorf("download or verify signed installer: %w", err)
	}

	downloadDir, err := os.MkdirTemp(stateDir, "download-")
	if err != nil {
		return fmt.Errorf("create update download directory: %w", err)
	}
	installerPath := filepath.Join(downloadDir, candidate.Manifest.Installer.Name)
	defer func() {
		_ = os.Remove(installerPath)
		_ = os.Remove(downloadDir)
	}()
	if err := os.WriteFile(installerPath, installerBytes, 0o600); err != nil {
		return fmt.Errorf("write verified installer: %w", err)
	}
	writtenHash, err := hashFile(installerPath)
	if err != nil {
		return fmt.Errorf("rehash verified installer: %w", err)
	}
	info, err := os.Stat(installerPath)
	if err != nil {
		return err
	}
	if info.Size() != candidate.Manifest.Installer.Size ||
		!strings.EqualFold(writtenHash, candidate.Manifest.Installer.SHA256) {
		return errors.New("verified installer changed after it was written to disk")
	}

	installLog := filepath.Join(stateDir, "installer.log")
	command := exec.Command(
		installerPath,
		"-terminal-data-dir="+installed.SelectedTerminalDataDir,
		"-quiet",
		"-log="+installLog,
	)
	command.Stdout = nil
	command.Stderr = nil
	if err := command.Run(); err != nil {
		return fmt.Errorf("signed installer returned an error: %w", err)
	}
	updated, _, err := readVerifiedUpdaterInstall(installed.InstallPath)
	if err != nil {
		return fmt.Errorf("verify completed installation: %w", err)
	}
	if updated.Version != candidate.Manifest.Version {
		return fmt.Errorf(
			"completed installation reports version %s instead of %s",
			updated.Version,
			candidate.Manifest.Version,
		)
	}
	log.printf("installer completed version=%s sha256=%s", candidate.Manifest.Version, writtenHash)
	return nil
}

func readVerifiedUpdaterInstall(productDir string) (installManifest, string, error) {
	productDir, err := filepath.Abs(productDir)
	if err != nil {
		return installManifest{}, "", err
	}
	productDir = filepath.Clean(productDir)
	manifestPath := filepath.Join(productDir, manifestName)
	if err := validateRegularNonReparseFile(manifestPath); err != nil {
		return installManifest{}, "", fmt.Errorf("installed update manifest is unsafe: %w", err)
	}
	raw, err := os.ReadFile(manifestPath)
	if err != nil {
		return installManifest{}, "", fmt.Errorf("read installed update manifest: %w", err)
	}
	var manifest installManifest
	if err := json.Unmarshal(raw, &manifest); err != nil {
		return installManifest{}, "", fmt.Errorf("parse installed update manifest: %w", err)
	}
	if manifest.SchemaVersion != manifestSchema || manifest.Product != productName {
		return installManifest{}, "", errors.New("installed manifest is not updater-aware LotCraft schema 2")
	}
	if _, err := lotupdate.ParseVersion(manifest.Version); err != nil {
		return installManifest{}, "", fmt.Errorf("installed manifest version is invalid: %w", err)
	}
	if manifest.UpdaterSHA256 == "" || manifest.InstallerSHA256 == "" || manifest.InstalledEX5SHA256 == "" {
		return installManifest{}, "", errors.New("installed manifest is missing a required owned-file hash")
	}
	expectedOwned := map[string]bool{
		ex5Name: true, updaterName: true, uninstallName: true, manifestName: true,
	}
	if len(manifest.OwnedFiles) != len(expectedOwned) {
		return installManifest{}, "", errors.New("installed manifest owned-file inventory is not exact")
	}
	seen := map[string]bool{}
	for _, name := range manifest.OwnedFiles {
		if filepath.Base(name) != name || !expectedOwned[name] || seen[name] {
			return installManifest{}, "", errors.New("installed manifest contains an unsafe owned-file inventory")
		}
		seen[name] = true
	}

	installResolved, err := resolveExistingPath(productDir)
	if err != nil {
		return installManifest{}, "", fmt.Errorf("resolve installed product directory: %w", err)
	}
	if !sameWindowsPath(installResolved, manifest.InstallResolved) {
		return installManifest{}, "", errors.New("installed product directory no longer matches its verified manifest")
	}
	expertsResolved, err := resolveExistingPath(manifest.ExpertsPath)
	if err != nil {
		return installManifest{}, "", fmt.Errorf("resolve installed Experts directory: %w", err)
	}
	if !sameWindowsPath(expertsResolved, manifest.ExpertsResolved) {
		return installManifest{}, "", errors.New("installed Experts directory no longer matches its verified manifest")
	}
	inside, err := policy.Within(expertsResolved, installResolved)
	if err != nil || !inside {
		return installManifest{}, "", errors.New("installed LotCraft directory is outside its verified Experts root")
	}
	if err := validateTerminalDataDir(manifest.SelectedTerminalDataDir); err != nil {
		return installManifest{}, "", fmt.Errorf("recorded terminal data directory is no longer valid: %w", err)
	}
	selectedResolved, err := resolveExistingPath(manifest.SelectedTerminalDataDir)
	if err != nil || !sameWindowsPath(selectedResolved, manifest.SelectedTerminalResolved) {
		return installManifest{}, "", errors.New("recorded terminal data directory no longer matches its verified destination")
	}
	for _, owned := range []struct {
		name string
		hash string
	}{
		{ex5Name, manifest.InstalledEX5SHA256},
		{updaterName, manifest.UpdaterSHA256},
		{uninstallName, manifest.InstallerSHA256},
	} {
		if err := verifyRequiredOwnedFileHash(filepath.Join(productDir, owned.name), owned.hash); err != nil {
			return installManifest{}, "", fmt.Errorf("verify installed %s: %w", owned.name, err)
		}
	}
	return manifest, installResolved, nil
}

func verifyRequiredOwnedFileHash(path, expected string) error {
	if expected == "" {
		return errors.New("expected SHA-256 is missing")
	}
	if err := validateRegularNonReparseFile(path); err != nil {
		return err
	}
	actual, err := hashFile(path)
	if err != nil {
		return err
	}
	if !strings.EqualFold(actual, expected) {
		return fmt.Errorf("SHA-256 mismatch expected=%s actual=%s", expected, actual)
	}
	return nil
}

func updaterInstallationID(installResolved string) string {
	sum := sha256.Sum256([]byte(strings.ToLower(filepath.Clean(installResolved))))
	return hex.EncodeToString(sum[:16])
}

func updaterStateDirectory(installationID string) (string, error) {
	local := os.Getenv("LOCALAPPDATA")
	if local == "" {
		return "", errors.New("LOCALAPPDATA is unavailable")
	}
	return filepath.Join(local, "LotCraft", "Updater", installationID), nil
}

func loadUpdaterState(path, installationID string) (lotupdate.State, error) {
	raw, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return lotupdate.State{SchemaVersion: updateStateSchema, InstallationID: installationID}, nil
	}
	if err != nil {
		return lotupdate.State{}, err
	}
	var state lotupdate.State
	decoder := json.NewDecoder(bytes.NewReader(raw))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&state); err != nil {
		return lotupdate.State{}, err
	}
	if state.SchemaVersion != updateStateSchema || state.InstallationID != installationID {
		return lotupdate.State{}, errors.New("updater state identity or schema does not match this installation")
	}
	return state, nil
}

func saveUpdaterState(path string, state lotupdate.State) error {
	raw, err := json.MarshalIndent(state, "", "  ")
	if err != nil {
		return err
	}
	raw = append(raw, '\r', '\n')
	temp, err := os.CreateTemp(filepath.Dir(path), ".state-*.tmp")
	if err != nil {
		return err
	}
	tempPath := temp.Name()
	ok := false
	defer func() {
		_ = temp.Close()
		if !ok {
			_ = os.Remove(tempPath)
		}
	}()
	if _, err := temp.Write(raw); err != nil {
		return err
	}
	if err := temp.Sync(); err != nil {
		return err
	}
	if err := temp.Close(); err != nil {
		return err
	}
	if err := moveFile(tempPath, path, true); err != nil {
		return err
	}
	ok = true
	return nil
}

func rotateUpdaterLog(path string) error {
	info, err := os.Stat(path)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("inspect updater log: %w", err)
	}
	if info.Size() < updateLogLimit {
		return nil
	}
	previous := path + ".1"
	_ = os.Remove(previous)
	if err := os.Rename(path, previous); err != nil {
		return fmt.Errorf("rotate updater log: %w", err)
	}
	return nil
}

func acquireUpdaterMutex(installationID string) (*namedMutex, bool, error) {
	name := "Local\\LotCraft-Updater-" + installationID
	namePtr, err := syscall.UTF16PtrFromString(name)
	if err != nil {
		return nil, false, err
	}
	handle, _, callErr := procCreateMutexW.Call(0, 0, uintptr(unsafe.Pointer(namePtr)))
	if handle == 0 {
		return nil, false, windowsCallError("CreateMutexW", callErr)
	}
	if errors.Is(callErr, errorAlreadyExists) {
		procCloseHandle.Call(handle)
		return nil, false, nil
	}
	return &namedMutex{handle: handle}, true, nil
}

func (mutex *namedMutex) Close() {
	if mutex != nil && mutex.handle != 0 {
		procCloseHandle.Call(mutex.handle)
		mutex.handle = 0
	}
}

func scheduleUpdaterWorkerDeletion() {
	self := executablePath()
	_ = scheduleDeleteAtReboot(self)
}

func appendEmergencyUpdaterLog(updateErr error) {
	local := os.Getenv("LOCALAPPDATA")
	if local == "" {
		return
	}
	directory := filepath.Join(local, "LotCraft", "Updater")
	if err := os.MkdirAll(directory, 0o700); err != nil {
		return
	}
	path := filepath.Join(directory, "bootstrap.log")
	file, err := os.OpenFile(path, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o600)
	if err != nil {
		return
	}
	defer file.Close()
	_, _ = fmt.Fprintf(file, "%s LotCraft updater failure: %v\r\n", time.Now().UTC().Format(time.RFC3339Nano), updateErr)
}
