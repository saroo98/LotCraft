from __future__ import annotations

from dataclasses import replace
import math
import random

import pytest

from reference_model import (
    AccountMode,
    CommissionMode,
    Direction,
    Market,
    Model,
    OrderMode,
    OrderType,
    RiskAuthority,
    calculate,
    floor_volume,
    switch_account_mode,
)


@pytest.mark.parametrize(
    ("direction", "expected"),
    [(Direction.LONG, OrderType.BUY), (Direction.SHORT, OrderType.SELL)],
)
def test_instant_long_and_short(direction, expected):
    market = Market(one_lot_price_loss=250.0)
    stop = market.bid - 0.002 if direction is Direction.LONG else market.ask + 0.002
    result = calculate(Model(direction=direction, stop_loss=stop), market)
    assert result.valid, result.error
    assert result.order_type is expected
    assert result.effective_entry == pytest.approx(market.ask if direction is Direction.LONG else market.bid)


@pytest.mark.parametrize(
    ("direction", "entry", "stop", "take", "expected"),
    [
        (Direction.LONG, 1.0980, 1.0960, 1.1020, OrderType.BUY_LIMIT),
        (Direction.LONG, 1.1020, 1.1000, 1.1040, OrderType.BUY_STOP),
        (Direction.SHORT, 1.1020, 1.1040, 1.1000, OrderType.SELL_LIMIT),
        (Direction.SHORT, 1.0980, 1.1000, 1.0960, OrderType.SELL_STOP),
    ],
)
def test_every_pending_subtype(direction, entry, stop, take, expected):
    result = calculate(
        Model(direction=direction, order_mode=OrderMode.PENDING, entry=entry, stop_loss=stop, take_profit=take),
        Market(one_lot_price_loss=200.0),
    )
    assert result.valid, result.error
    assert result.order_type is expected


def test_risk_entered_as_percentage():
    result = calculate(Model(requested_risk_percent=2.0), Market(equity=12_500, one_lot_price_loss=250))
    assert result.valid
    assert result.requested_money == pytest.approx(250)
    assert result.requested_percent == pytest.approx(2)


def test_risk_entered_as_money():
    model = Model(risk_authority=RiskAuthority.MONEY, requested_risk_money=375)
    result = calculate(model, Market(equity=15_000, one_lot_price_loss=250))
    assert result.valid
    assert result.requested_money == pytest.approx(375)
    assert result.requested_percent == pytest.approx(2.5)


@pytest.mark.parametrize(
    ("mode", "expected"),
    [(AccountMode.EQUITY, 11_111), (AccountMode.BALANCE, 10_321), (AccountMode.MANUAL, 25_000)],
)
def test_account_money_modes(mode, expected):
    model = Model(account_mode=mode, manual_account_money=25_000)
    result = calculate(model, Market(equity=11_111, balance=10_321))
    assert result.valid
    assert result.account_basis == pytest.approx(expected)


def test_live_equity_change_with_percent_authority_changes_money_and_size():
    model = Model(risk_authority=RiskAuthority.PERCENT, requested_risk_percent=1.0)
    before = calculate(model, Market(equity=10_000, one_lot_price_loss=100))
    after = calculate(model, Market(equity=12_000, one_lot_price_loss=100))
    assert before.requested_percent == after.requested_percent == 1.0
    assert after.requested_money > before.requested_money
    assert after.volume > before.volume


def test_live_equity_change_with_money_authority_preserves_money_and_changes_percent():
    model = Model(risk_authority=RiskAuthority.MONEY, requested_risk_money=100)
    before = calculate(model, Market(equity=10_000, one_lot_price_loss=100))
    after = calculate(model, Market(equity=20_000, one_lot_price_loss=100))
    assert before.requested_money == after.requested_money == 100
    assert after.requested_percent == pytest.approx(before.requested_percent / 2)
    assert after.volume == before.volume


def test_live_balance_change_authority_semantics():
    percent = Model(account_mode=AccountMode.BALANCE, risk_authority=RiskAuthority.PERCENT, requested_risk_percent=2)
    money = replace(percent, risk_authority=RiskAuthority.MONEY, requested_risk_money=150)
    p1 = calculate(percent, Market(balance=10_000))
    p2 = calculate(percent, Market(balance=11_000))
    m1 = calculate(money, Market(balance=10_000))
    m2 = calculate(money, Market(balance=11_000))
    assert p2.requested_money > p1.requested_money
    assert m2.requested_money == m1.requested_money
    assert m2.requested_percent < m1.requested_percent


