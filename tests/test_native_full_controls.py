"""Exercise production pointer dispatch with terminal effects stubbed out."""

import pytest

from native_mql_harness import compile_and_run, extract_function, extract_functions


EA = "MQL5/Experts/LotCraft/LotCraft.mq5"
UI = "MQL5/Experts/LotCraft/PS_UI.mqh"
TYPES = "MQL5/Experts/LotCraft/PS_Types.mqh"


@pytest.fixture(scope="module")
def pointer_choice_rows(tmp_path_factory):
    source = r'''
#include <algorithm>
#include <cmath>
#include <iostream>
#include <string>
using string=std::string;
using ulong=unsigned long long;
enum PSControlId {PS_CTRL_NONE=-1,PS_CTRL_MANUAL,PS_CTRL_FULL,PS_CTRL_COMPACT,PS_CTRL_MINI,
 PS_CTRL_THEME,PS_CTRL_CLOSE,PS_CTRL_DIRECTION,PS_CTRL_ORDER_MODE,PS_CTRL_LINES,
 PS_CTRL_COMMISSION_MODE,PS_CTRL_ACCOUNT_MODE,PS_CTRL_CONFIRM,PS_CTRL_ENTRY_COPY,
 PS_CTRL_STOP_COPY,PS_CTRL_TAKE_COPY,PS_CTRL_POSITION_COPY,PS_CTRL_EXPOSURE_SUMMARY,
 PS_CTRL_MOVE_SLS,PS_CTRL_TRADE,PS_CTRL_COUNT};
enum PSViewMode {PS_VIEW_FULL,PS_VIEW_COMPACT,PS_VIEW_MINI};
enum PSDirection {PS_DIRECTION_LONG,PS_DIRECTION_SHORT};
enum PSOrderMode {PS_ORDER_INSTANT,PS_ORDER_PENDING};
enum PSExposureHit {PS_EXPOSURE_HIT_NONE,PS_EXPOSURE_HIT_ROW};
enum {PS_THEME_DARK,PS_THEME_LIGHT,PS_COMMISSION_ONE_SIDE,PS_COMMISSION_ROUND_TRIP,
 PS_ACCOUNT_EQUITY,PS_ACCOUNT_BALANCE,PS_ACCOUNT_MANUAL};
enum {PS_CAPTURE_NONE,PS_CAPTURE_CONTROL,PS_CAPTURE_PANEL,PS_CAPTURE_HANDLE_ENTRY,
 PS_CAPTURE_HANDLE_STOP,PS_CAPTURE_HANDLE_TAKE,PS_FIELD_NONE};
struct PSRect {int x=0,y=0,w=0,h=0;};
struct PSModel {PSViewMode view_mode=PS_VIEW_FULL; PSDirection direction=PS_DIRECTION_LONG;
 PSOrderMode order_mode=PS_ORDER_INSTANT; int theme_mode=PS_THEME_DARK,commission_mode=0,
 account_mode=0,revision=0; bool lines_visible=true,ask_confirmation=true; } g_model;
struct PSUIState {bool dirty=false;} g_ui;
struct {int capture=PS_CAPTURE_NONE;PSControlId control=PS_CTRL_NONE;
 bool drag_started=false;int start_x=0,start_y=0,panel_offset_x=0,panel_offset_y=0,applied_x=0,applied_y=0;} g_pointer;
struct {bool details_open=false;int scroll_offset=0;} g_exposure_ui;
struct {bool valid=true;int issue=0;} g_calc;
bool g_initialized=true,g_symbol_transition_pending=false,g_ps_panel_render_ready=true;
bool g_exposure_details_dirty=false,g_exposure_labels_dirty=false,g_pointer_motion_pending=false;
bool g_ps_control_visible[PS_CTRL_COUNT]={};
PSRect g_ps_control_rects[PS_CTRL_COUNT];
ulong g_control_last_action[PS_CTRL_COUNT]={},clock_ms=1000;
PSExposureHit g_exposure_pressed_hit=PS_EXPOSURE_HIT_NONE;
int g_exposure_pressed_row=-1,g_market=0;
string _Symbol="TEST";
double scale=1;
int PS_U(int value) {return (int)std::round(value*scale);}
void PS_UISetRect(PSRect &r,int x,int y,int w,int h){r={x,y,w,h};}
ulong GetTickCount64(){return clock_ms;}
void PS_SetStatus(const string&,bool,int=5000){}
bool PS_PlatformOpenNativeOrderDialog(string&){return false;}
void PS_SetViewModeState(PSViewMode mode){g_model.view_mode=mode;}
void PS_SaveState(){}
void ExpertRemove(){}
void PS_ModelChangeDirection(PSModel &model,int,PSDirection direction){model.direction=direction;}
bool PS_ModelChangeOrderMode(PSModel &model,int,PSOrderMode mode,string&){model.order_mode=mode;return true;}
bool PS_CommitEditor(){return true;}
void PS_ClearTransientStatus(){}
void PS_Recalculate(bool){}
void PS_DoCopy(PSControlId){}
void PS_DoMoveStops(){}
void PS_DoTrade(){}
string PS_CalcIssueText(int){return "";}
void PS_RenderIfDirty(){}
bool PS_IsMotionCapture(){return false;}
void PS_MouseMoveCaptured(int,int){}
void PS_AbortInteractionForContextChange(){}
void PS_UISetPanelPosition(PSUIState&,int,int,PSViewMode){}
void PS_UIPreparePanelDrop(PSUIState&){}
int PS_UIFieldForControl(PSControlId){return PS_FIELD_NONE;}
PSExposureHit PS_UIExposureHitTest(int,int,int&){return PS_EXPOSURE_HIT_NONE;}
void PS_ExposureAction(PSExposureHit,int){}
void PS_UpdateLevelFromPointer(int,int,int,bool){}
void PS_UIApplyLineLock(PSUIState&,const string&){}
void PS_ResetCapture(int,int){g_pointer.capture=PS_CAPTURE_NONE;g_pointer.control=PS_CTRL_NONE;}
void PS_UIEndPanelDrag(PSUIState&){}
'''
    source += extract_function(TYPES, "PS_RectContains")
    source += extract_function(EA, "PS_Action")
    # Added helpers are included when present; pre-fix tests still execute the old
    # complete production release path, rather than a simulated toggle function.
    try:
        source += extract_function(UI, "PS_UISplitChoiceRects")
        source += extract_function(EA, "PS_PointerAction")
    except ValueError:
        pass
    source += extract_function(EA, "PS_MouseRelease")
    source += r'''
void click(PSControlId control,int down_x,int release_x) {
 g_pointer.capture=PS_CAPTURE_CONTROL;g_pointer.control=control;
 g_pointer.start_x=PS_U(down_x);g_pointer.start_y=20;
 PS_MouseRelease(PS_U(release_x),20);clock_ms+=1000;
 std::cout << g_model.direction << ' ' << g_model.order_mode << '\n';
}
int main(){
 for(auto &visible:g_ps_control_visible)visible=true;
 for(int dpi=0;dpi<2;dpi++) {
  scale=dpi==0 ? 1 : 1.5;
  for(auto &rect:g_ps_control_rects)rect={0,0,PS_U(190),40};
  g_model={};
  click(PS_CTRL_DIRECTION,40,40);  // Selected Long stays Long.
  click(PS_CTRL_DIRECTION,140,140);
  click(PS_CTRL_DIRECTION,140,140); // Selected Short stays Short.
  click(PS_CTRL_DIRECTION,95,95); // The 8px gap does not choose either side.
  click(PS_CTRL_DIRECTION,40,140); // Crossing from one button to the other is not a click.
  click(PS_CTRL_DIRECTION,40,40);
  click(PS_CTRL_ORDER_MODE,40,40);
  click(PS_CTRL_ORDER_MODE,140,140);
  click(PS_CTRL_ORDER_MODE,140,140);
  click(PS_CTRL_ORDER_MODE,95,95);
  g_model.view_mode=PS_VIEW_COMPACT;
  click(PS_CTRL_DIRECTION,40,40); // Compact remains one toggling control.
  click(PS_CTRL_ORDER_MODE,40,40);
  g_model.view_mode=PS_VIEW_FULL;
  PS_Action(PS_CTRL_DIRECTION);PS_Action(PS_CTRL_ORDER_MODE); // Keyboard action toggles.
  std::cout << g_model.direction << ' ' << g_model.order_mode << '\n';
 }
}
'''
    output = compile_and_run(tmp_path_factory.mktemp("full_choices"), source)
    return [tuple(map(int, row.split())) for row in output.splitlines()]


