"""Execute production editor/refresh logic with platform-only stubs.

These tests catch stale financial output and lost selection replacement. They
do not emulate MT5's event queue, canvas renderer, broker, or DLL integration.
"""
from native_mql_harness import compile_and_run, extract_functions
from test_native_ui import declaration

EA = "MQL5/Experts/LotCraft/LotCraft.mq5"
EDITOR = "MQL5/Experts/LotCraft/PS_Editor.mqh"
TYPES = "MQL5/Experts/LotCraft/PS_Types.mqh"


def test_selected_text_can_be_replaced_at_input_limit(tmp_path):
    source = r'''
#include <string>
#include <algorithm>
#include <cassert>
using string = std::string;
using std::min;
using std::max;
int StringLen(const string &s) { return int(s.size()); }
string StringSubstr(const string &s, int begin, int length=-1) {
  return s.substr(begin, length < 0 ? string::npos : size_t(length));
}
int MathMin(int a,int b) { return min(a,b); }
int MathMax(int a,int b) { return max(a,b); }
struct PSEditorState { string raw_text; int cursor=0,anchor=0; bool has_selection=false; };
'''
    source += extract_functions(
        EDITOR, "PS_EditorSelectionStart", "PS_EditorSelectionEnd",
        "PS_EditorDeleteSelection", "PS_EditorInsert",
    )
    source += r'''
int main() {
  PSEditorState e;
  e.raw_text=string(32,'9'); e.anchor=0; e.cursor=32; e.has_selection=true;
  PS_EditorInsert(e,"2");
  assert(e.raw_text=="2" && e.cursor==1 && !e.has_selection);
  e.raw_text=string(32,'9'); e.cursor=32; e.anchor=31; e.has_selection=true;
  PS_EditorInsert(e,"7");
  assert(e.raw_text==string(31,'9')+"7");
  PS_EditorInsert(e,"8");
  assert(e.raw_text.size()==32 && e.raw_text.back()=='7');
  e.anchor=30; e.has_selection=true;
  PS_EditorInsert(e,"123");
  assert(e.raw_text==string(31,'9')+"7" && e.has_selection);
}
'''
    compile_and_run(tmp_path, source)


def test_failed_exposure_refresh_invalidates_display_and_bounds_retry(tmp_path):
    source = r'''
#include <string>
#include <cassert>
using string=std::string;
using ulong=unsigned long long;
struct PSExposureSnapshot { bool enumeration_valid=false; double money=0; };
struct Market { int currency_digits=2; } g_market;
struct UI { bool dirty=false,line_dirty=false; } g_ui;
PSExposureSnapshot g_exposure{true,123.45};
bool g_initialized=true,g_symbol_transition_pending=false,g_exposure_dirty=true;
bool g_exposure_details_dirty=false,g_exposure_labels_dirty=false;
ulong g_last_exposure_refresh_ms=0,g_exposure_retry_after_ms=0,clock_ms=2000;
int calculate_calls=0; bool broker_ok=false,copy_ok=true;
string _Symbol="TEST"; const int ACCOUNT_EQUITY=1;
ulong GetTickCount64() {return clock_ms;}
double AccountInfoDouble(int) {return 1000;}
void PS_ExposureReset(PSExposureSnapshot &s) {s={};}
bool PS_ExposureCalculate(PSExposureSnapshot &s,const string&,double,string &error) {
  ++calculate_calls; s={true,55}; error="selection failed"; return broker_ok;
}
bool PS_ExposureMeaningfullyChanged(const PSExposureSnapshot &a,const PSExposureSnapshot &b,int) {
  return a.money!=b.money || a.enumeration_valid!=b.enumeration_valid;
}
bool PS_CopyExposureSnapshot(PSExposureSnapshot &a,const PSExposureSnapshot &b) {
  if(!copy_ok) {a={};return false;} a=b;return true;
}
void PS_LogWarningRateLimited(const string&,const string&,int) {}
'''
    source += extract_functions(EA, "PS_RefreshExposure")
    source += r'''
int main() {
  PS_RefreshExposure();
  assert(calculate_calls==1);
  assert(!g_exposure.enumeration_valid && g_exposure.money==0);
  assert(g_ui.dirty && g_exposure_details_dirty && g_exposure_labels_dirty);
  for(int i=1;i<1000;i+=8) {clock_ms=2000+i; PS_RefreshExposure();}
  assert(calculate_calls==1);
  clock_ms=3000;broker_ok=true;PS_RefreshExposure();
  assert(calculate_calls==2 && g_exposure.enumeration_valid && g_exposure.money==55);
  assert(!g_exposure_dirty);
  clock_ms=4000;g_exposure_dirty=true;copy_ok=false;PS_RefreshExposure();
  assert(!g_exposure.enumeration_valid && g_exposure_dirty);
}
'''
    compile_and_run(tmp_path, source)


