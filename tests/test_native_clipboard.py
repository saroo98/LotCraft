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
        "PSControlId", "PSDirection", "PSOrderMode", "PSAccountMode", "PSRiskAuthority", "PSFieldId",
    )) + r'''
struct PSModel {
  PSOrderMode order_mode=PS_ORDER_PENDING; PSDirection direction=PS_DIRECTION_LONG;
  PSAccountMode account_mode=PS_ACCOUNT_MANUAL;
  double entry=1.23456,stop_loss=1.12345,take_profit=1.34567;
  double commission_per_lot=0,manual_account_money=1000,requested_risk_percent=1,requested_risk_money=10;
  PSRiskAuthority risk_authority=PS_RISK_PERCENT;ulong revision=0;
} g_model;
void PS_CopyModel(PSModel &to,const PSModel &from){to=from;}
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
using uint=unsigned int;
struct PSEditorState {
  bool active=true,has_selection=true;PSFieldId field=PS_FIELD_STOP;
  string raw_text="1.12345",original_text="1.12345";int cursor=7,anchor=0;
  string history_text[32];int history_cursor[32]={},history_anchor[32]={},history_count=0,history_index=0;
  PSModel history_model[32];
  PSModel before;
} g_editor;
bool g_initialized=true,g_symbol_transition_pending=false,g_ps_panel_render_ready=true;
bool g_shift_down=false,g_ctrl_down=false,g_panel_dirty=false;
bool g_shift_state_known=false,g_ctrl_state_known=false;
uint g_shift_pressed_keys=0,g_ctrl_pressed_keys=0;
uint g_shortcut_keydowns=0;
bool g_shortcut_ctrl_context=false,g_shortcut_shift_context=false;
PSFieldId g_shortcut_field=PS_FIELD_NONE;
uint physical_ctrl_keys=0,physical_shift_keys=0;
const int TERMINAL_KEYSTATE_SHIFT=1,TERMINAL_KEYSTATE_CONTROL=2;
int native_ctrl=0,native_shift=0;
const int MQL_DLLS_ALLOWED=1;
bool dll_allowed=true;short windows_ctrl=0,windows_shift=0;
int windows_key_reads=0;
bool MQLInfoInteger(int){return dll_allowed;}
short GetAsyncKeyState(int key){
  ++windows_key_reads;assert(key==16 || key==17);
  return key==17?windows_ctrl:windows_shift;
}
int TerminalInfoInteger(int key){
  return key==TERMINAL_KEYSTATE_CONTROL?native_ctrl:native_shift;
}
uint MapVirtualKeyW(uint key,uint mode){assert(key==161 && mode==0);return 0x36;}
bool clipboard_read_ok=true;int clipboard_reads=0;
bool PS_PlatformClipboardGet(string &text,string &error){
  ++clipboard_reads;if(!clipboard_read_ok){error="Windows clipboard is currently unavailable.";return false;}
  text=clipboard_text;error="";return true;
}
bool g_exposure_details_dirty=false,g_exposure_labels_dirty=false;
bool g_ps_control_visible[PS_CTRL_COUNT]={};PSControlId g_keyboard_focus=PS_CTRL_STOP_FIELD;
struct {bool details_open=false;} g_exposure_ui;
int recalculations=0;
int keyboard_renders=0;
int StringLen(const string &s){return int(s.size());}
string StringSubstr(const string &s,int begin,int length=-1){return s.substr(begin,length<0?string::npos:size_t(length));}
int MathMin(int a,int b){return std::min(a,b);}int MathMax(int a,int b){return std::max(a,b);}
int PS_ClampInt(int v,int lo,int hi){return std::clamp(v,lo,hi);}
short TranslateKey(int key){return key>=96 && key<=105?short(key-96+'0'):key==110?'.':key==109?'-':key==107?'+':key==188?',':key==190?'.':(key>=48 && key<=90)?short(key):0;}
string ShortToString(short key){return string(1,char(key));}
ushort StringGetCharacter(const string &s,int i){return (unsigned char)s.at(i);}
void StringTrimLeft(string &s){s.erase(0,s.find_first_not_of(" \t\r\n"));}
void StringTrimRight(string &s){auto i=s.find_last_not_of(" \t\r\n");s.erase(i==string::npos?0:i+1);}
void StringReplace(string &s,const string &a,const string &b){for(size_t i=0;(i=s.find(a,i))!=string::npos;i+=b.size())s.replace(i,a.size(),b);}
double StringToDouble(const string &s){return std::stod(s);}
void PS_KeyboardFocusNext(bool){}void PS_CancelEditor(){}void PS_SaveState(){}
void PS_RenderIfDirty(){++keyboard_renders;}void PS_Action(PSControlId){}void PS_UIGuardEnter(decltype(g_ui)&){}
bool PS_EditorApplyRaw(PSEditorState&,PSModel&,PSMarketSnapshot&,bool,string&){return true;}
void PS_ClearTransientStatus(){}void PS_Recalculate(bool){++recalculations;}
bool PS_CommitEditor(){return true;}
''' + extract_functions(EDITOR,
        "PS_EditorSelectAll", "PS_EditorSelectionStart", "PS_EditorSelectionEnd",
        "PS_EditorRefreshSelection", "PS_EditorRecordChange", "PS_EditorRestoreHistory", "PS_EditorDeleteSelection", "PS_EditorInsert",
        "PS_EditorMoveCursor", "PS_EditorBackspace", "PS_EditorDelete", "PS_EditorParseNumber", "PS_EditorPaste", "PS_EditorKey",
    ) + "\n" + extract_functions(PLATFORM, "PS_PlatformKeyboardModifiers", "PS_PlatformModifierSide") + "\n" + extract_functions(
        EA, "PS_ResetShortcutContext", "PS_RecordShortcutContext", "PS_KeyboardShortcutBit",
        "PS_ResetKeyboardModifiers", "PS_ObserveKeyboardModifier", "PS_ObserveMouseModifiers",
        "PS_ExecuteEditorKey", "PS_HandleKeyDown", "PS_HandleKeyUp",
    ) + r'''
// Physical input observations are independent of LotCraft's logical flags.
void PressKey(int key,uint flags=0){
  if(key==16 || key==160 || key==161){
    physical_shift_keys|=(key==161 || (key==16 && (flags&0xff)==0x36))?2:1;
    native_shift=0x8000;windows_shift=-32768;
  }
  if(key==17 || key==162 || key==163){
    physical_ctrl_keys|=(key==163 || (key==17 && (flags&0x100)))?2:1;
    native_ctrl=0x8000;windows_ctrl=-32768;
  }
  PS_HandleKeyDown(key,flags);
}
void ReleaseKey(int key,uint flags=0){
  if(key==16 || key==160 || key==161){
    physical_shift_keys&=~((key==161 || (key==16 && (flags&0xff)==0x36))?2U:1U);
    native_shift=physical_shift_keys?0x8000:0;windows_shift=physical_shift_keys?-32768:0;
  }
  if(key==17 || key==162 || key==163){
    physical_ctrl_keys&=~((key==163 || (key==17 && (flags&0x100)))?2U:1U);
    native_ctrl=physical_ctrl_keys?0x8000:0;windows_ctrl=physical_ctrl_keys?-32768:0;
  }
  PS_HandleKeyUp(key,flags);
}
'''


