"""Execute production UI geometry and field rendering with a headless canvas.

These tests do not render MT5 or claim font/raster fidelity. The canvas provides
deterministic text extents and records drawing bounds. Layout, viewport, paging,
and cursor decisions come from the actual MQL function bodies.
"""
from __future__ import annotations

import re
from pathlib import Path

from native_mql_harness import compile_and_run, extract_function, extract_functions


ROOT = Path(__file__).resolve().parents[1]
UI = "MQL5/Experts/LotCraft/PS_UI.mqh"
METRICS = "MQL5/Experts/LotCraft/PS_UI_Metrics.mqh"
TYPES = "MQL5/Experts/LotCraft/PS_Types.mqh"


def declaration(path: str, name: str) -> str:
    text = (ROOT / path).read_text(encoding="utf-8")
    match = re.search(rf"(?:enum|struct)\s+{name}\s*\{{.*?\}};", text, re.S)
    assert match, f"Missing production declaration: {name}"
    return match.group(0)


def geometry_source() -> str:
    return r'''
#include <algorithm>
#include <cmath>
#include <iostream>
#include <iomanip>
#include <sstream>
#include <string>
#include <vector>
using string=std::string;
using color=int;
using uint=unsigned int;
using ulong=unsigned long long;
template<class A,class B> auto MathMin(A a,B b){return std::min<double>(a,b);}
template<class A,class B> auto MathMax(A a,B b){return std::max<double>(a,b);}
double MathRound(double x){return std::round(x);}
int PS_ClampInt(int x,int lo,int hi){return std::min(std::max(x,lo),hi);}
int fixture_dpi=96,fixture_chart_w=1000,fixture_chart_h=600;
const int TERMINAL_SCREEN_DPI=0,CHART_WIDTH_IN_PIXELS=0,CHART_HEIGHT_IN_PIXELS=1;
int TerminalInfoInteger(int){return fixture_dpi;}
int ChartID(){return 1;}
int ChartGetInteger(int,int prop,int){return prop==0?fixture_chart_w:fixture_chart_h;}
''' + "\n".join(
        declaration(TYPES, name)
        for name in ("PSViewMode", "PSFieldId", "PSControlId", "PSRect", "PSExposureScope", "PSExposureUIState")
    ) + "\n" + declaration(METRICS, "PSUIMetrics") + r'''
PSUIMetrics g_ps_metrics;
struct PSUIState {int chart_w=0,chart_h=0,panel_x=0,panel_y=0,panel_w=0,panel_h=0;bool dirty=false;};
PSExposureUIState g_exposure_ui;
PSRect g_ps_control_rects[PS_CTRL_COUNT];
bool g_ps_control_visible[PS_CTRL_COUNT];
int g_ps_field_view_start[PS_CTRL_COUNT],g_ps_field_view_end[PS_CTRL_COUNT];
bool g_ps_field_view_active[PS_CTRL_COUNT];
''' + extract_functions(METRICS, "PS_U", "PS_Font", "PS_UIMetricsRefresh") + "\n" + extract_functions(
        UI, "PS_UIResetRect", "PS_UISetRect", "PS_UIReadChartSize", "PS_UIClampPanel",
        "PS_UILayout", "PS_PremiumControlRect", "PS_UIExposurePlace",
    )


def test_compact_price_actions_keep_section_inner_padding(tmp_path):
    # Regresses the old final Copy/Lines edge at x364, exactly on the section
    # border. The other content has an 8px inset from this border.
    program = geometry_source() + r'''
int main(){
  PSUIState ui;
  for(int dpi: {96,120,144,192}) {
    fixture_dpi=dpi; fixture_chart_w=1600; fixture_chart_h=1200;
    PS_UILayout(ui,PS_VIEW_COMPACT);
    int border=ui.panel_x+PS_U(8)+PS_U(356);
    int min_padding=PS_U(8);
    for(auto id:{PS_CTRL_ENTRY_COPY,PS_CTRL_STOP_COPY,PS_CTRL_TAKE_COPY,PS_CTRL_LINES}) {
      auto r=g_ps_control_rects[id];
      std::cout<<(border-(r.x+r.w)>=min_padding)<<"\n";
    }
  }
}
'''
    assert set(compile_and_run(tmp_path, program).split()) == {"1"}