def test_waiting_panel_cannot_activate_stale_keyboard_focus(tmp_path):
    source = r'''
#include <string>
#include <cassert>
using string=std::string;
''' + declaration(EDITOR, "PSEditKeyResult") + r'''
const int PS_CTRL_NONE=-1,PS_CTRL_COUNT=40;
bool g_initialized=true,g_symbol_transition_pending=true;
bool g_ps_panel_render_ready=true;
bool g_shift_down=false,g_ctrl_down=false,g_panel_dirty=false;
bool g_exposure_details_dirty=false,g_exposure_labels_dirty=false;
bool g_ps_control_visible[PS_CTRL_COUNT]={};
int g_keyboard_focus=1,actions=0,tabs=0;
struct UI {bool dirty=false;} g_ui;
struct PSEditorState {bool active=false,has_selection=false;string raw_text;int cursor=0,anchor=0;} g_editor;
struct ExposureUI {bool details_open=false;} g_exposure_ui;
int g_model=0,g_market=0;
void PS_KeyboardFocusNext(bool) {++tabs;}
void PS_CancelEditor() {}
void PS_SaveState() {}
void PS_RenderIfDirty() {}
void PS_Action(int) {++actions;}
void PS_UIGuardEnter(UI&) {}
PSEditKeyResult PS_EditorKey(PSEditorState&,int,bool,bool) {return PS_EDIT_KEY_NONE;}
void PS_EditorApplyRaw(PSEditorState&,int&,int,bool,string&) {}
void PS_ClearTransientStatus() {}
void PS_Recalculate(bool) {}
bool PS_CommitEditor() {return true;}
int MathMin(int a,int b){return a<b?a:b;}int MathMax(int a,int b){return a>b?a:b;}
string StringSubstr(const string &s,int p,int n){return s.substr(p,n);}
int copies=0;bool PS_CopyText(const string&,const string&){++copies;return true;}
'''
    source += extract_functions(EDITOR, "PS_EditorSelectionStart", "PS_EditorSelectionEnd")
    source += extract_functions(EA, "PS_HandleKeyDown")
    source += r'''
int main() {
  g_ps_control_visible[1]=true;
  PS_HandleKeyDown(13); PS_HandleKeyDown(9);
  assert(actions==0 && tabs==0);
  g_editor.active=true;g_editor.has_selection=true;g_editor.raw_text="1.12345";g_editor.cursor=7;
  PS_HandleKeyDown(17);PS_HandleKeyDown(67);assert(copies==0);
  g_editor.active=false;
  g_symbol_transition_pending=false;
  PS_HandleKeyDown(13); assert(actions==1);
  g_ps_control_visible[1]=false;
  PS_HandleKeyDown(13); assert(actions==1);
  g_initialized=false;g_ps_control_visible[1]=true;
  PS_HandleKeyDown(13);assert(actions==1);
}
'''
    compile_and_run(tmp_path, source)


def test_return_to_original_symbol_cancels_failed_transition(tmp_path):
    source = r'''
#include <string>
#include <cassert>
using string=std::string;
using ulong=unsigned long long;
struct PSMarketSnapshot {string symbol;};
PSMarketSnapshot g_market{"USDJPY"};
string g_active_symbol="USDJPY",g_transition_target_symbol="",next_symbol="USTEC";
bool g_symbol_transition_pending=false,g_exposure_dirty=false;
ulong g_last_market_refresh_ms=0;
int g_ui=0,g_model=42,redraws=0,waiting=0;
bool quote_available=false;
ulong GetTickCount64(){return 2000;}
void PS_MarketAcquire(PSMarketSnapshot &s){s.symbol=next_symbol;}
void PS_SaveState(){}
void PS_AbortInteractionForContextChange(){}
void PS_CopyMarketSnapshot(PSMarketSnapshot &a,const PSMarketSnapshot &b){a=b;}
bool PS_BuildFreshPlan(string &error){error="no quote";return quote_available;}
void PS_SetStatus(const string&,bool,int){}
void PS_UIHidePanelContent(int){}
void PS_UIHidePlanningLines(int){}
void PS_UIRenderWaitingPanel(int,int,const string&){++waiting;}
void PS_LogWarningRateLimited(const string&,const string&,int){}
void PS_ModelEnsureInitialPrices(int&,const PSMarketSnapshot&){}
void PS_Recalculate(bool){++redraws;}
void PS_RefreshExposure(bool){}
'''
    source += extract_functions(EA, "PS_RefreshMarket")
    source += r'''
int main(){
  PS_RefreshMarket();
  assert(g_symbol_transition_pending && g_transition_target_symbol=="USTEC");
  assert(g_active_symbol=="USDJPY" && waiting==1 && g_model==42);
  next_symbol="USDJPY";quote_available=true;
  PS_RefreshMarket();
  assert(!g_symbol_transition_pending && g_transition_target_symbol.empty());
  assert(g_market.symbol=="USDJPY" && g_model==42 && redraws==1);
}
'''
    compile_and_run(tmp_path, source)


