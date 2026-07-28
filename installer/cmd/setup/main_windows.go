//go:build windows

package main

import (
	"crypto/sha256"
	_ "embed"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"syscall"
	"time"
	"unsafe"

	"lotcraft.local/installer/internal/policy"
	lotupdate "lotcraft.local/installer/internal/update"
)

//go:embed embedded_payload.txt
var embeddedEX5 []byte

const (
	productName       = "LotCraft"
	productVersion    = "1.0.0"
	setupTitle        = "LotCraft 1.0.0 Setup"
	ex5Name           = "LotCraft.ex5"
	updaterName       = "LotCraft-Updater.exe"
	uninstallName     = "LotCraft-Uninstall.exe"
	manifestName      = "LotCraft-install.json"
	defaultInstallRel = `MQL5\Experts\LotCraft`
	manifestSchema    = 2

	fileAttributeDirectory    = 0x00000010
	fileAttributeReparsePoint = 0x00000400
	invalidFileAttributes     = 0xFFFFFFFF
	fileShareRead             = 0x00000001
	fileShareWrite            = 0x00000002
	fileShareDelete           = 0x00000004
	openExisting              = 3
	fileFlagBackupSemantics   = 0x02000000

	moveFileReplaceExisting  = 0x00000001
	moveFileDelayUntilReboot = 0x00000004
	moveFileWriteThrough     = 0x00000008

	mbOK              = 0x00000000
	mbYesNo           = 0x00000004
	mbIconError       = 0x00000010
	mbIconQuestion    = 0x00000020
	mbIconWarning     = 0x00000030
	mbIconInformation = 0x00000040
	mbSetForeground   = 0x00010000
	idYes             = 6

	bifReturnOnlyFSDirs = 0x00000001
	bifEditBox          = 0x00000010
	bifNewDialogStyle   = 0x00000040
)

var (
	kernel32                     = syscall.NewLazyDLL("kernel32.dll")
	user32                       = syscall.NewLazyDLL("user32.dll")
	shell32                      = syscall.NewLazyDLL("shell32.dll")
	ole32                        = syscall.NewLazyDLL("ole32.dll")
	procGetFileAttributesW       = kernel32.NewProc("GetFileAttributesW")
	procCreateFileW              = kernel32.NewProc("CreateFileW")
	procCloseHandle              = kernel32.NewProc("CloseHandle")
	procGetFinalPathNameByHandle = kernel32.NewProc("GetFinalPathNameByHandleW")
	procMoveFileExW              = kernel32.NewProc("MoveFileExW")
	procMessageBoxW              = user32.NewProc("MessageBoxW")
	procSHBrowseForFolderW       = shell32.NewProc("SHBrowseForFolderW")
	procSHGetPathFromIDListW     = shell32.NewProc("SHGetPathFromIDListW")
	procCoTaskMemFree            = ole32.NewProc("CoTaskMemFree")
)

type options struct {
	terminalRoot  string
	payload       string
	uninstall     bool
	allowReparse  bool
	quiet         bool
	logPath       string
	versionOnly   bool
	cleanupTarget string
	cleanupDir    string
	cleanupParent int
	checkUpdate   bool
	updaterWorker bool
	productDir    string
}

type installManifest struct {
	SchemaVersion             int      `json:"schema_version,omitempty"`
	Product                   string   `json:"product"`
	Version                   string   `json:"version"`
	InstalledAtUTC            string   `json:"installed_at_utc"`
	SelectedTerminalDataDir   string   `json:"selected_terminal_data_dir"`
	SelectedTerminalResolved  string   `json:"selected_terminal_resolved"`
	ExpertsPath               string   `json:"experts_path"`
	ExpertsResolved           string   `json:"experts_resolved"`
	InstallPath               string   `json:"install_path"`
	InstallResolved           string   `json:"install_resolved"`
	CanonicalEX5Path          string   `json:"canonical_ex5_path"`
	CanonicalEX5SHA256        string   `json:"canonical_ex5_sha256"`
	StagedEX5SHA256           string   `json:"staged_ex5_sha256"`
	InstalledEX5SHA256        string   `json:"installed_ex5_sha256"`
	InstallerSHA256           string   `json:"installer_sha256"`
	UpdaterSHA256             string   `json:"updater_sha256,omitempty"`
	OwnedFiles                []string `json:"owned_files"`
	ReparseComponentsObserved []string `json:"reparse_components_observed,omitempty"`
}

type browseInfo struct {
	owner       uintptr
	root        uintptr
	displayName *uint16
	title       *uint16
	flags       uint32
	callback    uintptr
	param       uintptr
	image       int32
}

type logger struct {
	file  *os.File
	quiet bool
}

func main() {
	opt := parseOptions()
	if opt.cleanupTarget != "" {
		if err := runCleanupHelper(opt); err != nil {
			os.Exit(1)
		}
		return
	}
	base := strings.ToLower(filepath.Base(executablePath()))
	if opt.checkUpdate || opt.updaterWorker || strings.Contains(base, "updater") {
		if err := runUpdaterMode(opt); err != nil {
			// Background update-check failures are intentionally silent. The
			// updater writes the exact reason to its local rotating log.
			os.Exit(1)
		}
		return
	}
	logPath := opt.logPath
	if logPath == "" {
		logPath = filepath.Join(os.TempDir(), "LotCraft-1.0.0-install.log")
	}
	log, err := newLogger(logPath, opt.quiet)
	if err != nil {
		showMessage(setupTitle, "Cannot create installer log: "+err.Error(), mbOK|mbIconError|mbSetForeground)
		os.Exit(1)
	}
	defer log.close()

	log.printf("start product=%s version=%s executable=%s", productName, productVersion, executablePath())
	if opt.versionOnly {
		message := productName + " " + productVersion + "\nWindows installer"
		log.printf(message)
		if !opt.quiet {
			showMessage(setupTitle, message, mbOK|mbIconInformation|mbSetForeground)
		}
		return
	}

	if opt.uninstall || strings.Contains(base, "uninstall") {
		if err := runUninstall(opt, log); err != nil {
			log.fatal(err)
		}
		return
	}
	if err := runInstall(opt, log); err != nil {
		log.fatal(err)
	}
}

