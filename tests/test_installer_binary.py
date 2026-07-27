from __future__ import annotations

import importlib.util
from pathlib import Path
import struct


ROOT = Path(__file__).resolve().parents[1]
BINARY = ROOT / "build" / "LotCraft-1.0.0-Setup.exe"
SCRIPT = ROOT / "scripts" / "stamp_pe_version.py"
spec = importlib.util.spec_from_file_location("stamp_pe_version", SCRIPT)
assert spec and spec.loader
stamp_pe_version = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stamp_pe_version)


def binary_bytes() -> bytearray:
    assert BINARY.is_file() and BINARY.stat().st_size > 0
    return bytearray(BINARY.read_bytes())


def test_installer_is_x64_windows_gui_pe_with_version_1_0():
    raw = binary_bytes()
    pe_offset = struct.unpack_from("<I", raw, 0x3C)[0]
    coff = pe_offset + 4
    optional = coff + 20
    assert raw[pe_offset : pe_offset + 4] == b"PE\0\0"
    assert struct.unpack_from("<H", raw, coff)[0] == 0x8664
    assert struct.unpack_from("<H", raw, optional)[0] == 0x20B
    assert struct.unpack_from("<HH", raw, optional + 44) == (1, 0)
    assert struct.unpack_from("<H", raw, optional + 68)[0] == 2


def test_installer_has_valid_resource_directory_and_version_strings():
    stamp_pe_version.verify(BINARY)
    raw = binary_bytes()
    _optional, data_directory, _section_table, sections = stamp_pe_version.parse_pe_layout(raw)
    resource_rva, resource_size = struct.unpack_from("<II", raw, data_directory + 16)
    resource = next(section for section in sections if section["name"] == ".rsrc")
    assert resource_rva == resource["virtual_address"]
    assert resource_size > 0
    payload = bytes(raw[int(resource["raw_pointer"]) : int(resource["raw_pointer"]) + int(resource["raw_size"])])
    for text in ["LotCraft", "LotCraft 1.0.0 Installer", "1.0.0.0"]:
        assert stamp_pe_version.utf16z(text) in payload


def test_installer_pe_timestamp_is_reproducible_zero():
    raw = binary_bytes()
    pe_offset = struct.unpack_from("<I", raw, 0x3C)[0]
    assert struct.unpack_from("<I", raw, pe_offset + 8)[0] == 0


def test_installer_pe_checksum_matches_contents():
    raw = binary_bytes()
    optional, _data_directory, _section_table, _sections = stamp_pe_version.parse_pe_layout(raw)
    offset = optional + 64
    recorded = struct.unpack_from("<I", raw, offset)[0]
    assert recorded == stamp_pe_version.pe_checksum(raw, offset)
