from __future__ import annotations

import pytest

from exposure_reference import ExposureItem, ExposureKind, aggregate_exposure, money_symbol


def item(
    ticket: int,
    symbol: str,
    projected_result: float | None,
    *,
    stop_loss: float = 1.0,
    kind: ExposureKind = ExposureKind.POSITION,
) -> ExposureItem:
    return ExposureItem(
        kind=kind,
        ticket=ticket,
        symbol=symbol,
        side="buy",
        volume=0.1,
        entry=2.0,
        stop_loss=stop_loss,
        projected_result=projected_result,
    )


def test_chart_and_account_exposure_are_separate_and_loss_only():
    snapshot = aggregate_exposure(
        [
            item(1, "EURUSD", -100.0),
            item(2, "EURUSD", 25.0),
            item(3, "USTEC", -50.0),
        ],
        current_symbol="EURUSD",
        equity=10_000.0,
    )

    assert snapshot.chart_loss == pytest.approx(100.0)
    assert snapshot.account_loss == pytest.approx(150.0)
    assert snapshot.chart_percent == pytest.approx(1.0)
    assert snapshot.account_percent == pytest.approx(1.5)


def test_missing_sl_and_failed_projection_are_not_silently_zeroed():
    snapshot = aggregate_exposure(
        [
            item(1, "EURUSD", None, stop_loss=1.1),
            item(2, "EURUSD", None, stop_loss=0.0),
        ],
        current_symbol="EURUSD",
        equity=10_000.0,
    )

    assert snapshot.chart_unavailable == 1
    assert snapshot.chart_no_sl == 1
    assert snapshot.chart_protected == 0


def test_zero_equity_produces_unavailable_percent_not_infinity():
    snapshot = aggregate_exposure(
        [item(1, "EURUSD", -100.0)],
        current_symbol="EURUSD",
        equity=0.0,
    )

    assert snapshot.account_loss == pytest.approx(100.0)
    assert snapshot.account_percent is None


def test_pending_orders_share_the_same_downside_contract_and_currency_is_explicit():
    snapshot = aggregate_exposure(
        [item(7, "EURUSD", -20.0, kind=ExposureKind.PENDING)],
        current_symbol="EURUSD",
        equity=1_000.0,
    )

    assert snapshot.chart_loss == pytest.approx(20.0)
    assert money_symbol("USD") == "$"
    assert money_symbol("GBP") == "£"
    assert money_symbol("EUR") == "€"
    assert money_symbol("JPY") == "¥"
    assert money_symbol("CHF") == "CHF"


def test_rows_sort_by_largest_downside_then_position_before_pending_then_ticket():
    snapshot = aggregate_exposure(
        [
            item(9, "EURUSD", -20.0, kind=ExposureKind.PENDING),
            item(7, "EURUSD", -20.0, kind=ExposureKind.POSITION),
            item(3, "EURUSD", -50.0, kind=ExposureKind.PENDING),
            item(2, "EURUSD", 10.0, kind=ExposureKind.POSITION),
        ],
        current_symbol="EURUSD",
        equity=1_000.0,
    )

    assert [row.ticket for row in snapshot.ordered_items] == [3, 7, 9, 2]