func parseOptions() options {
	var opt options
	flag.StringVar(&opt.terminalRoot, "terminal-data-dir", "", "MT5 terminal data directory")
	flag.StringVar(&opt.payload, "payload", "", "canonical LotCraft.ex5 path")
	flag.BoolVar(&opt.uninstall, "uninstall", false, "uninstall LotCraft-owned files")
	flag.BoolVar(&opt.allowReparse, "allow-reparse", false, "accept the displayed resolved MQL5\\Experts destination")
	flag.BoolVar(&opt.quiet, "quiet", false, "do not display dialogs")
	flag.StringVar(&opt.logPath, "log", "", "installer log path")
	flag.BoolVar(&opt.versionOnly, "version", false, "show installer version")
	flag.StringVar(&opt.cleanupTarget, "cleanup-target", "", "internal post-uninstall cleanup target")
	flag.StringVar(&opt.cleanupDir, "cleanup-dir", "", "internal post-uninstall product directory")
	flag.IntVar(&opt.cleanupParent, "cleanup-parent-pid", 0, "internal post-uninstall parent process")
	flag.BoolVar(&opt.checkUpdate, "check-update", false, "check the latest signed stable release")
	flag.BoolVar(&opt.updaterWorker, "updater-worker", false, "internal detached updater worker")
	flag.StringVar(&opt.productDir, "product-dir", "", "internal verified LotCraft installation directory")
	flag.Parse()
	return opt
}

func newLogger(path string, quiet bool) (*logger, error) {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return nil, err
	}
	f, err := os.OpenFile(path, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o600)
	if err != nil {
		return nil, err
	}
	return &logger{file: f, quiet: quiet}, nil
}

func (l *logger) close() { _ = l.file.Close() }
func (l *logger) printf(format string, args ...any) {
	line := fmt.Sprintf(format, args...)
	_, _ = fmt.Fprintf(l.file, "%s LotCraft %s\r\n", time.Now().UTC().Format(time.RFC3339Nano), line)
	_ = l.file.Sync()
}
func (l *logger) fatal(err error) {
	l.printf("failure: %v", err)
	if !l.quiet {
		showMessage(setupTitle, "Installation did not complete.\n\n"+err.Error()+"\n\nLog: "+l.file.Name(), mbOK|mbIconError|mbSetForeground)
	}
	os.Exit(1)
}

