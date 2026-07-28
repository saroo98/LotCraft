from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import Callable, Iterable


class Direction(Enum):
    LONG = "Long"
    SHORT = "Short"


ACCEPTED_RETCODES = {"DONE", "PLACED", "DONE_PARTIAL"}
SL_ACCEPTED_RETCODES = ACCEPTED_RETCODES | {"NO_CHANGES"}


@dataclass
class TradeGate:
    connected: bool = True
    terminal_trade_allowed: bool = True
    ea_trade_allowed: bool = True
    account_trade_allowed: bool = True
    account_expert_allowed: bool = True
    session_known: bool = True
    session_open: bool = True
    direction_allowed: bool = True
    in_flight: bool = False
    last_submit_ms: int = -10_000
    send_calls: int = 0


@dataclass(frozen=True)
class RequestSnapshot:
    symbol: str = "EURUSD"
    direction: Direction = Direction.LONG
    order_type: str = "Buy market"
    entry: float = 1.1002
    stop: float = 1.0980
    take: float = 1.1040
    volume: float = 0.1
    actual_risk: float = 100.0


@dataclass(frozen=True)
class ExecutionResult:
    success: bool
    request_sent: bool
    reason: str
    confirmations: int = 0


@dataclass(frozen=True)
class SlEntity:
    is_position: bool
    ticket: int
    symbol: str
    direction: Direction
    entry: float
    old_sl: float
    tp: float
    protective_reference: float


@dataclass(frozen=True)
class SlTarget:
    entity: SlEntity
    target_sl: float


@dataclass(frozen=True)
class BatchResult:
    succeeded: int
    failed: int
    details: tuple[str, ...]


def permission_error(gate: TradeGate) -> str | None:
    if not gate.connected:
        return "no connection"
    if not gate.terminal_trade_allowed:
        return "terminal trading disabled"
    if not gate.ea_trade_allowed:
        return "EA trading disabled"
    if not gate.account_trade_allowed or not gate.account_expert_allowed:
        return "account trading disabled"
    if gate.session_known and not gate.session_open:
        return "market closed"
    if not gate.direction_allowed:
        return "direction not permitted"
    return None


def execute_trade(
    gate: TradeGate,
    *,
    now_ms: int,
    snapshots: list[RequestSnapshot],
    confirmation_enabled: bool,
    approvals: Iterable[bool],
    send: Callable[[RequestSnapshot], tuple[bool, str]],
) -> ExecutionResult:
    if gate.in_flight:
        return ExecutionResult(False, False, "request in flight")
    if now_ms - gate.last_submit_ms < 750:
        return ExecutionResult(False, False, "duplicate blocked")
    if error := permission_error(gate):
        return ExecutionResult(False, False, error)
    if not snapshots:
        return ExecutionResult(False, False, "invalid snapshot")

    approvals_iter = iter(approvals)
    confirmations = 0
    selected = snapshots[0]
    if confirmation_enabled:
        confirmations += 1
        if not next(approvals_iter, False):
            return ExecutionResult(False, False, "canceled", confirmations)
        if len(snapshots) < 2:
            return ExecutionResult(False, False, "refresh unavailable", confirmations)
        selected = snapshots[1]

    gate.in_flight = True
    gate.last_submit_ms = now_ms
    try:
        gate.send_calls += 1
        local, retcode = send(selected)
    finally:
        gate.in_flight = False
    if not local:
        return ExecutionResult(False, True, "local send failed", confirmations)
    if retcode not in ACCEPTED_RETCODES:
        return ExecutionResult(False, True, f"server rejected: {retcode}", confirmations)
    return ExecutionResult(True, True, retcode, confirmations)


def new_order_allowed(*, hedging: bool, existing_symbol_positions: int) -> bool:
    return hedging or existing_symbol_positions == 0


def sl_needs_change(old_sl: float, target_sl: float, tick_size: float) -> bool:
    if target_sl <= 0 or tick_size <= 0:
        return False
    if old_sl <= 0:
        return True
    return abs(old_sl - target_sl) > tick_size * 0.5


def sl_price_valid(entity: SlEntity, target_sl: float, tick_size: float) -> bool:
    tolerance = tick_size * 0.5
    if entity.direction is Direction.LONG:
        return target_sl < entity.protective_reference - tolerance
    return target_sl > entity.protective_reference + tolerance


def collect_sl_targets(
    entities: Iterable[SlEntity],
    *,
    current_symbol: str,
    target_sl: float,
    tick_size: float,
) -> list[SlTarget]:
    targets: list[SlTarget] = []
    for entity in entities:
        if entity.symbol != current_symbol:
            continue
        if not sl_needs_change(entity.old_sl, target_sl, tick_size):
            continue
        if not sl_price_valid(entity, target_sl, tick_size):
            continue
        targets.append(SlTarget(entity=entity, target_sl=target_sl))
    return targets


def execute_sl_batch(
    targets: Iterable[SlTarget],
    outcomes: dict[int, tuple[bool, str]],
) -> BatchResult:
    succeeded = 0
    failed = 0
    details: list[str] = []
    for target in targets:
        local, retcode = outcomes[target.entity.ticket]
        if local and retcode in SL_ACCEPTED_RETCODES:
            succeeded += 1
            details.append(f"#{target.entity.ticket}: {retcode}; TP={target.entity.tp}")
        else:
            failed += 1
            details.append(f"#{target.entity.ticket}: failed {retcode}; TP={target.entity.tp}")
    return BatchResult(succeeded, failed, tuple(details))
