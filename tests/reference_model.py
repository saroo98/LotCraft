"""Deterministic reference model for LotCraft offline verification.

This module mirrors the safety-critical arithmetic and parsing policies in the
MQL5 source. It does not pretend to replace OrderCalcProfit or broker-side
OrderCheck; symbol fixtures supply a one-lot loss already expressed in account
currency, which is exactly the value the EA obtains from OrderCalcProfit.
"""

from __future__ import annotations

from dataclasses import dataclass, replace
from enum import Enum
import math


class Direction(str, Enum):
    LONG = "Long"
    SHORT = "Short"


class OrderMode(str, Enum):
    INSTANT = "Instant"
    PENDING = "Pending"


class AccountMode(str, Enum):
    EQUITY = "Equity"
    BALANCE = "Balance"
    MANUAL = "Manual"


class RiskAuthority(str, Enum):
    PERCENT = "Percent"
    MONEY = "Money"


class CommissionMode(str, Enum):
    ONE_SIDE = "One side"
    ROUND_TRIP = "Round trip"


class OrderType(str, Enum):
    BUY = "Buy market"
    SELL = "Sell market"
    BUY_LIMIT = "Buy Limit"
    BUY_STOP = "Buy Stop"
    SELL_LIMIT = "Sell Limit"
    SELL_STOP = "Sell Stop"


@dataclass(frozen=True)
class Market:
    symbol: str = "EURUSD"
    bid: float = 1.1000
    ask: float = 1.1002
    point: float = 0.00001
    tick_size: float = 0.00001
    digits: int = 5
    volume_min: float = 0.01
    volume_max: float = 100.0
    volume_step: float = 0.01
    volume_limit: float = 0.0
    exposure_long: float = 0.0
    exposure_short: float = 0.0
    stops_level_points: int = 10
    freeze_level_points: int = 0
    equity: float = 10_000.0
    balance: float = 10_000.0
    account_currency: str = "USD"
    one_lot_price_loss: float = 100.0
    valid: bool = True
    allow_limit: bool = True
    allow_stop: bool = True

    @property
    def protective_distance(self) -> float:
        points = max(self.stops_level_points, self.freeze_level_points)
        return max(points * self.point, self.tick_size)


@dataclass(frozen=True)
class Model:
    direction: Direction = Direction.LONG
    order_mode: OrderMode = OrderMode.INSTANT
    account_mode: AccountMode = AccountMode.EQUITY
    risk_authority: RiskAuthority = RiskAuthority.PERCENT
    commission_mode: CommissionMode = CommissionMode.ROUND_TRIP
    entry: float = 1.1002
    stop_loss: float = 1.0992
    take_profit: float = 0.0
    manual_account_money: float = 20_000.0
    requested_risk_percent: float = 1.0
    requested_risk_money: float = 100.0
    commission_per_lot: float = 0.0
    revision: int = 1


@dataclass(frozen=True)
class Result:
    valid: bool
    error: str = ""
    order_type: OrderType | None = None
    effective_entry: float = 0.0
    account_basis: float = 0.0
    requested_money: float = 0.0
    requested_percent: float = 0.0
    one_lot_risk: float = 0.0
    raw_volume: float = 0.0
    volume: float = 0.0
    actual_money: float = 0.0
    actual_percent: float = 0.0
    volume_capped: bool = False
    volume_raised_to_minimum: bool = False


def is_positive_finite(value: float) -> bool:
    return math.isfinite(value) and value > 0.0


def decimals_for_step(step: float) -> int:
    if not is_positive_finite(step):
        return 2
    for digits in range(9):
        if abs(step - round(step, digits)) <= max(1e-12, step * 1e-9):
            return digits
    return 8


def normalize_price(price: float, market: Market) -> float:
    if not math.isfinite(price) or not is_positive_finite(market.tick_size):
        return 0.0
    # Python round uses bankers' rounding; fixtures avoid half-tick ties.
    steps = math.floor(price / market.tick_size + 0.5)
    return round(steps * market.tick_size, market.digits)


def default_level_distance(reference: float, market: Market) -> float:
    return max(
        market.protective_distance + market.tick_size,
        100 * market.tick_size,
        abs(reference) * 0.002,
    )


def pending_leg_gap(market: Market) -> float:
    spread = max(0.0, market.ask - market.bid)
    return max(
        market.protective_distance + 4 * market.tick_size,
        8 * market.tick_size,
        2 * spread,
    )


def outward_price(reference: float, distance: float, sign: int, market: Market) -> float:
    ticks = max(1, math.ceil(distance / market.tick_size - 1e-12))
    for _ in range(4):
        candidate = normalize_price(reference + sign * ticks * market.tick_size, market)
        if candidate > 0 and sign * (candidate - reference) + 1e-12 >= distance:
            return candidate
        ticks += 1
    raise ValueError("outward price unavailable")


