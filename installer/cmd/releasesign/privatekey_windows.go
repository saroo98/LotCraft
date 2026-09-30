//go:build windows

package main

import (
	"fmt"
	"os"
	"os/user"
	"syscall"
	"unsafe"
)

// Apply a protected current-user-only DACL during CREATE_NEW, before the file
// exists or any secret bytes are written. A later icacls call leaves an access
// window in which another inherited principal can retain a file handle.
func newPrivateKeyFile(path string) (*os.File, error) {
	current, err := user.Current()
	if err != nil {
		return nil, fmt.Errorf("resolve signing-key owner: %w", err)
	}
	sddl, err := syscall.UTF16PtrFromString("D:P(A;;FA;;;" + current.Uid + ")")
	if err != nil {
		return nil, err
	}
	var descriptor uintptr
	convert := syscall.NewLazyDLL("advapi32.dll").NewProc("ConvertStringSecurityDescriptorToSecurityDescriptorW")
	result, _, callErr := convert.Call(uintptr(unsafe.Pointer(sddl)), 1, uintptr(unsafe.Pointer(&descriptor)), 0)
	if result == 0 {
		return nil, fmt.Errorf("create signing-key ACL: %w", callErr)
	}
	defer syscall.NewLazyDLL("kernel32.dll").NewProc("LocalFree").Call(descriptor)
	attributes := syscall.SecurityAttributes{
		Length: uint32(unsafe.Sizeof(syscall.SecurityAttributes{})), SecurityDescriptor: descriptor,
	}
	wide, err := syscall.UTF16PtrFromString(path)
	if err != nil {
		return nil, err
	}
	handle, err := syscall.CreateFile(wide, syscall.GENERIC_WRITE, 0, &attributes, syscall.CREATE_NEW, syscall.FILE_ATTRIBUTE_NORMAL, 0)
	if err != nil {
		return nil, fmt.Errorf("create private signing key exclusively: %w", err)
	}
	return os.NewFile(uintptr(handle), path), nil
}
