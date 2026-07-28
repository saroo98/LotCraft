package update

import (
	"bytes"
	"context"
	"crypto/ed25519"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"
)

const (
	ProductName          = "LotCraft"
	ManifestAssetName    = "LotCraft-update.json"
	SignatureAssetName   = "LotCraft-update.sig"
	ManifestSchema       = 1
	MaxReleaseResponse   = 1 << 20
	MaxManifestResponse  = 64 << 10
	MaxSignatureResponse = 4 << 10
	MaxInstallerResponse = 64 << 20
)

// TrustedPublicKeyBase64 is injected into release builds with -ldflags -X.
// Keeping the private signing key outside the repository makes this public
// value safe to publish and pin in every installed updater.
var TrustedPublicKeyBase64 string

type Version struct {
	Major int
	Minor int
	Patch int
}

func ParseVersion(raw string) (Version, error) {
	if raw == "" || strings.TrimSpace(raw) != raw || strings.ContainsAny(raw, "+-") {
		return Version{}, fmt.Errorf("version %q is not a stable semantic version", raw)
	}
	parts := strings.Split(raw, ".")
	if len(parts) != 3 {
		return Version{}, fmt.Errorf("version %q must contain major.minor.patch", raw)
	}
	values := [3]int{}
	for index, part := range parts {
		if part == "" || (len(part) > 1 && part[0] == '0') {
			return Version{}, fmt.Errorf("version component %q is invalid", part)
		}
		value, err := strconv.Atoi(part)
		if err != nil || value < 0 {
			return Version{}, fmt.Errorf("version component %q is invalid", part)
		}
		values[index] = value
	}
	return Version{Major: values[0], Minor: values[1], Patch: values[2]}, nil
}

func (version Version) Compare(other Version) int {
	left := [3]int{version.Major, version.Minor, version.Patch}
	right := [3]int{other.Major, other.Minor, other.Patch}
	for index := range left {
		if left[index] < right[index] {
			return -1
		}
		if left[index] > right[index] {
			return 1
		}
	}
	return 0
}

type InstallerDescriptor struct {
	Name   string `json:"name"`
	Size   int64  `json:"size"`
	SHA256 string `json:"sha256"`
}

type Manifest struct {
	SchemaVersion int                 `json:"schema_version"`
	Product       string              `json:"product"`
	Version       string              `json:"version"`
	Tag           string              `json:"tag"`
	Installer     InstallerDescriptor `json:"installer"`
}

type ReleaseAsset struct {
	Name               string `json:"name"`
	BrowserDownloadURL string `json:"browser_download_url"`
	Size               int64  `json:"size"`
	Digest             string `json:"digest"`
}

type LatestRelease struct {
	TagName    string         `json:"tag_name"`
	Draft      bool           `json:"draft"`
	Prerelease bool           `json:"prerelease"`
	Assets     []ReleaseAsset `json:"assets"`
}

type Candidate struct {
	Manifest       Manifest
	InstallerAsset ReleaseAsset
}

type Checker struct {
	Client         *http.Client
	LatestURL      string
	PublicKey      ed25519.PublicKey
	AllowedHosts   map[string]bool
	CurrentVersion string
}

func DecodePublicKey(encoded string) (ed25519.PublicKey, error) {
	raw, err := base64.StdEncoding.DecodeString(strings.TrimSpace(encoded))
	if err != nil {
		return nil, fmt.Errorf("decode update public key: %w", err)
	}
	if len(raw) != ed25519.PublicKeySize {
		return nil, fmt.Errorf("update public key has %d bytes; expected %d", len(raw), ed25519.PublicKeySize)
	}
	return ed25519.PublicKey(raw), nil
}

func VerifySignedManifest(manifestBytes, signatureBytes []byte, publicKey ed25519.PublicKey) (Manifest, error) {
	signature, err := base64.StdEncoding.DecodeString(strings.TrimSpace(string(signatureBytes)))
	if err != nil {
		return Manifest{}, fmt.Errorf("decode update signature: %w", err)
	}
	if len(signature) != ed25519.SignatureSize || !ed25519.Verify(publicKey, manifestBytes, signature) {
		return Manifest{}, errors.New("update manifest signature is invalid")
	}

	var manifest Manifest
	decoder := json.NewDecoder(bytes.NewReader(manifestBytes))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&manifest); err != nil {
		return Manifest{}, fmt.Errorf("parse signed update manifest: %w", err)
	}
	if err := ensureJSONEOF(decoder); err != nil {
		return Manifest{}, err
	}
	if err := ValidateManifest(manifest); err != nil {
		return Manifest{}, err
	}
	return manifest, nil
}

