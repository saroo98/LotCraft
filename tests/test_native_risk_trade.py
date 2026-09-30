"""Production-helper regressions. All terminal/broker calls use offline fixtures.

These tests execute the actual selected function bodies with g++, not MT5. They
verify decisions and property selection, not broker pricing or server execution.
"""

import pytest

from native_mql_harness import compile_and_run, extract_function, extract_functions


MODULE = "MQL5/Experts/LotCraft/"
COMMON = r"""
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <iostream>
#include <string>
#include <vector>
using string = std::string;
#define ulong uint64_t
using uint = unsigned int;
enum PSDirection { PS_DIRECTION_LONG, PS_DIRECTION_SHORT };
enum ENUM_ORDER_TYPE { ORDER_TYPE_BUY, ORDER_TYPE_SELL, ORDER_TYPE_BUY_LIMIT,
 ORDER_TYPE_SELL_LIMIT, ORDER_TYPE_BUY_STOP, ORDER_TYPE_SELL_STOP,
 ORDER_TYPE_BUY_STOP_LIMIT, ORDER_TYPE_SELL_STOP_LIMIT, ORDER_TYPE_CLOSE_BY };
enum PSExposureKind { PS_EXPOSURE_POSITION, PS_EXPOSURE_PENDING };
enum PSExposureStatus { PS_EXPOSURE_VALID, PS_EXPOSURE_NO_SL, PS_EXPOSURE_UNAVAILABLE };
const double PS_DOUBLE_EPS=1e-12;
bool MathIsValidNumber(double value) { return std::isfinite(value); }
double MathMax(double a,double b) { return std::max(a,b); }
void ResetLastError() {}
int GetLastError() { return 0; }
template<class... T> string StringFormat(const char *format,T...) { return format; }
template<class T> int ArraySize(const std::vector<T>& values) { return (int)values.size(); }
template<class T> int ArrayResize(std::vector<T>& values,int size) { values.resize(size); return size; }
""" + extract_functions(
    MODULE + "PS_Types.mqh", "PS_IsFinite", "PS_IsPositiveFinite", "PS_IsBuyOrderType", "PS_IsSellOrderType"
)


@pytest.fixture(scope="module")
def pending_exposure_rows(tmp_path_factory):
    source = COMMON + r"""
struct PSExposureItem {
 PSExposureKind kind; PSExposureStatus status; ulong ticket; string symbol;
 PSDirection direction; double volume,entry,stop_loss,projected_result,loss_money,loss_percent;
 int price_digits=8,volume_digits=8;
};
struct PSExposureSnapshot { std::vector<PSExposureItem> items; };
enum { SYMBOL_DIGITS, SYMBOL_VOLUME_STEP };
bool SymbolInfoInteger(const string&,int,long& digits) { digits=2; return true; }
double SymbolInfoDouble(const string&,int) { return .1; }
double MathAbs(double value) { return std::abs(value); }
double NormalizeDouble(double value,int digits) { double scale=std::pow(10,digits); return std::round(value*scale)/scale; }
enum { ORDER_TYPE, ORDER_VOLUME_CURRENT, ORDER_PRICE_OPEN, ORDER_PRICE_STOPLIMIT, ORDER_SL, ORDER_SYMBOL };
ENUM_ORDER_TYPE fixture_type=ORDER_TYPE_BUY_STOP_LIMIT;
double fixture_limit=105;
ulong OrderGetTicket(int) { return 1; }
long OrderGetInteger(int) { return fixture_type; }
string OrderGetString(int) { return "TEST"; }
double OrderGetDouble(int property) {
 if(property==ORDER_VOLUME_CURRENT) return 1;
 if(property==ORDER_PRICE_OPEN) return fixture_type==ORDER_TYPE_SELL_STOP_LIMIT ? 90 : 110;
 if(property==ORDER_PRICE_STOPLIMIT) return fixture_limit;
 if(property==ORDER_SL) return 100;
 return 0;
}
bool OrderCalcProfit(ENUM_ORDER_TYPE type,const string&,double volume,double entry,double stop,double& result) {
 result=(type==ORDER_TYPE_BUY ? stop-entry : entry-stop)*volume; return true;
}
""" + extract_function(MODULE + "PS_Types.mqh", "PS_DecimalsForStep") + extract_functions(
        MODULE + "PS_Exposure.mqh",
        "PS_ExposureResetItem", "PS_ExposureCopyItem", "PS_ExposureAppend", "PS_ExposureProject", "PS_ExposureReadPrecision", "PS_ExposureAddPending",
    ) + r"""
int main() {
 for(int index=0;index<5;index++) {
  fixture_type=index==1 ? ORDER_TYPE_SELL_STOP_LIMIT : index==4 ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_BUY_STOP_LIMIT;
  fixture_limit=index==1 ? 95 : index==2 ? 0 : index==3 ? NAN : 105;
  PSExposureSnapshot snapshot; string error;
  if(!PS_ExposureAddPending(snapshot,0,error)) return 1;
  const auto& item=snapshot.items.at(0);
  std::cout << item.status << ' ' << item.loss_money << '\n';
 }
}
"""
    return [tuple(map(float, line.split())) for line in compile_and_run(tmp_path_factory.mktemp("exposure"), source).splitlines()]