def test_snapshot_copy_failure_cannot_index_unallocated_rows(tmp_path):
    source = r'''
#include <string>
#include <vector>
#include <cassert>
using string=std::string;
using ulong=unsigned long long;
struct Item {
  int kind=0,status=0,direction=0,price_digits=0,volume_digits=0;
  ulong ticket=0;
  string symbol;
  double volume=0,entry=0,stop_loss=0,projected_result=0,loss_money=0,loss_percent=0;
};
struct Items : std::vector<Item> {
  Item& operator[](size_t n) {return at(n);}
  const Item& operator[](size_t n) const {return at(n);}
};
struct PSExposureSnapshot {
  Items items;
  bool enumeration_valid=false;
  double equity_basis=0,chart_loss_money=0,account_loss_money=0,chart_loss_percent=0,account_loss_percent=0;
  int chart_protected=0,account_protected=0,chart_no_sl=0,account_no_sl=0,chart_unavailable=0,account_unavailable=0;
  ulong fingerprint=0,calculated_at_ms=0;
};
bool refuse_growth=false;
int ArraySize(const Items &a){return int(a.size());}
int ArrayResize(Items &a,int n){
  if(refuse_growth && n>int(a.size())) return -1;
  a.resize(n);return n;
}
'''
    source += extract_functions(TYPES, "PS_ExposureReset", "PS_CopyExposureSnapshot")
    source += r'''
int main(){
  PSExposureSnapshot source,destination;
  source.items.resize(2);source.enumeration_valid=true;
  source.items[1].ticket=88;source.account_loss_money=22;
  PS_CopyExposureSnapshot(destination,source);
  assert(destination.items.size()==2 && destination.items[1].ticket==88);
  destination.items.resize(1);refuse_growth=true;
  PS_CopyExposureSnapshot(destination,source);
  assert(destination.items.empty() && !destination.enumeration_valid);
}
'''
    compile_and_run(tmp_path, source)


def test_trade_refresh_does_not_reuse_snapshot_during_symbol_transition(tmp_path):
    source = r'''
#include <string>
#include <cassert>
using string=std::string;
struct PSTradeSnapshot {string error;};
int g_model=0,g_market=0,g_calc=0,builders=0;
bool g_symbol_transition_pending=false;
void PS_RefreshMarket(bool){g_symbol_transition_pending=true;}
bool PS_TradeBuildSnapshot(int,int,int,PSTradeSnapshot&){++builders;return true;}
'''
    source += extract_functions(EA, "PS_BuildFreshTradeSnapshot")
    source += r'''
int main(){
  PSTradeSnapshot snapshot;string error;
  assert(!PS_BuildFreshTradeSnapshot(snapshot,error));
  assert(builders==0 && !error.empty());
}
'''
    compile_and_run(tmp_path, source)