func ensureJSONEOF(decoder *json.Decoder) error {
	var extra any
	if err := decoder.Decode(&extra); !errors.Is(err, io.EOF) {
		if err == nil {
			return errors.New("signed update manifest contains trailing JSON")
		}
		return fmt.Errorf("parse signed update manifest trailer: %w", err)
	}
	return nil
}

func ValidateManifest(manifest Manifest) error {
	if manifest.SchemaVersion != ManifestSchema {
		return fmt.Errorf("unsupported update manifest schema %d", manifest.SchemaVersion)
	}
	if manifest.Product != ProductName {
		return fmt.Errorf("update manifest product %q is not %s", manifest.Product, ProductName)
	}
	if _, err := ParseVersion(manifest.Version); err != nil {
		return err
	}
	if manifest.Tag != "v"+manifest.Version {
		return fmt.Errorf("update manifest tag %q does not match version %q", manifest.Tag, manifest.Version)
	}
	expectedInstaller := fmt.Sprintf("%s-%s-Setup.exe", ProductName, manifest.Version)
	if manifest.Installer.Name != expectedInstaller {
		return fmt.Errorf("installer name %q does not match %q", manifest.Installer.Name, expectedInstaller)
	}
	if manifest.Installer.Size <= 0 || manifest.Installer.Size > MaxInstallerResponse {
		return fmt.Errorf("installer size %d is outside the allowed range", manifest.Installer.Size)
	}
	if len(manifest.Installer.SHA256) != sha256.Size*2 {
		return errors.New("installer SHA-256 length is invalid")
	}
	if _, err := hex.DecodeString(manifest.Installer.SHA256); err != nil {
		return errors.New("installer SHA-256 is invalid")
	}
	return nil
}

func (checker Checker) Check(ctx context.Context) (*Candidate, error) {
	if checker.Client == nil {
		return nil, errors.New("update HTTP client is nil")
	}
	current, err := ParseVersion(checker.CurrentVersion)
	if err != nil {
		return nil, fmt.Errorf("installed version: %w", err)
	}

	releaseBytes, err := checker.fetch(ctx, checker.LatestURL, MaxReleaseResponse)
	if err != nil {
		return nil, fmt.Errorf("download latest release metadata: %w", err)
	}
	var release LatestRelease
	decoder := json.NewDecoder(bytes.NewReader(releaseBytes))
	if err := decoder.Decode(&release); err != nil {
		return nil, fmt.Errorf("parse latest release metadata: %w", err)
	}
	if release.Draft || release.Prerelease {
		return nil, errors.New("latest release is not stable")
	}

	manifestAsset, ok := findAsset(release.Assets, ManifestAssetName)
	if !ok {
		return nil, fmt.Errorf("latest release does not contain %s", ManifestAssetName)
	}
	signatureAsset, ok := findAsset(release.Assets, SignatureAssetName)
	if !ok {
		return nil, fmt.Errorf("latest release does not contain %s", SignatureAssetName)
	}
	manifestBytes, err := checker.fetch(ctx, manifestAsset.BrowserDownloadURL, MaxManifestResponse)
	if err != nil {
		return nil, fmt.Errorf("download signed update manifest: %w", err)
	}
	signatureBytes, err := checker.fetch(ctx, signatureAsset.BrowserDownloadURL, MaxSignatureResponse)
	if err != nil {
		return nil, fmt.Errorf("download update signature: %w", err)
	}
	manifest, err := VerifySignedManifest(manifestBytes, signatureBytes, checker.PublicKey)
	if err != nil {
		return nil, err
	}
	if manifest.Tag != release.TagName {
		return nil, fmt.Errorf("signed tag %q does not match GitHub tag %q", manifest.Tag, release.TagName)
	}
	available, err := ParseVersion(manifest.Version)
	if err != nil {
		return nil, err
	}
	if available.Compare(current) <= 0 {
		return nil, nil
	}

	installerAsset, ok := findAsset(release.Assets, manifest.Installer.Name)
	if !ok {
		return nil, fmt.Errorf("latest release does not contain signed installer %s", manifest.Installer.Name)
	}
	if installerAsset.Size != manifest.Installer.Size {
		return nil, errors.New("GitHub installer size differs from the signed manifest")
	}
	if installerAsset.Digest != "" &&
		!strings.EqualFold(strings.TrimPrefix(installerAsset.Digest, "sha256:"), manifest.Installer.SHA256) {
		return nil, errors.New("GitHub installer digest differs from the signed manifest")
	}
	return &Candidate{Manifest: manifest, InstallerAsset: installerAsset}, nil
}