@pytest.mark.parametrize("dpi", [0, 1])
@pytest.mark.parametrize("index,expected", [
    (0, (0, 0)), (1, (1, 0)), (2, (1, 0)), (3, (1, 0)), (4, (1, 0)), (5, (0, 0)),
    (6, (0, 0)), (7, (0, 1)), (8, (0, 1)), (9, (0, 1)), (10, (1, 1)), (11, (1, 0)), (12, (0, 1)),
])
def test_full_pointer_click_selects_drawn_choice_without_toggling_active_choice(pointer_choice_rows, dpi, index, expected):
    assert pointer_choice_rows[dpi * 13 + index] == expected


@pytest.mark.parametrize("transition_at", [2, 3])
def test_stop_batch_aborts_if_symbol_changes_during_confirmation(tmp_path, transition_at):
    source = r'''
#include <algorithm>
#include <iostream>
#include <string>
#include <vector>
using string=std::string;using ulong=unsigned long long;
struct PSSlTarget {int id=0;};
struct {bool ask_confirmation=true;} g_model;
struct {double tick_size=1;bool symbol_ready=true;} g_market;
bool g_trade_in_flight=false,g_symbol_transition_pending=false;
ulong g_last_submit_ms=0;int refreshes=0,collections=0,batches=0;
int transition_at=0;
const string PS_PRODUCT_NAME="LotCraft";
enum {MB_YESNO=1,MB_ICONQUESTION=2,IDYES=6,MB_OK=0,MB_ICONWARNING=4,MB_ICONINFORMATION=8};
ulong GetTickCount64(){return 2000;}
void PS_SetStatus(const string&,bool,int=5000){}
bool PS_CommitEditor(){return true;}
void PS_RefreshMarket(bool){++refreshes;if(refreshes==transition_at)g_symbol_transition_pending=true;}
int PS_TradeCollectSlTargets(decltype(g_model)&,decltype(g_market)&,std::vector<PSSlTarget>& targets){
 ++collections;targets={{transition_at==3 && collections>=2 ? 2 : 1}};return 1;
}
template<class T> int ArraySize(const std::vector<T>& items){return (int)items.size();}
string PS_TradeSlConfirmationText(decltype(g_model)&,decltype(g_market)&,std::vector<PSSlTarget>&){return "";}
int MessageBox(const string&,const string&,int){return IDYES;}
bool PS_TradeSlTargetSetsEqual(const std::vector<PSSlTarget>& a,const std::vector<PSSlTarget>& b,double){return a[0].id==b[0].id;}
bool PS_TradeCopySlTargets(std::vector<PSSlTarget>& a,const std::vector<PSSlTarget>& b){a=b;return true;}
void PS_TradeExecuteSlBatch(std::vector<PSSlTarget>&,int& succeeded,int& failed,string&){++batches;succeeded=1;failed=0;}
template<class... T> string StringFormat(const char* text,T...){return text;}
void PS_LogInfo(const string&){}
int StringLen(const string& value){return (int)value.size();}
string StringSubstr(const string& value,int start,int length){return value.substr(start,length);}
'''
    body = extract_function(EA, "PS_DoMoveStops")
    # Syntax-only adapter: MQL dynamic local arrays become C++ vectors. No
    # control-flow, comparison, or request logic is changed for this fixture.
    for name in ("targets", "refreshed", "final_targets"):
        body = body.replace(f"PSSlTarget {name}[];", f"std::vector<PSSlTarget> {name};")
    source += body
    source += f"\nint main(){{transition_at={transition_at};PS_DoMoveStops();std::cout<<batches<<' '<<collections;}}"
    assert compile_and_run(tmp_path, source).strip() == f"0 {transition_at - 1}"


