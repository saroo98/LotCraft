package main

import (
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	lotupdate "lotcraft.local/installer/internal/update"
)

func main() {
	if len(os.Args) < 2 {
		fatal(errors.New("usage: releasesign <generate|sign|verify> [options]"))
	}
	var err error
	switch os.Args[1] {
	case "generate":
		err = generate(os.Args[2:])
	case "sign":
		err = sign(os.Args[2:])
	case "verify":
		err = verify(os.Args[2:])
	default:
		err = fmt.Errorf("unknown command %q", os.Args[1])
	}
	if err != nil {
		fatal(err)
	}
}

func generate(arguments []string) error {
	flags := flag.NewFlagSet("generate", flag.ContinueOnError)
	privatePath := flags.String("private-key", "", "private key output path")
	publicPath := flags.String("public-key", "", "public key output path")
	if err := flags.Parse(arguments); err != nil {
		return err
	}
	if *privatePath == "" || *publicPath == "" {
		return errors.New("-private-key and -public-key are required")
	}
	privateAbs, err := filepath.Abs(*privatePath)
	if err != nil {
		return err
	}
	publicAbs, err := filepath.Abs(*publicPath)
	if err != nil {
		return err
	}
	if strings.EqualFold(privateAbs, publicAbs) {
		return errors.New("private and public key outputs must be distinct files")
	}
	for _, path := range []string{privateAbs, publicAbs} {
		if _, err := os.Lstat(path); err == nil {
			return fmt.Errorf("refusing to overwrite existing key output %s", path)
		} else if !errors.Is(err, os.ErrNotExist) {
			return err
		}
	}

	publicKey, privateKey, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		return err
	}
	if err := writePrivateKey(*privatePath, privateKey); err != nil {
		return err
	}
	if err := writeNewTextFile(*publicPath, base64.StdEncoding.EncodeToString(publicKey)+"\n", 0o644); err != nil {
		_ = os.Remove(*privatePath)
		return err
	}
	fmt.Printf("Generated LotCraft update public key: %s\n", base64.StdEncoding.EncodeToString(publicKey))
	return nil
}

func sign(arguments []string) error {
	flags := flag.NewFlagSet("sign", flag.ContinueOnError)
	privatePath := flags.String("private-key", "", "private key path")
	installerPath := flags.String("installer", "", "installer path")
	version := flags.String("version", "", "stable semantic version")
	tag := flags.String("tag", "", "GitHub release tag")
	manifestPath := flags.String("manifest", "", "manifest output path")
	signaturePath := flags.String("signature", "", "signature output path")
	if err := flags.Parse(arguments); err != nil {
		return err
	}
	if *privatePath == "" || *installerPath == "" || *version == "" || *tag == "" ||
		*manifestPath == "" || *signaturePath == "" {
		return errors.New("-private-key, -installer, -version, -tag, -manifest, and -signature are required")
	}
	privateKey, err := readPrivateKey(*privatePath)
	if err != nil {
		return err
	}
	installer, err := os.ReadFile(*installerPath)
	if err != nil {
		return err
	}
	digest := sha256.Sum256(installer)
	manifest := lotupdate.Manifest{
		SchemaVersion: lotupdate.ManifestSchema,
		Product:       lotupdate.ProductName,
		Version:       *version,
		Tag:           *tag,
		Installer: lotupdate.InstallerDescriptor{
			Name:   filepath.Base(*installerPath),
			Size:   int64(len(installer)),
			SHA256: hex.EncodeToString(digest[:]),
		},
	}
	if err := lotupdate.ValidateManifest(manifest); err != nil {
		return err
	}
	manifestBytes, err := json.MarshalIndent(manifest, "", "  ")
	if err != nil {
		return err
	}
	manifestBytes = append(manifestBytes, '\n')
	signature := ed25519.Sign(privateKey, manifestBytes)
	if err := writeTextFile(*manifestPath, string(manifestBytes), 0o644); err != nil {
		return err
	}
	if err := writeTextFile(*signaturePath, base64.StdEncoding.EncodeToString(signature)+"\n", 0o644); err != nil {
		return err
	}
	return nil
}

func verify(arguments []string) error {
	flags := flag.NewFlagSet("verify", flag.ContinueOnError)
	publicPath := flags.String("public-key-file", "", "public key path")
	manifestPath := flags.String("manifest", "", "manifest path")
	signaturePath := flags.String("signature", "", "signature path")
	if err := flags.Parse(arguments); err != nil {
		return err
	}
	if *publicPath == "" || *manifestPath == "" || *signaturePath == "" {
		return errors.New("-public-key-file, -manifest, and -signature are required")
	}
	publicText, err := os.ReadFile(*publicPath)
	if err != nil {
		return err
	}
	publicKey, err := lotupdate.DecodePublicKey(string(publicText))
	if err != nil {
		return err
	}
	manifestBytes, err := os.ReadFile(*manifestPath)
	if err != nil {
		return err
	}
	signatureBytes, err := os.ReadFile(*signaturePath)
	if err != nil {
		return err
	}
	_, err = lotupdate.VerifySignedManifest(manifestBytes, signatureBytes, publicKey)
	return err
}

func readPrivateKey(path string) (ed25519.PrivateKey, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	decoded, err := base64.StdEncoding.DecodeString(strings.TrimSpace(string(raw)))
	if err != nil {
		return nil, fmt.Errorf("decode private key: %w", err)
	}
	if len(decoded) != ed25519.PrivateKeySize {
		return nil, fmt.Errorf("private key has %d bytes; expected %d", len(decoded), ed25519.PrivateKeySize)
	}
	return ed25519.PrivateKey(decoded), nil
}

func writePrivateKey(path string, privateKey ed25519.PrivateKey) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	file, err := newPrivateKeyFile(path)
	if err != nil {
		return err
	}
	return finishNewTextFile(file, base64.StdEncoding.EncodeToString(privateKey)+"\n")
}

func writeNewTextFile(path, value string, mode os.FileMode) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	file, err := os.OpenFile(path, os.O_CREATE|os.O_EXCL|os.O_WRONLY, mode)
	if err != nil {
		return err
	}
	return finishNewTextFile(file, value)
}

func finishNewTextFile(file *os.File, value string) (err error) {
	defer func() {
		_ = file.Close()
		if err != nil {
			_ = os.Remove(file.Name())
		}
	}()
	if _, err = file.WriteString(value); err != nil {
		return err
	}
	if err = file.Sync(); err != nil {
		return err
	}
	return file.Close()
}

func writeTextFile(path, value string, mode os.FileMode) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	return os.WriteFile(path, []byte(value), mode)
}

func fatal(err error) {
	_, _ = fmt.Fprintln(os.Stderr, "releasesign:", err)
	os.Exit(1)
}