def test_failed_panel_render_retains_work_and_limits_retries(tmp_path):
    source = r'''
#include <cassert>
using ulong=unsigned long long;
enum {PS_CAPTURE_NONE,PS_CAPTURE_PANEL,PS_CAPTURE_HANDLE_ENTRY,PS_CAPTURE_HANDLE_STOP,PS_CAPTURE_HANDLE_TAKE};
struct UI {bool created=true,dirty=true,line_dirty=true;} g_ui;
struct Pointer {int capture=PS_CAPTURE_NONE;bool drag_started=false;} g_pointer;
bool g_initialized=true,g_symbol_transition_pending=false,g_panel_dirty=false;
bool g_exposure_details_dirty=true,g_exposure_labels_dirty=true,paint_ok=false;
bool g_ps_panel_render_ready=true;
const int PS_EXPOSURE_HIT_NONE=0;
bool g_ps_exposure_labels_layout_dirty=false;
int g_exposure_pressed_hit=0,g_exposure_pressed_row=-1;
ulong now=2000,g_panel_retry_after_ms=0,g_ps_exposure_retry_after_ms=0;
int g_model=0,g_calc=0,g_market=0,g_exposure=0,g_editor=0,g_copy_feedback_control=0;
int attempts=0,details=0,labels=0,lines=0,redraws=0;
ulong GetTickCount64(){return now;}
bool PS_UIRenderPanel(UI&,int,int,int,int,int,int){++attempts;g_ps_panel_render_ready=paint_ok;return paint_ok;}
void PS_AbortInteractionForContextChange(){g_pointer.capture=PS_CAPTURE_NONE;}
bool PS_UIRenderExposureDetails(UI&,int,int,int){++details;return true;}
void PS_UIRenderExposureLabels(UI&,int,int,int){++labels;}
void PS_UIRenderLinesOnly(UI &ui,int,int){++lines;ui.line_dirty=false;}
int ChartID(){return 1;}
void ChartRedraw(int){++redraws;}
'''
    source += extract_functions(EA, "PS_AbortInteractionForRenderFailure", "PS_RenderIfDirty")
    source += r'''
int main(){
  PS_RenderIfDirty();
  assert(attempts==1 && g_panel_dirty && details==0 && labels==0 && lines==0);
  for(int i=1;i<1000;i+=8){now=2000+i;PS_RenderIfDirty();}
  assert(attempts==1 && redraws==0);
  now=3000;paint_ok=true;PS_RenderIfDirty();
  assert(attempts==2 && !g_panel_dirty && details==1 && labels==1 && lines==1 && redraws==1);
  PS_RenderIfDirty();assert(attempts==2);
}
'''
    compile_and_run(tmp_path, source)


def test_new_order_confirmation_is_single_stage_and_sends_fresh_snapshot(tmp_path):
    source = r'''
#include <string>
#include <cassert>
using string=std::string;
using ulong=unsigned long long;
struct PSTradeSnapshot{int revision=0;};
struct MqlTradeResult{ulong order=0,deal=0;unsigned retcode=0;};
struct Model{bool ask_confirmation=true;} g_model;
bool g_trade_in_flight=false,refresh_valid=true;
ulong g_last_submit_ms=0;
int g_market=0,builds=0,dialogs=0,sends=0,sent_revision=0,approval=1;
const int IDYES=1,MB_YESNO=1,MB_ICONQUESTION=2;
const string PS_PRODUCT_NAME="LotCraft",PS_VERSION_TEXT="test";
ulong GetTickCount64(){return 2000;}
void PS_SetStatus(const string&,bool,int=0){}
bool PS_CommitEditor(){return true;}
bool PS_BuildFreshTradeSnapshot(PSTradeSnapshot &s,string&){s.revision=++builds;return builds!=2||refresh_valid;}
string PS_TradeConfirmationText(const PSTradeSnapshot&,int){return "risk";}
int MessageBox(const string&,const string&,int){++dialogs;return approval;}
void PS_CopyTradeSnapshot(PSTradeSnapshot &a,const PSTradeSnapshot&b){a=b;}
bool PS_TradeSendSnapshot(const PSTradeSnapshot &s,MqlTradeResult&,string&){
  assert(g_trade_in_flight);++sends;sent_revision=s.revision;return true;
}
template<class... Args> string StringFormat(const char*,Args...){return "test";}
string PS_TradeRetcodeText(unsigned){return "DONE";}
void PS_RefreshMarket(bool){}
void reset(){builds=dialogs=sends=sent_revision=0;g_last_submit_ms=0;}
'''
    source += extract_functions(EA, "PS_DoTrade")
    source += r'''
int main(){
  PS_DoTrade();
  assert(dialogs==1 && builds==2 && sends==1 && sent_revision==2 && !g_trade_in_flight);
  PS_DoTrade();assert(sends==1 && dialogs==1);
  reset();approval=0;PS_DoTrade();assert(dialogs==1 && sends==0 && builds==1);
  reset();approval=1;refresh_valid=false;PS_DoTrade();assert(dialogs==1 && sends==0 && builds==2);
  reset();g_model.ask_confirmation=false;PS_DoTrade();assert(dialogs==0 && sends==1 && sent_revision==1);
}
'''
    compile_and_run(tmp_path, source)
