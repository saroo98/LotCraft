"""Replay the native Ctrl+A chart-change failure through production handlers.

Platform, broker refresh and painting use offline boundaries. The event callback,
shortcut controller, editor and context-abort bodies are production source.
This does not emulate native MT5 delivery or replace owner acceptance.
"""
import pytest

from native_mql_harness import compile_and_run, extract_functions
from test_native_clipboard import keyboard_source

EA = "MQL5/Experts/LotCraft/LotCraft.mq5"
EDITOR = "MQL5/Experts/LotCraft/PS_Editor.mqh"


def chart_keyboard_source():
    source = keyboard_source().replace(
        "struct {bool dirty=false;} g_ui;",
        'struct {bool dirty=false,line_dirty=false;string prefix="fixture.";} g_ui;',
    ).replace("ulong revision=0;", "ulong revision=0;int view_mode=0;").replace(
        "struct {bool details_open=false;} g_exposure_ui;",
        "struct {bool details_open=false;int sidecar_rect=0,scroll_offset=0;} g_exposure_ui;",
    )
    source += r'''
enum {CHARTEVENT_KEYDOWN,CHARTEVENT_KEYUP,CHARTEVENT_MOUSE_MOVE,
      CHARTEVENT_MOUSE_WHEEL,CHARTEVENT_CLICK,CHARTEVENT_CHART_CHANGE,
      CHARTEVENT_OBJECT_DRAG,CHARTEVENT_OBJECT_CHANGE,CHARTEVENT_OBJECT_CLICK};
const int PS_CAPTURE_NONE=0;
struct {
  int capture=PS_CAPTURE_NONE,native_offset_x=0,native_offset_y=0;
  PSControlId control=PS_CTRL_NONE;
  bool native_pointer_calibrated=false,drag_started=false,editor_double_click=false;
  bool stepper_active=false,stepper_pointer_inside=false;
} g_pointer;
bool g_pointer_motion_pending=false;
PSControlId g_pressed_control=PS_CTRL_NONE,g_hovered_control=PS_CTRL_NONE;
ulong g_last_chart_mouse_event_ms=0;
int g_exposure=0,market_refresh_calls=0;
bool market_context_changes=false;
long StringToInteger(const string &s){return s.empty()?0:std::stol(s);}
int StringFind(const string &s,const string &part){auto i=s.find(part);return i==string::npos?-1:int(i);}
bool PS_PlatformPointerPosition(int&,int&){assert(false);return false;}
void PS_HandleMouseEvent(int,int,uint){assert(false);}
bool PS_RectContains(int,int,int){return false;}
int PS_UIExposureFilteredCount(int){assert(false);return 0;}
int PS_UIExposurePageCapacity(){assert(false);return 0;}
void PS_UpdateInteractionGuard(int,int){}
bool PS_UIInPanel(const decltype(g_ui)&,int,int){return true;}
void PS_UIClampPanel(decltype(g_ui)&,int){}
void PS_UIApplyLineLock(decltype(g_ui)&,const string&){assert(false);}
void PS_UIGuardExit(decltype(g_ui)&){}
void PS_AbortInteractionForContextChange();
// Refresh retains its normal non-context-changing boundary. A simulated true
// context change uses the real production abort, not a fake editor reset.
void PS_RefreshMarket(bool clear_status){
  assert(!clear_status);++market_refresh_calls;
  if(market_context_changes)PS_AbortInteractionForContextChange();
}
'''
    source += extract_functions(EDITOR, "PS_EditorReset") + "\n" + extract_functions(
        EA, "PS_AbortInteractionForContextChange", "OnChartEvent",
    ) + r'''
void ChartKeyDown(int key,uint flags){
  if(key==17){native_ctrl=0x8000;windows_ctrl=-32768;}
  OnChartEvent(CHARTEVENT_KEYDOWN,key,1,std::to_string(flags));
}
void ChartKeyUp(int key,uint flags){
  if(key==17){native_ctrl=0;windows_ctrl=0;}
  OnChartEvent(CHARTEVENT_KEYUP,key,1,std::to_string(flags));
}
void ChartLayout(){OnChartEvent(CHARTEVENT_CHART_CHANGE,0,0,"");}
'''
    return source


