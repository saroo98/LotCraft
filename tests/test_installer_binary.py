from __future__ import annotations

import importlib.util
from pathlib import Path
import struct


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "stamp_pe_version.py"
spec = importlib.util.spec_from_file_location("stamp_pe_version", SCRIPT)
assert spec and spec.loader
stamp_pe_version = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stamp_pe_version)


def binary_bytes(binary: Path) -> bytearray:
    assert binary.is_file() and binary.stat().st_size > 0
    return bytearray(binary.read_bytes())


def test_installer_is_x64_windows_gui_pe_with_version_1_2(synthetic_installer: Path):
    raw = binary_bytes(synthetic_installer)
    pe_offset = struct.unpack_from("<I", raw, 0x3C)[0]
    coff = pe_offset + 4
    optional = coff + 20
    assert raw[pe_offset : pe_offset + 4] == b"PE\0\0"
    assert struct.unpack_from("<H", raw, coff)[0] == 0x8664
    assert struct.unpack_from("<H", raw, optional)[0] == 0x20B
    assert struct.unpack_from("<HH", raw, optional + 44) == (1, 0)
    assert struct.unpack_from("<H", raw, optional + 68)[0] == 2


def test_installer_has_valid_resource_directory_and_version_strings(synthetic_installer: Path):
    stamp_pe_version.verify(synthetic_installer)
    raw = binary_bytes(synthetic_installer)
    _optional, data_directory, _section_table, sections = stamp_pe_version.parse_pe_layout(raw)
    resource_rva, resource_size = struct.unpack_from("<II", raw, data_directory + 16)
    resource = next(section for section in sections if section["name"] == ".rsrc")
    assert resource_rva == resource["virtual_address"]
    assert resource_size > 0
    payload = bytes(raw[int(resource["raw_pointer"]) : int(resource["raw_pointer"]) + int(resource["raw_size"])])
    for text in ["LotCraft", "LotCraft 1.2.2 Installer", "1.2.2.0"]:
        assert stamp_pe_version.utf16z(text) in payload


def test_installer_pe_timestamp_is_reproducible_zero(synthetic_installer: Path):
    raw = binary_bytes(synthetic_installer)
    pe_offset = struct.unpack_from("<I", raw, 0x3C)[0]
    assert struct.unpack_from("<I", raw, pe_offset + 8)[0] == 0


def test_installer_pe_checksum_matches_contents(synthetic_installer: Path):
    raw = binary_bytes(synthetic_installer)
    optional, _data_directory, _section_table, _sections = stamp_pe_version.parse_pe_layout(raw)
    offset = optional + 64
    recorded = struct.unpack_from("<I", raw, offset)[0]
    assert recorded == stamp_pe_version.pe_checksum(raw, offset)


def test_alternate_build_embeds_the_pinned_update_key(synthetic_installer: Path):
    key = (ROOT / "installer" / "update-public-key.txt").read_text(encoding="utf-8").strip()
    # Go may omit linker flags from build-info with -trimpath. The key is not
    # present in the Go source or synthetic payload, so its bytes must come
    # from the alternate build's injected trusted-public-key value.
    assert key.encode("ascii") in synthetic_installer.read_bytes()
