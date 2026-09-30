package main

import (
	"crypto/ed25519"
	"crypto/rand"
	"os"
	"path/filepath"
	"testing"
)

func TestPrivateKeyCreationNeverOverwritesExistingFile(t *testing.T) {
	path := filepath.Join(t.TempDir(), "disposable-private.key")
	if err := os.WriteFile(path, []byte("existing private fixture"), 0o600); err != nil {
		t.Fatal(err)
	}
	_, private, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	if err := writePrivateKey(path, private); err == nil {
		t.Fatal("private-key writer overwrote an existing file")
	}
	actual, err := os.ReadFile(path)
	if err != nil || string(actual) != "existing private fixture" {
		t.Fatalf("existing private-key fixture changed: %v", err)
	}
}

func TestGenerateDoesNotOverwriteExistingPublicKey(t *testing.T) {
	directory := t.TempDir()
	private := filepath.Join(directory, "disposable-private.key")
	public := filepath.Join(directory, "disposable-public.txt")
	if err := os.WriteFile(public, []byte("existing pinned public fixture"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := generate([]string{"-private-key", private, "-public-key", public}); err == nil {
		t.Fatal("key generation replaced an existing pinned public key")
	}
	actual, err := os.ReadFile(public)
	if err != nil || string(actual) != "existing pinned public fixture" {
		t.Fatalf("existing public-key fixture changed: %v", err)
	}
	if _, err := os.Stat(private); !os.IsNotExist(err) {
		t.Fatal("failed key generation left a new private key")
	}
}

func TestGenerateRejectsSamePrivateAndPublicOutput(t *testing.T) {
	path := filepath.Join(t.TempDir(), "same-output")
	if err := generate([]string{"-private-key", path, "-public-key", path}); err == nil {
		t.Fatal("key generation accepted identical private/public outputs")
	}
	if _, err := os.Stat(path); !os.IsNotExist(err) {
		t.Fatal("invalid key generation left output data")
	}
}