@pytest.mark.parametrize("index,expected", [(0, (0, 5)), (1, (0, 5)), (2, (2, 0)), (3, (2, 0)), (4, (0, 10))])
def test_pending_exposure_uses_fill_price_not_stop_trigger(pending_exposure_rows, index, expected):
    # A wrong property read doubles this hand-calculated loss or hides missing fill data.
    assert pending_exposure_rows[index] == expected


@pytest.fixture(scope="module")
def session_rows(tmp_path_factory):
    source = COMMON + r"""
using datetime = int64_t;
enum ENUM_DAY_OF_WEEK { SUNDAY, MONDAY, TUESDAY, WEDNESDAY, THURSDAY, FRIDAY, SATURDAY };
struct MqlDateTime { int day_of_week,hour,min,sec; };
struct Session { int day; datetime from,to; };
std::vector<Session> sessions;
bool TimeToStruct(datetime value,MqlDateTime& parts) {
 if(value<0) return false;
 parts.day_of_week=(int)(value/86400)%7;
 parts.hour=(int)(value%86400)/3600; parts.min=(int)(value%3600)/60; parts.sec=(int)(value%60);
 return true;
}
bool SymbolInfoSessionTrade(const string&,ENUM_DAY_OF_WEEK day,uint index,datetime& from,datetime& to) {
 uint found=0;
 for(const auto& session:sessions) if(session.day==day) {
  if(found++==index) { from=session.from; to=session.to; return true; }
 }
 return false;
}
""" + extract_functions(MODULE + "PS_Market.mqh", "PS_MarketSessionBounds", "PS_MarketSessionState") + r"""
void check(int day,int seconds,std::vector<Session> schedule) {
 sessions=schedule; bool known=false;
 bool open=PS_MarketSessionState("TEST",day*86400+seconds,known);
 std::cout << known << ' ' << open << '\n';
}
int main() {
 check(MONDAY,9*3600,{{MONDAY,9*3600,17*3600}});
 check(MONDAY,17*3600,{{MONDAY,9*3600,17*3600}});
 check(SATURDAY,12*3600,{{MONDAY,9*3600,17*3600}});
 check(TUESDAY,1800,{{MONDAY,23*3600,25*3600}});
 check(SATURDAY,1800,{{FRIDAY,23*3600,25*3600}});
 check(SUNDAY,1800,{{SATURDAY,23*3600,25*3600}});
 check(WEDNESDAY,1800,{{WEDNESDAY,23*3600,3600}});
 check(WEDNESDAY,1800,{{TUESDAY,23*3600,3600}});
 check(MONDAY,86399,{{MONDAY,0,86400}});
 check(TUESDAY,0,{{MONDAY,0,86400}});
 check(MONDAY,3600,{{MONDAY,0,0}});
 check(MONDAY,3600,{});
 check(MONDAY,13*3600,{{MONDAY,9*3600,12*3600},{MONDAY,14*3600,17*3600}});
 check(MONDAY,14*3600,{{MONDAY,9*3600,12*3600},{MONDAY,14*3600,17*3600}});
 check(MONDAY,10*3600,{{MONDAY,100*86400+9*3600,101*86400+17*3600}});
 check(MONDAY,10*3600,{{MONDAY,-1,17*3600}});
 check(MONDAY,3600,{{MONDAY,0,0},{TUESDAY,9*3600,17*3600}});
}
"""
    return [tuple(map(int, line.split())) for line in compile_and_run(tmp_path_factory.mktemp("sessions"), source).splitlines()]