def test_sidecar_stays_inside_chart_when_mini_panel_is_near_bottom(tmp_path):
    program = geometry_source() + r'''
int main(){
  PSUIState ui; ui.panel_x=0; ui.panel_y=500;
  PS_UILayout(ui,PS_VIEW_MINI);
  PS_UIExposurePlace(ui);
  auto r=g_exposure_ui.sidecar_rect;
  std::cout<<(r.x>=0 && r.y>=0 && r.x+r.w<=1000 && r.y+r.h<=600);
}
'''
    assert compile_and_run(tmp_path, program).strip() == "1"


def field_source() -> str:
    return geometry_source() + r'''
const int TA_LEFT=0,TA_TOP=0,TA_CENTER=1,TA_RIGHT=2,TA_VCENTER=4,clrNONE=-1;
struct PSEditorState {bool active=false,has_selection=false; PSFieldId field=PS_FIELD_NONE;
  int cursor=0,anchor=0; string raw_text;};
struct Draw {int left,right; string text; int top=0,bottom=0;};
std::vector<Draw> draws;
int StringLen(const string &s){return (int)s.size();}
string StringSubstr(const string &s,int p,int n=-1){return s.substr(p,n<0?s.size():n);}
struct Canvas {
  int font_size=110;
  void FontSet(const string&,int size){font_size=std::abs(size);}
  int TextWidth(const string &s){return (int)s.size()*8;}
  int TextHeight(const string &){return 14;}
  void TextOut(int x,int y,const string&s,uint,uint align=0){
    int w=TextWidth(s); if(align&TA_RIGHT)x-=w;else if(align&TA_CENTER)x-=w/2;
    int h=TextHeight(s); if(align&TA_VCENTER)y-=h/2;
    draws.push_back({x,x+w,s,y,y+h});
  }
  void FillRectangle(int x,int,int right,int,uint){draws.push_back({x,right+1,""});}
  void Erase(uint){} void Rectangle(int,int,int,int,uint){}
  void Line(int,int,int,int,uint){} void Update(bool){}
} g_ps_panel_canvas;
using CCanvas=Canvas;
int PS_ThemeReadOnly(){return 0;} int PS_ThemeField(){return 0;}
int PS_ThemeAction(){return 0;} int PS_ThemeBorder(){return 0;}
int PS_ThemeSelection(){return 0;} int PS_ThemeReadOnlyText(){return 0;}
int PS_ThemeText(){return 0;}
uint PS_PremiumColor(color x){return x;}
int recorded_fill=0;
void PS_PremiumRoundRect(int,int,int,int,int,color fill,color){recorded_fill=fill;}
''' + extract_functions("MQL5/Experts/LotCraft/PS_Editor.mqh", "PS_EditorSelectionStart", "PS_EditorSelectionEnd") + "\n" + extract_functions(
        UI, "PS_PremiumOpticalCenterOffset", "PS_PremiumText", "PS_UIFieldPadding", "PS_UIFieldViewport", "PS_UIFitText", "PS_UITextHeight", "PS_UIEditorCursorIndex", "PS_PremiumCompactField",
    )


