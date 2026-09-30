//go:build windows

package main

import (
	"os/user"
	"path/filepath"
	"syscall"
	"testing"
	"unsafe"
)

func TestPrivateKeyACLIsProtectedBeforeAnySecretBytesAreWritten(t *testing.T) {
	file, err := newPrivateKeyFile(filepath.Join(t.TempDir(), "disposable-empty-key"))
	if err != nil {
		t.Fatal(err)
	}
	defer file.Close()
	info, err := file.Stat()
	if err != nil || info.Size() != 0 {
		t.Fatalf("test must inspect the newly created empty file: %v", err)
	}
	type aclHeader struct {
		Revision  byte
		Reserved  byte
		Size      uint16
		AceCount  uint16
		Reserved2 uint16
	}
	var descriptor unsafe.Pointer
	var dacl *aclHeader
	security := syscall.NewLazyDLL("advapi32.dll")
	status, _, _ := security.NewProc("GetSecurityInfo").Call(
		file.Fd(), 1, 4, 0, 0, uintptr(unsafe.Pointer(&dacl)), 0, uintptr(unsafe.Pointer(&descriptor)),
	)
	if status != 0 {
		t.Fatalf("GetSecurityInfo status %d", status)
	}
	defer syscall.NewLazyDLL("kernel32.dll").NewProc("LocalFree").Call(uintptr(descriptor))
	var control uint16
	var revision uint32
	ok, _, callErr := security.NewProc("GetSecurityDescriptorControl").Call(
		uintptr(descriptor), uintptr(unsafe.Pointer(&control)), uintptr(unsafe.Pointer(&revision)),
	)
	if ok == 0 || control&0x1000 == 0 || dacl == nil || dacl.AceCount != 1 {
		t.Fatalf("empty private file does not have a protected single-principal ACL: %v", callErr)
	}
	var ace unsafe.Pointer
	ok, _, callErr = security.NewProc("GetAce").Call(uintptr(unsafe.Pointer(dacl)), 0, uintptr(unsafe.Pointer(&ace)))
	if ok == 0 || *(*byte)(ace) != 0 {
		t.Fatalf("private file ACL is not an explicit allow entry: %v", callErr)
	}
	sid := (*syscall.SID)(unsafe.Add(ace, 8))
	owner, err := sid.String()
	if err != nil {
		t.Fatal(err)
	}
	current, err := user.Current()
	if err != nil || owner != current.Uid {
		t.Fatal("private key ACL grants access to a principal other than the current user")
	}
}