def required_fresh_gap(
    reference: float,
    market: Market,
    *,
    visible_min: float | None = None,
    visible_max: float | None = None,
    chart_height: int = 0,
    pending: bool = False,
) -> float:
    gap = max(default_level_distance(reference, market), 3 * pending_leg_gap(market))
    if (
        chart_height > 0
        and visible_min is not None
        and visible_max is not None
        and visible_min <= reference <= visible_max
        and visible_max > visible_min
    ):
        visual = (visible_max - visible_min) * 34 / chart_height
        gap = max(gap, visual / 0.60 if pending else visual)
    return gap


def _limit_entry(reference: float, stop: float, direction: Direction, market: Market) -> float:
    leg = pending_leg_gap(market)
    available = abs(reference - stop)
    minimum_ticks = max(1, math.ceil(leg / market.tick_size - 1e-12))
    available_ticks = math.floor(available / market.tick_size + 1e-12)
    maximum_ticks = available_ticks - minimum_ticks
    if maximum_ticks < minimum_ticks:
        raise ValueError("limit geometry unavailable")
    target_ticks = min(maximum_ticks, max(minimum_ticks, math.ceil(available_ticks * 0.40 - 1e-12)))
    sign = -1 if direction is Direction.LONG else 1
    entry = normalize_price(reference + sign * target_ticks * market.tick_size, market)
    quote_leg = reference - entry if direction is Direction.LONG else entry - reference
    stop_leg = entry - stop if direction is Direction.LONG else stop - entry
    if quote_leg + 1e-12 < leg or stop_leg + 1e-12 < leg:
        raise ValueError("limit geometry unavailable")
    return entry


def _stop_entry(reference: float, stop: float, direction: Direction, market: Market) -> float:
    leg = pending_leg_gap(market)
    if direction is Direction.LONG:
        required = max(leg, stop - reference + leg)
        return outward_price(reference, required, 1, market)
    required = max(leg, reference - stop + leg)
    return outward_price(reference, required, -1, market)


def build_fresh_symbol_plan(
    model: Model,
    market: Market,
    *,
    visible_min: float | None = None,
    visible_max: float | None = None,
    chart_height: int = 0,
) -> Model:
    if not market.valid or market.ask <= 0 or market.bid <= 0 or market.tick_size <= 0:
        raise ValueError("quote invalid")
    reference = normalize_price(market.ask if model.direction is Direction.LONG else market.bid, market)
    gap = required_fresh_gap(
        reference,
        market,
        visible_min=visible_min,
        visible_max=visible_max,
        chart_height=chart_height,
        pending=model.order_mode is OrderMode.PENDING,
    )
    stop = outward_price(reference, gap, -1 if model.direction is Direction.LONG else 1, market)
    if model.order_mode is OrderMode.INSTANT:
        entry = reference
    elif market.allow_limit:
        entry = _limit_entry(reference, stop, model.direction, market)
    elif market.allow_stop:
        entry = _stop_entry(reference, stop, model.direction, market)
    else:
        raise ValueError("pending subtype unsupported")
    take = 0.0
    if model.take_profit > 0:
        take = outward_price(entry, gap, 1 if model.direction is Direction.LONG else -1, market)
    candidate = replace(model, entry=entry, stop_loss=stop, take_profit=take, revision=model.revision + 1)
    order_type, effective_entry = resolve_order(candidate, market)
    _validate_prices(candidate, market, effective_entry)
    if model.order_mode is OrderMode.PENDING and order_type not in {
        OrderType.BUY_LIMIT,
        OrderType.SELL_LIMIT,
        OrderType.BUY_STOP,
        OrderType.SELL_STOP,
    }:
        raise AssertionError("fresh pending plan did not resolve as pending")
    return candidate


def change_order_mode(model: Model, market: Market, new_mode: OrderMode) -> Model:
    if model.order_mode is new_mode:
        return model
    reference = normalize_price(market.ask if model.direction is Direction.LONG else market.bid, market)
    if new_mode is OrderMode.PENDING:
        if market.allow_limit:
            try:
                entry = _limit_entry(reference, model.stop_loss, model.direction, market)
            except ValueError:
                if not market.allow_stop:
                    raise
                entry = _stop_entry(reference, model.stop_loss, model.direction, market)
        elif market.allow_stop:
            entry = _stop_entry(reference, model.stop_loss, model.direction, market)
        else:
            raise ValueError("pending subtype unsupported")
        take = model.take_profit
        minimum = market.protective_distance + market.tick_size
        take_valid = take <= 0 or (
            take - entry >= minimum if model.direction is Direction.LONG else entry - take >= minimum
        )
        if not take_valid:
            distance = max(abs(model.take_profit - model.entry), minimum)
            take = outward_price(entry, distance, 1 if model.direction is Direction.LONG else -1, market)
        candidate = replace(
            model,
            order_mode=OrderMode.PENDING,
            entry=entry,
            stop_loss=model.stop_loss,
            take_profit=take,
            revision=model.revision + 1,
        )
    else:
        delta = reference - model.entry
        candidate = replace(
            model,
            order_mode=OrderMode.INSTANT,
            entry=reference,
            stop_loss=normalize_price(model.stop_loss + delta, market),
            take_profit=normalize_price(model.take_profit + delta, market) if model.take_profit > 0 else 0.0,
            revision=model.revision + 1,
        )
    _, effective_entry = resolve_order(candidate, market)
    _validate_prices(candidate, market, effective_entry)
    return candidate