def test_numeric_text_selection_and_caret_never_draw_outside_the_field(tmp_path):
    program = field_source() + r'''
int main(){
  PSUIState ui; PS_UILayout(ui,PS_VIEW_MINI);
  PSEditorState editor; editor.active=true; editor.field=PS_FIELD_RISK_PERCENT;
  editor.raw_text=string(32,'9'); editor.cursor=32;
  for(bool selection:{false,true}) {
    editor.has_selection=selection; editor.anchor=0; draws.clear();
    PS_PremiumCompactField(ui,PS_CTRL_RISK_PERCENT_FIELD,editor.raw_text,editor,
      PS_FIELD_RISK_PERCENT,false,true,11,10);
    auto rect=g_ps_control_rects[PS_CTRL_RISK_PERCENT_FIELD];
    bool bounded=true;
    for(auto d:draws) bounded=bounded && d.left>=rect.x+10 && d.right<=rect.x+rect.w-10;
    std::cout<<bounded<<"\n";
  }
}
'''
    assert compile_and_run(tmp_path, program).split() == ["1", "1"]


def test_money_field_cursor_uses_its_actual_padding(tmp_path):
    program = field_source() + r'''
int main(){
  PSUIState ui; PS_UILayout(ui,PS_VIEW_FULL);
  auto rect=g_ps_control_rects[PS_CTRL_RISK_MONEY_FIELD];
  // The money field's left padding is10px. The first glyph midpoint is14px.
  // At15px the caret belongs after the first glyph, not before it.
  std::cout<<PS_UIEditorCursorIndex(ui,PS_CTRL_RISK_MONEY_FIELD,"123",rect.x+15);
}
'''
    assert compile_and_run(tmp_path, program).strip() == "1"


def test_pointer_selection_can_scroll_past_either_numeric_viewport_edge(tmp_path):
    program = field_source() + r'''
int main(){
  PSUIState ui; PS_UILayout(ui,PS_VIEW_MINI);
  PSEditorState editor;editor.active=true;editor.field=PS_FIELD_RISK_PERCENT;editor.raw_text=string(32,'9');
  auto rect=g_ps_control_rects[PS_CTRL_RISK_PERCENT_FIELD];
  editor.cursor=32;
  PS_PremiumCompactField(ui,PS_CTRL_RISK_PERCENT_FIELD,editor.raw_text,editor,PS_FIELD_RISK_PERCENT,false,true,11,10);
  int start=g_ps_field_view_start[PS_CTRL_RISK_PERCENT_FIELD];
  std::cout<<(PS_UIEditorCursorIndex(ui,PS_CTRL_RISK_PERCENT_FIELD,editor.raw_text,rect.x)==start-1)<<"\n";
  editor.cursor=0;
  PS_PremiumCompactField(ui,PS_CTRL_RISK_PERCENT_FIELD,editor.raw_text,editor,PS_FIELD_RISK_PERCENT,false,true,11,10);
  int finish=g_ps_field_view_end[PS_CTRL_RISK_PERCENT_FIELD];
  std::cout<<(PS_UIEditorCursorIndex(ui,PS_CTRL_RISK_PERCENT_FIELD,editor.raw_text,rect.x+rect.w)==finish+1)<<"\n";
}
'''
    assert compile_and_run(tmp_path, program).split() == ["1", "1"]


