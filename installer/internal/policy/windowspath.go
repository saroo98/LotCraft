package policy

import (
	"errors"
	"strings"
)

// CleanWindowsPath normalizes separators and redundant components without
// resolving links. The installer separately resolves every ownership boundary
// with GetFinalPathNameByHandleW before applying this lexical containment test.
func CleanWindowsPath(input string) (string, error) {
	p := strings.TrimSpace(strings.ReplaceAll(input, "/", `\`))
	p = stripExtendedPrefix(p)
	if p == "" {
		return "", errors.New("path is empty")
	}

	volume, rest, ok := splitVolume(p)
	if !ok {
		return "", errors.New("path is not an absolute Windows path")
	}

	parts := make([]string, 0, 16)
	for _, part := range strings.Split(rest, `\`) {
		switch part {
		case "", ".":
			continue
		case "..":
			if len(parts) == 0 {
				return "", errors.New("path escapes its volume root")
			}
			parts = parts[:len(parts)-1]
		default:
			parts = append(parts, part)
		}
	}

	if strings.HasPrefix(volume, `\\`) {
		if len(parts) == 0 {
			return volume, nil
		}
		return volume + `\` + strings.Join(parts, `\`), nil
	}
	if len(parts) == 0 {
		return volume + `\`, nil
	}
	return volume + `\` + strings.Join(parts, `\`), nil
}

// Within reports whether child is root itself or is strictly below root. It is
// case-insensitive because Windows' ordinary NTFS path lookup is case-insensitive.
func Within(root, child string) (bool, error) {
	cleanRoot, err := CleanWindowsPath(root)
	if err != nil {
		return false, err
	}
	cleanChild, err := CleanWindowsPath(child)
	if err != nil {
		return false, err
	}
	rootFold := strings.ToLower(strings.TrimRight(cleanRoot, `\`))
	childFold := strings.ToLower(strings.TrimRight(cleanChild, `\`))
	return childFold == rootFold || strings.HasPrefix(childFold, rootFold+`\`), nil
}

// ProductDestination is the sole installer-owned EA directory beneath the
// resolved MQL5\\Experts root.
func ProductDestination(expertsRoot string) (string, error) {
	root, err := CleanWindowsPath(expertsRoot)
	if err != nil {
		return "", err
	}
	return strings.TrimRight(root, `\`) + `\LotCraft`, nil
}

func stripExtendedPrefix(p string) string {
	lower := strings.ToLower(p)
	if strings.HasPrefix(lower, `\\?\unc\`) {
		return `\\` + p[len(`\\?\UNC\`):]
	}
	if strings.HasPrefix(lower, `\\?\`) {
		return p[len(`\\?\`):]
	}
	return p
}

func splitVolume(p string) (volume, rest string, ok bool) {
	if len(p) >= 3 && ((p[0] >= 'A' && p[0] <= 'Z') || (p[0] >= 'a' && p[0] <= 'z')) && p[1] == ':' && p[2] == '\\' {
		return strings.ToUpper(p[:2]), p[3:], true
	}
	if strings.HasPrefix(p, `\\`) {
		fields := strings.Split(strings.TrimPrefix(p, `\\`), `\`)
		if len(fields) < 2 || fields[0] == "" || fields[1] == "" {
			return "", "", false
		}
		volume = `\\` + fields[0] + `\` + fields[1]
		return volume, strings.Join(fields[2:], `\`), true
	}
	return "", "", false
}