@pytest.mark.parametrize(("cursor", "anchor", "expected"), [
    (7, 0, "1.12345"), (2, 7, "12345"), (5, 2, "123"),
])
def test_ctrl_c_copies_selected_text_without_committing_or_recalculating(tmp_path, cursor, anchor, expected):
    source = keyboard_source() + f'''
int main() {{
  g_editor.cursor={cursor};g_editor.anchor={anchor};
  PressKey(17);PressKey(67);
  assert(clipboard_text=="{expected}" && clipboard_calls==1);
  assert(g_editor.raw_text=="1.12345" && g_editor.active && g_editor.has_selection);
  assert(g_editor.cursor=={cursor} && g_editor.anchor=={anchor} && recalculations==0);
}}
'''
    compile_and_run(tmp_path, source)


def test_plain_c_and_ctrl_c_without_selection_do_not_overwrite_clipboard(tmp_path):
    compile_and_run(tmp_path, keyboard_source() + r'''
int main(){
  PressKey(67);assert(clipboard_calls==0);
  g_editor.has_selection=false;g_editor.anchor=g_editor.cursor;
  PressKey(17);PressKey(67);
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
      PressKey(17);PressKey(65);PressKey(67);
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
  clipboard_ok=false;PressKey(17);PressKey(67);
  assert(clipboard_text=="unchanged" && clipboard_calls==1 && status_error && warning_calls==1);
  assert(g_copy_feedback_control==PS_CTRL_NONE && g_copy_feedback_until_ms==0);
  assert(g_editor.active && g_editor.raw_text=="1.12345" && g_editor.has_selection);
  assert(g_editor.cursor==7 && g_editor.anchor==0 && recalculations==0);
}
''')