def sidecar_source() -> str:
    return field_source() + "\n" + "\n".join(
        declaration(TYPES, name)
        for name in ("PSDirection", "PSExposureKind", "PSExposureStatus", "PSExposureItem")
    ) + "\n" + declaration(TYPES, "PSExposureSnapshot").replace(
        "PSExposureItem items[];", "std::vector<PSExposureItem> items;"
    ) + r'''
const int PS_EXPOSURE_VISIBLE_ROWS=8,OBJPROP_TIMEFRAMES=0,OBJ_NO_PERIODS=0;
bool g_ps_exposure_canvas_created=false;
ulong fixture_sidecar_clock=2000,g_ps_exposure_retry_after_ms=0;
ulong GetTickCount64(){return fixture_sidecar_clock;}
string g_ps_exposure_canvas_name,_Symbol="FIXTURE";
Canvas g_ps_exposure_canvas;
struct PSMarketSnapshot {};
int ArraySize(const std::vector<PSExposureItem>&a){return (int)a.size();}
int ObjectSetInteger(int,const string&,int,int){return 1;}
bool PS_UIExposureCanvasEnsure(const PSUIState&,const PSRect&){return true;}
std::vector<string> exposure_texts;
void PS_UIExposureText(int,int,const string &value,int,color,uint=TA_LEFT|TA_VCENTER,const string & ="Segoe UI"){exposure_texts.push_back(value);}
int PS_ThemePanel(){return 0;} int PS_ThemeControl(){return 0;}
int PS_ThemeMuted(){return 0;} int PS_ThemeOnAccent(){return 0;}
int PS_ThemeLoss(){return 0;} int PS_ThemeIncomplete(){return 0;}
int PS_ThemeProfit(){return 0;} int PS_ThemeHover(){return 0;}
int PS_ThemeDivider(){return 0;}
string IntegerToString(int n){return std::to_string(n);}
string DoubleToString(double n,int digits){std::ostringstream s;s<<std::fixed<<std::setprecision(digits)<<n;return s.str();}
string StringFormat(const string&,int n){return std::to_string(n);}
double MathAbs(double n){return std::abs(n);}
bool PS_IsPositiveFinite(double n){return std::isfinite(n)&&n>0;}
string PS_FormatMoneyDisplay(double n,const PSMarketSnapshot&){return DoubleToString(n,2);}
''' + extract_function("MQL5/Experts/LotCraft/PS_Exposure.mqh", "PS_ExposureCopyItem") + "\n" + sidecar_recovery_helpers() + extract_functions(
        UI, "PS_UIExposurePageCapacity", "PS_UIExposureFilteredCount", "PS_UIExposureFilteredIndex", "PS_UIExposureProjectedMoney", "PS_UIExposureSidecarRender",
    # C++ needs an explicit string operand for this MQL string concatenation.
    # No branch, loop, geometry or arithmetic in the production body changes.
    ).replace('"Chart labels: "+', 'string("Chart labels: ")+')


def sidecar_recovery_helpers() -> str:
    try:
        return extract_function(UI, "PS_UIExposureHide") + "\n"
    except ValueError:
        return ""  # Keep the reproducer runnable before the recovery helper exists.


def test_sidecar_canvas_failure_invalidates_hits_and_bounds_retries(tmp_path):
    program = sidecar_source().replace(
        'bool PS_UIExposureCanvasEnsure(const PSUIState&,const PSRect&){return true;}',
        'bool fixture_canvas_ok=true;int canvas_attempts=0;'
        'bool PS_UIExposureCanvasEnsure(const PSUIState&,const PSRect&){++canvas_attempts;return fixture_canvas_ok;}',
    ).replace(
        'int ObjectSetInteger(int,const string&,int,int){return 1;}',
        'int hide_calls=0;int ObjectSetInteger(int,const string&,int,int){++hide_calls;return 1;}',
    )
    program += declaration(TYPES, "PSExposureHit")
    program += extract_function(TYPES, "PS_RectContains")
    program += extract_function(UI, "PS_UIExposureHitTest")
    program += r'''
int main(){
 PSUIState ui;PS_UILayout(ui,PS_VIEW_FULL);
 PSExposureSnapshot exposure{};PSMarketSnapshot market;
 g_exposure_ui.details_open=true;g_ps_exposure_canvas_created=true;
 PS_UIExposureSidecarRender(ui,exposure,market);
 auto old=g_exposure_ui.close_rect;int row=-1;
 std::cout<<PS_UIExposureHitTest(old.x+1,old.y+1,row)<<'\n';
 fixture_canvas_ok=false;PS_UIExposureSidecarRender(ui,exposure,market);
 std::cout<<PS_UIExposureHitTest(old.x+1,old.y+1,row)<<' '<<g_exposure_ui.sidecar_rect.w<<' '<<hide_calls<<'\n';
 for(int i=1;i<1000;i+=8){fixture_sidecar_clock=2000+i;PS_UIExposureSidecarRender(ui,exposure,market);}
 std::cout<<canvas_attempts<<'\n';
 fixture_sidecar_clock=3000;fixture_canvas_ok=true;PS_UIExposureSidecarRender(ui,exposure,market);
 auto recovered=g_exposure_ui.close_rect;
 std::cout<<canvas_attempts<<' '<<PS_UIExposureHitTest(recovered.x+1,recovered.y+1,row)<<'\n';
}
'''
    assert compile_and_run(tmp_path, program).splitlines() == ["1", "0 0 1", "2", "3 1"]