func runInstall(opt options, log *logger) error {
	terminalRoot, err := selectTerminalRoot(opt, log)
	if err != nil {
		return err
	}
	terminalRoot, err = filepath.Abs(terminalRoot)
	if err != nil {
		return fmt.Errorf("resolve selected terminal data directory: %w", err)
	}
	terminalRoot = filepath.Clean(terminalRoot)
	if err := validateTerminalDataDir(terminalRoot); err != nil {
		return err
	}

	selectedResolved, err := resolveExistingPath(terminalRoot)
	if err != nil {
		return fmt.Errorf("resolve selected terminal data directory: %w", err)
	}
	expertsPath := filepath.Join(terminalRoot, "MQL5", "Experts")
	if err := os.MkdirAll(expertsPath, 0o755); err != nil {
		return fmt.Errorf("create MQL5\\Experts: %w", err)
	}
	expertsResolved, err := resolveExistingPath(expertsPath)
	if err != nil {
		return fmt.Errorf("resolve MQL5\\Experts: %w", err)
	}

	installPath := filepath.Join(expertsPath, productName)
	if err := os.MkdirAll(installPath, 0o755); err != nil {
		return fmt.Errorf("create dedicated destination %s: %w", installPath, err)
	}
	installResolved, err := resolveExistingPath(installPath)
	if err != nil {
		return fmt.Errorf("resolve dedicated destination: %w", err)
	}
	inside, err := policy.Within(expertsResolved, installResolved)
	if err != nil || !inside {
		return fmt.Errorf("resolved destination escapes the selected terminal's MQL5\\Experts ownership root: experts=%s destination=%s", expertsResolved, installResolved)
	}

	reparseObserved := uniqueSorted(append(
		append(reparseComponents(terminalRoot), reparseComponents(expertsPath)...),
		reparseComponents(installPath)...,
	))
	if len(reparseObserved) > 0 {
		message := "A junction, symbolic link, or mount point was detected.\n\n" +
			"Selected data directory:\n" + terminalRoot + "\n\n" +
			"Resolved MQL5\\Experts ownership root:\n" + expertsResolved + "\n\n" +
			"Resolved final product directory:\n" + installResolved + "\n\n" +
			"The final product directory has been validated as remaining inside the resolved Experts root. Continue?"
		if !opt.allowReparse {
			if opt.quiet {
				return errors.New("reparse path requires --allow-reparse after independently validating the resolved destination")
			}
			if showMessage(setupTitle, message, mbYesNo|mbIconWarning|mbSetForeground) != idYes {
				return errors.New("installation cancelled at reparse-path confirmation")
			}
		}
		log.printf("reparse accepted components=%q experts_resolved=%s install_resolved=%s", strings.Join(reparseObserved, ";"), expertsResolved, installResolved)
	}
	if err := validateExistingInstallOwnership(installPath, installResolved, expertsResolved); err != nil {
		return fmt.Errorf("existing destination ownership check failed: %w", err)
	}

	payloadPath := opt.payload
	embeddedPayloadPath := ""
	if payloadPath == "" {
		embeddedPayloadPath, err = materializeEmbeddedPayload()
		if err != nil {
			return err
		}
		defer func() {
			_ = os.Remove(embeddedPayloadPath)
			_ = os.Remove(filepath.Dir(embeddedPayloadPath))
		}()
		payloadPath = embeddedPayloadPath
	}
	payloadPath, err = filepath.Abs(payloadPath)
	if err != nil {
		return fmt.Errorf("resolve canonical EX5 path: %w", err)
	}
	payloadPath = filepath.Clean(payloadPath)
	if !strings.EqualFold(filepath.Base(payloadPath), ex5Name) {
		return fmt.Errorf("canonical payload must be named exactly %s; got %s", ex5Name, filepath.Base(payloadPath))
	}
	if err := validateRegularNonReparseFile(payloadPath); err != nil {
		return fmt.Errorf("canonical EX5 is unavailable or unsafe: %w", err)
	}
	payloadInfo, err := os.Stat(payloadPath)
	if err != nil {
		return err
	}
	if payloadInfo.Size() <= 0 {
		return errors.New("canonical LotCraft.ex5 is empty")
	}

	selfPath := executablePath()
	if err := validateRegularNonReparseFile(selfPath); err != nil {
		return fmt.Errorf("installer executable is unsafe: %w", err)
	}
	canonicalHash, err := hashFile(payloadPath)
	if err != nil {
		return fmt.Errorf("hash canonical EX5: %w", err)
	}
	installerHash, err := hashFile(selfPath)
	if err != nil {
		return fmt.Errorf("hash installer: %w", err)
	}

	ex5Temp, stagedHash, err := copyToTempAndHash(payloadPath, installPath, ".LotCraft-ex5-*.tmp")
	if err != nil {
		return fmt.Errorf("stage EX5: %w", err)
	}
	if stagedHash != canonicalHash {
		_ = os.Remove(ex5Temp)
		return errors.New("staged EX5 SHA-256 differs from canonical EX5")
	}
	uninstallTemp, uninstallHash, err := copyToTempAndHash(selfPath, installPath, ".LotCraft-uninstall-*.tmp")
	if err != nil {
		_ = os.Remove(ex5Temp)
		return fmt.Errorf("stage uninstaller: %w", err)
	}
	if uninstallHash != installerHash {
		_ = os.Remove(ex5Temp)
		_ = os.Remove(uninstallTemp)
		return errors.New("staged uninstaller SHA-256 differs from installer")
	}
	updaterTemp, updaterHash, err := copyToTempAndHash(selfPath, installPath, ".LotCraft-updater-*.tmp")
	if err != nil {
		_ = os.Remove(ex5Temp)
		_ = os.Remove(uninstallTemp)
		return fmt.Errorf("stage updater: %w", err)
	}
	if updaterHash != installerHash {
		_ = os.Remove(ex5Temp)
		_ = os.Remove(uninstallTemp)
		_ = os.Remove(updaterTemp)
		return errors.New("staged updater SHA-256 differs from installer")
	}

	manifest := installManifest{
		SchemaVersion:             manifestSchema,
		Product:                   productName,
		Version:                   productVersion,
		InstalledAtUTC:            time.Now().UTC().Format(time.RFC3339),
		SelectedTerminalDataDir:   terminalRoot,
		SelectedTerminalResolved:  selectedResolved,
		ExpertsPath:               expertsPath,
		ExpertsResolved:           expertsResolved,
		InstallPath:               installPath,
		InstallResolved:           installResolved,
		CanonicalEX5Path:          payloadPath,
		CanonicalEX5SHA256:        canonicalHash,
		StagedEX5SHA256:           stagedHash,
		InstalledEX5SHA256:        stagedHash,
		InstallerSHA256:           installerHash,
		UpdaterSHA256:             updaterHash,
		OwnedFiles:                []string{ex5Name, updaterName, uninstallName, manifestName},
		ReparseComponentsObserved: reparseObserved,
	}
	manifestTemp, err := writeJSONTemp(manifest, installPath)
	if err != nil {
		_ = os.Remove(ex5Temp)
		_ = os.Remove(uninstallTemp)
		_ = os.Remove(updaterTemp)
		return fmt.Errorf("stage install manifest: %w", err)
	}

	prepared := []*preparedFile{
		{temp: ex5Temp, final: filepath.Join(installPath, ex5Name)},
		{temp: updaterTemp, final: filepath.Join(installPath, updaterName)},
		{temp: uninstallTemp, final: filepath.Join(installPath, uninstallName)},
		{temp: manifestTemp, final: filepath.Join(installPath, manifestName)},
	}
	if err := commitPrepared(prepared); err != nil {
		return fmt.Errorf("commit installation atomically: %w", err)
	}

	installedPath := filepath.Join(installPath, ex5Name)
	installedResolved, err := resolveExistingPath(installedPath)
	if err != nil {
		rollbackPrepared(prepared)
		return fmt.Errorf("resolve installed EX5: %w", err)
	}
	inside, err = policy.Within(expertsResolved, installedResolved)
	if err != nil || !inside {
		rollbackPrepared(prepared)
		return fmt.Errorf("installed EX5 escaped resolved MQL5\\Experts root: %s", installedResolved)
	}
	installedHash, err := hashFile(installedPath)
	if err != nil || installedHash != canonicalHash {
		rollbackPrepared(prepared)
		if err != nil {
			return fmt.Errorf("hash installed EX5: %w", err)
		}
		return errors.New("installed EX5 SHA-256 differs from canonical EX5")
	}
	finalizePrepared(prepared)

	log.printf("success selected=%s selected_resolved=%s experts_resolved=%s final=%s", terminalRoot, selectedResolved, expertsResolved, installedResolved)
	log.printf("hash canonical_ex5=%s staged_ex5=%s installed_ex5=%s installer=%s updater=%s", canonicalHash, stagedHash, installedHash, installerHash, updaterHash)
	if !opt.quiet {
		showMessage(setupTitle,
			"LotCraft 1.0.0 was installed successfully.\n\nFinal destination:\n"+installedResolved+"\n\nSHA-256:\n"+installedHash+"\n\nRestart MetaTrader 5 or refresh the Navigator before attaching the EA.",
			mbOK|mbIconInformation|mbSetForeground)
	}
	return nil
}

