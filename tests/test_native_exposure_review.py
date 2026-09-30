"""Regression checks for exposure repaint decisions and chart-label bounds.

Production MQL bodies run in the native harness. Chart APIs and text extents are
deterministic boundaries, not evidence of MT5 raster or live-account behavior.
"""
from __future__ import annotations

import pytest

from native_mql_harness import compile_and_run, extract_function, extract_functions
from test_native_ui import UI, sidecar_source


EXPOSURE = "MQL5/Experts/LotCraft/PS_Exposure.mqh"


@pytest.mark.parametrize(
    "profit,before_equity,after_equity,changed",
    [
        (100, 100, 200, "1"),
        (100, 100, 100.000001, "0"),
        (10.0049, 100, 99.998, "1"),
        (100, 0, 100, "1"),
        (100, 100, 0, "1"),
    ],
)
def test_profit_row_repaints_when_its_displayed_equity_percent_changes(
    tmp_path, profit, before_equity, after_equity, changed
):
    # Regresses loss-only change detection: locked profits contribute zero to
    # loss totals, but their displayed signed percentages still use equity.
    program = sidecar_source() + r'''
double MathPow(double a,double b){return std::pow(a,b);}
double NormalizeDouble(double n,int digits){double p=std::pow(10.0,digits);return std::round(n*p)/p;}
''' + extract_function(EXPOSURE, "PS_ExposureMeaningfullyChanged") + f'''
int main(){{
  PSExposureSnapshot before={{}},after={{}};
  before.enumeration_valid=after.enumeration_valid=true;
  before.equity_basis={before_equity};after.equity_basis={after_equity};
  before.items.resize(1);after.items.resize(1);
  before.items[0].status=after.items[0].status=PS_EXPOSURE_VALID;
  before.items[0].projected_result=after.items[0].projected_result={profit};
  before.fingerprint=after.fingerprint=17;
  std::cout<<PS_ExposureMeaningfullyChanged(before,after,2);
}}
'''
    assert compile_and_run(tmp_path, program).strip() == changed


def label_source() -> str:
    # Text extents are deliberately conservative and deterministic. They scale
    # with DPI and permit checking the production fit algorithm without fonts.
    source = sidecar_source().replace(
        "int TextWidth(const string &s){return (int)s.size()*8;}",
        "int TextWidth(const string &s){return (int)std::ceil(s.size()*8*g_ps_metrics.scale);}",
    )
    source += r'''
using datetime=long long;
const int _Period=0,PS_EXPOSURE_LABEL_MAX=128;
Canvas g_ps_exposure_label_canvas[PS_EXPOSURE_LABEL_MAX];
PSRect g_ps_exposure_label_rects[PS_EXPOSURE_LABEL_MAX];
int g_ps_exposure_label_item_indexes[PS_EXPOSURE_LABEL_MAX];
int g_ps_exposure_label_count=0;
PSRect g_ps_handle_rects[3]{};
bool g_ps_handle_visible[3]{};
const color PS_PREMIUM_GREEN=0,PS_CLR_SHORT=0;
datetime iTime(const string&,int,int){return 1;}
bool ChartTimePriceToXY(int,int,datetime,double,int &x,int &y){x=700;y=200;return true;}
void PS_UIExposureLabelsHideFrom(int){}
bool PS_UIExposureLabelsCanvasEnsure(const PSUIState&,int,const PSRect&){return true;}
'''
    source += extract_functions(
        UI, "PS_UIHorizontalLaneIntersects", "PS_UIExposureLaneBlocked", "PS_UIExposureLabelText", "PS_UIExposureLabelsRender"
    ).replace("canvas.", "canvas->").replace(
        "void PS_UIExposureLabelText(CCanvas &canvas", "void PS_UIExposureLabelText(CCanvas *canvas"
    ).replace("PS_UIFitText(canvas,", "PS_UIFitText(*canvas,")
    # MQL object pointers use '.', C++ uses '->'. This adapts syntax only.
    return source