def test_sidecar_can_scroll_to_the_last_row_when_chart_height_limits_page_size(tmp_path):
    program = sidecar_source() + r'''
int main(){
  fixture_chart_h=250;
  PSUIState ui; PS_UILayout(ui,PS_VIEW_COMPACT);
  g_exposure_ui.details_open=true; g_exposure_ui.scope=PS_EXPOSURE_SCOPE_ACCOUNT;
  g_exposure_ui.scroll_offset=999;
  PSExposureSnapshot exposure={}; exposure.equity_basis=1000; exposure.enumeration_valid=true;
  exposure.items.resize(10);
  for(auto &item:exposure.items){item.symbol="FIXTURE";item.kind=PS_EXPOSURE_POSITION;item.status=PS_EXPOSURE_VALID;}
  PSMarketSnapshot market;
  PS_UIExposureSidecarRender(ui,exposure,market);
  int visible=0;
  for(auto row:g_exposure_ui.row_rects) if(row.h>0)visible++;
  std::cout<<(visible>0 && g_exposure_ui.scroll_offset+visible==10);
}
'''
    assert compile_and_run(tmp_path, program).strip() == "1"


def test_incomplete_current_chart_exposure_is_visibly_marked(tmp_path):
    program = sidecar_source() + "\n" + extract_functions(
        UI, "PS_UIExposureWarning", "PS_UIExposureTile", "PS_UIExposureSummary",
    ) + r'''
int main(){
  PSUIState ui; PS_UILayout(ui,PS_VIEW_FULL);
  PSExposureSnapshot exposure={}; exposure.equity_basis=1000; exposure.enumeration_valid=true;
  exposure.chart_no_sl=1; exposure.account_no_sl=1;
  PSMarketSnapshot market;
  PS_UIExposureSummary(ui,exposure,market,false);
  auto rect=g_ps_control_rects[PS_CTRL_EXPOSURE_SUMMARY];
  bool chart_warning=false;
  for(auto d:draws) if(d.text=="!" && d.left<rect.x+rect.w/2)chart_warning=true;
  std::cout<<chart_warning;
}
'''
    assert compile_and_run(tmp_path, program).strip() == "1"


def test_position_detail_preserves_five_digit_price_and_millilot_volume(tmp_path):
    program = sidecar_source() + r'''
int main(){
  PSUIState ui; PS_UILayout(ui,PS_VIEW_FULL);
  g_exposure_ui.details_open=true; g_exposure_ui.scope=PS_EXPOSURE_SCOPE_ACCOUNT;
  PSExposureSnapshot exposure={}; exposure.equity_basis=1000; exposure.enumeration_valid=true;
  exposure.items.resize(1); auto &item=exposure.items[0];
  item.symbol="FIXTURE";item.volume=0.001;item.stop_loss=1.12345;
  item.price_digits=5;item.volume_digits=3;
  PSMarketSnapshot market;
  PS_UIExposureSidecarRender(ui,exposure,market);
  bool price=false,volume=false;
  for(auto text:exposure_texts){if(text.find("1.12345")!=string::npos)price=true;if(text.find("0.001")!=string::npos)volume=true;}
  std::cout<<price<<" "<<volume;
}
'''
    assert compile_and_run(tmp_path, program).split() == ["1", "1"]