@pytest.mark.parametrize("pending", [False, True])
@pytest.mark.parametrize("failure", ["none", "allocation", "selection"])
def test_sl_collection_failure_does_not_publish_partial_targets(tmp_path, pending, failure):
    source = r'''
#include <cmath>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>
using string=std::string;using ulong=unsigned long long;using datetime=long long;
enum PSDirection {PS_DIRECTION_LONG,PS_DIRECTION_SHORT};
enum ENUM_POSITION_TYPE {POSITION_TYPE_BUY,POSITION_TYPE_SELL};
enum ENUM_ORDER_TYPE {ORDER_TYPE_BUY,ORDER_TYPE_SELL,ORDER_TYPE_BUY_LIMIT,ORDER_TYPE_SELL_LIMIT,
 ORDER_TYPE_BUY_STOP,ORDER_TYPE_SELL_STOP,ORDER_TYPE_BUY_STOP_LIMIT,ORDER_TYPE_SELL_STOP_LIMIT};
enum ENUM_ORDER_TYPE_TIME {ORDER_TIME_GTC};enum ENUM_ORDER_TYPE_FILLING {ORDER_FILLING_RETURN};
enum {POSITION_SYMBOL,POSITION_TYPE,POSITION_SL,POSITION_PRICE_OPEN,POSITION_TP,ORDER_SYMBOL,
 ORDER_TYPE,ORDER_PRICE_OPEN,ORDER_SL,ORDER_TP,ORDER_PRICE_STOPLIMIT,ORDER_TIME_EXPIRATION,ORDER_TIME,ORDER_FILLING};
#define ORDER_TYPE_TIME ORDER_TIME
#define ORDER_TYPE_FILLING ORDER_FILLING
#define ZeroMemory(value) value={}
struct PSModel {double stop_loss=90;} model;
struct PSMarketSnapshot {string symbol="TEST";double tick_size=1;} market;
struct PSSlTarget {bool is_position=false;ulong ticket=0;string symbol;PSDirection direction=PS_DIRECTION_LONG;
 double entry=0,old_sl=0,tp=0,target_sl=0,price=0,stoplimit=0;datetime expiration=0;
 ENUM_ORDER_TYPE order_type=ORDER_TYPE_BUY;ENUM_ORDER_TYPE_TIME type_time=ORDER_TIME_GTC;
 ENUM_ORDER_TYPE_FILLING type_filling=ORDER_FILLING_RETURN;};
template<class T> struct NativeArray:std::vector<T> {T& operator[](int index){return this->at(index);}};
bool pending=false,fail_allocation=false,fail_selection=false;
template<class T>int ArrayResize(NativeArray<T>& values,int size){if(fail_allocation && size==2)return -1;values.resize(size);return size;}
template<class T>int ArraySize(const NativeArray<T>& values){return (int)values.size();}
int PositionsTotal(){return pending?0:2;}int OrdersTotal(){return pending?2:0;}
ulong PositionGetTicket(int index){return fail_selection && index==1?0:index+1;}
ulong OrderGetTicket(int index){return fail_selection && index==1?0:index+1;}
string PositionGetString(int){return "TEST";}string OrderGetString(int){return "TEST";}
long PositionGetInteger(int){return POSITION_TYPE_BUY;}
long OrderGetInteger(int property){return property==ORDER_TYPE?ORDER_TYPE_BUY_STOP:0;}
double PositionGetDouble(int property){return property==POSITION_PRICE_OPEN?100:0;}
double OrderGetDouble(int property){return property==ORDER_PRICE_OPEN?110:0;}
double PS_NormalizePrice(double value,const PSMarketSnapshot&){return value;}
bool PS_IsBuyOrderType(ENUM_ORDER_TYPE type){return type==ORDER_TYPE_BUY_STOP;}
bool PS_IsSellOrderType(ENUM_ORDER_TYPE){return false;}
bool PS_TradeSlNeedsChange(double,double,double){return true;}
bool PS_TradeValidateTargetSL(PSDirection,double,bool,double,const PSMarketSnapshot&,string&,double=0){return true;}
'''
    body = extract_function("MQL5/Experts/LotCraft/PS_Trade.mqh", "PS_TradeCollectSlTargets")
    # Syntax-only array-reference adapter; every collection decision runs unchanged.
    source += body.replace("PSSlTarget &targets[]", "NativeArray<PSSlTarget> &targets")
    source += f"\nint main(){{pending={str(pending).lower()};fail_allocation={str(failure == 'allocation').lower()};fail_selection={str(failure == 'selection').lower()};"
    source += r'''NativeArray<PSSlTarget> targets;int count=-99;
 try{count=PS_TradeCollectSlTargets(model,market,targets);}catch(const std::out_of_range&){}
 std::cout<<count<<' '<<targets.size();}'''
    expected = "2 2" if failure == "none" else "-1 0"
    assert compile_and_run(tmp_path, source).strip() == expected