@pytest.mark.parametrize("index,expected", [
    (0, (1, 1)), (1, (1, 0)), (2, (1, 0)), (3, (1, 1)), (4, (1, 1)),
    (5, (1, 1)), (6, (1, 0)), (7, (1, 1)), (8, (1, 1)), (9, (1, 0)),
    (10, (0, 0)), (11, (0, 0)), (12, (1, 0)), (13, (1, 1)),
])
def test_session_availability_honors_weekly_and_overnight_boundaries(session_rows, index, expected):
    assert session_rows[index] == expected


@pytest.mark.parametrize("index,expected", [(14, (1, 1)), (15, (0, 0)), (16, (0, 0))])
def test_session_dates_and_invalid_intervals_do_not_create_false_closure(session_rows, index, expected):
    assert session_rows[index] == expected


@pytest.fixture(scope="module")
def risk_permission_rows(tmp_path_factory):
    source = COMMON + r"""
enum ENUM_SYMBOL_TRADE_MODE { SYMBOL_TRADE_MODE_DISABLED, SYMBOL_TRADE_MODE_LONGONLY,
 SYMBOL_TRADE_MODE_SHORTONLY, SYMBOL_TRADE_MODE_CLOSEONLY, SYMBOL_TRADE_MODE_FULL };
enum { PS_CALC_ISSUE_NONE, PS_CALC_ISSUE_QUOTE, PS_CALC_ISSUE_PERMISSION, PS_CALC_ISSUE_SESSION,
 PS_CALC_ISSUE_NETTING, PS_CALC_ISSUE_UNKNOWN, PS_CALC_ISSUE_VOLUME, PS_CALC_ISSUE_STOP };
enum { PS_ACCOUNT_EQUITY, PS_ACCOUNT_BALANCE, PS_ACCOUNT_MANUAL, PS_RISK_PERCENT, PS_RISK_MONEY,
 PS_COMMISSION_ONE_SIDE, PS_COMMISSION_ROUND_TRIP, ACCOUNT_MARGIN_MODE_RETAIL_HEDGING };
const int PS_CALC_BUDGET_US=1000;
struct PSModel {
 PSDirection direction=PS_DIRECTION_LONG;
 int account_mode=PS_ACCOUNT_EQUITY, risk_authority=PS_RISK_PERCENT, commission_mode=PS_COMMISSION_ROUND_TRIP;
 double manual_account_money=10000,requested_risk_percent=1,requested_risk_money=100;
 double commission_per_lot=0,stop_loss=90;
};
struct PSMarketSnapshot {
 struct { double bid=100,ask=100; long time=3600; } tick;
 bool tick_valid=true,symbol_ready=true,terminal_connected=true,terminal_trade_allowed=true,
 mql_trade_allowed=true,account_trade_allowed=true,account_expert_allowed=true,session_known=true,session_open=true;
 int account_margin_mode=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING,current_symbol_positions=0;
 long trade_mode=SYMBOL_TRADE_MODE_FULL;
 double equity=10000,balance=10000,volume_min=.1,volume_max=100,volume_step=.1,volume_limit=0,
 exposure_long=0,exposure_short=0;
 string error,symbol="TEST";
};
struct PSCalcResult {
 bool valid=false,sizing_available=false,quote_valid=false,volume_capped=false,volume_raised_to_minimum=false;
 int issue=0;
 double account_basis=0,requested_percent=0,requested_money=0,commission_risk_per_lot=0,
 effective_entry=0,one_lot_loss=0,raw_volume=0,directional_exposure=0,remaining_volume_limit=0,
 volume=0,actual_money=0,actual_percent=0;
 string error,notice;
};
#define ZeroMemory(value) value={}
ulong GetMicrosecondCount() { return 0; }
void PS_PerfCheck(const string&,ulong,int) {}
double MathAbs(double value) { return std::abs(value); }
double MathMin(double a,double b) { return std::min(a,b); }
double MathFloor(double value) { return std::floor(value); }
double NormalizeDouble(double value,int digits) { double scale=std::pow(10,digits); return std::round(value*scale)/scale; }
string DoubleToString(double value,int) { return std::to_string(value); }
// Geometry is valid in this fixture. Its validation is separate from permission gating.
bool PS_RiskResolveOrder(const PSModel&,const PSMarketSnapshot& market,PSCalcResult& calc,string&,bool require_current_quote=true) {
 if(require_current_quote && !market.tick_valid) return false;
 calc.effective_entry=100; return true;
}
bool PS_RiskValidateProtectivePrices(const PSModel&,const PSMarketSnapshot&,PSCalcResult&,string&) { return true; }
bool OrderCalcProfit(ENUM_ORDER_TYPE,const string&,double,double,double,double& profit) { profit=-100; return true; }
""" + extract_functions(MODULE + "PS_Types.mqh", "PS_DecimalsForStep", "PS_FloorVolume") + extract_function(
        MODULE + "PS_Market.mqh", "PS_MarketDirectionPermitted"
    ) + extract_function(MODULE + "PS_Market.mqh", "PS_MarketHasUsableQuote") + extract_function(MODULE + "PS_Risk.mqh", "PS_RiskCalculate") + r"""
int main() {
 for(int index=0;index<13;index++) {
  PSModel model; PSMarketSnapshot market; PSCalcResult calc;
  if(index==1) market.terminal_connected=false;
  if(index==2) market.trade_mode=SYMBOL_TRADE_MODE_DISABLED;
  if(index==3) market.trade_mode=SYMBOL_TRADE_MODE_CLOSEONLY;
  if(index==4 || index==6) market.trade_mode=SYMBOL_TRADE_MODE_SHORTONLY;
  if(index==5 || index==7) market.trade_mode=SYMBOL_TRADE_MODE_LONGONLY;
  if(index==5 || index==6) model.direction=PS_DIRECTION_SHORT;
  if(index==8) market.terminal_trade_allowed=false;
  if(index>=9) model.requested_risk_percent=2;
  if(index==9) market.session_open=false;
  if(index==10) market.tick_valid=false;
  if(index==11) market.mql_trade_allowed=false;
  if(index==12) model.requested_risk_percent=.0001;
  bool valid=PS_RiskCalculate(model,market,calc);
  std::cout << valid << ' ' << calc.valid << ' ' << calc.sizing_available << ' ' << calc.requested_money << ' ' << calc.volume;
  if(index==12) std::cout << ' ' << calc.actual_money << ' ' << calc.volume_raised_to_minimum
                         << ' ' << (calc.notice.find("Actual SL loss")!=string::npos);
  std::cout << '\n';
 }
}
"""
    return [tuple(map(float, line.split())) for line in compile_and_run(tmp_path_factory.mktemp("risk_permissions"), source).splitlines()]


