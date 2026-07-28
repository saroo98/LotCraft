from __future__ import annotations

from dataclasses import replace

import pytest

from trade_reference import (
    Direction,
    RequestSnapshot,
    SlEntity,
    TradeGate,
    collect_sl_targets,
    execute_sl_batch,
    execute_trade,
    new_order_allowed,
)


def accepted_send(_snapshot: RequestSnapshot) -> tuple[bool, str]:
    return True, "DONE"


@pytest.mark.parametrize(
    ("field", "reason"),
    [
        ("connected", "no connection"),
        ("terminal_trade_allowed", "terminal trading disabled"),
        ("ea_trade_allowed", "EA trading disabled"),
        ("account_trade_allowed", "account trading disabled"),
        ("account_expert_allowed", "account trading disabled"),
        ("session_open", "market closed"),
        ("direction_allowed", "direction not permitted"),
    ],
)
def test_preflight_failures_send_nothing(field: str, reason: str):
    gate = TradeGate()
    setattr(gate, field, False)
    result = execute_trade(
        gate,
        now_ms=1000,
        snapshots=[RequestSnapshot()],
        confirmation_enabled=False,
        approvals=[],
        send=accepted_send,
    )
    assert not result.success
    assert not result.request_sent
    assert result.reason == reason
    assert gate.send_calls == 0


def test_confirmation_cancel_sends_nothing():
    gate = TradeGate()
    result = execute_trade(
        gate,
        now_ms=1000,
        snapshots=[RequestSnapshot(), RequestSnapshot()],
        confirmation_enabled=True,
        approvals=[False],
        send=accepted_send,
    )
    assert result.reason == "canceled"
    assert not result.request_sent
    assert gate.send_calls == 0


def test_unchanged_confirmation_sends_once():
    gate = TradeGate()
    snapshot = RequestSnapshot()
    result = execute_trade(
        gate,
        now_ms=1000,
        snapshots=[snapshot, snapshot],
        confirmation_enabled=True,
        approvals=[True],
        send=accepted_send,
    )
    assert result.success
    assert result.confirmations == 1
    assert gate.send_calls == 1


def test_material_change_uses_refreshed_request_without_second_confirmation():
    gate = TradeGate()
    first = RequestSnapshot(entry=1.1002, actual_risk=100)
    refreshed = replace(first, entry=1.1003, actual_risk=101)
    result = execute_trade(
        gate,
        now_ms=1000,
        snapshots=[first, refreshed],
        confirmation_enabled=True,
        approvals=[True],
        send=accepted_send,
    )
    assert result.success
    assert result.confirmations == 1
    assert gate.send_calls == 1


@pytest.mark.parametrize("retcode", ["REQUOTE", "INVALID_STOPS", "INVALID_VOLUME", "INVALID_FILL", "MARKET_CLOSED", "REJECT"])
def test_local_send_true_is_not_success_when_server_retcode_rejects(retcode: str):
    gate = TradeGate()
    result = execute_trade(
        gate,
        now_ms=1000,
        snapshots=[RequestSnapshot()],
        confirmation_enabled=False,
        approvals=[],
        send=lambda _snapshot: (True, retcode),
    )
    assert not result.success
    assert result.request_sent
    assert retcode in result.reason


def test_local_send_false_is_failure_even_with_done_retcode():
    gate = TradeGate()
    result = execute_trade(
        gate,
        now_ms=1000,
        snapshots=[RequestSnapshot()],
        confirmation_enabled=False,
        approvals=[],
        send=lambda _snapshot: (False, "DONE"),
    )
    assert not result.success
    assert result.reason == "local send failed"


@pytest.mark.parametrize("retcode", ["DONE", "PLACED", "DONE_PARTIAL"])
def test_only_accepted_server_retcodes_are_success(retcode: str):
    gate = TradeGate()
    result = execute_trade(
        gate,
        now_ms=1000,
        snapshots=[RequestSnapshot()],
        confirmation_enabled=False,
        approvals=[],
        send=lambda _snapshot: (True, retcode),
    )
    assert result.success


