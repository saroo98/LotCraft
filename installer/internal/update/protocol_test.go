package update

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
	"time"
)

func TestStableSemanticVersions(t *testing.T) {
	for _, raw := range []string{"0.0.0", "1.0.0", "12.34.56"} {
		if _, err := ParseVersion(raw); err != nil {
			t.Fatalf("ParseVersion(%q): %v", raw, err)
		}
	}
	for _, raw := range []string{"v1.0.0", "1.0", "1.0.0-beta", "1.0.0+build", "01.0.0", " 1.0.0"} {
		if _, err := ParseVersion(raw); err == nil {
			t.Fatalf("ParseVersion(%q) unexpectedly succeeded", raw)
		}
	}
	if got := (Version{1, 2, 3}).Compare(Version{1, 3, 0}); got >= 0 {
		t.Fatalf("unexpected comparison result %d", got)
	}
	if got := (Version{2, 0, 0}).Compare(Version{1, 99, 99}); got <= 0 {
		t.Fatalf("unexpected comparison result %d", got)
	}
}

func TestSignedManifestRejectsTampering(t *testing.T) {
	publicKey, privateKey, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	raw := validManifestBytes(t, []byte("installer"))
	signature := base64.StdEncoding.EncodeToString(ed25519.Sign(privateKey, raw))
	if _, err := VerifySignedManifest(raw, []byte(signature), publicKey); err != nil {
		t.Fatalf("valid signature rejected: %v", err)
	}
	tampered := append([]byte(nil), raw...)
	tampered[len(tampered)-2] ^= 1
	if _, err := VerifySignedManifest(tampered, []byte(signature), publicKey); err == nil {
		t.Fatal("tampered manifest was accepted")
	}
}

