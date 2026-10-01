"""Execute selected production MQL helper bodies with explicit platform stubs.

This is native C++ execution of the source, not an MT5 integration test. Tests
must stub terminal/broker APIs and document the boundary they do not exercise.
No production function bodies are rewritten or translated by this utility.
"""

from pathlib import Path
import re
import shutil
import subprocess

import pytest


ROOT = Path(__file__).resolve().parents[1]


def _code_characters(text: str, start: int):
    """Yield only syntax characters, excluding literals and comments."""
    index = start
    while index < len(text):
        if text.startswith("//", index):
            end = text.find("\n", index + 2)
            index = len(text) if end < 0 else end + 1
        elif text.startswith("/*", index):
            end = text.find("*/", index + 2)
            if end < 0:
                raise ValueError("Unterminated source comment")
            index = end + 2
        elif text[index] in "\"'":
            quote = text[index]
            index += 1
            while index < len(text):
                if text[index] == "\\":
                    index += 2
                elif text[index] == quote:
                    index += 1
                    break
                else:
                    index += 1
        else:
            yield index, text[index]
            index += 1


def extract_function(source_rel: str | Path, name: str) -> str:
    path = Path(source_rel)
    source = (path if path.is_absolute() else ROOT / path).read_text(encoding="utf-8-sig")
    declaration = re.compile(
        rf"(?m)^[ \t]*(?:[A-Za-z_]\w*[ \t*&]+)+{re.escape(name)}\s*\("
    )
    for match in declaration.finditer(source):
        depth = 0
        opened = False
        for index, character in _code_characters(source, match.start()):
            if not opened and character == ";":
                break  # Forward declaration, not the implementation.
            if character == "{":
                opened = True
                depth += 1
            elif character == "}" and opened:
                depth -= 1
                if depth == 0:
                    return source[match.start() : index + 1]
    raise ValueError(f"Function implementation {name!r} not found in {path.name}")


def extract_functions(source_rel: str | Path, *names: str) -> str:
    return "\n\n".join(extract_function(source_rel, name) for name in names)


def compile_and_run(tmp_path: Path, source_string: str, *, link_args: tuple[str, ...] = ()) -> str:
    compiler = shutil.which("g++")
    if compiler is None:
        pytest.skip("Native production-function tests require g++ on PATH; MT5 behavior remains unverified")
    source = tmp_path / "native_fixture.cpp"
    executable = tmp_path / "native_fixture.exe"
    source.write_text(source_string, encoding="utf-8")
    build = subprocess.run(
        [compiler, "-std=c++17", "-O0", "-Wall", "-Wextra", str(source), "-o", str(executable), *link_args],
        capture_output=True,
        text=True,
        timeout=60,
    )
    assert build.returncode == 0, f"Native fixture compilation failed:\n{build.stdout}\n{build.stderr}"
    result = subprocess.run([str(executable)], capture_output=True, text=True, timeout=15)
    assert result.returncode == 0, f"Native fixture execution failed:\n{result.stdout}\n{result.stderr}"
    return result.stdout