def test_exposure_text_has_real_top_and_bottom_insets(tmp_path):
    program = sidecar_source() + "\n" + extract_functions(
        UI, "PS_UIExposureWarning", "PS_UIExposureTile", "PS_UIExposureSummary",
    ) + r'''
int main(){
  PSExposureSnapshot exposure={}; exposure.equity_basis=1000; exposure.enumeration_valid=true;
  PSMarketSnapshot market;
  for(auto mode:{PS_VIEW_COMPACT,PS_VIEW_FULL}) {
    PSUIState ui; PS_UILayout(ui,mode); draws.clear();
    PS_UIExposureSummary(ui,exposure,market,mode==PS_VIEW_COMPACT);
    auto rect=g_ps_control_rects[PS_CTRL_EXPOSURE_SUMMARY];
    bool bounded=true;
    for(auto d:draws) if(d.text!="" && d.text!="!") bounded=bounded && d.top>=rect.y+PS_U(6) && d.bottom<=rect.y+rect.h-PS_U(6);
    std::cout<<bounded<<"\n";
  }
}
'''
    assert compile_and_run(tmp_path, program).split() == ["1", "1"]


def marker_source() -> str:
    functions = extract_functions(UI, "PS_UIHandleCanvasDestroy", "PS_UIEnsureHandleCanvas", "PS_UISetHandle")
    # MQL's color literal is an int here. Color choice does not affect geometry.
    functions = functions.replace("C'10,12,16'", "0")
    return geometry_source() + "\n" + declaration(TYPES, "PSLevelId") + r'''
const int COLOR_FORMAT_XRGB_NOALPHA=0,CORNER_LEFT_UPPER=0,TA_CENTER=1,TA_VCENTER=4;
const int OBJPROP_CORNER=0,OBJPROP_SELECTABLE=1,OBJPROP_SELECTED=2,OBJPROP_HIDDEN=3;
const int OBJPROP_BACK=4,OBJPROP_TOOLTIP=5,OBJPROP_ZORDER=6,OBJPROP_XDISTANCE=7,OBJPROP_YDISTANCE=8;
const int OBJPROP_TIMEFRAMES=9,OBJ_ALL_PERIODS=1,OBJ_NO_PERIODS=0,clrNONE=-1,PS_CLR_TEXT=0;
bool fixture_canvas_ok=true;
struct Canvas {
  int w=0,h=0,font=0;
  bool CreateBitmapLabel(int,int,const string&,int,int,int width,int height,int){if(!fixture_canvas_ok)return false;w=width;h=height;return true;}
  bool Resize(int width,int height){if(!fixture_canvas_ok)return false;w=width;h=height;return true;}
  int Width(){return w;} int Height(){return h;}
  void Destroy(){w=h=0;} void Erase(uint){} void Rectangle(int,int,int,int,uint){}
  void FontSet(const string&,int size){font=size;}
  void TextOut(int,int,const string&,uint,uint){} void Update(bool){}
} g_ps_handle_canvas[3];
bool g_ps_handle_canvas_created[3],g_ps_handle_visible[3];
string g_ps_handle_canvas_name[3],g_ps_handle_canvas_text[3];
color g_ps_handle_canvas_color[3];
PSRect g_ps_handle_rects[3];
int ObjectSetInteger(int,const string&,int,long){return 1;}
int ObjectGetInteger(int,const string&,int){return 0;}
int ObjectSetString(int,const string&,int,const string&){return 1;}
string PS_UIName(const PSUIState&,const string &suffix){return suffix;}
void PS_UIShow(const PSUIState&,const string&,bool){}
uint COLOR2RGB(color c){return c;}
color PS_UIAccessibleAccent(color c){return c;}
color PS_ThemeOnAccent(){return 0;}
int GetLastError(){return 0;}
void PS_LogError(const string&){}
template<class... Args> string StringFormat(const string &value,Args...){return value;}
''' + functions


