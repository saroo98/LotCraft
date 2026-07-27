from __future__ import annotations

import math
import pytest

from reference_model import parse_number


@pytest.mark.parametrize(
    ("text", "expected"),
    [
        ("1", 1.0),
        ("2", 2.0),
        ("1.25", 1.25),
        ("1,25", 1.25),
        (".5", 0.5),
        (",5", 0.5),
        ("-2", -2.0),
        ("+2", 2.0),
        ("0002.500", 2.5),
    ],
)
def test_valid_immediate_numeric_states(text, expected):
    parsed, value, incomplete = parse_number(text)
    assert parsed
    assert not incomplete
    assert value == pytest.approx(expected)


@pytest.mark.parametrize("text", ["", ".", ",", "-", "+", "-.", "-,", "+.", "+,"])
def test_incomplete_editing_states_are_not_applied(text):
    parsed, _value, incomplete = parse_number(text)
    assert not parsed
    assert incomplete


@pytest.mark.parametrize(
    "text",
    [
        "1.2.3",
        "1,2,3",
        "1.2,3",
        "--1",
        "+-1",
        "1-",
        "1e3",
        "NaN",
        "nan",
        "Infinity",
        "inf",
        "1 2",
        "£12",
        "abc",
    ],
)
def test_invalid_characters_nan_and_infinity_are_rejected(text):
    parsed, _value, incomplete = parse_number(text)
    assert not parsed
    assert not incomplete


def test_selection_replacement_semantics_reference():
    raw = "1"
    # Ctrl+A then typing 2 deletes the selection and inserts the new character.
    start, finish = 0, len(raw)
    raw = raw[:start] + "2" + raw[finish:]
    parsed, value, incomplete = parse_number(raw)
    assert parsed and not incomplete and value == 2


def test_backspace_and_delete_can_create_safe_incomplete_state():
    raw = "1"
    raw = raw[:-1]
    parsed, _value, incomplete = parse_number(raw)
    assert not parsed and incomplete


def test_very_large_finite_input_is_accepted_by_parser_but_domain_validation_remains_separate():
    parsed, value, incomplete = parse_number("99999999999999999999999999999999")
    assert parsed and not incomplete and math.isfinite(value)