def test_sl_target_copy_allocation_failure_invalidates_destination(tmp_path):
    source = r'''
#include <iostream>
#include <stdexcept>
#include <vector>
struct PSSlTarget {int id=0;};
template<class T>struct NativeArray:std::vector<T>{
 T& operator[](int i){return this->at(i);}const T& operator[](int i)const{return this->at(i);}
};
template<class T>int ArraySize(const NativeArray<T>& items){return (int)items.size();}
template<class T>int ArrayResize(NativeArray<T>& items,int size){if(size==2)return -1;items.resize(size);return size;}
void PS_CopySlTarget(PSSlTarget& a,const PSSlTarget& b){a=b;}
'''
    body = extract_function("MQL5/Experts/LotCraft/PS_Trade.mqh", "PS_TradeCopySlTargets")
    body = body.replace("PSSlTarget &destination[]", "NativeArray<PSSlTarget> &destination")
    body = body.replace("const PSSlTarget &source[]", "const NativeArray<PSSlTarget> &source")
    source += body + r'''
int main(){NativeArray<PSSlTarget> source,destination;source.resize(2);destination.resize(1);
 source[0].id=1;source[1].id=2;destination[0].id=9;
 try{PS_TradeCopySlTargets(destination,source);}catch(const std::out_of_range&){}
 std::cout<<destination.size()<<' '<<source[0].id<<' '<<source[1].id;}
'''
    assert compile_and_run(tmp_path, source).strip() == "0 1 2"
