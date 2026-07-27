package policy

import "testing"

func TestCleanWindowsPath(t *testing.T) {
	tests := map[string]string{
		`C:\Users\A\..\B\MQL5`:              `C:\Users\B\MQL5`,
		`c:/Users/A/MQL5/Experts/./EA`:      `C:\Users\A\MQL5\Experts\EA`,
		`\\?\C:\Meta\Terminal`:              `C:\Meta\Terminal`,
		`\\?\UNC\server\share\MQL5\Experts`: `\\server\share\MQL5\Experts`,
	}
	for input, want := range tests {
		got, err := CleanWindowsPath(input)
		if err != nil {
			t.Fatalf("%q: %v", input, err)
		}
		if got != want {
			t.Fatalf("%q: got %q want %q", input, got, want)
		}
	}
}

func TestRejectRelativeOrRootEscape(t *testing.T) {
	for _, input := range []string{`MQL5\Experts`, `C:\..\Windows`, `\\server`} {
		if _, err := CleanWindowsPath(input); err == nil {
			t.Fatalf("expected %q to be rejected", input)
		}
	}
}

func TestWithinCaseInsensitiveAndBoundarySafe(t *testing.T) {
	root := `C:\Terminal\MQL5\Experts`
	cases := []struct {
		child string
		want  bool
	}{
		{`c:\terminal\mql5\experts`, true},
		{`C:\Terminal\MQL5\Experts\LotCraft`, true},
		{`C:\Terminal\MQL5\Experts2\LotCraft`, false},
		{`C:\Terminal\MQL5\Files`, false},
		{`D:\Terminal\MQL5\Experts\LotCraft`, false},
	}
	for _, tc := range cases {
		got, err := Within(root, tc.child)
		if err != nil {
			t.Fatal(err)
		}
		if got != tc.want {
			t.Fatalf("child %q: got %v want %v", tc.child, got, tc.want)
		}
	}
}

func TestProductDestination(t *testing.T) {
	got, err := ProductDestination(`C:\T\MQL5\Experts`)
	if err != nil {
		t.Fatal(err)
	}
	if got != `C:\T\MQL5\Experts\LotCraft` {
		t.Fatalf("got %q", got)
	}
}

func TestWithinRejectsDeceptivePrefixesAndOtherShares(t *testing.T) {
	root := `\\server\share\Terminal\MQL5\Experts`
	cases := []struct {
		child string
		want  bool
	}{
		{`\\server\share\Terminal\MQL5\Experts\LotCraft`, true},
		{`\\server\share\Terminal\MQL5\Experts-old\LotCraft`, false},
		{`\\server\share2\Terminal\MQL5\Experts\LotCraft`, false},
		{`\\other\share\Terminal\MQL5\Experts\LotCraft`, false},
	}
	for _, tc := range cases {
		got, err := Within(root, tc.child)
		if err != nil {
			t.Fatal(err)
		}
		if got != tc.want {
			t.Fatalf("child %q: got %v want %v", tc.child, got, tc.want)
		}
	}
}

func TestCleanWindowsPathRejectsMalformedUNCAndRelativeForms(t *testing.T) {
	for _, input := range []string{``, ` `, `\\server`, `\rooted\but\no\share`, `..\MQL5`, `C:MQL5\Experts`} {
		if _, err := CleanWindowsPath(input); err == nil {
			t.Fatalf("expected %q to be rejected", input)
		}
	}
}

func TestProductDestinationNeverUsesLegacyName(t *testing.T) {
	got, err := ProductDestination(`D:\Meta\MQL5\Experts\`)
	if err != nil {
		t.Fatal(err)
	}
	if got != `D:\Meta\MQL5\Experts\LotCraft` {
		t.Fatalf("got %q", got)
	}
}
