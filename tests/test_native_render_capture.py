"""Controller recovery with an already captured pointer and a failed canvas.

Execute production controller bodies. Chart, canvas and broker boundaries use
offline doubles. This does not prove MT5's event queue or native guard behavior.
"""

import pytest

from native_mql_harness import compile_and_run, extract_function


EA = "MQL5/Experts/LotCraft/LotCraft.mq5"
UI = "MQL5/Experts/LotCraft/PS_UI.mqh"


@pytest.fixture(scope="module")
def render_capture_rows(tmp_path_factory):
    source = r'''
#include <algorithm>
#include <cmath>
#include <iostream>
#include <string>
using string=std::string;using ulong=unsigned long long;using datetime=long long;
enum PSControlId {PS_CTRL_NONE=-1,PS_CTRL_TEST,PS_CTRL_COUNT};
enum PSCaptureMode {PS_CAPTURE_NONE,PS_CAPTURE_PANEL,PS_CAPTURE_HANDLE_ENTRY,
 PS_CAPTURE_HANDLE_STOP,PS_CAPTURE_HANDLE_TAKE,PS_CAPTURE_STEPPER,PS_CAPTURE_CONTROL};
enum PSExposureHit {PS_EXPOSURE_HIT_NONE,PS_EXPOSURE_HIT_ROW};
enum {PS_FIELD_NONE,PS_ORDER_INSTANT,PS_ORDER_PENDING,PS_PANEL_DRAG_THRESHOLD_PX=4,
 PS_HANDLE_DRAG_THRESHOLD_PX=4,CHART_MOUSE_SCROLL,CHART_CONTEXT_MENU,CHART_CROSSHAIR_TOOL,
 CHART_DRAG_TRADE_LEVELS,CHART_KEYBOARD_CONTROL,CHART_QUICK_NAVIGATION};
struct PSRect {int x=0,y=0,w=100,h=100;};
struct UIState {bool created=true,dirty=true,line_dirty=true,guard_saved=true;
 bool saved_mouse_scroll=true,saved_context_menu=false,saved_crosshair=true,
 saved_drag_trade_levels=false,saved_keyboard_control=true,saved_quick_navigation=false;} g_ui;
struct Pointer {PSCaptureMode capture=PS_CAPTURE_NONE;PSControlId control=PS_CTRL_TEST;
 bool drag_started=true,editor_double_click=false,native_pointer_calibrated=true,
 stepper_active=true,stepper_pointer_inside=true;
 int start_x=0,start_y=0,last_x=0,last_y=0,applied_x=0,applied_y=0,
 native_offset_x=0,native_offset_y=0,panel_offset_x=0,panel_offset_y=0;
 ulong press_ms=0,last_repeat_ms=0;} g_pointer;
struct {bool active=true;string raw_text="1";int field=PS_FIELD_NONE;} g_editor;
struct {int order_mode=PS_ORDER_PENDING,view_mode=0,revision=0;
 double entry=100,stop_loss=90,take_profit=0;} g_model;
struct {double tick_size=1;} g_market;
struct {bool details_open=true;PSRect sidecar_rect;} g_exposure_ui;
int g_calc=0,g_exposure=0,g_copy_feedback_control=0;
bool g_initialized=true,g_symbol_transition_pending=false,g_ps_panel_render_ready=true,
 g_pointer_motion_pending=true,g_panel_dirty=false,g_exposure_details_dirty=true,
 g_exposure_labels_dirty=true,g_ps_exposure_labels_layout_dirty=false,g_shift_down=true,g_ctrl_down=true;
int g_pointer_motion_x=0,g_pointer_motion_y=0;
PSControlId g_keyboard_focus=PS_CTRL_TEST,g_pressed_control=PS_CTRL_TEST,g_hovered_control=PS_CTRL_TEST;
PSExposureHit g_exposure_pressed_hit=PS_EXPOSURE_HIT_ROW;
int g_exposure_pressed_row=0;
PSRect g_ps_control_rects[PS_CTRL_COUNT];
ulong g_control_last_action[PS_CTRL_COUNT]={},now=2000,g_panel_retry_after_ms=0,g_ps_exposure_retry_after_ms=0;
bool paint_ok=false,flip_direction=false,details_ok=true;
int paint_attempts=0,line_paints=0,saves=0,steps=0,actions=0,redraws=0,guard_entries=0,details_attempts=0;
bool restored_flags[6]={};
const int PS_RENDER_BUDGET_US=1000;
ulong GetTickCount64(){return now;}
int ChartID(){return 1;}
void ChartRedraw(int){++redraws;}
int MathAbs(int value){return std::abs(value);}
double MathAbs(double value){return std::abs(value);}
int MathMax(int a,int b){return std::max(a,b);}
double MathMax(double a,double b){return std::max(a,b);}
void PS_EditorReset(decltype(g_editor)& editor){editor.active=false;}
bool PS_UISetChartFlag(int property,bool value,const string&){
 restored_flags[property-CHART_MOUSE_SCROLL]=value;return true;
}
void PS_UIGuardEnter(UIState& ui){++guard_entries;ui.guard_saved=true;}
bool PS_UIInPanel(const UIState&,int,int){return true;}
int PS_UIHitHandle(int,int,bool& hit){hit=true;return 0;}
bool PS_RectContains(const PSRect& r,int x,int y){return x>=r.x&&y>=r.y&&x<r.x+r.w&&y<r.y+r.h;}
bool PS_UIRenderPanel(UIState& ui,decltype(g_model)&,int,decltype(g_market)&,int,decltype(g_editor)&,int){
 ++paint_attempts;g_ps_panel_render_ready=paint_ok;ui.dirty=!paint_ok;return paint_ok;
}
bool PS_UIRenderExposureDetails(UIState&,decltype(g_model)&,int,decltype(g_market)&){
 ++details_attempts;g_ps_exposure_retry_after_ms=details_ok ? 0 : now+1000;return details_ok;
}
void PS_UIRenderExposureLabels(UIState&,decltype(g_model)&,int,decltype(g_market)&){}
void PS_UIRenderLinesOnly(UIState& ui,decltype(g_model)&,decltype(g_market)&){++line_paints;ui.line_dirty=false;}
void PS_UIRender(UIState& ui,decltype(g_model)& model,int calc,decltype(g_market)& market,int exposure,decltype(g_editor)& editor,int feedback){
 PS_UIRenderPanel(ui,model,calc,market,exposure,editor,feedback);
}
bool ChartXYToTimePrice(int,int,int y,int& window,datetime& time,double& price){window=0;time=1;price=y;return true;}
double PS_NormalizePrice(double value,decltype(g_market)&){return value;}
bool PS_IsPositiveFinite(double value){return std::isfinite(value)&&value>0;}
bool PS_ModelChangeOrderMode(decltype(g_model)& model,decltype(g_market)&,int mode,string&){model.order_mode=mode;return true;}
bool PS_ModelAlignDirectionToStop(decltype(g_model)&,decltype(g_market)&){return flip_direction;}
void PS_SetStatus(const string&,bool,int){}
void PS_Recalculate(bool){g_ui.dirty=true;g_ui.line_dirty=true;}
void PS_ClearTransientStatus(){}
void PS_SaveState(){++saves;}
void PS_UISetPanelPosition(UIState&,int,int,int){}
bool PS_UIBeginPanelDrag(UIState&,int){return true;}
void PS_UIPreparePanelDrop(UIState&){}
void PS_UIEndPanelDrag(UIState&){}
int PS_UIFieldForControl(PSControlId){return PS_FIELD_NONE;}
int PS_UIEditorCursorIndex(UIState&,PSControlId,const string&,int){return 0;}
void PS_EditorSetCursorIndex(decltype(g_editor)&,int,bool){}
bool PS_PointerAction(PSControlId,int,int){++actions;return true;}
PSExposureHit PS_UIExposureHitTest(int,int,int&){return PS_EXPOSURE_HIT_ROW;}
void PS_ExposureAction(PSExposureHit,int){++actions;}
void PS_UIApplyLineLock(UIState&,const string&){}
ulong PS_StepperRepeatInterval(ulong){return 15;}
int PS_StepperTickMultiplier(ulong){return 1;}
void PS_StepPrice(PSControlId,int){++steps;g_model.stop_loss+=1;}
void PS_MouseMoveCaptured(int,int);
void PS_UpdateInteractionGuard(int,int);
void PS_RenderIfDirty();
'''
    source += extract_function(UI, "PS_UIGuardExit").replace("PSUIState", "UIState")
    source += extract_function(EA, "PS_AbortInteractionForContextChange")
    try:
        source += extract_function(EA, "PS_AbortInteractionForRenderFailure")
    except ValueError:
        pass
    for name in (
        "PS_RenderIfDirty", "PS_UpdateLevelFromPointer", "PS_UpdateInteractionGuard",
        "PS_IsMotionCapture", "PS_ResetCapture", "PS_MouseMoveCaptured",
        "PS_MouseRelease", "PS_TimerStepper",
    ):
        source += extract_function(EA, name)
    source += r'''
void reset(PSCaptureMode capture){
 g_ui={};g_pointer={};g_pointer.capture=capture;g_model.stop_loss=90;
 g_editor.active=true;g_ps_panel_render_ready=true;g_panel_dirty=false;
 g_panel_retry_after_ms=0;g_ps_exposure_retry_after_ms=0;now=2000;paint_ok=false;flip_direction=false;details_ok=true;
 details_attempts=0;
 paint_attempts=line_paints=saves=steps=actions=redraws=guard_entries=0;
 for(auto& flag:restored_flags)flag=false;
}
void report(){
 std::cout<<g_pointer.capture<<' '<<g_model.stop_loss<<' '<<saves<<' '<<steps<<' '
 <<line_paints<<' '<<paint_attempts<<' '<<g_ui.guard_saved<<' '
 <<restored_flags[0]<<restored_flags[1]<<restored_flags[2]<<restored_flags[3]<<restored_flags[4]<<restored_flags[5]<<'\n';
}
int main(){
 // A held stepper causes a regular panel paint to fail. Its next timer/release
 // must not change or save the unseen plan. Chart flags must be restored.
 reset(PS_CAPTURE_STEPPER);PS_RenderIfDirty();
 PS_TimerStepper();PS_MouseRelease(20,200);PS_UpdateInteractionGuard(20,200);report();
 // A stop crossing Entry invokes the direct render path while dragging.
 reset(PS_CAPTURE_HANDLE_STOP);flip_direction=true;
 PS_MouseMoveCaptured(20,110);double failed_at=g_model.stop_loss;
 PS_MouseMoveCaptured(20,150);PS_MouseRelease(20,170);
 PS_UpdateInteractionGuard(20,170);report();
 std::cout<<failed_at<<'\n';
 // Retain failure work without repaints before the fixed retry deadline.
 for(int i=1;i<1000;i+=8){now=2000+i;PS_RenderIfDirty();}
 std::cout<<paint_attempts<<' '<<line_paints<<' '<<g_panel_dirty<<'\n';
 now=3000;paint_ok=true;PS_RenderIfDirty();
 std::cout<<paint_attempts<<' '<<g_panel_dirty<<' '<<g_ps_panel_render_ready<<'\n';
 // A normal painted drag still applies its final coordinate and persists once.
 reset(PS_CAPTURE_HANDLE_STOP);paint_ok=true;
 PS_MouseMoveCaptured(20,80);PS_MouseRelease(20,70);report();
 // A failing sidecar must remain pending without blocking normal lines/panel.
 reset(PS_CAPTURE_NONE);paint_ok=true;details_ok=false;g_exposure_details_dirty=true;
 PS_RenderIfDirty();std::cout<<g_exposure_details_dirty<<' '<<line_paints<<' '<<g_ps_panel_render_ready<<'\n';
 for(int i=1;i<1000;i+=8){now=2000+i;PS_RenderIfDirty();}
 std::cout<<details_attempts<<' '<<redraws<<'\n';
 now=3000;details_ok=true;PS_RenderIfDirty();
 std::cout<<details_attempts<<' '<<g_exposure_details_dirty<<' '<<redraws<<'\n';
}
'''
    return compile_and_run(tmp_path_factory.mktemp("render_capture"), source).splitlines()


def test_failed_stepper_paint_cancels_hidden_repeat_and_restores_chart_guard(render_capture_rows):
    assert render_capture_rows[0] == "0 90 0 0 0 1 0 101010"


def test_failed_drag_paint_cancels_mutation_and_release_save(render_capture_rows):
    assert render_capture_rows[1] == "0 110 0 0 0 1 0 101010"
    assert render_capture_rows[2] == "110"


def test_failed_capture_has_bounded_repaint_and_recovers(render_capture_rows):
    assert render_capture_rows[3] == "1 0 1"
    assert render_capture_rows[4] == "2 0 1"


def test_successful_drag_still_persists_final_coordinate(render_capture_rows):
    row = render_capture_rows[5].split()
    assert row[:4] == ["0", "70", "1", "0"]


def test_sidecar_retry_does_not_block_the_panel_or_lines(render_capture_rows):
    assert render_capture_rows[6] == "1 1 1"


def test_sidecar_backoff_does_not_schedule_repeated_chart_redraws(render_capture_rows):
    assert render_capture_rows[7:] == ["1 1", "2 0 2"]