@pytest.mark.parametrize("index,expected", [
    (0, (1, 1)), (1, (0, 0)), (2, (0, 0)), (3, (0, 0)), (4, (0, 0)),
    (5, (0, 0)), (6, (1, 1)), (7, (1, 1)), (8, (0, 0)),
])
def test_risk_preview_disables_connection_and_direction_restrictions(risk_permission_rows, index, expected):
    assert risk_permission_rows[index][:2] == expected


@pytest.mark.parametrize("index", [9, 10, 11])
def test_untradable_market_still_recalculates_planning_risk(risk_permission_rows, index):
    assert risk_permission_rows[index] == (0, 0, 1, 200, 2)


def test_minimum_volume_notice_names_the_current_actual_loss_field(risk_permission_rows):
    assert risk_permission_rows[12] == (1, 1, 1, .01, .1, 10, 1, 1)


@pytest.fixture(scope="module")
def sl_validation_rows(tmp_path_factory):
    source = COMMON + r"""
struct PSMarketSnapshot {
 struct { double bid=100,ask=100; } tick;
 long stops_level_points=1,freeze_level_points=0;
 double point=1,tick_size=1;
};
double MathAbs(double value) { return std::abs(value); }
""" + extract_function(MODULE + "PS_Market.mqh", "PS_MarketProtectiveDistance") + extract_function(
        MODULE + "PS_Trade.mqh", "PS_TradeValidateTargetSL"
    ) + r"""
int main() {
 PSMarketSnapshot market; string error;
 std::cout << PS_TradeValidateTargetSL(PS_DIRECTION_LONG,105,true,110,market,error) << '\n';
 std::cout << PS_TradeValidateTargetSL(PS_DIRECTION_SHORT,95,true,90,market,error) << '\n';
 std::cout << PS_TradeValidateTargetSL(PS_DIRECTION_LONG,110,true,110,market,error) << '\n';
 std::cout << PS_TradeValidateTargetSL(PS_DIRECTION_SHORT,90,true,90,market,error) << '\n';
 std::cout << PS_TradeValidateTargetSL(PS_DIRECTION_LONG,105,false,110,market,error) << '\n';
 std::cout << PS_TradeValidateTargetSL(PS_DIRECTION_SHORT,95,false,90,market,error) << '\n';
 std::cout << PS_TradeValidateTargetSL(PS_DIRECTION_LONG,90,false,110,market,error) << '\n';
 std::cout << PS_TradeValidateTargetSL(PS_DIRECTION_SHORT,110,false,90,market,error) << '\n';
 market.freeze_level_points=2;
 std::cout << PS_TradeValidateTargetSL(PS_DIRECTION_LONG,98,true,100.5,market,error) << '\n';
 std::cout << PS_TradeValidateTargetSL(PS_DIRECTION_SHORT,102,true,99.5,market,error) << '\n';
 // Stop-limit fills can be near the quote while their triggers are outside freeze.
 std::cout << PS_TradeValidateTargetSL(PS_DIRECTION_LONG,98,true,100.5,market,error,110) << '\n';
 std::cout << PS_TradeValidateTargetSL(PS_DIRECTION_LONG,98,true,110,market,error,100.5) << '\n';
 std::cout << PS_TradeValidateTargetSL(PS_DIRECTION_LONG,109,true,110,market,error) << '\n';
 std::cout << PS_TradeValidateTargetSL(PS_DIRECTION_SHORT,91,true,90,market,error) << '\n';
 std::cout << PS_TradeValidateTargetSL(PS_DIRECTION_LONG,99,false,110,market,error) << '\n';
}
"""
    return list(map(int, compile_and_run(tmp_path_factory.mktemp("sl_validation"), source).splitlines()))