func TestCheckerFindsOnlyNewerSignedStableRelease(t *testing.T) {
	publicKey, privateKey, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	installer := []byte("installer")
	manifestRaw := validManifestBytes(t, installer)
	signatureRaw := []byte(base64.StdEncoding.EncodeToString(ed25519.Sign(privateKey, manifestRaw)))

	mux := http.NewServeMux()
	server := httptest.NewTLSServer(mux)
	defer server.Close()
	host := mustHost(t, server.URL)
	installerDigest := sha256.Sum256(installer)
	release := LatestRelease{
		TagName: "v1.1.0",
		Assets: []ReleaseAsset{
			{Name: ManifestAssetName, BrowserDownloadURL: server.URL + "/manifest", Size: int64(len(manifestRaw))},
			{Name: SignatureAssetName, BrowserDownloadURL: server.URL + "/signature", Size: int64(len(signatureRaw))},
			{
				Name:               "LotCraft-1.1.0-Setup.exe",
				BrowserDownloadURL: server.URL + "/installer",
				Size:               int64(len(installer)),
				Digest:             "sha256:" + hex.EncodeToString(installerDigest[:]),
			},
		},
	}
	releaseRaw, _ := json.Marshal(release)
	mux.HandleFunc("/latest", func(writer http.ResponseWriter, _ *http.Request) { _, _ = writer.Write(releaseRaw) })
	mux.HandleFunc("/manifest", func(writer http.ResponseWriter, _ *http.Request) { _, _ = writer.Write(manifestRaw) })
	mux.HandleFunc("/signature", func(writer http.ResponseWriter, _ *http.Request) { _, _ = writer.Write(signatureRaw) })
	mux.HandleFunc("/installer", func(writer http.ResponseWriter, _ *http.Request) { _, _ = writer.Write(installer) })

	client := server.Client()
	client.CheckRedirect = NewHTTPClient(map[string]bool{host: true}).CheckRedirect
	checker := Checker{
		Client:         client,
		LatestURL:      server.URL + "/latest",
		PublicKey:      publicKey,
		AllowedHosts:   map[string]bool{host: true},
		CurrentVersion: "1.0.0",
	}
	candidate, err := checker.Check(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if candidate == nil || candidate.Manifest.Version != "1.1.0" {
		t.Fatalf("unexpected candidate %#v", candidate)
	}
	raw, err := checker.DownloadInstaller(context.Background(), *candidate)
	if err != nil || string(raw) != string(installer) {
		t.Fatalf("download installer: %v", err)
	}

	checker.CurrentVersion = "1.1.0"
	candidate, err = checker.Check(context.Background())
	if err != nil || candidate != nil {
		t.Fatalf("same version should not update: candidate=%#v err=%v", candidate, err)
	}
}

func TestCheckerRejectsBadDigestAndUnapprovedHost(t *testing.T) {
	checker := Checker{AllowedHosts: map[string]bool{"api.github.com": true}}
	if _, err := checker.fetch(context.Background(), "https://example.com/file", 10); err == nil {
		t.Fatal("unapproved host was accepted")
	}

	candidate := Candidate{
		Manifest:       Manifest{Installer: InstallerDescriptor{Size: 1, SHA256: hex.EncodeToString(make([]byte, sha256.Size))}},
		InstallerAsset: ReleaseAsset{BrowserDownloadURL: "https://api.github.com/file"},
	}
	checker.Client = &http.Client{Transport: roundTripFunc(func(*http.Request) (*http.Response, error) {
		return &http.Response{
			StatusCode: http.StatusOK,
			Header:     make(http.Header),
			Body:       io.NopCloser(strings.NewReader("x")),
		}, nil
	})}
	if _, err := checker.DownloadInstaller(context.Background(), candidate); err == nil {
		t.Fatal("bad installer digest was accepted")
	}
}

func TestCheckerRejectsPrereleaseAndInstallerSizeMismatch(t *testing.T) {
	publicKey, privateKey, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	installer := []byte("installer")
	manifestRaw := validManifestBytes(t, installer)
	signatureRaw := []byte(base64.StdEncoding.EncodeToString(ed25519.Sign(privateKey, manifestRaw)))
	mux := http.NewServeMux()
	server := httptest.NewTLSServer(mux)
	defer server.Close()
	host := mustHost(t, server.URL)
	release := LatestRelease{
		TagName:    "v1.1.0",
		Prerelease: true,
		Assets: []ReleaseAsset{
			{Name: ManifestAssetName, BrowserDownloadURL: server.URL + "/manifest"},
			{Name: SignatureAssetName, BrowserDownloadURL: server.URL + "/signature"},
			{Name: "LotCraft-1.1.0-Setup.exe", BrowserDownloadURL: server.URL + "/installer", Size: int64(len(installer) + 1)},
		},
	}
	releaseRaw, _ := json.Marshal(release)
	mux.HandleFunc("/latest", func(writer http.ResponseWriter, _ *http.Request) { _, _ = writer.Write(releaseRaw) })
	mux.HandleFunc("/manifest", func(writer http.ResponseWriter, _ *http.Request) { _, _ = writer.Write(manifestRaw) })
	mux.HandleFunc("/signature", func(writer http.ResponseWriter, _ *http.Request) { _, _ = writer.Write(signatureRaw) })

	client := server.Client()
	client.CheckRedirect = NewHTTPClient(map[string]bool{host: true}).CheckRedirect
	checker := Checker{
		Client: client, LatestURL: server.URL + "/latest", PublicKey: publicKey,
		AllowedHosts: map[string]bool{host: true}, CurrentVersion: "1.0.0",
	}
	if _, err := checker.Check(context.Background()); err == nil {
		t.Fatal("prerelease was accepted")
	}
	release.Prerelease = false
	releaseRaw, _ = json.Marshal(release)
	if _, err := checker.Check(context.Background()); err == nil {
		t.Fatal("installer size mismatch was accepted")
	}
}

func TestHTTPRedirectTimeoutAndResponseLimits(t *testing.T) {
	allowed := map[string]bool{"api.github.com": true}
	client := NewHTTPClient(allowed)
	redirect, _ := http.NewRequest(http.MethodGet, "https://example.com/file", nil)
	if err := client.CheckRedirect(redirect, nil); err == nil {
		t.Fatal("redirect to an unapproved host was accepted")
	}

	checker := Checker{
		Client: &http.Client{Transport: roundTripFunc(func(*http.Request) (*http.Response, error) {
			return &http.Response{
				StatusCode:    http.StatusOK,
				ContentLength: 11,
				Header:        make(http.Header),
				Body:          io.NopCloser(strings.NewReader("01234567890")),
			}, nil
		})},
		AllowedHosts: allowed,
	}
	if _, err := checker.fetch(context.Background(), "https://api.github.com/file", 10); err == nil {
		t.Fatal("oversized response was accepted")
	}

	server := httptest.NewTLSServer(http.HandlerFunc(func(writer http.ResponseWriter, _ *http.Request) {
		time.Sleep(100 * time.Millisecond)
		_, _ = writer.Write([]byte("late"))
	}))
	defer server.Close()
	host := mustHost(t, server.URL)
	timeoutClient := server.Client()
	timeoutClient.Timeout = 10 * time.Millisecond
	timeoutChecker := Checker{Client: timeoutClient, AllowedHosts: map[string]bool{host: true}}
	if _, err := timeoutChecker.fetch(context.Background(), server.URL, 10); err == nil {
		t.Fatal("HTTP timeout was ignored")
	}
}

func TestDailyAttemptAndDeferral(t *testing.T) {
	now := time.Date(2026, 7, 28, 12, 0, 0, 0, time.UTC)
	state := State{LastAttemptUTC: now, DeferredVersion: "1.1.0", DeferredUntilUTC: now.Add(24 * time.Hour)}
	if state.ShouldAttempt(now.Add(23*time.Hour), 24*time.Hour) {
		t.Fatal("daily throttle was ignored")
	}
	if !state.ShouldAttempt(now.Add(24*time.Hour), 24*time.Hour) {
		t.Fatal("daily throttle did not expire")
	}
	if !state.IsDeferred("1.1.0", now.Add(time.Hour)) || state.IsDeferred("1.2.0", now.Add(time.Hour)) {
		t.Fatal("version deferral is incorrect")
	}
}

func validManifestBytes(t *testing.T, installer []byte) []byte {
	t.Helper()
	digest := sha256.Sum256(installer)
	manifest := Manifest{
		SchemaVersion: ManifestSchema,
		Product:       ProductName,
		Version:       "1.1.0",
		Tag:           "v1.1.0",
		Installer: InstallerDescriptor{
			Name:   "LotCraft-1.1.0-Setup.exe",
			Size:   int64(len(installer)),
			SHA256: hex.EncodeToString(digest[:]),
		},
	}
	raw, err := json.Marshal(manifest)
	if err != nil {
		t.Fatal(err)
	}
	return raw
}

func mustHost(t *testing.T, rawURL string) string {
	t.Helper()
	parsed, err := url.Parse(rawURL)
	if err != nil {
		t.Fatal(err)
	}
	return parsed.Hostname()
}

type roundTripFunc func(*http.Request) (*http.Response, error)

func (function roundTripFunc) RoundTrip(request *http.Request) (*http.Response, error) {
	return function(request)
}