func materializeEmbeddedPayload() (string, error) {
	if len(embeddedEX5) < 1024 {
		return "", errors.New("the installer does not contain a compiled LotCraft EA payload; use scripts/build_release.ps1")
	}
	directory, err := os.MkdirTemp("", "LotCraft-payload-*")
	if err != nil {
		return "", fmt.Errorf("create temporary payload directory: %w", err)
	}
	path := filepath.Join(directory, ex5Name)
	if err := os.WriteFile(path, embeddedEX5, 0o600); err != nil {
		_ = os.Remove(directory)
		return "", fmt.Errorf("write embedded LotCraft payload: %w", err)
	}
	return path, nil
}

func runUninstall(opt options, log *logger) error {
	self := executablePath()
	productDir := filepath.Dir(self)
	if !strings.Contains(strings.ToLower(filepath.Base(self)), "uninstall") {
		if opt.terminalRoot == "" {
			if opt.quiet {
				return errors.New("--terminal-data-dir is required for quiet uninstall outside the installed uninstaller")
			}
			root, err := selectTerminalRoot(opt, log)
			if err != nil {
				return err
			}
			productDir = filepath.Join(root, defaultInstallRel)
		} else {
			productDir = filepath.Join(opt.terminalRoot, defaultInstallRel)
		}
	}
	productDir, err := filepath.Abs(productDir)
	if err != nil {
		return err
	}
	productDir = filepath.Clean(productDir)

	manifestPath := filepath.Join(productDir, manifestName)
	raw, err := os.ReadFile(manifestPath)
	if err != nil {
		return fmt.Errorf("read LotCraft install manifest: %w", err)
	}
	var manifest installManifest
	if err := json.Unmarshal(raw, &manifest); err != nil {
		return fmt.Errorf("parse install manifest: %w", err)
	}
	if manifest.Product != productName || manifest.Version != productVersion {
		return fmt.Errorf("manifest identity mismatch: product=%q version=%q", manifest.Product, manifest.Version)
	}
	if manifest.SchemaVersion != manifestSchema {
		return fmt.Errorf("manifest schema %d is unsupported by this uninstaller", manifest.SchemaVersion)
	}
	expectedOwned := map[string]bool{
		ex5Name: true, updaterName: true, uninstallName: true, manifestName: true,
	}
	if len(manifest.OwnedFiles) != len(expectedOwned) {
		return errors.New("manifest owned-file inventory is not exact")
	}
	seenOwned := make(map[string]bool, len(expectedOwned))
	for _, name := range manifest.OwnedFiles {
		if filepath.Base(name) != name || !expectedOwned[name] || seenOwned[name] {
			return errors.New("manifest contains an unexpected, duplicate, or nonlocal owned filename")
		}
		seenOwned[name] = true
	}
	currentProductResolved, err := resolveExistingPath(productDir)
	if err != nil {
		return fmt.Errorf("resolve current product directory: %w", err)
	}
	if !sameWindowsPath(currentProductResolved, manifest.InstallResolved) {
		return fmt.Errorf("product directory resolution changed; refusing deletion: recorded=%s current=%s", manifest.InstallResolved, currentProductResolved)
	}
	currentExpertsResolved, err := resolveExistingPath(manifest.ExpertsPath)
	if err != nil {
		return fmt.Errorf("resolve recorded MQL5\\Experts root: %w", err)
	}
	if !sameWindowsPath(currentExpertsResolved, manifest.ExpertsResolved) {
		return fmt.Errorf("MQL5\\Experts link target changed; refusing deletion: recorded=%s current=%s", manifest.ExpertsResolved, currentExpertsResolved)
	}
	inside, err := policy.Within(currentExpertsResolved, currentProductResolved)
	if err != nil || !inside {
		return errors.New("recorded product directory is no longer inside the verified MQL5\\Experts root")
	}

	ex5Path := filepath.Join(productDir, ex5Name)
	updaterPath := filepath.Join(productDir, updaterName)
	uninstallerPath := filepath.Join(productDir, uninstallName)
	// Validate every hash-protected owned file before deleting any of them. This
	// keeps a tampered uninstaller or payload from leaving an unrecoverable
	// half-uninstalled directory with its manifest already removed.
	if err := verifyOwnedFileHashIfPresent(ex5Path, manifest.InstalledEX5SHA256); err != nil {
		return fmt.Errorf("verify installed EX5 before uninstall: %w", err)
	}
	if err := verifyOwnedFileHashIfPresent(uninstallerPath, manifest.InstallerSHA256); err != nil {
		return fmt.Errorf("verify installed uninstaller before uninstall: %w", err)
	}
	if err := verifyOwnedFileHashIfPresent(updaterPath, manifest.UpdaterSHA256); err != nil {
		return fmt.Errorf("verify installed updater before uninstall: %w", err)
	}
	if err := validateRegularNonReparseFile(manifestPath); err != nil {
		return fmt.Errorf("manifest is unsafe: %w", err)
	}

	if !opt.quiet {
		message := "Remove LotCraft 1.0.0 from:\n" + currentProductResolved + "\n\nOnly the four installer-owned files will be removed. Unrelated files will be preserved."
		if showMessage(setupTitle, message, mbYesNo|mbIconQuestion|mbSetForeground) != idYes {
			return errors.New("uninstall cancelled")
		}
	}

	if err := removeOwnedFile(ex5Path, manifest.InstalledEX5SHA256, log); err != nil {
		return fmt.Errorf("remove installed EX5: %w", err)
	}
	if err := removeOwnedFile(updaterPath, manifest.UpdaterSHA256, log); err != nil {
		return fmt.Errorf("remove installed updater: %w", err)
	}

	if sameWindowsPath(uninstallerPath, self) {
		if err := validateRegularNonReparseFile(uninstallerPath); err != nil {
			return fmt.Errorf("installed uninstaller is unsafe: %w", err)
		}
		selfHash, err := hashFile(uninstallerPath)
		if err != nil {
			return fmt.Errorf("hash installed uninstaller: %w", err)
		}
		if manifest.InstallerSHA256 == "" || !strings.EqualFold(selfHash, manifest.InstallerSHA256) {
			return fmt.Errorf("installed uninstaller SHA-256 mismatch; refusing self-deletion: expected=%s actual=%s", manifest.InstallerSHA256, selfHash)
		}
		if err := scheduleSelfDelete(uninstallerPath, productDir); err != nil {
			// A reboot-time delete is the safe fallback if the transient helper cannot start.
			if fallbackErr := scheduleDeleteAtReboot(uninstallerPath); fallbackErr != nil {
				return fmt.Errorf("schedule uninstaller removal: helper=%v fallback=%v", err, fallbackErr)
			}
			log.printf("uninstaller scheduled for deletion at reboot")
		} else {
			log.printf("uninstaller scheduled for immediate post-exit deletion")
		}
	} else if err := removeOwnedFile(uninstallerPath, manifest.InstallerSHA256, log); err != nil {
		return fmt.Errorf("remove copied uninstaller: %w", err)
	}
	// Keep the ownership record until every other owned-file removal has either
	// completed or, for the running uninstaller, been safely scheduled.
	if err := os.Remove(manifestPath); err != nil && !errors.Is(err, os.ErrNotExist) {
		return fmt.Errorf("remove install manifest: %w", err)
	}

	log.printf("uninstall complete product_dir=%s", currentProductResolved)
	if !opt.quiet {
		showMessage(setupTitle, "LotCraft 1.0.0 owned files were removed.\n\nDirectory checked:\n"+currentProductResolved+"\n\nAny unrelated files in that directory were preserved.", mbOK|mbIconInformation|mbSetForeground)
	}
	return nil
}

