"""Execute production copy/editor/platform bodies, without a user's clipboard.

Platform failure fixtures model documented Win32 ownership and allocation rules.
The separate Windows integration fixture uses a private noninteractive station.
Neither fixture is an MT5 DLL-import or mouse/event-queue acceptance test.
"""
from __future__ import annotations

import pytest

from native_mql_harness import compile_and_run, extract_function, extract_functions
from test_native_ui import declaration, geometry_source

EA = "MQL5/Experts/LotCraft/LotCraft.mq5"
EDITOR = "MQL5/Experts/LotCraft/PS_Editor.mqh"
PLATFORM = "MQL5/Experts/LotCraft/PS_Platform.mqh"
TYPES = "MQL5/Experts/LotCraft/PS_Types.mqh"


def copy_source() -> str:
    return r'''
#include <algorithm>
#include <cassert>
#include <cmath>
#include <iomanip>
#include <sstream>
#include <string>
using string=std::string;
using ulong=unsigned long long;
''' + "\n".join(declaration(TYPES, name) for name in (
        "PSControlId", "PSDirection", "PSOrderMode", "PSAccountMode", "PSFieldId",
    )) + r'''
struct PSModel {
  PSOrderMode order_mode=PS_ORDER_PENDING; PSDirection direction=PS_DIRECTION_LONG;
  PSAccountMode account_mode=PS_ACCOUNT_MANUAL;
  double entry=1.23456,stop_loss=1.12345,take_profit=1.34567;
  double commission_per_lot=0,manual_account_money=1000,requested_risk_percent=1,requested_risk_money=10;
} g_model;
struct PSMarketSnapshot {
  bool tick_valid=true; double tick_size=0.00001,volume_step=0.001,equity=1000,balance=900;
  int digits=5,currency_digits=2;
  struct {double ask=1.23457,bid=1.23455;} tick;
} g_market;
struct {bool sizing_available=true; double volume=0.123;} g_calc;
struct {bool dirty=false;} g_ui;
PSControlId g_copy_feedback_control=PS_CTRL_NONE;
ulong g_copy_feedback_until_ms=0;
string clipboard_text="unchanged",last_status,last_warning;
bool clipboard_ok=true,status_error=false;
int clipboard_calls=0,warning_calls=0;
bool PS_IsFinite(double v){return std::isfinite(v);}
bool PS_IsPositiveFinite(double v){return std::isfinite(v)&&v>0;}
double MathRound(double v){return std::round(v);}
double NormalizeDouble(double v,int digits){double p=std::pow(10,digits);return std::round(v*p)/p;}
string DoubleToString(double v,int digits){std::ostringstream out;out<<std::fixed<<std::setprecision(digits)<<v;return out.str();}
int PS_DecimalsForStep(double step){return step==0.001?3:step==0.1?1:2;}
ulong GetTickCount64(){return 2000;}
void PS_SetStatus(const string &s,bool failed,ulong=5000){last_status=s;status_error=failed;g_ui.dirty=true;}
void PS_LogWarningRateLimited(const string&,const string &s,int){++warning_calls;last_warning=s;}
bool PS_PlatformClipboardSet(const string &s,string &error){
  ++clipboard_calls;if(!clipboard_ok){error="Windows clipboard is currently unavailable.";return false;}
  error="";clipboard_text=s;return true;
}
''' + extract_functions(TYPES, "PS_NormalizePrice", "PS_PriceText", "PS_VolumeText") + "\n" + extract_functions(
        EA, "PS_CopyText", "PS_DoCopy",
    )


@pytest.mark.parametrize(("action", "expected"), [
    ("PS_CTRL_ENTRY_COPY", "1.23456"),
    ("PS_CTRL_STOP_COPY", "1.12345"),
    ("PS_CTRL_TAKE_COPY", "1.34567"),
    ("PS_CTRL_POSITION_COPY", "0.123"),
])
def test_each_copy_button_transfers_full_precision_and_marks_success(tmp_path, action, expected):
    source = copy_source() + f'''
int main() {{
  PS_DoCopy({action});
  assert(clipboard_text=="{expected}" && clipboard_calls==1);
  assert(g_copy_feedback_control=={action} && g_copy_feedback_until_ms==3200);
  assert(g_ui.dirty && !status_error);
}}
'''
    compile_and_run(tmp_path, source)