def test_double_click_debounce_and_inflight_guard_send_at_most_once():
    gate = TradeGate()
    first = execute_trade(
        gate,
        now_ms=1000,
        snapshots=[RequestSnapshot()],
        confirmation_enabled=False,
        approvals=[],
        send=accepted_send,
    )
    second = execute_trade(
        gate,
        now_ms=1200,
        snapshots=[RequestSnapshot()],
        confirmation_enabled=False,
        approvals=[],
        send=accepted_send,
    )
    gate.in_flight = True
    third = execute_trade(
        gate,
        now_ms=2000,
        snapshots=[RequestSnapshot()],
        confirmation_enabled=False,
        approvals=[],
        send=accepted_send,
    )
    assert first.success
    assert second.reason == "duplicate blocked"
    assert third.reason == "request in flight"
    assert gate.send_calls == 1


def test_netting_or_exchange_existing_position_is_blocked_but_hedging_is_allowed():
    assert not new_order_allowed(hedging=False, existing_symbol_positions=1)
    assert new_order_allowed(hedging=False, existing_symbol_positions=0)
    assert new_order_allowed(hedging=True, existing_symbol_positions=4)


def entity(ticket: int, *, symbol="EURUSD", direction=Direction.LONG, old_sl=0.0, tp=1.12, reference=1.10, is_position=True):
    return SlEntity(is_position, ticket, symbol, direction, 1.10, old_sl, tp, reference)


def test_move_sl_zero_eligible_targets():
    targets = collect_sl_targets(
        [
            entity(1, symbol="GBPUSD"),
            entity(2, old_sl=1.09),
            entity(3, direction=Direction.SHORT, reference=1.10),
        ],
        current_symbol="EURUSD",
        target_sl=1.09,
        tick_size=0.0001,
    )
    assert targets == []


def test_move_sl_filters_only_symbol_validity_and_unchanged_stops():
    targets = collect_sl_targets(
        [
            entity(1, old_sl=1.08),
            entity(2, old_sl=1.095),
            entity(3, symbol="GBPUSD"),
            entity(4, old_sl=1.09),
            entity(5, direction=Direction.SHORT, old_sl=1.08, reference=1.08),
        ],
        current_symbol="EURUSD",
        target_sl=1.09,
        tick_size=0.0001,
    )
    assert [target.entity.ticket for target in targets] == [1, 2, 5]


def test_move_sl_includes_both_directions_when_the_red_line_is_valid():
    targets = collect_sl_targets(
        [
            entity(1, direction=Direction.LONG, old_sl=1.08, reference=1.12),
            entity(2, direction=Direction.SHORT, old_sl=1.14, reference=1.10),
        ],
        current_symbol="EURUSD",
        target_sl=1.11,
        tick_size=0.0001,
    )
    assert [target.entity.ticket for target in targets] == [1, 2]


def test_move_sl_partial_success_is_reported_per_ticket_and_tp_is_preserved():
    targets = collect_sl_targets(
        [entity(10, tp=1.12), entity(11, tp=1.13), entity(12, tp=1.14, is_position=False)],
        current_symbol="EURUSD",
        target_sl=1.09,
        tick_size=0.0001,
    )
    result = execute_sl_batch(
        targets,
        {
            10: (True, "DONE"),
            11: (True, "INVALID_STOPS"),
            12: (True, "NO_CHANGES"),
        },
    )
    assert result.succeeded == 2
    assert result.failed == 1
    assert len(result.details) == 3
    assert "#10" in result.details[0] and "TP=1.12" in result.details[0]
    assert "#11" in result.details[1] and "INVALID_STOPS" in result.details[1]
    assert "#12" in result.details[2] and "NO_CHANGES" in result.details[2]