def test_held_ctrl_without_modifier_key_event_selects_and_copies(tmp_path):
    compile_and_run(tmp_path, keyboard_source() + r'''
int main(){
  native_ctrl=0x8000;windows_ctrl=-32768;
  g_editor.has_selection=false;g_editor.anchor=g_editor.cursor;
  PressKey(65);PressKey(67);
  assert(clipboard_calls==1 && clipboard_text=="1.12345");
  assert(g_editor.has_selection && g_editor.anchor==0 && g_editor.cursor==7);
  assert(recalculations==0);
}
''')


def test_windows_ctrl_state_works_when_terminal_modifier_observation_is_zero(tmp_path):
    # Break caught: relying only on TerminalInfoInteger ignores a held Ctrl
    # that Windows reports independently. No modifier key event is injected.
    compile_and_run(tmp_path, keyboard_source() + r'''
int main(){
  dll_allowed=true;native_ctrl=0;windows_ctrl=-32768;
  g_editor.has_selection=false;g_editor.anchor=g_editor.cursor;
  PressKey(65);PressKey(67);
  assert(g_editor.has_selection && g_editor.cursor==7 && g_editor.anchor==0);
  assert(clipboard_calls==1 && clipboard_text=="1.12345" && recalculations==0);
  clipboard_text="2.5";PressKey(86);
  assert(clipboard_reads==1 && g_editor.raw_text=="2.5" && recalculations==1);
}
''')


def test_windows_shift_state_extends_selection_when_terminal_observation_is_zero(tmp_path):
    compile_and_run(tmp_path, keyboard_source() + r'''
int main(){
  dll_allowed=true;windows_shift=-32768;
  g_editor.has_selection=false;g_editor.cursor=3;g_editor.anchor=3;
  PressKey(37);
  assert(g_editor.cursor==2 && g_editor.anchor==3 && g_editor.has_selection);
  PressKey(45);
  assert(clipboard_reads==1);
}
''')


def test_windows_modifier_release_overrides_a_stale_terminal_observation(tmp_path):
    compile_and_run(tmp_path, keyboard_source() + r'''
int main(){
  dll_allowed=true;native_ctrl=0x8000;native_shift=0x8000;
  windows_ctrl=1;windows_shift=1;g_ctrl_down=true;g_shift_down=true;
  PressKey(67);
  assert(clipboard_calls==0 && !g_ctrl_down && !g_shift_down);
  PressKey(50);
  assert(g_editor.raw_text=="2" && recalculations==1);
}
''')


def test_dll_disabled_keyboard_fallback_never_calls_windows_key_api(tmp_path):
    compile_and_run(tmp_path, keyboard_source() + r'''
int main(){
  dll_allowed=false;native_ctrl=0x8000;windows_ctrl=0;
  g_editor.has_selection=false;g_editor.anchor=g_editor.cursor;
  PressKey(65);
  assert(g_editor.has_selection && g_editor.anchor==0 && g_editor.cursor==7);
  ReleaseKey(17);windows_ctrl=-32768;PressKey(50);
  assert(g_editor.raw_text=="2" && recalculations==1 && windows_key_reads==0);
}
''')


@pytest.mark.parametrize("key", [65, 67, 86])
def test_delivered_ctrl_press_survives_physical_release_before_shortcut_dispatch(tmp_path, key):
    # These are delivered events, not a claim that MT5 enqueues every event.
    # The physical press has ended before the EA handles the shortcut.
    compile_and_run(tmp_path, keyboard_source() + f'''
int main(){{
  native_ctrl=0;windows_ctrl=0;clipboard_text="2.5";
  if({key}==65){{g_editor.has_selection=false;g_editor.anchor=g_editor.cursor;}}
  PS_HandleKeyDown(17);PS_HandleKeyDown({key});PS_HandleKeyUp(17);
  if({key}==65) assert(g_editor.has_selection && g_editor.anchor==0 && g_editor.cursor==7);
  if({key}==67) assert(clipboard_calls==1 && clipboard_text=="1.12345");
  if({key}==86) assert(clipboard_reads==1 && g_editor.raw_text=="2.5");
  assert(!g_ctrl_down);
}}
''')


def test_delivered_shift_press_survives_physical_release_before_arrow_dispatch(tmp_path):
    compile_and_run(tmp_path, keyboard_source() + r'''
int main(){
  native_shift=0;windows_shift=0;
  g_editor.has_selection=false;g_editor.cursor=3;g_editor.anchor=3;
  PS_HandleKeyDown(16);PS_HandleKeyDown(37);PS_HandleKeyUp(16);
  assert(g_editor.has_selection && g_editor.cursor==2 && g_editor.anchor==3 && !g_shift_down);
}
''')