def floor_volume(requested: float, minimum: float, maximum: float, step: float) -> float:
    if not all(is_positive_finite(v) for v in (requested, minimum, maximum, step)):
        return 0.0
    if maximum < minimum:
        return 0.0
    capped = min(requested, maximum)
    epsilon = step * 1e-9
    if capped + epsilon < minimum:
        return 0.0
    count = math.floor((capped - minimum + epsilon) / step)
    volume = minimum + count * step
    if volume > capped + epsilon:
        volume -= step
    if volume + epsilon < minimum:
        return 0.0
    volume = min(volume, maximum)
    digits = decimals_for_step(step)
    volume = round(volume, digits)
    if volume > capped + epsilon:
        volume = round(volume - step, digits)
    return volume if volume + epsilon >= minimum else 0.0


def resolve_order(model: Model, market: Market) -> tuple[OrderType, float]:
    if not market.valid or not is_positive_finite(market.bid) or not is_positive_finite(market.ask):
        raise ValueError("quote invalid")
    if market.ask < market.bid:
        raise ValueError("crossed quote")
    if model.order_mode is OrderMode.INSTANT:
        entry = market.ask if model.direction is Direction.LONG else market.bid
        return (OrderType.BUY if model.direction is Direction.LONG else OrderType.SELL, normalize_price(entry, market))

    entry = normalize_price(model.entry, market)
    if not is_positive_finite(entry):
        raise ValueError("pending entry invalid")
    tolerance = market.tick_size * 0.5
    minimum = market.protective_distance
    if model.direction is Direction.LONG:
        if entry < market.ask - tolerance:
            if market.ask - entry + 1e-12 < minimum:
                raise ValueError("buy limit inside broker distance")
            return OrderType.BUY_LIMIT, entry
        if entry > market.ask + tolerance:
            if entry - market.ask + 1e-12 < minimum:
                raise ValueError("buy stop inside broker distance")
            return OrderType.BUY_STOP, entry
        raise ValueError("long pending ambiguous")
    if entry > market.bid + tolerance:
        if entry - market.bid + 1e-12 < minimum:
            raise ValueError("sell limit inside broker distance")
        return OrderType.SELL_LIMIT, entry
    if entry < market.bid - tolerance:
        if market.bid - entry + 1e-12 < minimum:
            raise ValueError("sell stop inside broker distance")
        return OrderType.SELL_STOP, entry
    raise ValueError("short pending ambiguous")


def _validate_prices(model: Model, market: Market, effective_entry: float) -> None:
    stop = model.stop_loss
    take = model.take_profit
    tp_enabled = is_positive_finite(take)
    tolerance = market.tick_size * 0.5
    if not is_positive_finite(stop):
        raise ValueError("stop invalid")
    if model.direction is Direction.LONG:
        if stop >= effective_entry - tolerance:
            raise ValueError("long stop crossed")
        if tp_enabled and take <= effective_entry + tolerance:
            raise ValueError("long take crossed")
    else:
        if stop <= effective_entry + tolerance:
            raise ValueError("short stop crossed")
        if tp_enabled and take >= effective_entry - tolerance:
            raise ValueError("short take crossed")

    minimum = market.protective_distance
    if model.order_mode is OrderMode.PENDING:
        stop_distance = effective_entry - stop if model.direction is Direction.LONG else stop - effective_entry
        if stop_distance + 1e-12 < minimum:
            raise ValueError("pending stop inside broker distance")
        if tp_enabled:
            take_distance = take - effective_entry if model.direction is Direction.LONG else effective_entry - take
            if take_distance + 1e-12 < minimum:
                raise ValueError("pending take inside broker distance")
        return

    if model.direction is Direction.LONG:
        if market.bid - stop + 1e-12 < minimum:
            raise ValueError("long stop inside bid distance")
        if tp_enabled and take - market.bid + 1e-12 < minimum:
            raise ValueError("long take inside bid distance")
    else:
        if stop - market.ask + 1e-12 < minimum:
            raise ValueError("short stop inside ask distance")
        if tp_enabled and market.ask - take + 1e-12 < minimum:
            raise ValueError("short take inside ask distance")