@pytest.mark.parametrize("scale", [0.82, 1.0, 1.5, 2.0])
def test_position_labels_do_not_cover_separated_planning_handles(tmp_path, scale):
    program = label_source() + f'''
int main(){{
  g_ps_metrics.scale={scale};
  PSUIState ui;ui.chart_w=2000;ui.chart_h=1000;
  g_exposure_ui.chart_labels_visible=true;
  PSExposureSnapshot exposure={{}};exposure.enumeration_valid=true;exposure.equity_basis=1000;
  exposure.items.resize(1);auto &item=exposure.items[0];
  item.symbol="FIXTURE";item.kind=PS_EXPOSURE_POSITION;item.status=PS_EXPOSURE_VALID;
  item.volume=.1;item.volume_digits=1;item.stop_loss=100;item.projected_result=-10;
  for(int i=0;i<3;i++){{
    g_ps_handle_visible[i]=true;
    g_ps_handle_rects[i]={{ui.chart_w-PS_U(54)-i*(PS_U(36)+PS_U(6)),200-PS_U(13),PS_U(36),PS_U(26)}};
  }}
  PSMarketSnapshot market;PS_UIExposureLabelsRender(ui,exposure,market);
  bool clear=g_ps_exposure_label_count==1;
  auto label=g_ps_exposure_label_rects[0];
  for(auto handle:g_ps_handle_rects)
    clear=clear && !(label.x<handle.x+handle.w && label.x+label.w>handle.x &&
                     label.y<handle.y+handle.h && label.y+label.h>handle.y);
  ui.panel_w=ui.chart_w;
  PS_UIExposureLabelsRender(ui,exposure,market);
  clear=clear && g_ps_exposure_label_count==0; // Never paint over a full-width panel.
  std::cout<<clear;
}}
'''
    assert compile_and_run(tmp_path, program).strip() == "1"


@pytest.mark.parametrize("scale", [0.82, 1.0, 1.5, 2.0])
@pytest.mark.parametrize(
    "volume,digits,result",
    [(0.00000001, 8, -10000), (12345.678, 3, 987654321.12), (0.01, 2, -10)],
)
def test_position_label_keeps_side_volume_and_loss_in_separate_bounds(
    tmp_path, scale, volume, digits, result
):
    # Regresses fixed-position volume and cash text that draw over one another
    # once precision or money length exceeds the original short examples.
    program = label_source() + f'''
int main(){{
  g_ps_metrics.scale={scale};
  PSUIState ui;ui.chart_w=2000;ui.chart_h=1000;
  g_exposure_ui.chart_labels_visible=true;g_exposure_ui.details_open=false;
  PSExposureSnapshot exposure={{}};exposure.enumeration_valid=true;exposure.equity_basis=1000;
  exposure.items.resize(1);auto &item=exposure.items[0];
  item.symbol="FIXTURE";item.kind=PS_EXPOSURE_POSITION;item.status=PS_EXPOSURE_VALID;
  item.direction=PS_DIRECTION_LONG;item.volume={volume};item.volume_digits={digits};
  item.stop_loss=100;item.projected_result={result};
  PSMarketSnapshot market;
  PS_UIExposureLabelsRender(ui,exposure,market);
  bool bounded=draws.size()==3 && g_ps_exposure_label_count==1;
  int width=g_ps_exposure_label_rects[0].w;
  for(auto d:draws) bounded=bounded && d.left>=0 && d.right<=width;
  bounded=bounded && draws[1].text!="" && draws[2].text!="";
  bounded=bounded && draws[0].right+PS_U(4)<=draws[1].left;
  bounded=bounded && draws[1].right+PS_U(6)<=draws[2].left;
  if(item.volume==0.01) bounded=bounded && draws[1].text=="0.01" && draws[2].text=="-10.00";
  std::cout<<bounded;
}}
'''
    assert compile_and_run(tmp_path, program).strip() == "1"