def test_known_ctrl_release_does_not_inject_future_ctrl_into_older_plain_v(tmp_path):
    compile_and_run(tmp_path, keyboard_source() + r'''
int main(){
  PS_HandleKeyUp(17);windows_ctrl=-32768;
  PS_HandleKeyDown(86);
  assert(clipboard_reads==0 && g_editor.raw_text=="1.12345" && !g_ctrl_down);
}
''')


def test_known_shift_release_does_not_turn_older_delete_into_cut(tmp_path):
    compile_and_run(tmp_path, keyboard_source() + r'''
int main(){
  PS_HandleKeyUp(16);windows_shift=-32768;
  g_editor.has_selection=false;g_editor.cursor=3;g_editor.anchor=3;
  PS_HandleKeyDown(46);
  assert(g_editor.raw_text=="1.1345" && clipboard_calls==0 && !g_shift_down);
}
''')


@pytest.mark.parametrize(("left", "right", "shortcut"), [(162, 163, 67), (160, 161, 37)])
def test_releasing_one_modifier_side_preserves_the_other_delivered_side(tmp_path, left, right, shortcut):
    compile_and_run(tmp_path, keyboard_source() + f'''
int main(){{
  if({left}==160){{g_editor.has_selection=false;g_editor.cursor=3;g_editor.anchor=3;}}
  PS_HandleKeyDown({left});PS_HandleKeyDown({right});PS_HandleKeyUp({left});
  if({left}==162)windows_ctrl=-32768;else windows_shift=-32768;
  PS_HandleKeyDown({shortcut});
  if({left}==162)assert(g_ctrl_down && clipboard_calls==1 && clipboard_text=="1.12345");
  else assert(g_shift_down && g_editor.has_selection && g_editor.cursor==2 && g_editor.anchor==3);
  PS_HandleKeyUp({right});assert(!g_ctrl_down && !g_shift_down);
}}
''')


def test_mouse_event_snapshot_recovers_missing_release_and_held_modifiers(tmp_path):
    compile_and_run(tmp_path, keyboard_source() + r'''
int main(){
  PS_HandleKeyDown(17);PS_ObserveMouseModifiers(0);PressKey(50);
  assert(g_editor.raw_text=="2" && !g_ctrl_down && !g_shift_down);
  PS_ObserveMouseModifiers(8);PS_HandleKeyDown(65);PS_HandleKeyDown(67);
  assert(clipboard_text=="2" && clipboard_calls==1 && g_ctrl_down);
  PS_ObserveMouseModifiers(0);PS_HandleKeyDown(39);
  PS_ObserveMouseModifiers(4);PS_HandleKeyDown(37);
  assert(g_editor.has_selection && g_editor.anchor==1 && g_editor.cursor==0);
  assert(g_shift_down && !g_ctrl_down);
}
''')


@pytest.mark.parametrize(("key", "left_flags", "right_flags", "shortcut"), [
    (17, 0x1D, 0x11D, 67), (16, 0x2A, 0x36, 37),
])
def test_generic_modifier_events_use_mql_scan_and_extended_flags(tmp_path, key, left_flags, right_flags, shortcut):
    compile_and_run(tmp_path, keyboard_source() + f'''
int main(){{
  if({key}==16){{g_editor.has_selection=false;g_editor.cursor=3;g_editor.anchor=3;}}
  PressKey({key},{left_flags});PressKey({key},{right_flags});ReleaseKey({key},{left_flags});
  PS_HandleKeyDown({shortcut});
  if({key}==17)assert(g_ctrl_down && windows_ctrl==-32768 && clipboard_calls==1);
  else assert(g_shift_down && windows_shift==-32768 && g_editor.has_selection && g_editor.cursor==2);
  ReleaseKey({key},{right_flags});assert(!g_ctrl_down && !g_shift_down);
}}
''')


@pytest.mark.parametrize(("left", "right", "mask", "shortcut"), [(162, 163, 8, 67), (160, 161, 4, 37)])
def test_held_mouse_snapshot_preserves_delivered_modifier_sides(tmp_path, left, right, mask, shortcut):
    compile_and_run(tmp_path, keyboard_source() + f'''
int main(){{
  if({left}==160){{g_editor.has_selection=false;g_editor.cursor=3;g_editor.anchor=3;}}
  PressKey({left});PressKey({right});PS_ObserveMouseModifiers({mask});ReleaseKey({left});
  PS_HandleKeyDown({shortcut});
  if({left}==162)assert(g_ctrl_down && windows_ctrl==-32768 && clipboard_calls==1);
  else assert(g_shift_down && windows_shift==-32768 && g_editor.has_selection && g_editor.cursor==2);
  ReleaseKey({right});assert(!g_ctrl_down && !g_shift_down);
  PS_ObserveMouseModifiers(0);assert(g_ctrl_pressed_keys==0 && g_shift_pressed_keys==0);
}}
''')