def test_marker_canvas_and_hit_rectangle_follow_dpi_changes(tmp_path):
    program = marker_source() + r'''
int main(){
  PSUIState ui; PS_UILayout(ui,PS_VIEW_FULL);
  PS_UISetHandle(ui,PS_LEVEL_STOP,10,10,"S",1,true);
  fixture_dpi=192; fixture_chart_w=1600; fixture_chart_h=1200;
  PS_UILayout(ui,PS_VIEW_FULL);
  PS_UISetHandle(ui,PS_LEVEL_STOP,10,10,"S",1,true);
  auto rect=g_ps_handle_rects[PS_LEVEL_STOP];
  auto &canvas=g_ps_handle_canvas[PS_LEVEL_STOP];
  std::cout<<(rect.w==72 && rect.h==52)<<"\n";
  std::cout<<(canvas.w==72 && canvas.h==52 && canvas.font==-200)<<"\n";
}
'''
    assert compile_and_run(tmp_path, program).split() == ["1", "1"]


def test_failed_marker_canvas_cannot_capture_an_invisible_handle(tmp_path):
    program = marker_source() + "\n" + extract_function(TYPES, "PS_RectContains") + "\n" + extract_function(UI, "PS_UIHitHandle") + r'''
int main(){
  PSUIState ui; PS_UILayout(ui,PS_VIEW_FULL);
  fixture_canvas_ok=false;
  PS_UISetHandle(ui,PS_LEVEL_STOP,10,10,"S",1,true);
  bool hit=false; PS_UIHitHandle(15,15,hit);
  std::cout<<(!hit);
}
'''
    assert compile_and_run(tmp_path, program).strip() == "1"


def test_disabled_trade_button_explains_distinct_failure_causes(tmp_path):
    program = geometry_source() + "\n" + "\n".join(
        declaration(TYPES, name) for name in ("PSDirection", "PSOrderMode", "PSCalcIssue")
    ) + r'''
struct PSModel{PSDirection direction=PS_DIRECTION_LONG; PSOrderMode order_mode=PS_ORDER_INSTANT;};
struct PSCalcResult{bool valid=false;PSCalcIssue issue;double volume=0;string resolved_order_text;};
struct PSMarketSnapshot{};
string PS_VolumeText(double,const PSMarketSnapshot&){return "1.00";}
string PS_Upper(const string&s){return s;}
''' + extract_function(TYPES, "PS_CalcIssueText") + "\n" + extract_function(UI, "PS_UITradeText") + r'''
int main(){
  PSModel model; PSCalcResult calc; PSMarketSnapshot market;
  for(auto issue:{PS_CALC_ISSUE_STOP_DISTANCE,PS_CALC_ISSUE_NETTING,PS_CALC_ISSUE_ENTRY,PS_CALC_ISSUE_VOLUME}) {
    calc.issue=issue; std::cout<<PS_UITradeText(model,calc,market,false)<<"\n";
  }
}
'''
    assert compile_and_run(tmp_path, program).splitlines() == [
        "SL too close", "Netting conflict", "Invalid entry", "Volume unavailable",
    ]


def test_actual_risk_stays_visible_when_sizing_succeeds_but_market_is_closed(tmp_path):
    program = geometry_source() + r'''
struct PSCalcResult{bool valid=false,sizing_available=true;double actual_money=123.45;};
struct PSMarketSnapshot{};
bool PS_IsFinite(double n){return std::isfinite(n);}
string PS_FormatMoneyDisplay(double,const PSMarketSnapshot&){return "123.45";}
''' + extract_function(UI, "PS_UIActualRiskMoneyDisplay") + r'''
int main(){
  PSCalcResult calc; PSMarketSnapshot market;
  std::cout<<PS_UIActualRiskMoneyDisplay(calc,market);
}
'''
    assert compile_and_run(tmp_path, program).strip() == "123.45"


def color_literals(source: str) -> str:
    """Represent MQL RGB color values as RGB ints for luminance calculations."""
    return re.sub(
        r"C'(\d+),(\d+),(\d+)'",
        lambda m: str((int(m[1]) << 16) | (int(m[2]) << 8) | int(m[3])), source,
    )