func selectTerminalRoot(opt options, log *logger) (string, error) {
	if opt.terminalRoot != "" {
		return opt.terminalRoot, nil
	}
	if opt.quiet {
		return "", errors.New("--terminal-data-dir is required in quiet mode")
	}
	candidates := discoverTerminalDataDirs()
	log.printf("discovered terminal data directories=%q", strings.Join(candidates, ";"))
	if len(candidates) == 1 {
		message := "Use this discovered MetaTrader 5 terminal data directory?\n\n" + candidates[0]
		if showMessage(setupTitle, message, mbYesNo|mbIconQuestion|mbSetForeground) == idYes {
			return candidates[0], nil
		}
	} else if len(candidates) > 1 {
		shown := candidates
		if len(shown) > 8 {
			shown = shown[:8]
		}
		showMessage(setupTitle, "Multiple MetaTrader 5 data directories were discovered. Select the intended terminal in the next dialog.\n\n"+strings.Join(shown, "\n"), mbOK|mbIconInformation|mbSetForeground)
	}
	selected, err := browseForFolder("Select the MetaTrader 5 terminal data directory (the folder containing MQL5)")
	if err != nil {
		return "", err
	}
	if selected == "" {
		return "", errors.New("no MetaTrader 5 terminal data directory was selected")
	}
	return selected, nil
}

func discoverTerminalDataDirs() []string {
	appData := os.Getenv("APPDATA")
	if appData == "" {
		return nil
	}
	base := filepath.Join(appData, "MetaQuotes", "Terminal")
	entries, err := os.ReadDir(base)
	if err != nil {
		return nil
	}
	var out []string
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		candidate := filepath.Join(base, entry.Name())
		if validateTerminalDataDir(candidate) == nil {
			out = append(out, candidate)
		}
	}
	sort.Strings(out)
	return out
}

func validateTerminalDataDir(root string) error {
	info, err := os.Stat(root)
	if err != nil || !info.IsDir() {
		return fmt.Errorf("selected path is not an accessible directory: %s", root)
	}
	mql5 := filepath.Join(root, "MQL5")
	info, err = os.Stat(mql5)
	if err != nil || !info.IsDir() {
		return fmt.Errorf("selected directory is not an MT5 data directory because MQL5 is missing: %s", root)
	}
	markers := []string{"config", "bases", "history", "logs", "origin.txt"}
	markerFound := false
	for _, name := range markers {
		if _, err := os.Stat(filepath.Join(root, name)); err == nil {
			markerFound = true
			break
		}
	}
	if !markerFound {
		return fmt.Errorf("selected directory lacks normal MT5 terminal-data markers (config, bases, history, logs, or origin.txt): %s", root)
	}
	return nil
}

func validateRegularNonReparseFile(path string) error {
	info, err := os.Stat(path)
	if err != nil {
		return err
	}
	if !info.Mode().IsRegular() {
		return errors.New("path is not a regular file")
	}
	attrs, err := getFileAttributes(path)
	if err != nil {
		return err
	}
	if attrs&fileAttributeReparsePoint != 0 {
		return errors.New("file is a reparse point")
	}
	return nil
}