func (checker Checker) DownloadInstaller(ctx context.Context, candidate Candidate) ([]byte, error) {
	raw, err := checker.fetch(ctx, candidate.InstallerAsset.BrowserDownloadURL, MaxInstallerResponse)
	if err != nil {
		return nil, err
	}
	if int64(len(raw)) != candidate.Manifest.Installer.Size {
		return nil, errors.New("downloaded installer size differs from the signed manifest")
	}
	digest := sha256.Sum256(raw)
	if !strings.EqualFold(hex.EncodeToString(digest[:]), candidate.Manifest.Installer.SHA256) {
		return nil, errors.New("downloaded installer SHA-256 differs from the signed manifest")
	}
	return raw, nil
}

func (checker Checker) fetch(ctx context.Context, rawURL string, maximum int64) ([]byte, error) {
	parsed, err := url.Parse(rawURL)
	if err != nil || parsed.Scheme != "https" || parsed.Hostname() == "" {
		return nil, fmt.Errorf("update URL %q is not a valid HTTPS URL", rawURL)
	}
	if len(checker.AllowedHosts) > 0 && !checker.AllowedHosts[strings.ToLower(parsed.Hostname())] {
		return nil, fmt.Errorf("update URL host %q is not allowed", parsed.Hostname())
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, rawURL, nil)
	if err != nil {
		return nil, err
	}
	request.Header.Set("Accept", "application/vnd.github+json")
	request.Header.Set("X-GitHub-Api-Version", "2022-11-28")
	request.Header.Set("User-Agent", "LotCraft-Updater")
	response, err := checker.Client.Do(request)
	if err != nil {
		return nil, err
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("HTTP status %d", response.StatusCode)
	}
	if response.ContentLength > maximum {
		return nil, fmt.Errorf("response exceeds the %d-byte limit", maximum)
	}
	limited := io.LimitReader(response.Body, maximum+1)
	raw, err := io.ReadAll(limited)
	if err != nil {
		return nil, err
	}
	if int64(len(raw)) > maximum {
		return nil, fmt.Errorf("response exceeds the %d-byte limit", maximum)
	}
	return raw, nil
}

func findAsset(assets []ReleaseAsset, name string) (ReleaseAsset, bool) {
	for _, asset := range assets {
		if asset.Name == name {
			return asset, true
		}
	}
	return ReleaseAsset{}, false
}

func NewHTTPClient(allowedHosts map[string]bool) *http.Client {
	return &http.Client{
		Timeout: 30 * time.Second,
		CheckRedirect: func(request *http.Request, via []*http.Request) error {
			if len(via) >= 5 {
				return errors.New("too many update download redirects")
			}
			if request.URL.Scheme != "https" || !allowedHosts[strings.ToLower(request.URL.Hostname())] {
				return fmt.Errorf("update redirect host %q is not allowed", request.URL.Hostname())
			}
			return nil
		},
	}
}

type State struct {
	SchemaVersion          int       `json:"schema_version"`
	InstallationID         string    `json:"installation_id"`
	LastAttemptUTC         time.Time `json:"last_attempt_utc,omitempty"`
	LastSuccessfulCheckUTC time.Time `json:"last_successful_check_utc,omitempty"`
	DeferredVersion        string    `json:"deferred_version,omitempty"`
	DeferredUntilUTC       time.Time `json:"deferred_until_utc,omitempty"`
}

func (state State) ShouldAttempt(now time.Time, interval time.Duration) bool {
	if state.LastAttemptUTC.IsZero() {
		return true
	}
	return !now.Before(state.LastAttemptUTC.Add(interval))
}

func (state State) IsDeferred(version string, now time.Time) bool {
	return state.DeferredVersion == version && now.Before(state.DeferredUntilUTC)
}