@pytest.mark.parametrize("ctrl_released_first", [False, True])
def test_chart_layout_preserves_release_only_select_all_gesture(tmp_path, ctrl_released_first):
    # Reintroducing a blanket layout-event reset must break this captured path.
    releases = (
        "ChartKeyUp(17,0xC01D);ChartKeyUp(65,0xC01E);" if ctrl_released_first else
        "ChartKeyUp(65,0xC01E);ChartKeyUp(17,0xC01D);"
    )
    compile_and_run(tmp_path, chart_keyboard_source() + f'''
int main(){{
  g_editor.has_selection=false;g_editor.anchor=g_editor.cursor;
  PS_ObserveMouseModifiers(0);ChartKeyDown(17,0x1D);ChartLayout();{releases}
  assert(g_editor.active && g_editor.has_selection && g_editor.anchor==0 && g_editor.cursor==7);
  assert(g_editor.raw_text=="1.12345" && g_editor.history_count==0 && recalculations==0);
  assert(!g_ctrl_down && market_refresh_calls==1 && keyboard_renders==1 && g_ui.line_dirty);
}}
''')


def test_chart_layout_after_ctrl_release_keeps_pending_select_all(tmp_path):
    compile_and_run(tmp_path, chart_keyboard_source() + r'''
int main(){
  g_editor.has_selection=false;g_editor.anchor=g_editor.cursor;
  PS_ObserveMouseModifiers(0);ChartKeyDown(17,0x1D);ChartKeyUp(17,0xC01D);
  ChartLayout();ChartKeyUp(65,0xC01E);
  assert(g_editor.has_selection && g_editor.anchor==0 && g_editor.cursor==7);
  assert(g_editor.raw_text=="1.12345" && recalculations==0 && !g_ctrl_down);
}
''')


@pytest.mark.parametrize("ctrl_released_first", [False, True])
def test_chart_layout_does_not_dispatch_delivered_paste_twice(tmp_path, ctrl_released_first):
    # Layout must also preserve press deduplication, not just modifier context.
    releases = (
        "ChartKeyUp(17,0xC01D);ChartKeyUp(86,0xC02F);" if ctrl_released_first else
        "ChartKeyUp(86,0xC02F);ChartKeyUp(17,0xC01D);"
    )
    compile_and_run(tmp_path, chart_keyboard_source() + f'''
int main(){{
  clipboard_text="2.5";PS_ObserveMouseModifiers(0);
  ChartKeyDown(17,0x1D);ChartKeyDown(86,0x2F);ChartLayout();{releases}
  assert(g_editor.raw_text=="2.5" && clipboard_reads==1 && recalculations==1);
  assert(g_editor.history_count==2 && !g_ctrl_down);
}}
''')


def test_true_context_change_invalidates_pending_select_all(tmp_path):
    compile_and_run(tmp_path, chart_keyboard_source() + r'''
int main(){
  g_editor.has_selection=false;g_editor.anchor=g_editor.cursor;
  PS_ObserveMouseModifiers(0);ChartKeyDown(17,0x1D);market_context_changes=true;
  ChartLayout();ChartKeyUp(17,0xC01D);ChartKeyUp(65,0xC01E);
  assert(!g_editor.active && !g_editor.has_selection && g_editor.field==PS_FIELD_NONE);
  assert(!g_shortcut_ctrl_context && !g_ctrl_down && recalculations==0);
}
''')


@pytest.mark.parametrize("event", ["CHARTEVENT_CLICK", "CHARTEVENT_MOUSE_WHEEL"])
def test_explicit_pointer_event_invalidates_pending_select_all(tmp_path, event):
    compile_and_run(tmp_path, chart_keyboard_source() + f'''
int main(){{
  g_editor.has_selection=false;g_editor.anchor=g_editor.cursor;
  PS_ObserveMouseModifiers(0);ChartKeyDown(17,0x1D);
  OnChartEvent({event},0,0,"");ChartKeyUp(17,0xC01D);ChartKeyUp(65,0xC01E);
  assert(g_editor.active && !g_editor.has_selection && g_editor.raw_text=="1.12345");
  assert(!g_shortcut_ctrl_context && clipboard_reads==0 && recalculations==0);
}}
''')