def test_manual_amount_persists_across_mode_switches():
    model = Model(account_mode=AccountMode.MANUAL, manual_account_money=43_210)
    model = switch_account_mode(model, AccountMode.EQUITY)
    model = switch_account_mode(model, AccountMode.BALANCE)
    model = switch_account_mode(model, AccountMode.MANUAL)
    assert model.manual_account_money == 43_210
    assert calculate(model, Market()).account_basis == 43_210


@pytest.mark.parametrize(
    ("mode", "commission", "expected_one_lot"),
    [
        (CommissionMode.ROUND_TRIP, 0, 100),
        (CommissionMode.ROUND_TRIP, 7, 107),
        (CommissionMode.ONE_SIDE, 7, 114),
    ],
)
def test_commission_zero_and_nonzero(mode, commission, expected_one_lot):
    result = calculate(
        Model(commission_mode=mode, commission_per_lot=commission),
        Market(one_lot_price_loss=100),
    )
    assert result.valid
    assert result.one_lot_risk == pytest.approx(expected_one_lot)


@pytest.mark.parametrize(
    "market",
    [
        Market(symbol="EURUSD", digits=5, point=0.00001, tick_size=0.00001, volume_step=0.01, one_lot_price_loss=100),
        Market(symbol="XAUUSD", bid=2399.9, ask=2400.1, digits=2, point=0.01, tick_size=0.1, volume_step=0.01, one_lot_price_loss=1000),
        Market(symbol="US500", bid=5500.0, ask=5500.5, digits=1, point=0.1, tick_size=0.5, volume_step=0.1, one_lot_price_loss=50),
        Market(symbol="WTI", bid=78.10, ask=78.12, digits=2, point=0.01, tick_size=0.01, volume_step=0.01, one_lot_price_loss=500),
        Market(symbol="FUT-EX", bid=18500, ask=18501, digits=0, point=1, tick_size=1, volume_min=1, volume_step=1, volume_max=50, one_lot_price_loss=250),
    ],
    ids=["forex", "metal", "index", "energy", "exchange"],
)
def test_diverse_symbol_classes(market):
    distance = max(market.protective_distance + market.tick_size, market.tick_size * 100)
    stop = market.bid - distance
    requested = 500.0 if market.volume_min >= 1.0 else 100.0
    model = Model(
        entry=market.ask,
        stop_loss=stop,
        risk_authority=RiskAuthority.MONEY,
        requested_risk_money=requested,
    )
    result = calculate(model, market)
    assert result.valid, result.error
    assert result.volume >= market.volume_min
    assert result.actual_money <= result.requested_money + 1e-8


def test_account_currency_different_from_profit_currency_is_already_account_converted():
    market = Market(account_currency="GBP", one_lot_price_loss=83.25)
    result = calculate(Model(requested_risk_percent=1), market)
    assert result.valid
    assert result.one_lot_risk == pytest.approx(83.25)
    assert result.actual_money <= 100


def test_minimum_volume_exactly_allowed():
    result = calculate(Model(risk_authority=RiskAuthority.MONEY, requested_risk_money=1), Market(one_lot_price_loss=100))
    assert result.valid
    assert result.volume == 0.01


def test_requested_volume_below_minimum_is_raised_and_actual_risk_is_reported():
    result = calculate(Model(risk_authority=RiskAuthority.MONEY, requested_risk_money=0.99), Market(one_lot_price_loss=100))
    assert result.valid
    assert result.volume == 0.01
    assert result.volume_raised_to_minimum
    assert result.actual_money == 1.0
    assert result.actual_money > result.requested_money


def test_requested_volume_above_maximum_is_capped_downward():
    market = Market(volume_max=2.0, one_lot_price_loss=10)
    result = calculate(Model(risk_authority=RiskAuthority.MONEY, requested_risk_money=1000), market)
    assert result.valid
    assert result.volume == 2.0
    assert result.volume_capped
    assert result.actual_money < result.requested_money