@pytest.mark.parametrize("control", [17, 162, 163])
def test_ctrl_release_restores_plain_typing_after_shortcut(tmp_path, control):
    compile_and_run(tmp_path, keyboard_source() + f'''
int main(){{
  PressKey({control});PressKey(65);PressKey(67);
  assert(clipboard_calls==1 && clipboard_text=="1.12345");
  ReleaseKey({control});assert(!g_ctrl_down);
  PressKey(50);
  assert(g_editor.raw_text=="2" && recalculations==1 && clipboard_calls==1);
}}
''')


def test_unknown_modifier_seed_does_not_reuse_old_logical_flag(tmp_path):
    compile_and_run(tmp_path, keyboard_source() + r'''
int main(){
  native_ctrl=0;g_ctrl_down=true;
  PressKey(67);
  assert(clipboard_calls==0 && !g_ctrl_down && clipboard_text=="unchanged");
}
''')


@pytest.mark.parametrize(("cursor", "anchor", "selected", "paste", "expected"), [
    (7, 0, True, "65032.05", "65032.05"),
    (2, 5, True, "9", "1.945"),
    (2, 2, False, "9", "1.912345"),
    (7, 0, True, " 1,25\r\n", "1,25"),
])
def test_ctrl_v_replaces_selection_or_inserts_at_cursor(tmp_path, cursor, anchor, selected, paste, expected):
    import json
    compile_and_run(tmp_path, keyboard_source() + f'''
int main(){{
  g_editor.cursor={cursor};g_editor.anchor={anchor};g_editor.has_selection={str(selected).lower()};
  clipboard_text={json.dumps(paste)};
  PressKey(17);PressKey(86);
  assert(g_editor.raw_text=="{expected}" && clipboard_reads==1 && recalculations==1);
  assert(!g_editor.has_selection && g_editor.active);
}}
''')


@pytest.mark.parametrize("paste", ["1.2.3", "abc", "£100", "1 2", "9" * 33, "1,234.56"])
def test_invalid_paste_is_atomic_and_does_not_recalculate(tmp_path, paste):
    import json
    compile_and_run(tmp_path, keyboard_source() + f'''
int main(){{
  clipboard_text={json.dumps(paste)};PressKey(17);PressKey(86);
  assert(g_editor.raw_text=="1.12345" && g_editor.cursor==7 && g_editor.anchor==0 && g_editor.has_selection);
  assert(clipboard_reads==1 && recalculations==0 && status_error);
}}
''')


def test_cut_only_deletes_after_successful_copy(tmp_path):
    compile_and_run(tmp_path, keyboard_source() + r'''
int main(){
  PressKey(17);clipboard_ok=false;PressKey(88);
  assert(g_editor.raw_text=="1.12345" && g_editor.has_selection && recalculations==0);
  clipboard_ok=true;PressKey(88);
  assert(clipboard_text=="1.12345" && g_editor.raw_text.empty() && !g_editor.has_selection);
  assert(recalculations==1);
}
''')


def test_numeric_edit_undo_redo_restores_selection_and_rejects_old_redo(tmp_path):
    compile_and_run(tmp_path, keyboard_source() + r'''
int main(){
  PressKey(50);assert(g_editor.raw_text=="2");
  PressKey(17);PressKey(90);
  assert(g_editor.raw_text=="1.12345" && g_editor.has_selection && g_editor.anchor==0);
  PressKey(89);assert(g_editor.raw_text=="2");
  PressKey(90);ReleaseKey(17);PressKey(51);
  assert(g_editor.raw_text=="3");PressKey(17);PressKey(89);
  assert(g_editor.raw_text=="3");
}
''')


def test_ctrl_navigation_shift_selection_and_whole_number_deletion(tmp_path):
    compile_and_run(tmp_path, keyboard_source() + r'''
int main(){
  g_editor.has_selection=false;g_editor.anchor=g_editor.cursor;
  PressKey(17);PressKey(37);assert(g_editor.cursor==0);
  PressKey(16);PressKey(39);
  assert(g_editor.cursor==7 && g_editor.anchor==0 && g_editor.has_selection);
  ReleaseKey(16);PressKey(8);assert(g_editor.raw_text.empty());
}
''')