def contrast(first: int, second: int) -> float:
    def luminance(rgb: int) -> float:
        channels = [(rgb >> shift & 255) / 255 for shift in (16, 8, 0)]
        linear = [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in channels]
        return sum(v * weight for v, weight in zip(linear, (0.2126, 0.7152, 0.0722)))
    a, b = sorted((luminance(first), luminance(second)))
    return (b + 0.05) / (a + 0.05)


def test_small_active_button_text_meets_45_contrast_without_changing_chart_colors(tmp_path):
    source = (ROOT / UI).read_text(encoding="utf-8")
    constants = "\n".join(re.findall(r"const color PS_(?:PREMIUM_GREEN|PREMIUM_BLUE|CLR_SHORT|CLR_LONG|CLR_ACCENT)\s*=.*?;", source))
    program = field_source() + "\n" + color_literals(constants) + r'''
int PS_ThemeControl(){return 0;} int PS_ThemeMuted(){return 0;}
''' + color_literals(extract_functions(UI, "PS_ThemeOnAccent", "PS_UIAccessibleAccent", "PS_PremiumButton")) + r'''
int main(){
  PSRect rect={0,0,200,30}; g_ps_metrics.scale=1;
  for(auto accent:{PS_PREMIUM_GREEN,PS_CLR_SHORT,PS_PREMIUM_BLUE}) {
    PS_PremiumButton(rect,"Label",true,accent,21,true);
    std::cout<<PS_ThemeOnAccent()<<" "<<recorded_fill<<"\n";
  }
}
'''
    rows = [tuple(map(int, row.split())) for row in compile_and_run(tmp_path, program).splitlines()]
    assert all(contrast(text, fill) >= 4.5 for text, fill in rows)


def test_failed_panel_paint_clears_interaction_and_keeps_retry_dirty(tmp_path):
    program = geometry_source() + r'''
struct PSModel{PSViewMode view_mode=PS_VIEW_FULL;};
struct PSCalcResult{};struct PSMarketSnapshot{};struct PSExposureSnapshot{};struct PSEditorState{};
bool g_ps_panel_render_ready=true,g_ps_handle_visible[3]={true,true,true};
int g_ps_exposure_label_count=3;
bool panel_hidden=false,lines_hidden=false;
const int PS_RENDER_BUDGET_US=8000;
ulong GetMicrosecondCount(){return 1;}
void PS_PerfCheck(const string&,ulong,int){}
bool PS_UIPremiumRender(PSUIState&,const PSModel&,const PSCalcResult&,const PSMarketSnapshot&,
  const PSExposureSnapshot&,const PSEditorState&,PSControlId){return false;}
void PS_UIHidePanelContent(const PSUIState&){panel_hidden=true;}
void PS_UIHidePlanningLines(PSUIState&){lines_hidden=true;}
void PS_UIUpdateLines(PSUIState&,const PSModel&,const PSMarketSnapshot&){}
''' + extract_functions(UI, "PS_UIInvalidatePanelHits", "PS_UIRenderPanel") + r'''
int main(){
  PSUIState ui;PSModel model;PSCalcResult calc;PSMarketSnapshot market;PSExposureSnapshot exposure;PSEditorState editor;
  bool result=PS_UIRenderPanel(ui,model,calc,market,exposure,editor,PS_CTRL_NONE);
  bool controls_hidden=true;
  for(bool visible:g_ps_control_visible) controls_hidden=controls_hidden&&!visible;
  for(bool visible:g_ps_handle_visible) controls_hidden=controls_hidden&&!visible;
  std::cout<<(!result && !g_ps_panel_render_ready && ui.dirty && controls_hidden &&
    g_ps_exposure_label_count==0 && panel_hidden && lines_hidden);
}
'''
    assert compile_and_run(tmp_path, program).strip() == "1"
    # Removing invalidation must be detected, even though the renderer still
    # returns false and hides its surfaces. Invisible interactive controls matter.
    mutant = program.replace("PS_UIInvalidatePanelHits();", "")
    assert compile_and_run(tmp_path, mutant).strip() == "0"