@pytest.mark.parametrize("index,expected", [(0, 1), (1, 1), (2, 0), (3, 0), (4, 0), (5, 0), (6, 1), (7, 1), (8, 0), (9, 0), (10, 1), (11, 0), (12, 1), (13, 1), (14, 0)])
def test_pending_sl_uses_entry_distance_and_pending_freeze(sl_validation_rows, index, expected):
    assert sl_validation_rows[index] == expected


@pytest.fixture(scope="module")
def directional_exposure_rows(tmp_path_factory):
    source = COMMON + r"""
enum ENUM_POSITION_TYPE { POSITION_TYPE_BUY, POSITION_TYPE_SELL };
enum { POSITION_SYMBOL, POSITION_VOLUME, POSITION_TYPE, ORDER_SYMBOL, ORDER_VOLUME_CURRENT, ORDER_TYPE };
struct Record { string symbol; int type; double volume; };
struct PSMarketSnapshot {
 string symbol="TEST",error;
 bool symbol_ready=true;
 double exposure_long=0,exposure_short=0;
 int current_symbol_positions=0;
};
std::vector<Record> positions,orders;
const Record* selected=nullptr;
int fail_position=-1,fail_order=-1;
int PositionsTotal() { return (int)positions.size(); }
int OrdersTotal() { return (int)orders.size(); }
ulong PositionGetTicket(int index) {
 if(index==fail_position) return 0;
 selected=&positions.at(index); return index+1;
}
ulong OrderGetTicket(int index) {
 if(index==fail_order) return 0;
 selected=&orders.at(index); return index+1;
}
string PositionGetString(int) { return selected->symbol; }
string OrderGetString(int) { return selected->symbol; }
double PositionGetDouble(int) { return selected->volume; }
double OrderGetDouble(int) { return selected->volume; }
long PositionGetInteger(int) { return selected->type; }
long OrderGetInteger(int) { return selected->type; }
""" + extract_function(MODULE + "PS_Market.mqh", "PS_MarketCalculateDirectionalExposure") + r"""
int main() {
 for(int index=0;index<11;index++) {
  positions={{"TEST",POSITION_TYPE_BUY,2}}; orders={}; fail_position=-1; fail_order=-1;
  if(index==1) fail_position=0;
  if(index==2) { positions.push_back({"TEST",POSITION_TYPE_SELL,3}); fail_position=1; }
  if(index>=3 && index<=6) positions[0].volume=index==3 ? 0 : index==4 ? -1 : index==5 ? NAN : INFINITY;
  if(index==7) positions={{"TEST",POSITION_TYPE_BUY,1e308},{"TEST",POSITION_TYPE_BUY,1e308}};
  if(index==8) { positions.push_back({"OTHER",POSITION_TYPE_SELL,5}); orders={{"TEST",ORDER_TYPE_SELL_STOP,3}}; }
  if(index==9) positions[0].type=2;
  if(index==10) { orders={{"TEST",ORDER_TYPE_BUY_LIMIT,3}}; fail_order=0; }
  PSMarketSnapshot market;
  PS_MarketCalculateDirectionalExposure(market);
  std::cout << market.symbol_ready << ' ' << market.exposure_long << ' ' << market.exposure_short << ' ' << market.current_symbol_positions << '\n';
 }
}
"""
    return [tuple(map(float, line.split())) for line in compile_and_run(tmp_path_factory.mktemp("directional_exposure"), source).splitlines()]