def test_noop_edit_keys_do_not_reapply_model_or_recalculate(tmp_path):
    compile_and_run(tmp_path, keyboard_source() + r'''
int main(){
  g_editor.has_selection=false;g_editor.cursor=0;g_editor.anchor=0;
  PressKey(8);assert(recalculations==0);
  g_editor.cursor=7;g_editor.anchor=7;PressKey(46);assert(recalculations==0);
  PressKey(17);PressKey(49);assert(g_editor.raw_text=="1.12345" && recalculations==0);
}
''')


def test_modifier_events_do_not_repaint_or_recalculate_before_shortcut(tmp_path):
    compile_and_run(tmp_path, keyboard_source() + r'''
int main(){
  for(int key:{16,160,161,17,162,163}){PressKey(key);ReleaseKey(key);}
  assert(keyboard_renders==0 && recalculations==0 && !g_ui.dirty);
  assert(g_editor.raw_text=="1.12345" && g_editor.has_selection);
}
''')


def test_editor_redraw_is_deferred_to_existing_frame_timer(tmp_path):
    compile_and_run(tmp_path, keyboard_source() + r'''
int main(){
  PressKey(50);
  assert(g_editor.raw_text=="2" && recalculations==1 && g_ui.dirty);
  assert(keyboard_renders==0);
  PressKey(17);PressKey(65);PressKey(67);
  assert(clipboard_calls==1 && clipboard_text=="2" && g_editor.has_selection);
  assert(keyboard_renders==0 && g_ui.dirty);
}
''')


def test_manual_account_field_is_in_keyboard_focus_order(tmp_path):
    # Keep geometry/editability at the platform boundary; execute the actual
    # traversal rather than asserting that the source names the account field.
    source = keyboard_source().replace("void PS_KeyboardFocusNext(bool){}", r'''
bool PS_UIControlIsEditable(PSControlId c,const PSModel&){return c==PS_CTRL_ACCOUNT_FIELD || c==PS_CTRL_RISK_PERCENT_FIELD;}
PSFieldId PS_UIFieldForControl(PSControlId c){return c==PS_CTRL_ACCOUNT_FIELD?PS_FIELD_ACCOUNT:c==PS_CTRL_RISK_PERCENT_FIELD?PS_FIELD_RISK_PERCENT:PS_FIELD_NONE;}
void PS_EditorBegin(PSEditorState &e,PSFieldId f,const PSModel&,const PSMarketSnapshot&){e.active=true;e.field=f;}
void PS_KeyboardFocusNext(bool);
''') + "\n" + extract_function(EA, "PS_KeyboardFocusNext") + r'''
int main(){
  g_editor.active=false;g_keyboard_focus=PS_CTRL_TAKE_FIELD;
  g_ps_control_visible[PS_CTRL_ACCOUNT_FIELD]=true;
  g_ps_control_visible[PS_CTRL_RISK_PERCENT_FIELD]=true;
  PS_KeyboardFocusNext(false);
  assert(g_keyboard_focus==PS_CTRL_ACCOUNT_FIELD && g_editor.field==PS_FIELD_ACCOUNT);
  PS_KeyboardFocusNext(false);assert(g_keyboard_focus==PS_CTRL_RISK_PERCENT_FIELD);
  PS_KeyboardFocusNext(true);assert(g_keyboard_focus==PS_CTRL_ACCOUNT_FIELD);
  g_editor.active=false;g_keyboard_focus=PS_CTRL_NONE;
  g_ps_control_visible[PS_CTRL_TRADE]=true;
  PS_KeyboardFocusNext(true);assert(g_keyboard_focus==PS_CTRL_TRADE);
}
'''
    compile_and_run(tmp_path, source)