def calculate(model: Model, market: Market) -> Result:
    try:
        if not market.valid:
            raise ValueError("symbol data invalid")
        if not all(is_positive_finite(v) for v in (market.tick_size, market.point, market.volume_min, market.volume_max, market.volume_step)):
            raise ValueError("broker constraints invalid")
        if market.volume_max < market.volume_min:
            raise ValueError("broker constraints invalid")

        if model.account_mode is AccountMode.EQUITY:
            basis = market.equity
        elif model.account_mode is AccountMode.BALANCE:
            basis = market.balance
        else:
            basis = model.manual_account_money
        if not is_positive_finite(basis):
            raise ValueError("account basis invalid")

        if model.risk_authority is RiskAuthority.PERCENT:
            if not is_positive_finite(model.requested_risk_percent):
                raise ValueError("risk percent invalid")
            requested_percent = model.requested_risk_percent
            requested_money = basis * requested_percent / 100.0
        else:
            if not is_positive_finite(model.requested_risk_money):
                raise ValueError("risk money invalid")
            requested_money = model.requested_risk_money
            requested_percent = requested_money / basis * 100.0

        order_type, entry = resolve_order(model, market)
        _validate_prices(model, market, entry)
        if not math.isfinite(model.commission_per_lot) or model.commission_per_lot < 0.0:
            raise ValueError("commission invalid")
        commission = model.commission_per_lot * (2.0 if model.commission_mode is CommissionMode.ONE_SIDE else 1.0)
        if not is_positive_finite(market.one_lot_price_loss):
            raise ValueError("one-lot loss invalid")
        one_lot_risk = market.one_lot_price_loss + commission
        if not is_positive_finite(one_lot_risk):
            raise ValueError("one-lot risk invalid")

        raw = requested_money / one_lot_risk
        exposure = market.exposure_long if model.direction is Direction.LONG else market.exposure_short
        cap = market.volume_max
        if is_positive_finite(market.volume_limit):
            cap = min(cap, max(0.0, market.volume_limit - exposure))
        if cap + market.volume_step * 1e-9 < market.volume_min:
            raise ValueError("no volume remains")
        volume_epsilon = market.volume_step * 1e-9
        volume_capped = raw > cap + volume_epsilon
        volume_raised_to_minimum = raw + volume_epsilon < market.volume_min
        volume = market.volume_min if volume_raised_to_minimum else floor_volume(raw, market.volume_min, cap, market.volume_step)
        if volume <= 0.0:
            raise ValueError("invalid volume")
        actual_money = one_lot_risk * volume
        tolerance = max(1e-9, abs(requested_money) * 1e-12)
        if not volume_raised_to_minimum and actual_money > requested_money + tolerance:
            volume = floor_volume(volume - market.volume_step, market.volume_min, cap, market.volume_step)
            if volume <= 0.0:
                raise ValueError("minimum exceeds requested risk")
            actual_money = one_lot_risk * volume
            if actual_money > requested_money + tolerance:
                raise ValueError("rounding proof failed")
        return Result(
            valid=True,
            order_type=order_type,
            effective_entry=entry,
            account_basis=basis,
            requested_money=requested_money,
            requested_percent=requested_percent,
            one_lot_risk=one_lot_risk,
            raw_volume=raw,
            volume=volume,
            actual_money=actual_money,
            actual_percent=actual_money / basis * 100.0,
            volume_capped=volume_capped,
            volume_raised_to_minimum=volume_raised_to_minimum,
        )
    except ValueError as exc:
        return Result(valid=False, error=str(exc))


def parse_number(raw: str) -> tuple[bool, float, bool]:
    """Return parsed, value, incomplete using the MQL editor's exact grammar."""
    if raw == "":
        return False, 0.0, True
    if raw in {".", ",", "-", "+", "-.", "-,", "+.", "+,"}:
        return False, 0.0, True
    digit_seen = False
    separator_seen = False
    for i, ch in enumerate(raw):
        if "0" <= ch <= "9":
            digit_seen = True
            continue
        if ch in ".,":
            if separator_seen:
                return False, 0.0, False
            separator_seen = True
            continue
        if ch in "+-" and i == 0:
            continue
        return False, 0.0, False
    if not digit_seen:
        return False, 0.0, True
    try:
        value = float(raw.replace(",", "."))
    except ValueError:
        return False, 0.0, False
    return (math.isfinite(value), value if math.isfinite(value) else 0.0, False)


def switch_account_mode(model: Model, mode: AccountMode) -> Model:
    """Reference helper showing that the stored Manual amount is untouched."""
    return replace(model, account_mode=mode)
