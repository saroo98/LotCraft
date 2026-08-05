#!/usr/bin/env python3
"""Add a VERSIONINFO resource to an existing PE executable.

The script uses GNU/LLVM objcopy only to append a read-only .rsrc section, then
patches the PE resource data-directory entry and the version-resource data RVA.
It refuses to operate when a .rsrc section already exists.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile


RT_VERSION = 16
LANG_EN_US = 0x0409
CODEPAGE_UNICODE = 1200


def align4(data: bytes) -> bytes:
    return data + b"\0" * ((-len(data)) % 4)


def utf16z(text: str) -> bytes:
    return text.encode("utf-16le") + b"\0\0"


def version_block(
    key: str,
    *,
    value: bytes = b"",
    value_length: int = 0,
    value_type: int = 1,
    children: tuple[bytes, ...] = (),
) -> bytes:
    data = struct.pack("<HHH", 0, value_length, value_type) + utf16z(key)
    data = align4(data)
    data += value
    if children:
        data = align4(data)
        for child in children:
            data += child
    data = bytearray(data)
    struct.pack_into("<H", data, 0, len(data))
    return bytes(data)


def string_value(key: str, value: str) -> bytes:
    encoded = utf16z(value)
    return version_block(
        key,
        value=encoded,
        value_length=len(encoded) // 2,
        value_type=1,
    )


def make_version_info(
    *,
    product: str,
    version: tuple[int, int, int, int],
    filename: str,
    description: str,
) -> bytes:
    major, minor, patch, build = version
    version_ms = (major << 16) | minor
    version_ls = (patch << 16) | build
    fixed = struct.pack(
        "<13I",
        0xFEEF04BD,  # VS_FFI_SIGNATURE
        0x00010000,  # VS_FFI_STRUCVERSION
        version_ms,
        version_ls,
        version_ms,
        version_ls,
        0x0000003F,  # VS_FFI_FILEFLAGSMASK
        0,
        0x00040004,  # VOS_NT_WINDOWS32
        0x00000001,  # VFT_APP
        0,
        0,
        0,
    )

    string_table = version_block(
        "040904B0",
        value_type=1,
        children=tuple(
            string_value(key, value)
            for key, value in (
                ("CompanyName", product),
                ("FileDescription", description),
                ("FileVersion", ".".join(map(str, version))),
                ("InternalName", Path(filename).stem),
                ("OriginalFilename", filename),
                ("ProductName", product),
                ("ProductVersion", f"{major}.{minor}.{patch}"),
                ("LegalCopyright", product),
                ("Comments", "MetaTrader 5 Expert Advisor installer"),
            )
        ),
    )
    string_file_info = version_block(
        "StringFileInfo",
        value_type=1,
        children=(string_table,),
    )
    translation = struct.pack("<HH", LANG_EN_US, CODEPAGE_UNICODE)
    var = version_block(
        "Translation",
        value=translation,
        value_length=len(translation),
        value_type=0,
    )
    var_file_info = version_block(
        "VarFileInfo",
        value_type=1,
        children=(var,),
    )
    return version_block(
        "VS_VERSION_INFO",
        value=fixed,
        value_length=len(fixed),
        value_type=0,
        children=(string_file_info, var_file_info),
    )


def make_resource_section(version_info: bytes) -> tuple[bytes, int, int]:
    # Three ID-only directory levels: RT_VERSION -> ID 1 -> en-US.
    root_offset = 0
    type_offset = 24
    name_offset = 48
    data_entry_offset = 72
    blob_offset = 88

    directory = struct.pack("<IIHHHH", 0, 0, 0, 0, 0, 1)
    root = directory + struct.pack("<II", RT_VERSION, 0x80000000 | type_offset)
    type_dir = directory + struct.pack("<II", 1, 0x80000000 | name_offset)
    name_dir = directory + struct.pack("<II", LANG_EN_US, data_entry_offset)
    data_entry = struct.pack("<IIII", 0, len(version_info), CODEPAGE_UNICODE, 0)
    section = root + type_dir + name_dir + data_entry
    if len(section) != blob_offset:
        raise AssertionError(f"resource layout error: {len(section)}")
    section += version_info
    return align4(section), data_entry_offset, blob_offset


def parse_pe_layout(raw: bytearray) -> tuple[int, int, int, list[dict[str, int | str]]]:
    if raw[:2] != b"MZ":
        raise ValueError("input is not a PE executable (missing MZ)")
    pe_offset = struct.unpack_from("<I", raw, 0x3C)[0]
    if raw[pe_offset : pe_offset + 4] != b"PE\0\0":
        raise ValueError("input is not a PE executable (missing PE signature)")
    coff = pe_offset + 4
    section_count = struct.unpack_from("<H", raw, coff + 2)[0]
    optional_size = struct.unpack_from("<H", raw, coff + 16)[0]
    optional = coff + 20
    magic = struct.unpack_from("<H", raw, optional)[0]
    if magic == 0x20B:
        data_directory = optional + 112
    elif magic == 0x10B:
        data_directory = optional + 96
    else:
        raise ValueError(f"unsupported PE optional-header magic 0x{magic:04x}")
    section_table = optional + optional_size
    sections: list[dict[str, int | str]] = []
    for index in range(section_count):
        base = section_table + index * 40
        name = bytes(raw[base : base + 8]).split(b"\0", 1)[0].decode("ascii", "replace")
        virtual_size, virtual_address, raw_size, raw_pointer = struct.unpack_from("<IIII", raw, base + 8)
        sections.append(
            {
                "name": name,
                "virtual_size": virtual_size,
                "virtual_address": virtual_address,
                "raw_size": raw_size,
                "raw_pointer": raw_pointer,
            }
        )
    return optional, data_directory, section_table, sections



def pe_checksum(raw: bytearray, checksum_offset: int) -> int:
    working = bytearray(raw)
    struct.pack_into("<I", working, checksum_offset, 0)
    checksum = 0
    length = len(working)
    for offset in range(0, length, 2):
        word = working[offset]
        if offset + 1 < length:
            word |= working[offset + 1] << 8
        checksum = (checksum & 0xFFFF) + (checksum >> 16) + word
        checksum = (checksum & 0xFFFF) + (checksum >> 16)
    checksum = (checksum & 0xFFFF) + (checksum >> 16)
    return (checksum + length) & 0xFFFFFFFF


def stamp(input_path: Path, output_path: Path, *, objcopy: str) -> None:
    version_info = make_version_info(
        product="LotCraft",
        version=(1, 1, 0, 0),
        filename="LotCraft-1.1.0-Setup.exe",
        description="LotCraft 1.1.0 Installer",
    )
    section, data_entry_offset, blob_offset = make_resource_section(version_info)

    input_raw = bytearray(input_path.read_bytes())
    input_pe_offset = struct.unpack_from("<I", input_raw, 0x3C)[0]
    input_timestamp = struct.unpack_from("<I", input_raw, input_pe_offset + 8)[0]
    optional, _data_directory, _section_table, input_sections = parse_pe_layout(input_raw)
    if any(section_info["name"] == ".rsrc" for section_info in input_sections):
        raise ValueError("input already contains a .rsrc section")
    magic = struct.unpack_from("<H", input_raw, optional)[0]
    if magic == 0x20B:
        image_base = struct.unpack_from("<Q", input_raw, optional + 24)[0]
    else:
        image_base = struct.unpack_from("<I", input_raw, optional + 28)[0]
    size_of_image = struct.unpack_from("<I", input_raw, optional + 56)[0]
    resource_vma = image_base + size_of_image

    with tempfile.TemporaryDirectory(prefix="LotCraft-version-") as temp_dir:
        temp = Path(temp_dir)
        resource_path = temp / "version.rsrc"
        unstamped_copy = temp / "input.exe"
        appended_path = temp / "appended.exe"
        resource_path.write_bytes(section)
        shutil.copyfile(input_path, unstamped_copy)
        command = [
            objcopy,
            "--add-section",
            f".rsrc={resource_path}",
            "--set-section-flags",
            ".rsrc=alloc,load,readonly,data,contents",
            "--change-section-vma",
            f".rsrc=0x{resource_vma:x}",
            str(unstamped_copy),
            str(appended_path),
        ]
        subprocess.run(command, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        raw = bytearray(appended_path.read_bytes())

    _optional, data_directory, _section_table, sections = parse_pe_layout(raw)
    matches = [section_info for section_info in sections if section_info["name"] == ".rsrc"]
    if len(matches) != 1:
        raise ValueError(f"expected one .rsrc section after stamping, found {len(matches)}")
    resource = matches[0]
    rva = int(resource["virtual_address"])
    raw_pointer = int(resource["raw_pointer"])
    raw_size = int(resource["raw_size"])
    if raw_size < len(section):
        raise ValueError("objcopy truncated the VERSIONINFO resource section")

    # IMAGE_RESOURCE_DATA_ENTRY.OffsetToData is an RVA.
    struct.pack_into("<I", raw, raw_pointer + data_entry_offset, rva + blob_offset)
    # IMAGE_OPTIONAL_HEADER.DataDirectory[IMAGE_DIRECTORY_ENTRY_RESOURCE].
    struct.pack_into("<II", raw, data_directory + 2 * 8, rva, len(section))
    # objcopy updates the COFF timestamp; restore the original Go linker value so
    # identical source produces an identical installer.
    output_pe_offset = struct.unpack_from("<I", raw, 0x3C)[0]
    struct.pack_into("<I", raw, output_pe_offset + 8, input_timestamp)
    # Recompute IMAGE_OPTIONAL_HEADER.CheckSum after all header/data patches.
    checksum_offset = _optional + 64
    struct.pack_into("<I", raw, checksum_offset, pe_checksum(raw, checksum_offset))

    output_path.parent.mkdir(parents=True, exist_ok=True)
    temporary = output_path.with_suffix(output_path.suffix + ".tmp")
    temporary.write_bytes(raw)
    os.replace(temporary, output_path)


def verify(path: Path) -> None:
    raw = bytearray(path.read_bytes())
    _optional, data_directory, _section_table, sections = parse_pe_layout(raw)
    resource_rva, resource_size = struct.unpack_from("<II", raw, data_directory + 2 * 8)
    matches = [section for section in sections if section["name"] == ".rsrc"]
    if len(matches) != 1:
        raise ValueError("VERSIONINFO verification failed: .rsrc section missing")
    resource = matches[0]
    if resource_rva != resource["virtual_address"] or resource_size <= 0:
        raise ValueError("VERSIONINFO verification failed: resource data directory is invalid")
    start = int(resource["raw_pointer"])
    end = start + min(int(resource["raw_size"]), resource_size)
    payload = bytes(raw[start:end])
    for text in [
        "VS_VERSION_INFO",
        "LotCraft",
        "LotCraft 1.1.0 Installer",
        "LotCraft-1.1.0-Setup.exe",
        "1.1.0.0",
    ]:
        if utf16z(text) not in payload:
            raise ValueError(f"VERSIONINFO verification failed: missing {text!r}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--objcopy", default=shutil.which("objcopy") or shutil.which("llvm-objcopy"))
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()
    if args.verify_only:
        verify(args.input)
        return
    if not args.objcopy:
        raise SystemExit("objcopy or llvm-objcopy is required")
    stamp(args.input, args.output, objcopy=args.objcopy)
    verify(args.output)


if __name__ == "__main__":
    main()