def test_selection_navigation_delete_and_numeric_keypad_matrix(tmp_path):
    compile_and_run(tmp_path, keyboard_source() + r'''
void reset(const string &text,int cursor,int anchor){
  g_editor=PSEditorState{};g_editor.raw_text=text;g_editor.cursor=cursor;g_editor.anchor=anchor;
  g_editor.has_selection=cursor!=anchor;native_ctrl=0;windows_ctrl=0;native_shift=0;windows_shift=0;
  PS_ResetKeyboardModifiers();
}
int main(){
  reset("123.45",5,2);PressKey(37);assert(g_editor.cursor==2 && !g_editor.has_selection);
  reset("123.45",2,5);PressKey(39);assert(g_editor.cursor==5 && !g_editor.has_selection);
  reset("123.45",3,3);native_shift=0x8000;windows_shift=-32768;
  PressKey(36);assert(g_editor.cursor==0 && g_editor.anchor==3 && g_editor.has_selection);
  PressKey(35);assert(g_editor.cursor==6 && g_editor.anchor==3);
  ReleaseKey(16);PressKey(38);assert(g_editor.cursor==0 && !g_editor.has_selection);
  PressKey(40);assert(g_editor.cursor==6);
  reset("123.45",3,3);PressKey(8);assert(g_editor.raw_text=="12.45");
  reset("123.45",3,3);PressKey(46);assert(g_editor.raw_text=="12345");
  reset("123.45",3,3);native_ctrl=0x8000;windows_ctrl=-32768;PressKey(8);assert(g_editor.raw_text==".45");
  reset("123.45",3,3);native_ctrl=0x8000;windows_ctrl=-32768;PressKey(46);assert(g_editor.raw_text=="123");
  reset("123.45",2,5);PressKey(46);assert(g_editor.raw_text=="125");
  reset("123.45",6,0);PressKey(98);PressKey(110);PressKey(101);
  assert(g_editor.raw_text=="2.5");
  reset("123.45",6,0);PressKey(109);PressKey(100);assert(g_editor.raw_text=="-4");
  reset("123.45",6,0);PressKey(107);PressKey(99);PressKey(188);PressKey(102);
  assert(g_editor.raw_text=="+3,6");
}
''')


def test_clipboard_aliases_cut_without_selection_and_shift_ctrl_redo(tmp_path):
    compile_and_run(tmp_path, keyboard_source() + r'''
int main(){
  PressKey(17);PressKey(45);assert(clipboard_text=="1.12345");
  ReleaseKey(17);PressKey(16);PressKey(46);
  assert(clipboard_text=="1.12345" && g_editor.raw_text.empty());
  ReleaseKey(16);PressKey(17);PressKey(90);assert(g_editor.raw_text=="1.12345");
  PressKey(16);PressKey(90);assert(g_editor.raw_text.empty());
  ReleaseKey(17);clipboard_text="2,5";PressKey(45);
  assert(g_editor.raw_text=="2,5");
  ReleaseKey(16);PressKey(17);int calls=clipboard_calls;PressKey(88);
  assert(g_editor.raw_text=="2,5" && clipboard_calls==calls);
}
''')


def test_bounded_history_keeps_latest_31_changes_and_redoes_after_navigation(tmp_path):
    compile_and_run(tmp_path, keyboard_source() + r'''
int main(){
  native_ctrl=0x8000;windows_ctrl=-32768;
  for(int i=0;i<40;i++){
    PressKey(65);clipboard_text=DoubleToString(i,0);PressKey(86);
    assert(g_editor.history_count<=32 && g_editor.history_index<32);
  }
  for(int i=0;i<40;i++)PressKey(90);
  assert(g_editor.raw_text=="8");PressKey(35);
  for(int i=0;i<40;i++)PressKey(89);
  assert(g_editor.raw_text=="39" && g_editor.cursor==2);
}
''')


def test_paste_undo_redo_updates_real_valid_stop_preview(tmp_path):
    source = keyboard_source().replace(
        "bool PS_EditorApplyRaw(PSEditorState&,PSModel&,PSMarketSnapshot&,bool,string&){return true;}",
        "bool PS_EditorApplyRaw(PSEditorState&,PSModel&,const PSMarketSnapshot&,bool,string&);",
    ) + "\n" + extract_function(EDITOR, "PS_EditorApplyRaw") + r'''
int main(){
  native_ctrl=0x8000;windows_ctrl=-32768;clipboard_text="1.22345";PressKey(86);
  assert(std::abs(g_model.stop_loss-1.22345)<1e-12);
  PressKey(90);assert(std::abs(g_model.stop_loss-1.12345)<1e-12);
  PressKey(89);assert(std::abs(g_model.stop_loss-1.22345)<1e-12);
  assert(g_model.entry==1.23456 && g_model.requested_risk_percent==1);
}
'''
    compile_and_run(tmp_path, source)