@pytest.mark.parametrize(("configuration", "action", "expected"), [
    ("g_market.tick_size=0;", "PS_CTRL_STOP_COPY", "1.12345"),
    ("g_market.tick_size=0;", "PS_CTRL_ENTRY_COPY", "1.23456"),
    ("g_market.tick_size=0;", "PS_CTRL_TAKE_COPY", "1.34567"),
    ("g_market.digits=2;g_market.tick_size=0.25;g_model.order_mode=PS_ORDER_INSTANT;g_market.tick.ask=128.13;", "PS_CTRL_ENTRY_COPY", "128.13"),
])
def test_copy_matches_displayed_price_without_trade_normalization(tmp_path, configuration, action, expected):
    # Mutating the copy path to re-normalize needs to fail independently of
    # trading validity. Copying a planning number does not submit a trade.
    source = copy_source() + f'''
int main() {{
  {configuration}
  PS_DoCopy({action});
  assert(clipboard_text=="{expected}");
}}
'''
    compile_and_run(tmp_path, source)


def test_disabled_take_profit_copies_zero(tmp_path):
    compile_and_run(tmp_path, copy_source() + r'''
int main(){g_model.take_profit=0;PS_DoCopy(PS_CTRL_TAKE_COPY);assert(clipboard_text=="0.00000");}
''')


@pytest.mark.parametrize(("configuration", "expected"), [
    ("g_model.order_mode=PS_ORDER_INSTANT;", "1.23457"),
    ("g_model.order_mode=PS_ORDER_INSTANT;g_model.direction=PS_DIRECTION_SHORT;", "1.23455"),
    ("g_model.order_mode=PS_ORDER_INSTANT;g_market.tick_valid=false;", "1.23456"),
    ("g_market.digits=3;g_model.entry=157.517;", "157.517"),
    ("g_market.digits=1;g_model.entry=7707.0;", "7707.0"),
])
def test_entry_copy_uses_displayed_side_or_cached_planning_price(tmp_path, configuration, expected):
    compile_and_run(tmp_path, copy_source() + f'''
int main() {{
  {configuration}
  PS_DoCopy(PS_CTRL_ENTRY_COPY);
  assert(clipboard_text=="{expected}" && clipboard_calls==1 && !status_error);
}}
''')


def test_unavailable_volume_does_not_copy_or_retain_old_success_feedback(tmp_path):
    compile_and_run(tmp_path, copy_source() + r'''
int main(){
  g_copy_feedback_control=PS_CTRL_POSITION_COPY;g_copy_feedback_until_ms=3200;
  g_calc.sizing_available=false;PS_DoCopy(PS_CTRL_POSITION_COPY);
  assert(clipboard_calls==0 && clipboard_text=="unchanged" && status_error);
  assert(g_copy_feedback_control==PS_CTRL_NONE && g_copy_feedback_until_ms==0);
}
''')


def test_failed_copy_clears_old_success_and_logs_reason_without_value(tmp_path):
    compile_and_run(tmp_path, copy_source() + r'''
int main(){
  PS_DoCopy(PS_CTRL_STOP_COPY);clipboard_ok=false;PS_DoCopy(PS_CTRL_STOP_COPY);
  assert(status_error && g_copy_feedback_control==PS_CTRL_NONE && g_copy_feedback_until_ms==0);
  assert(warning_calls==1 && last_warning=="Windows clipboard is currently unavailable.");
  assert(last_warning.find("1.12345")==string::npos);
}
''')


