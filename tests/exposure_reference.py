from __future__ import annotations

from dataclasses import dataclass
from enum import Enum


class ExposureKind(str, Enum):
    POSITION = "position"
    PENDING = "pending"


@dataclass(frozen=True)
class ExposureItem:
    kind: ExposureKind
    ticket: int
    symbol: str
    side: str
    volume: float
    entry: float
    stop_loss: float
    projected_result: float | None


@dataclass(frozen=True)
class ExposureSnapshot:
    chart_loss: float
    account_loss: float
    chart_percent: float | None
    account_percent: float | None
    chart_protected: int
    account_protected: int
    chart_no_sl: int
    account_no_sl: int
    chart_unavailable: int
    account_unavailable: int
    ordered_items: tuple[ExposureItem, ...]


def _is_protected(item: ExposureItem) -> bool:
    return item.stop_loss > 0.0 and item.projected_result is not None


def _loss(item: ExposureItem) -> float:
    if not _is_protected(item):
        return 0.0
    return max(0.0, -item.projected_result)


def aggregate_exposure(
    items: list[ExposureItem], current_symbol: str, equity: float
) -> ExposureSnapshot:
    chart_items = [item for item in items if item.symbol == current_symbol]
    account_loss = sum(_loss(item) for item in items)
    chart_loss = sum(_loss(item) for item in chart_items)
    kind_priority = {ExposureKind.POSITION: 0, ExposureKind.PENDING: 1}
    ordered = tuple(
        sorted(
            items,
            key=lambda item: (-_loss(item), kind_priority[item.kind], item.ticket),
        )
    )

    def percentage(loss: float) -> float | None:
        return loss / equity * 100.0 if equity > 0.0 else None

    return ExposureSnapshot(
        chart_loss=chart_loss,
        account_loss=account_loss,
        chart_percent=percentage(chart_loss),
        account_percent=percentage(account_loss),
        chart_protected=sum(_is_protected(item) for item in chart_items),
        account_protected=sum(_is_protected(item) for item in items),
        chart_no_sl=sum(item.stop_loss <= 0.0 for item in chart_items),
        account_no_sl=sum(item.stop_loss <= 0.0 for item in items),
        chart_unavailable=sum(
            item.stop_loss > 0.0 and item.projected_result is None
            for item in chart_items
        ),
        account_unavailable=sum(
            item.stop_loss > 0.0 and item.projected_result is None for item in items
        ),
        ordered_items=ordered,
    )


def money_symbol(currency: str) -> str:
    return {
        "USD": "$",
        "GBP": "£",
        "EUR": "€",
        "JPY": "¥",
    }.get(currency, currency)