@pytest.mark.parametrize(("field", "member", "initial", "authority"), [
    ("PS_FIELD_ENTRY", "entry", "1.23456", "PS_RISK_PERCENT"),
    ("PS_FIELD_STOP", "stop_loss", "1.12345", "PS_RISK_PERCENT"),
    ("PS_FIELD_TAKE", "take_profit", "1.34567", "PS_RISK_PERCENT"),
    ("PS_FIELD_COMMISSION", "commission_per_lot", "0", "PS_RISK_PERCENT"),
    ("PS_FIELD_ACCOUNT", "manual_account_money", "1000", "PS_RISK_PERCENT"),
    ("PS_FIELD_RISK_PERCENT", "requested_risk_percent", "1", "PS_RISK_MONEY"),
    ("PS_FIELD_RISK_MONEY", "requested_risk_money", "10", "PS_RISK_PERCENT"),
])
def test_undo_incomplete_text_restores_its_prior_model_preview(tmp_path, field, member, initial, authority):
    # Text-only undo would leave the later valid value in the calculation.
    source = keyboard_source().replace(
        "bool PS_EditorApplyRaw(PSEditorState&,PSModel&,PSMarketSnapshot&,bool,string&){return true;}",
        "bool PS_EditorApplyRaw(PSEditorState&,PSModel&,const PSMarketSnapshot&,bool,string&);",
    ) + "\n" + extract_function(EDITOR, "PS_EditorApplyRaw") + f'''
int main(){{
  g_editor.field={field};g_model.risk_authority={authority};
  g_editor.raw_text="{initial}";g_editor.cursor=StringLen(g_editor.raw_text);g_editor.anchor=0;
  PressKey(46);assert(g_editor.raw_text.empty());
  PressKey(17);clipboard_text="2";PressKey(86);
  assert(g_model.{member}==2);
  g_model.direction=PS_DIRECTION_SHORT;g_model.order_mode=PS_ORDER_INSTANT;
  PressKey(90);
  assert(g_editor.raw_text.empty() && std::abs(g_model.{member}-{initial})<1e-12);
  assert(g_model.risk_authority=={authority});
  assert(g_model.direction==PS_DIRECTION_SHORT && g_model.order_mode==PS_ORDER_INSTANT);
  PressKey(89);assert(g_editor.raw_text=="2" && g_model.{member}==2);
}}
'''
    compile_and_run(tmp_path, source)


def test_failed_clipboard_read_preserves_selection_without_logging_value(tmp_path):
    compile_and_run(tmp_path, keyboard_source() + r'''
int main(){
  clipboard_read_ok=false;clipboard_text="998877.66";native_ctrl=0x8000;windows_ctrl=-32768;PressKey(86);
  assert(g_editor.raw_text=="1.12345" && g_editor.cursor==7 && g_editor.anchor==0 && g_editor.has_selection);
  assert(recalculations==0 && status_error && warning_calls==1 && clipboard_reads==1);
  assert(last_warning=="Windows clipboard is currently unavailable.");
}
''')


def test_enter_escape_and_new_field_clear_history_with_real_commit_cancel(tmp_path):
    source = keyboard_source().replace(
        "bool PS_EditorApplyRaw(PSEditorState&,PSModel&,PSMarketSnapshot&,bool,string&){return true;}",
        "bool PS_EditorApplyRaw(PSEditorState&,PSModel&,const PSMarketSnapshot&,bool,string&);",
    ).replace("void PS_CancelEditor(){}", "void PS_CancelEditor();").replace(
        "bool PS_CommitEditor(){return true;}", "bool PS_CommitEditor();",
    ) + extract_functions(EDITOR,
        "PS_EditorReset", "PS_EditorModelText", "PS_EditorBegin", "PS_EditorApplyRaw",
        "PS_EditorNormalizedText", "PS_EditorCommit", "PS_EditorCancel",
    ) + r'''
void PS_CancelEditor(){PS_EditorCancel(g_editor,g_model);}
bool PS_CommitEditor(){string error;return PS_EditorCommit(g_editor,g_model,g_market,error);}
int main(){
  PS_EditorBegin(g_editor,PS_FIELD_STOP,g_model,g_market);PS_EditorSelectAll(g_editor);
  PressKey(50);assert(g_model.stop_loss==2 && g_editor.history_count==2);
  PressKey(27);
  assert(!g_editor.active && g_editor.history_count==0 && std::abs(g_model.stop_loss-1.12345)<1e-12);
  PS_EditorBegin(g_editor,PS_FIELD_STOP,g_model,g_market);PS_EditorSelectAll(g_editor);
  PressKey(50);PressKey(13);
  assert(!g_editor.active && g_editor.history_count==0 && g_model.stop_loss==2);
  PS_EditorBegin(g_editor,PS_FIELD_STOP,g_model,g_market);PS_EditorSelectAll(g_editor);
  PressKey(51);assert(g_editor.history_count==2);
  PS_EditorBegin(g_editor,PS_FIELD_RISK_PERCENT,g_model,g_market);
  native_ctrl=0x8000;windows_ctrl=-32768;PressKey(90);
  assert(g_editor.raw_text=="1.0000" && g_editor.history_count==0);
}
'''
    compile_and_run(tmp_path, source)


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