@pytest.mark.parametrize("index,expected", [
    (0, (1, 2, 0, 1)), (1, (0, 0, 0, 0)), (2, (0, 0, 0, 0)), (3, (0, 0, 0, 0)),
    (4, (0, 0, 0, 0)), (5, (0, 0, 0, 0)), (6, (0, 0, 0, 0)), (7, (0, 0, 0, 0)),
    (8, (1, 2, 3, 1)), (9, (0, 0, 0, 0)), (10, (0, 0, 0, 0)),
])
def test_incomplete_directional_enumeration_never_exposes_partial_ready_snapshot(directional_exposure_rows, index, expected):
    assert directional_exposure_rows[index] == expected


@pytest.mark.parametrize("change_positions,change_orders,expected", [
    (False, False, "1 1 1"), (True, False, "0 0 0"), (False, True, "0 0 0"),
])
def test_exposure_calculation_rejects_inventory_count_drift(tmp_path, change_positions, change_orders, expected):
    source = r'''
#include <iostream>
#include <string>
using string=std::string;using ulong=unsigned long long;
struct PSExposureSnapshot {bool enumeration_valid=false;ulong fingerprint=0,calculated_at_ms=0;};
const int ACCOUNT_CURRENCY_DIGITS=0;
bool change_positions=false,change_orders=false;
int position_reads=0,order_reads=0,aggregate_calls=0;
int PositionsTotal(){return ++position_reads>1 && change_positions ? 2 : 1;}
int OrdersTotal(){return ++order_reads>1 && change_orders ? 2 : 1;}
void PS_ExposureReset(PSExposureSnapshot& snapshot){snapshot={};}
bool PS_ExposureAddPosition(PSExposureSnapshot&,int,string&){return true;}
bool PS_ExposureAddPending(PSExposureSnapshot&,int,string&){return true;}
void PS_ExposureAggregate(PSExposureSnapshot&,const string&,double){++aggregate_calls;}
void PS_ExposureSort(PSExposureSnapshot&){}
long AccountInfoInteger(int){return 2;}
ulong PS_ExposureFingerprint(const PSExposureSnapshot&,int){return 1;}
ulong GetTickCount64(){return 1000;}
'''
    source += extract_function(MODULE + "PS_Exposure.mqh", "PS_ExposureCalculate")
    source += f"\nint main(){{change_positions={str(change_positions).lower()};change_orders={str(change_orders).lower()};"
    source += r'''PSExposureSnapshot snapshot;string error;
 bool valid=PS_ExposureCalculate(snapshot,"TEST",1000,error);
 std::cout<<valid<<' '<<snapshot.enumeration_valid<<' '<<aggregate_calls;}'''
    assert compile_and_run(tmp_path, source).strip() == expected