def test_aggregate_volume_limit_caps_same_direction():
    market = Market(volume_limit=5, exposure_long=4.37, volume_step=0.01, one_lot_price_loss=10)
    result = calculate(Model(risk_authority=RiskAuthority.MONEY, requested_risk_money=1000), market)
    assert result.valid
    assert result.volume == pytest.approx(0.63)
    assert result.volume_capped


def test_aggregate_volume_limit_rejects_when_below_minimum_remaining():
    market = Market(volume_limit=5, exposure_long=4.995, volume_min=0.01, volume_step=0.01)
    result = calculate(Model(), market)
    assert not result.valid
    assert "no volume remains" in result.error


@pytest.mark.parametrize(
    ("stop", "take", "needle"),
    [
        (1.1002, 0, "long stop crossed"),
        (1.10019, 0, "long stop inside bid distance"),
        (0, 0, "stop invalid"),
        (1.10015, 0, "long stop inside bid distance"),
        (1.0992, 1.1001, "long take crossed"),
    ],
)
def test_invalid_zero_one_tick_and_crossed_stops(stop, take, needle):
    result = calculate(Model(stop_loss=stop, take_profit=take), Market())
    assert not result.valid
    assert needle in result.error


def test_very_large_stop_distance_calculates_small_safe_volume():
    market = Market(one_lot_price_loss=10_000, volume_min=0.01, volume_step=0.01)
    result = calculate(Model(risk_authority=RiskAuthority.MONEY, requested_risk_money=100), market)
    assert result.valid
    assert result.volume == 0.01
    assert result.actual_money == 100


def test_pending_ambiguous_at_market_is_rejected():
    result = calculate(Model(order_mode=OrderMode.PENDING, entry=1.1002, stop_loss=1.099), Market())
    assert not result.valid
    assert "ambiguous" in result.error


def test_pending_inside_stops_level_is_rejected():
    market = Market(stops_level_points=100)
    result = calculate(Model(order_mode=OrderMode.PENDING, entry=1.1005, stop_loss=1.099), market)
    assert not result.valid
    assert "inside broker distance" in result.error


@pytest.mark.parametrize(
    "market",
    [
        Market(valid=False),
        Market(tick_size=0),
        Market(point=0),
        Market(volume_min=0),
        Market(volume_max=0.001, volume_min=0.01),
        Market(volume_step=0),
        Market(one_lot_price_loss=0),
    ],
)
def test_missing_or_invalid_symbol_data(market):
    assert not calculate(Model(), market).valid


def test_downward_rounding_proves_actual_risk_not_above_requested_randomized():
    rng = random.Random(100)
    for _ in range(10_000):
        step = rng.choice([0.001, 0.01, 0.05, 0.1, 1.0])
        minimum = rng.choice([step, 2 * step, 5 * step])
        maximum = minimum + rng.randint(1, 500) * step
        requested = rng.uniform(0.0001, maximum * 1.5)
        volume = floor_volume(requested, minimum, maximum, step)
        if volume == 0:
            assert requested + step * 1e-9 < minimum
        else:
            assert volume <= min(requested, maximum) + step * 1e-8
            assert volume >= minimum - step * 1e-8


def test_actual_risk_only_exceeds_requested_for_explicit_broker_minimum_override():
    for loss in [0.01, 0.1, 1, 7.13, 100, 1234.56]:
        for requested_money in [1, 10, 99.99, 100, 1000, 9999]:
            for step in [0.001, 0.01, 0.1, 1.0]:
                market = Market(volume_min=step, volume_step=step, volume_max=10_000, one_lot_price_loss=loss)
                result = calculate(Model(risk_authority=RiskAuthority.MONEY, requested_risk_money=requested_money), market)
                if result.valid:
                    tolerance = max(1e-9, requested_money * 1e-12)
                    if result.volume_raised_to_minimum:
                        assert result.volume == market.volume_min
                        assert result.actual_money > result.requested_money + tolerance
                    else:
                        assert result.actual_money <= result.requested_money + tolerance


def test_manual_account_value_must_be_positive_and_finite():
    for value in [0, -1, math.inf, math.nan]:
        result = calculate(Model(account_mode=AccountMode.MANUAL, manual_account_money=value), Market())
        assert not result.valid