def keyboard_source() -> str:
    return copy_source() + "\n" + declaration(EDITOR, "PSEditKeyResult") + r'''
using ushort=unsigned short;
struct PSEditorState {
  bool active=true,has_selection=true;PSFieldId field=PS_FIELD_STOP;
  string raw_text="1.12345",original_text="1.12345";int cursor=7,anchor=0;
} g_editor;
bool g_initialized=true,g_symbol_transition_pending=false,g_ps_panel_render_ready=true;
bool g_shift_down=false,g_ctrl_down=false,g_panel_dirty=false;
bool g_exposure_details_dirty=false,g_exposure_labels_dirty=false;
bool g_ps_control_visible[PS_CTRL_COUNT]={};PSControlId g_keyboard_focus=PS_CTRL_STOP_FIELD;
struct {bool details_open=false;} g_exposure_ui;
int recalculations=0;
int StringLen(const string &s){return int(s.size());}
string StringSubstr(const string &s,int begin,int length=-1){return s.substr(begin,length<0?string::npos:size_t(length));}
int MathMin(int a,int b){return std::min(a,b);}int MathMax(int a,int b){return std::max(a,b);}
int PS_ClampInt(int v,int lo,int hi){return std::clamp(v,lo,hi);}
short TranslateKey(int key){return (key>=48 && key<=90)?short(key):0;}
string ShortToString(short key){return string(1,char(key));}
ushort StringGetCharacter(const string &s,int i){return (unsigned char)s.at(i);}
void PS_KeyboardFocusNext(bool){}void PS_CancelEditor(){}void PS_SaveState(){}
void PS_RenderIfDirty(){}void PS_Action(PSControlId){}void PS_UIGuardEnter(decltype(g_ui)&){}
bool PS_EditorApplyRaw(PSEditorState&,PSModel&,PSMarketSnapshot&,bool,string&){return true;}
void PS_ClearTransientStatus(){}void PS_Recalculate(bool){++recalculations;}
bool PS_CommitEditor(){return true;}
''' + extract_functions(EDITOR,
        "PS_EditorSelectAll", "PS_EditorSelectionStart", "PS_EditorSelectionEnd",
        "PS_EditorRefreshSelection", "PS_EditorDeleteSelection", "PS_EditorInsert",
        "PS_EditorMoveCursor", "PS_EditorBackspace", "PS_EditorDelete", "PS_EditorKey",
    ) + "\n" + extract_function(EA, "PS_HandleKeyDown")


@pytest.mark.parametrize(("cursor", "anchor", "expected"), [
    (7, 0, "1.12345"), (2, 7, "12345"), (5, 2, "123"),
])
def test_ctrl_c_copies_selected_text_without_committing_or_recalculating(tmp_path, cursor, anchor, expected):
    source = keyboard_source() + f'''
int main() {{
  g_editor.cursor={cursor};g_editor.anchor={anchor};
  PS_HandleKeyDown(17);PS_HandleKeyDown(67);
  assert(clipboard_text=="{expected}" && clipboard_calls==1);
  assert(g_editor.raw_text=="1.12345" && g_editor.active && g_editor.has_selection);
  assert(g_editor.cursor=={cursor} && g_editor.anchor=={anchor} && recalculations==0);
}}
'''
    compile_and_run(tmp_path, source)


def test_plain_c_and_ctrl_c_without_selection_do_not_overwrite_clipboard(tmp_path):
    compile_and_run(tmp_path, keyboard_source() + r'''
int main(){
  PS_HandleKeyDown(67);assert(clipboard_calls==0);
  g_editor.has_selection=false;g_editor.anchor=g_editor.cursor;
  PS_HandleKeyDown(17);PS_HandleKeyDown(67);
  assert(clipboard_calls==0 && clipboard_text=="unchanged" && recalculations==0);
}
''')


def test_every_numeric_editor_copies_long_and_uncommitted_selections(tmp_path):
    # All seven fields share the same copy path. The hidden legacy commission
    # editor is included, but this test does not make it a visible control.
    compile_and_run(tmp_path, keyboard_source() + r'''
int main(){
  for(auto field:{PS_FIELD_ENTRY,PS_FIELD_STOP,PS_FIELD_TAKE,PS_FIELD_COMMISSION,
                  PS_FIELD_ACCOUNT,PS_FIELD_RISK_PERCENT,PS_FIELD_RISK_MONEY}) {
    for(const string &raw:{string("12345678901234567890123456789012"),string("1."),string("-"),string("1,234.50")}) {
      g_editor.field=field;g_editor.raw_text=raw;g_editor.cursor=int(raw.size());
      g_editor.anchor=g_editor.cursor;g_editor.has_selection=false;
      int previous_calls=clipboard_calls;
      PS_HandleKeyDown(17);PS_HandleKeyDown(65);PS_HandleKeyDown(67);
      assert(clipboard_text==raw && clipboard_calls==previous_calls+1);
      assert(g_editor.raw_text==raw && g_editor.active && g_editor.has_selection);
      assert(g_editor.cursor==int(raw.size()) && g_editor.anchor==0 && recalculations==0);
    }
  }
  assert(g_model.entry==1.23456 && g_model.stop_loss==1.12345 && g_model.requested_risk_percent==1);
}
''')