func validateExistingInstallOwnership(installPath, installResolved, expertsResolved string) error {
	manifestPath := filepath.Join(installPath, manifestName)
	finalPaths := []string{
		filepath.Join(installPath, ex5Name),
		filepath.Join(installPath, updaterName),
		filepath.Join(installPath, uninstallName),
		manifestPath,
	}
	anyExisting := false
	for _, path := range finalPaths {
		if _, err := os.Lstat(path); err == nil {
			anyExisting = true
		} else if !errors.Is(err, os.ErrNotExist) {
			return fmt.Errorf("inspect existing destination path %s: %w", path, err)
		}
	}
	if !anyExisting {
		return nil
	}
	if _, err := os.Lstat(manifestPath); err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return errors.New("an installer-owned filename already exists without a LotCraft install manifest; refusing to overwrite it")
		}
		return err
	}
	if err := validateRegularNonReparseFile(manifestPath); err != nil {
		return fmt.Errorf("existing install manifest is unsafe: %w", err)
	}
	raw, err := os.ReadFile(manifestPath)
	if err != nil {
		return fmt.Errorf("read existing install manifest: %w", err)
	}
	var manifest installManifest
	if err := json.Unmarshal(raw, &manifest); err != nil {
		return fmt.Errorf("parse existing install manifest: %w", err)
	}
	if manifest.Product != productName {
		return fmt.Errorf("existing manifest identity mismatch: product=%q version=%q", manifest.Product, manifest.Version)
	}
	existingVersion, err := lotupdate.ParseVersion(manifest.Version)
	if err != nil {
		return fmt.Errorf("existing manifest version is invalid: %w", err)
	}
	installingVersion, err := lotupdate.ParseVersion(productVersion)
	if err != nil {
		return fmt.Errorf("installer version is invalid: %w", err)
	}
	if existingVersion.Compare(installingVersion) > 0 {
		return fmt.Errorf("refusing to downgrade existing LotCraft %s to %s", manifest.Version, productVersion)
	}
	if !sameWindowsPath(manifest.InstallResolved, installResolved) ||
		!sameWindowsPath(manifest.ExpertsResolved, expertsResolved) {
		return errors.New("existing manifest ownership paths do not match the currently resolved destination")
	}
	inside, err := policy.Within(expertsResolved, installResolved)
	if err != nil || !inside {
		return errors.New("existing product directory is not inside the verified MQL5\\Experts root")
	}

	schema := manifest.SchemaVersion
	if schema == 0 {
		schema = 1
	}
	expectedOwned := map[string]bool{
		ex5Name:       true,
		uninstallName: true,
		manifestName:  true,
	}
	if schema == manifestSchema {
		expectedOwned[updaterName] = true
	} else if schema != 1 {
		return fmt.Errorf("existing manifest schema %d is unsupported", manifest.SchemaVersion)
	}
	if len(manifest.OwnedFiles) != len(expectedOwned) {
		return errors.New("existing manifest owned-file inventory is not exact")
	}
	seen := make(map[string]bool, len(expectedOwned))
	for _, name := range manifest.OwnedFiles {
		if !expectedOwned[name] || seen[name] || filepath.Base(name) != name {
			return errors.New("existing manifest contains an unexpected, duplicate, or nonlocal owned filename")
		}
		seen[name] = true
	}
	if err := verifyOwnedFileHashIfPresent(filepath.Join(installPath, ex5Name), manifest.InstalledEX5SHA256); err != nil {
		return fmt.Errorf("verify existing EX5 ownership: %w", err)
	}
	if err := verifyOwnedFileHashIfPresent(filepath.Join(installPath, uninstallName), manifest.InstallerSHA256); err != nil {
		return fmt.Errorf("verify existing uninstaller ownership: %w", err)
	}
	if schema == manifestSchema {
		if manifest.UpdaterSHA256 == "" {
			return errors.New("existing updater hash is missing")
		}
		if err := verifyOwnedFileHashIfPresent(filepath.Join(installPath, updaterName), manifest.UpdaterSHA256); err != nil {
			return fmt.Errorf("verify existing updater ownership: %w", err)
		}
	}
	return nil
}

