"""Actual Win32 clipboard integration in an owned, noninteractive window station.

The child process verifies isolation before any clipboard operation. It has no
interactive fallback, input injection, terminal launch or displayed window.
"""
import sys

import pytest

from native_mql_harness import ROOT, compile_and_run, extract_function


@pytest.mark.skipif(sys.platform != "win32", reason="Real clipboard isolation requires Windows")
@pytest.mark.parametrize("zero_owner", [False, True], ids=["unicode-and-contention", "zero-owner-preserves-data"])
def test_production_platform_body_on_private_windows_clipboard(tmp_path, zero_owner):
    source = (ROOT / "tests/fixtures/clipboard_win32.cpp").read_text(encoding="utf-8")
    source = source.replace("// INSERT_PRODUCTION_COPY_FUNCTION", extract_function(
        "MQL5/Experts/LotCraft/PS_Platform.mqh", "PS_PlatformClipboardSet",
    ))
    if zero_owner:
        # Select an existing fixture branch without passing arguments through
        # the shared runner. The production function is not rewritten.
        source = source.replace('test_zero_owner=false', 'test_zero_owner=true')
    output = compile_and_run(tmp_path, source, link_args=("-luser32", "-ladvapi32"))
    if "ISOLATION_UNAVAILABLE:" in output:
        pytest.skip(output.strip())
    assert "PRIVATE_STATION_VERIFIED:" in output