def test_failed_selection_copy_preserves_editor_and_previous_clipboard(tmp_path):
    compile_and_run(tmp_path, keyboard_source() + r'''
int main(){
  g_copy_feedback_control=PS_CTRL_STOP_COPY;g_copy_feedback_until_ms=3200;
  clipboard_ok=false;PS_HandleKeyDown(17);PS_HandleKeyDown(67);
  assert(clipboard_text=="unchanged" && clipboard_calls==1 && status_error && warning_calls==1);
  assert(g_copy_feedback_control==PS_CTRL_NONE && g_copy_feedback_until_ms==0);
  assert(g_editor.active && g_editor.raw_text=="1.12345" && g_editor.has_selection);
  assert(g_editor.cursor==7 && g_editor.anchor==0 && recalculations==0);
}
''')


def test_copy_button_hit_targets_follow_full_compact_and_mini_geometry(tmp_path):
    # Theme affects paint only. Hit testing uses these shared DPI-scaled rects.
    source = geometry_source() + "\n#include <cassert>\n" + extract_function(TYPES, "PS_RectContains")
    source += "\n" + extract_function("MQL5/Experts/LotCraft/PS_UI.mqh", "PS_UIHitControl") + r'''
int main(){
  for(int dpi:{96,120,144,192}) {
    fixture_dpi=dpi;fixture_chart_w=1600;fixture_chart_h=1400;
    for(auto mode:{PS_VIEW_FULL,PS_VIEW_COMPACT}) {
      PSUIState ui;ui.panel_x=17;ui.panel_y=31;PS_UILayout(ui,mode);
      for(auto control:{PS_CTRL_ENTRY_COPY,PS_CTRL_STOP_COPY,PS_CTRL_TAKE_COPY,PS_CTRL_POSITION_COPY}) {
        auto r=g_ps_control_rects[control];
        assert(g_ps_control_visible[control] && r.w>0 && r.h>0);
        assert(PS_UIHitControl(r.x+r.w/2,r.y+r.h/2)==control);
        assert(PS_UIHitControl(r.x+1,r.y+1)==control);
        assert(PS_UIHitControl(r.x+r.w-1,r.y+r.h-1)==control);
        assert(r.x>=ui.panel_x && r.y>=ui.panel_y);
        assert(r.x+r.w<=ui.panel_x+ui.panel_w && r.y+r.h<=ui.panel_y+ui.panel_h);
      }
    }
    PSUIState ui;PS_UILayout(ui,PS_VIEW_MINI);
    for(auto control:{PS_CTRL_ENTRY_COPY,PS_CTRL_STOP_COPY,PS_CTRL_TAKE_COPY,PS_CTRL_POSITION_COPY})
      assert(!g_ps_control_visible[control]);
    auto r=g_ps_control_rects[PS_CTRL_RISK_PERCENT_FIELD];
    assert(PS_UIHitControl(r.x+r.w/2,r.y+r.h/2)==PS_CTRL_RISK_PERCENT_FIELD);
  }
}
'''
    compile_and_run(tmp_path, source)