func reparseComponents(path string) []string {
	abs, err := filepath.Abs(path)
	if err != nil {
		return []string{"<unresolved:" + path + ">"}
	}
	abs = filepath.Clean(abs)
	volume := filepath.VolumeName(abs)
	if volume == "" {
		return []string{"<no-volume:" + abs + ">"}
	}
	root := volume + `\`
	rest := strings.TrimPrefix(abs, root)
	current := root
	var found []string
	for _, part := range strings.Split(rest, `\`) {
		if part == "" {
			continue
		}
		current = filepath.Join(current, part)
		attrs, attrErr := getFileAttributes(current)
		if attrErr != nil {
			break
		}
		if attrs&fileAttributeReparsePoint != 0 {
			found = append(found, current)
		}
	}
	return found
}

func getFileAttributes(path string) (uint32, error) {
	p, err := syscall.UTF16PtrFromString(longPath(path))
	if err != nil {
		return 0, err
	}
	result, _, callErr := procGetFileAttributesW.Call(uintptr(unsafe.Pointer(p)))
	if uint32(result) == invalidFileAttributes {
		return 0, windowsCallError("GetFileAttributesW", callErr)
	}
	return uint32(result), nil
}

func resolveExistingPath(path string) (string, error) {
	p, err := syscall.UTF16PtrFromString(longPath(path))
	if err != nil {
		return "", err
	}
	handle, _, callErr := procCreateFileW.Call(
		uintptr(unsafe.Pointer(p)),
		0,
		fileShareRead|fileShareWrite|fileShareDelete,
		0,
		openExisting,
		fileFlagBackupSemantics,
		0,
	)
	if handle == ^uintptr(0) {
		return "", windowsCallError("CreateFileW", callErr)
	}
	defer procCloseHandle.Call(handle)

	buffer := make([]uint16, 32768)
	n, _, callErr := procGetFinalPathNameByHandle.Call(handle, uintptr(unsafe.Pointer(&buffer[0])), uintptr(len(buffer)), 0)
	if n == 0 || n >= uintptr(len(buffer)) {
		return "", windowsCallError("GetFinalPathNameByHandleW", callErr)
	}
	resolved := syscall.UTF16ToString(buffer[:n])
	resolved = stripExtendedPrefix(resolved)
	return filepath.Clean(resolved), nil
}

func longPath(path string) string {
	clean := filepath.Clean(path)
	if strings.HasPrefix(clean, `\\?\`) {
		return clean
	}
	if strings.HasPrefix(clean, `\\`) {
		return `\\?\UNC\` + strings.TrimPrefix(clean, `\\`)
	}
	return `\\?\` + clean
}

func stripExtendedPrefix(path string) string {
	lower := strings.ToLower(path)
	if strings.HasPrefix(lower, `\\?\unc\`) {
		return `\\` + path[len(`\\?\UNC\`):]
	}
	if strings.HasPrefix(lower, `\\?\`) {
		return path[len(`\\?\`):]
	}
	return path
}

func hashFile(path string) (string, error) {
	file, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer file.Close()
	h := sha256.New()
	if _, err := io.Copy(h, file); err != nil {
		return "", err
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}

func copyToTempAndHash(source, destinationDir, pattern string) (string, string, error) {
	input, err := os.Open(source)
	if err != nil {
		return "", "", err
	}
	defer input.Close()
	temp, err := os.CreateTemp(destinationDir, pattern)
	if err != nil {
		return "", "", err
	}
	tempPath := temp.Name()
	ok := false
	defer func() {
		_ = temp.Close()
		if !ok {
			_ = os.Remove(tempPath)
		}
	}()
	h := sha256.New()
	if _, err := io.Copy(io.MultiWriter(temp, h), input); err != nil {
		return "", "", err
	}
	if err := temp.Sync(); err != nil {
		return "", "", err
	}
	if err := temp.Close(); err != nil {
		return "", "", err
	}
	ok = true
	return tempPath, hex.EncodeToString(h.Sum(nil)), nil
}

func writeJSONTemp(manifest installManifest, destinationDir string) (string, error) {
	raw, err := json.MarshalIndent(manifest, "", "  ")
	if err != nil {
		return "", err
	}
	raw = append(raw, '\r', '\n')
	temp, err := os.CreateTemp(destinationDir, ".LotCraft-manifest-*.tmp")
	if err != nil {
		return "", err
	}
	path := temp.Name()
	ok := false
	defer func() {
		_ = temp.Close()
		if !ok {
			_ = os.Remove(path)
		}
	}()
	if _, err := temp.Write(raw); err != nil {
		return "", err
	}
	if err := temp.Sync(); err != nil {
		return "", err
	}
	if err := temp.Close(); err != nil {
		return "", err
	}
	ok = true
	return path, nil
}

type preparedFile struct {
	temp      string
	final     string
	backup    string
	hadOld    bool
	committed bool
}

func commitPrepared(files []*preparedFile) error {
	for _, file := range files {
		if _, err := os.Lstat(file.final); err == nil {
			if err := validateRegularNonReparseFile(file.final); err != nil {
				rollbackPrepared(files)
				return fmt.Errorf("existing owned path %s is unsafe: %w", file.final, err)
			}
			backup, err := reserveSiblingName(file.final, ".LotCraft-backup-*.tmp")
			if err != nil {
				rollbackPrepared(files)
				return err
			}
			_ = os.Remove(backup)
			if err := moveFile(file.final, backup, false); err != nil {
				rollbackPrepared(files)
				return err
			}
			file.backup = backup
			file.hadOld = true
		} else if !errors.Is(err, os.ErrNotExist) {
			rollbackPrepared(files)
			return err
		}
		if err := moveFile(file.temp, file.final, true); err != nil {
			rollbackPrepared(files)
			return err
		}
		file.committed = true
	}
	return nil
}

func rollbackPrepared(files []*preparedFile) {
	for i := len(files) - 1; i >= 0; i-- {
		file := files[i]
		if file.committed {
			_ = os.Remove(file.final)
			file.committed = false
		}
		if file.hadOld && file.backup != "" {
			_ = moveFile(file.backup, file.final, true)
		}
		if file.temp != "" {
			_ = os.Remove(file.temp)
		}
	}
}

func finalizePrepared(files []*preparedFile) {
	for _, file := range files {
		if file.backup != "" {
			_ = os.Remove(file.backup)
		}
		file.temp = ""
	}
}

func reserveSiblingName(final, pattern string) (string, error) {
	file, err := os.CreateTemp(filepath.Dir(final), pattern)
	if err != nil {
		return "", err
	}
	name := file.Name()
	if err := file.Close(); err != nil {
		return "", err
	}
	return name, nil
}

func moveFile(source, destination string, replace bool) error {
	src, err := syscall.UTF16PtrFromString(longPath(source))
	if err != nil {
		return err
	}
	dst, err := syscall.UTF16PtrFromString(longPath(destination))
	if err != nil {
		return err
	}
	flags := uintptr(moveFileWriteThrough)
	if replace {
		flags |= moveFileReplaceExisting
	}
	result, _, callErr := procMoveFileExW.Call(uintptr(unsafe.Pointer(src)), uintptr(unsafe.Pointer(dst)), flags)
	if result == 0 {
		return windowsCallError("MoveFileExW", callErr)
	}
	return nil
}

func verifyOwnedFileHashIfPresent(path, expectedHash string) error {
	_, err := os.Lstat(path)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return err
	}
	if err := validateRegularNonReparseFile(path); err != nil {
		return err
	}
	actualHash, err := hashFile(path)
	if err != nil {
		return err
	}
	if expectedHash == "" || !strings.EqualFold(actualHash, expectedHash) {
		return fmt.Errorf("SHA-256 mismatch; preserving all owned files: path=%s expected=%s actual=%s", path, expectedHash, actualHash)
	}
	return nil
}

func removeOwnedFile(path, expectedHash string, log *logger) error {
	_, err := os.Lstat(path)
	if errors.Is(err, os.ErrNotExist) {
		log.printf("owned file already absent path=%s", path)
		return nil
	}
	if err != nil {
		return err
	}
	if err := validateRegularNonReparseFile(path); err != nil {
		return err
	}
	actualHash, err := hashFile(path)
	if err != nil {
		return err
	}
	if expectedHash == "" || !strings.EqualFold(actualHash, expectedHash) {
		return fmt.Errorf("SHA-256 mismatch; preserving file rather than deleting it: path=%s expected=%s actual=%s", path, expectedHash, actualHash)
	}
	if err := os.Remove(path); err != nil {
		return err
	}
	log.printf("removed owned file path=%s sha256=%s", path, actualHash)
	return nil
}

func scheduleSelfDelete(self, productDir string) error {
	if !strings.EqualFold(filepath.Base(self), uninstallName) {
		return errors.New("self-delete target is not the LotCraft uninstaller")
	}
	if !sameWindowsPath(filepath.Dir(self), productDir) {
		return errors.New("self-delete target is not inside the product directory")
	}
	helper, helperHash, err := copyToTempAndHash(self, os.TempDir(), "LotCraft-cleanup-*.exe")
	if err != nil {
		return fmt.Errorf("create cleanup helper: %w", err)
	}
	selfHash, err := hashFile(self)
	if err != nil || helperHash != selfHash {
		_ = os.Remove(helper)
		return errors.New("cleanup helper SHA-256 differs from the installed uninstaller")
	}
	process, err := os.StartProcess(
		helper,
		[]string{
			helper,
			"-cleanup-target", self,
			"-cleanup-dir", productDir,
			"-cleanup-parent-pid", fmt.Sprintf("%d", os.Getpid()),
			"-quiet",
		},
		&os.ProcAttr{Files: []*os.File{nil, nil, nil}},
	)
	if err != nil {
		_ = os.Remove(helper)
		return fmt.Errorf("start cleanup helper: %w", err)
	}
	return process.Release()
}

func scheduleDeleteAtReboot(path string) error {
	src, err := syscall.UTF16PtrFromString(longPath(path))
	if err != nil {
		return err
	}
	result, _, callErr := procMoveFileExW.Call(uintptr(unsafe.Pointer(src)), 0, moveFileDelayUntilReboot)
	if result == 0 {
		return windowsCallError("MoveFileExW(MOVEFILE_DELAY_UNTIL_REBOOT)", callErr)
	}
	return nil
}

func runCleanupHelper(opt options) error {
	target, err := filepath.Abs(opt.cleanupTarget)
	if err != nil {
		return err
	}
	target = filepath.Clean(target)
	productDir, err := filepath.Abs(opt.cleanupDir)
	if err != nil {
		return err
	}
	productDir = filepath.Clean(productDir)
	if !strings.EqualFold(filepath.Base(target), uninstallName) ||
		!sameWindowsPath(filepath.Dir(target), productDir) ||
		opt.cleanupParent <= 0 {
		return errors.New("invalid internal cleanup request")
	}
	if parent, findErr := os.FindProcess(opt.cleanupParent); findErr == nil {
		_, _ = parent.Wait()
		_ = parent.Release()
	}

	var removeErr error
	for attempt := 0; attempt < 50; attempt++ {
		removeErr = os.Remove(target)
		if removeErr == nil || errors.Is(removeErr, os.ErrNotExist) {
			removeErr = nil
			break
		}
		time.Sleep(100 * time.Millisecond)
	}
	if removeErr != nil {
		if err := scheduleDeleteAtReboot(target); err != nil {
			return fmt.Errorf("remove installed uninstaller: immediate=%v reboot=%v", removeErr, err)
		}
	}
	// This is intentionally non-recursive. It succeeds only when no unrelated
	// file remains in the dedicated product directory.
	_ = os.Remove(productDir)
	return scheduleDeleteAtReboot(executablePath())
}

func browseForFolder(title string) (string, error) {
	titlePtr, err := syscall.UTF16PtrFromString(title)
	if err != nil {
		return "", err
	}
	display := make([]uint16, 32768)
	info := browseInfo{
		displayName: &display[0],
		title:       titlePtr,
		flags:       bifReturnOnlyFSDirs | bifEditBox | bifNewDialogStyle,
	}
	pidl, _, callErr := procSHBrowseForFolderW.Call(uintptr(unsafe.Pointer(&info)))
	if pidl == 0 {
		if errno, ok := callErr.(syscall.Errno); ok && errno != 0 {
			return "", windowsCallError("SHBrowseForFolderW", callErr)
		}
		return "", nil
	}
	defer procCoTaskMemFree.Call(pidl)
	pathBuffer := make([]uint16, 32768)
	ok, _, callErr := procSHGetPathFromIDListW.Call(pidl, uintptr(unsafe.Pointer(&pathBuffer[0])))
	if ok == 0 {
		return "", windowsCallError("SHGetPathFromIDListW", callErr)
	}
	return syscall.UTF16ToString(pathBuffer), nil
}

func showMessage(title, message string, flags uintptr) int {
	titlePtr, _ := syscall.UTF16PtrFromString(title)
	messagePtr, _ := syscall.UTF16PtrFromString(message)
	result, _, _ := procMessageBoxW.Call(0, uintptr(unsafe.Pointer(messagePtr)), uintptr(unsafe.Pointer(titlePtr)), flags)
	return int(result)
}

func executablePath() string {
	path, err := os.Executable()
	if err != nil {
		return os.Args[0]
	}
	path, err = filepath.Abs(path)
	if err != nil {
		return path
	}
	return filepath.Clean(path)
}

func sameWindowsPath(a, b string) bool {
	cleanA, errA := policy.CleanWindowsPath(a)
	cleanB, errB := policy.CleanWindowsPath(b)
	if errA != nil || errB != nil {
		return strings.EqualFold(filepath.Clean(a), filepath.Clean(b))
	}
	return strings.EqualFold(strings.TrimRight(cleanA, `\`), strings.TrimRight(cleanB, `\`))
}

func uniqueSorted(values []string) []string {
	seen := make(map[string]string)
	for _, value := range values {
		key := strings.ToLower(filepath.Clean(value))
		seen[key] = filepath.Clean(value)
	}
	out := make([]string, 0, len(seen))
	for _, value := range seen {
		out = append(out, value)
	}
	sort.Strings(out)
	return out
}

func windowsCallError(operation string, err error) error {
	if errno, ok := err.(syscall.Errno); ok && errno == 0 {
		return errors.New(operation + " failed without an extended error code")
	}
	return fmt.Errorf("%s: %w", operation, err)
}