def platform_source() -> str:
    return r'''
#include <cassert>
#include <cstdint>
#include <sstream>
#include <string>
using string=std::string;using ulong=unsigned long long;using uint=unsigned int;using MqlLong=std::int64_t;
const int MQL_DLLS_ALLOWED=1,CHART_WINDOW_HANDLE=2;
const uint PS_CF_UNICODETEXT=13,PS_GMEM_MOVEABLE=2;
bool _IsX64=true,dll_allowed=true,chart_ok=true,clipboard_open=false,transferred=false;
MqlLong chart_handle=0x100000001LL;
int fail_stage=0,allocations=0,frees=0,locks=0,unlocks=0,opens=0,closes=0,empties=0;
ulong allocated_handle=0,locked_pointer=0;
string clipboard_text="previous",memory_text;
bool MQLInfoInteger(int){return dll_allowed;}
int ChartID(){return 1;}
bool ChartGetInteger(int,int,int,MqlLong &out){out=chart_handle;return chart_ok;}
int GetLastError(){return 7;}
template<class T> string StringFormat(const string &s,T){return s;}
int StringLen(const string &s){return int(s.size());}
template<class T> T GlobalAlloc(uint flags,T bytes){
  ++allocations;assert(flags==2 && bytes>=2);
  if(fail_stage==1)return 0;
  allocated_handle=sizeof(T)==8?0x1234567887654321ULL:0x87654321U;return T(allocated_handle);
}
template<class T> T GlobalLock(T handle){
  assert(ulong(handle)==allocated_handle);if(fail_stage==2)return 0;
  ++locks;locked_pointer=sizeof(T)==8?0x2234567887654321ULL:0x77654321U;return T(locked_pointer);
}
template<class T> int GlobalUnlock(T handle){assert(ulong(handle)==allocated_handle);++unlocks;return 0;}
template<class T> T GlobalFree(T handle){assert(ulong(handle)==allocated_handle && !transferred);++frees;return 0;}
template<class T> T lstrcpyW(T pointer,const string &s){
  assert(ulong(pointer)==locked_pointer);if(fail_stage==3)return 0;memory_text=s;return pointer;
}
template<class T> int OpenClipboard(T owner){
  ++opens;assert(!clipboard_open);
  if(fail_stage==4)return 0;
  assert(ulong(owner)==(_IsX64?ulong(chart_handle):ulong(uint(chart_handle))));
  clipboard_open=true;return 1;
}
int EmptyClipboard(){assert(clipboard_open);++empties;if(fail_stage==5)return 0;clipboard_text="";return 1;}
template<class T> T SetClipboardData(uint format,T handle){
  assert(clipboard_open && format==13 && ulong(handle)==allocated_handle && unlocks==locks);
  if(fail_stage==6 || chart_handle==0)return 0;
  clipboard_text=memory_text;transferred=true;return handle;
}
int CloseClipboard(){assert(clipboard_open);++closes;clipboard_open=false;return 1;}
''' + "\n#define long MqlLong\n" + extract_function(PLATFORM, "PS_PlatformClipboardSet") + "\n#undef long\n"


@pytest.mark.parametrize("bits", [32, 64])
@pytest.mark.parametrize("failure", [0, 1, 2, 3, 4, 5, 6])
def test_platform_pointer_width_transfer_and_each_failure_cleanup(tmp_path, bits, failure):
    source = platform_source() + f'''
int main() {{
  _IsX64={str(bits == 64).lower()};chart_handle={"0x100000001LL" if bits == 64 else "0x10001"};
  fail_stage={failure};string error="stale";
  bool success=PS_PlatformClipboardSet("1.12345",error);
  assert(success=={str(failure == 0).lower()});
  assert(!clipboard_open && locks==unlocks && closes==(opens>0 && fail_stage!=4?1:0));
  if(success){{assert(error.empty() && clipboard_text=="1.12345" && transferred && frees==0);}}
  else{{assert(!error.empty() && !transferred && frees==(fail_stage==1?0:1));}}
}}
'''
    compile_and_run(tmp_path, source)


@pytest.mark.parametrize("bits", [32, 64])
def test_zero_window_handle_cannot_clear_existing_clipboard(tmp_path, bits):
    compile_and_run(tmp_path, platform_source() + f'''
int main() {{
  _IsX64={str(bits == 64).lower()};chart_handle=0;string error;
  assert(!PS_PlatformClipboardSet("1.12345",error));
  assert(clipboard_text=="previous" && opens==0 && empties==0 && allocations==0 && !error.empty());
}}
''')


@pytest.mark.parametrize(("state", "expected"), [
    ("dll_allowed=false;", "DLL imports"),
    ("chart_ok=false;", "window handle"),
])
def test_permission_and_handle_failure_do_not_touch_clipboard(tmp_path, state, expected):
    compile_and_run(tmp_path, platform_source() + f'''
int main() {{
  {state} string error;
  assert(!PS_PlatformClipboardSet("1.12345",error));
  assert(clipboard_text=="previous" && opens==0 && allocations==0);
  assert(error.find("{expected}")!=string::npos);
}}
''')
