"""Exercise actual plan/persistence/marker functions without controlling MT5.

Only terminal storage, broker properties, clock and canvas APIs are fixtures.
These cases catch overwritten symbol plans, translated stops and hidden handles.
They do not prove MT5 persistence, native events or broker execution.
"""
import re

from native_mql_harness import ROOT, compile_and_run, extract_functions
from test_native_ui import declaration

MODULE = "MQL5/Experts/LotCraft/"
TYPES = MODULE + "PS_Types.mqh"
RISK = MODULE + "PS_Risk.mqh"
PERSIST = MODULE + "PS_Persistence.mqh"
UI = MODULE + "PS_UI.mqh"
MARKET = MODULE + "PS_Market.mqh"


def model_source():
    return r'''
#include <algorithm>
#include <cassert>
#include <cmath>
#include <cstdio>
#include <iostream>
#include <map>
#include <string>
using string=std::string;
using uint=unsigned int;
#define ulong unsigned long long
using datetime=long long;
struct MqlTick { datetime time=1; double bid=0,ask=0,last=0,volume=0; long long time_msc=0; uint flags=0; double volume_real=0; };
enum ENUM_ORDER_TYPE {ORDER_TYPE_BUY,ORDER_TYPE_SELL,ORDER_TYPE_BUY_LIMIT,ORDER_TYPE_SELL_LIMIT,
 ORDER_TYPE_BUY_STOP,ORDER_TYPE_SELL_STOP,ORDER_TYPE_BUY_STOP_LIMIT,ORDER_TYPE_SELL_STOP_LIMIT,ORDER_TYPE_CLOSE_BY};
const long SYMBOL_ORDER_MARKET=1,SYMBOL_ORDER_LIMIT=2,SYMBOL_ORDER_STOP=4,SYMBOL_ORDER_SL=16,SYMBOL_ORDER_TP=32;
const int PS_DIAGNOSTICS=0;
const double PS_DOUBLE_EPS=1e-12;
const string PS_STATE_NAMESPACE="LotCraft.100";
template<class A,class B> double MathMax(A a,B b){return std::max<double>(a,b);}
template<class A,class B> double MathMin(A a,B b){return std::min<double>(a,b);}
double MathAbs(double v){return std::abs(v);}
double MathCeil(double v){return std::ceil(v);}
double MathFloor(double v){return std::floor(v);}
double MathRound(double v){return std::round(v);}
bool MathIsValidNumber(double v){return std::isfinite(v);}
double NormalizeDouble(double v,int digits){double k=std::pow(10,digits);return std::round(v*k)/k;}
int StringLen(const string& s){return int(s.size());}
uint StringGetCharacter(const string& s,int i){return (unsigned char)s[i];}
string IntegerToString(long long n){return std::to_string(n);}
const char* arg(const string& s){return s.c_str();}
template<class T> T arg(T v){return v;}
template<class... T> string StringFormat(const string& fmt,T... args){char b[512];std::snprintf(b,sizeof b,fmt.c_str(),arg(args)...);return b;}
void PS_LogInfo(const string&){}
void PS_LogWarningRateLimited(const string&,const string&,int){}
int ChartID(){return 1;}
template<class T> void ZeroMemory(T& value){value=T{};}
''' + "\n".join(declaration(TYPES, name) for name in (
        "PSDirection", "PSOrderMode", "PSCommissionMode", "PSAccountMode", "PSRiskAuthority",
        "PSViewMode", "PSThemeMode", "PSCalcIssue", "PSMarketSnapshot", "PSModel", "PSCalcResult",
        "PSRect", "PSExposureScope", "PSExposureUIState",
    )) + extract_functions(TYPES, "PS_IsFinite", "PS_IsPositiveFinite", "PS_NormalizePrice",
                           "PS_HashString32", "PS_CopyModel", "PS_OrderTypeText")


def persistence_source():
    source = (ROOT / PERSIST).read_text(encoding="utf-8-sig")
    source = re.sub(r"(?m)^\s*#.*$", "", source)
    return model_source() + r'''
std::map<string,double> globals;
bool GlobalVariableCheck(const string& key){return globals.count(key)>0;}
double GlobalVariableGet(const string& key){return globals.at(key);}
datetime GlobalVariableSet(const string& key,double value){if(key.size()>63)return 0;globals[key]=value;return 1;}
''' + source


def test_each_symbol_keeps_its_last_stop_after_other_symbols_and_reinitialization(tmp_path):
    program = persistence_source() + r'''
int main(){
  const string base="LotCraft.100.12345678.01234567.76543210";
  PSExposureUIState ui{}; PSMarketSnapshot market{}; PSModel model{};
  model.direction=PS_DIRECTION_LONG;model.order_mode=PS_ORDER_INSTANT;
  model.requested_risk_percent=1;model.manual_account_money=10000;
  market.symbol="EURUSD";model.entry=1.10000;model.stop_loss=1.09500;model.take_profit=1.11000;
  PS_PersistenceSave(base,market,model,ui);
  market.symbol="XAUUSD";model.entry=2650;model.stop_loss=2617.5;model.take_profit=2700;
  model.order_mode=PS_ORDER_PENDING;PS_PersistenceSave(base,market,model,ui);
  PSModel reopened{};market.symbol="EURUSD";
  assert(PS_PersistenceLoad(base,market,reopened,ui));
  assert(reopened.stop_loss==1.09500 && reopened.take_profit==1.11000);
  assert(reopened.order_mode==PS_ORDER_INSTANT);
  reopened.stop_loss=1.09650;PS_PersistenceSave(base,market,reopened,ui);
  market.symbol="XAUUSD";assert(PS_PersistenceLoad(base,market,reopened,ui));
  assert(reopened.stop_loss==2617.5 && reopened.order_mode==PS_ORDER_PENDING);
  market.symbol="EURUSD";assert(PS_PersistenceLoad(base,market,reopened,ui));
  assert(reopened.stop_loss==1.09650);
  assert(!PS_PersistenceLoad(base+"other-chart",market,reopened,ui));
  market.symbol="EURUSD.a";assert(!PS_PersistenceLoad(base,market,reopened,ui));
}
'''
    compile_and_run(tmp_path, program)


def test_legacy_symbol_plan_remains_readable(tmp_path):
    program = persistence_source() + r'''
int main(){
  string base="LotCraft.100.12345678.01234567.76543210";
  globals[base+".plansym"]=PS_HashString32("EURUSD");
  globals[base+".direction"]=PS_DIRECTION_SHORT;globals[base+".ordermode"]=PS_ORDER_PENDING;
  globals[base+".entry"]=1.12;globals[base+".stop"]=1.13;globals[base+".take"]=0;
  PSMarketSnapshot m{};m.symbol="EURUSD";PSModel p{};PSExposureUIState ui{};
  assert(PS_PersistenceLoad(base,m,p,ui));
  assert(p.entry==1.12 && p.stop_loss==1.13 && p.order_mode==PS_ORDER_PENDING);
}
'''
    compile_and_run(tmp_path, program)


def risk_functions():
    return extract_functions(MARKET, "PS_MarketHasUsableQuote", "PS_MarketProtectiveDistance") + extract_functions(
        RISK, "PS_ModelDefaultLevelDistance", "PS_ModelPendingLegGap", "PS_ModelRequiredFreshGap", "PS_ModelPlaceOutward",
        "PS_ModelSyncInstantEntry", "PS_ModelStoredPlanStructurallyValid", "PS_RiskResolveOrder",
        "PS_RiskValidateProtectivePrices", "PS_ModelValidateCandidate", "PS_ModelLimitEntry",
        "PS_ModelStopEntryPreservingSl", "PS_ModelChangeOrderMode", "PS_ModelBuildFreshSymbolPlan",
    )


def risk_source():
    return model_source() + risk_functions()


def test_controller_restores_the_saved_symbol_plan_before_building_a_default(tmp_path):
    program = persistence_source() + risk_functions() + r'''
PSMarketSnapshot g_market{},next_market{};PSModel g_model{};PSExposureUIState g_exposure_ui{};
string g_active_symbol="EURUSD",g_transition_target_symbol="";
string g_persistence_base="LotCraft.100.12345678.01234567.76543210";
bool g_symbol_transition_pending=false,g_exposure_dirty=false;
ulong g_last_market_refresh_ms=0;int g_ui=0;
const int CHART_PRICE_MIN=0,CHART_PRICE_MAX=1,CHART_HEIGHT_IN_PIXELS=2;
double ChartGetDouble(int,int p,int){return next_market.tick.bid*(p==CHART_PRICE_MIN?.9:1.1);}
int ChartGetInteger(int,int,int){return 600;}
ulong GetTickCount64(){return 1000;}
void PS_MarketAcquire(PSMarketSnapshot& m){m=next_market;}
void PS_CopyMarketSnapshot(PSMarketSnapshot& a,const PSMarketSnapshot& b){a=b;}
void PS_AbortInteractionForContextChange(){}
void PS_SetStatus(const string&,bool,int){}
void PS_UIHidePanelContent(int){}
void PS_UIHidePlanningLines(int){}
void PS_UIRenderWaitingPanel(int,const PSModel&,const string&){}
void PS_ModelEnsureInitialPrices(PSModel&,const PSMarketSnapshot&){}
void PS_Recalculate(bool){PS_ModelSyncInstantEntry(g_model,g_market,false);}
void PS_RefreshExposure(bool){}
''' + extract_functions(MODULE + "LotCraft.mq5", "PS_SaveState", "PS_BuildFreshPlan", "PS_RefreshMarket") + r'''
int main(){
  g_market.symbol="EURUSD";g_market.symbol_ready=true;g_market.tick_valid=true;
  g_market.tick.bid=1.1;g_market.tick.ask=1.1002;g_market.tick.time=1;
  g_market.tick_size=.00001;g_market.point=.00001;g_market.digits=5;
  g_market.order_mode=SYMBOL_ORDER_MARKET|SYMBOL_ORDER_LIMIT|SYMBOL_ORDER_STOP|SYMBOL_ORDER_SL|SYMBOL_ORDER_TP;
  g_model.direction=PS_DIRECTION_LONG;g_model.order_mode=PS_ORDER_INSTANT;
  g_model.entry=1.1002;g_model.stop_loss=1.0965;g_model.take_profit=0;
  next_market=g_market;next_market.symbol="XAUUSD";next_market.tick.bid=2650;next_market.tick.ask=2651;
  next_market.point=.01;next_market.tick_size=.01;next_market.digits=2;
  PS_RefreshMarket();assert(g_active_symbol=="XAUUSD"&&!g_symbol_transition_pending);
  g_model.stop_loss=2627.5;
  next_market.symbol="EURUSD";next_market.tick.bid=1.104;next_market.tick.ask=1.1042;
  next_market.point=.00001;next_market.tick_size=.00001;next_market.digits=5;
  PS_RefreshMarket();assert(g_model.stop_loss==1.0965&&g_model.entry==1.1042);
  next_market.symbol="XAUUSD";next_market.tick.bid=2649;next_market.tick.ask=2650;
  next_market.point=.01;next_market.tick_size=.01;next_market.digits=2;
  PS_RefreshMarket();assert(g_model.stop_loss==2627.5&&g_model.entry==2650);
}
'''
    compile_and_run(tmp_path, program)


def test_repeated_mode_changes_preserve_stop_price_on_fx_metals_and_indices(tmp_path):
    program = risk_source() + r'''
int main(){
  double prices[]={1.10,2650,20000,5800,42000,150,65000};
  double ticks[]={.00001,.01,.1,.1,1,.001,.01};
  for(int i=0;i<7;i++)for(int side=0;side<2;side++){
    PSMarketSnapshot m{};m.symbol="TEST";m.digits=5;m.tick_size=ticks[i];m.point=ticks[i];m.tick_valid=true;
    m.tick.bid=prices[i];m.tick.ask=prices[i]+10*ticks[i];m.tick.time=1;
    m.order_mode=SYMBOL_ORDER_MARKET|SYMBOL_ORDER_LIMIT|SYMBOL_ORDER_STOP|SYMBOL_ORDER_SL|SYMBOL_ORDER_TP;
    PSModel p{};p.direction=(PSDirection)side;p.order_mode=PS_ORDER_INSTANT;
    p.entry=side==0?m.tick.ask:m.tick.bid;
    p.stop_loss=PS_NormalizePrice(p.entry+(side==0?-1:1)*prices[i]*.02,m);
    p.take_profit=PS_NormalizePrice(p.entry+(side==0?1:-1)*prices[i]*.03,m);
    double stop=p.stop_loss,take=p.take_profit;string error;
    for(int n=0;n<30;n++){
      assert(PS_ModelChangeOrderMode(p,m,PS_ORDER_PENDING,error));assert(p.stop_loss==stop);
      assert(PS_ModelChangeOrderMode(p,m,PS_ORDER_INSTANT,error));
      assert(p.stop_loss==stop && p.take_profit==take);
    }
  }
}
'''
    compile_and_run(tmp_path, program)


def test_stored_plan_is_preserved_when_current_stop_or_tp_is_not_executable(tmp_path):
    program = risk_source() + r'''
int main(){
  PSMarketSnapshot m{};m.tick_size=.01;m.digits=2;m.tick_valid=true;m.tick.bid=99;m.tick.ask=100;
  m.order_mode=SYMBOL_ORDER_MARKET|SYMBOL_ORDER_LIMIT|SYMBOL_ORDER_STOP|SYMBOL_ORDER_SL|SYMBOL_ORDER_TP;
  PSModel p{};p.direction=PS_DIRECTION_LONG;p.order_mode=PS_ORDER_PENDING;
  p.entry=110;p.stop_loss=105;p.take_profit=101;
  assert(PS_ModelStoredPlanStructurallyValid(p,m));
  string error;assert(PS_ModelChangeOrderMode(p,m,PS_ORDER_INSTANT,error));
  assert(p.stop_loss==105 && p.take_profit==101 && p.entry==100);
  PSCalcResult calc{};assert(!PS_ModelValidateCandidate(p,m,error));
}
'''
    compile_and_run(tmp_path, program)


def test_restricted_order_capability_does_not_trap_the_planning_panel(tmp_path):
    program = risk_source() + r'''
int main(){
  PSMarketSnapshot m{};m.symbol="USTEC";m.symbol_ready=true;m.tick.bid=20000;m.tick.ask=20001;
  m.tick.time=1;m.tick_size=.1;m.point=.1;m.digits=1;m.tick_valid=true;
  m.order_mode=SYMBOL_ORDER_MARKET|SYMBOL_ORDER_SL|SYMBOL_ORDER_TP;
  PSModel p{};p.direction=PS_DIRECTION_LONG;p.order_mode=PS_ORDER_PENDING;
  string error;assert(PS_ModelBuildFreshSymbolPlan(p,m,19900,20100,600,error));
  assert(p.entry>p.stop_loss && p.stop_loss>0 && p.order_mode==PS_ORDER_PENDING);
  assert(!PS_ModelValidateCandidate(p,m,error));
  double stop=p.stop_loss;assert(PS_ModelChangeOrderMode(p,m,PS_ORDER_INSTANT,error));
  assert(p.stop_loss==stop && PS_ModelValidateCandidate(p,m,error));
}
'''
    compile_and_run(tmp_path, program)


def test_close_markers_remain_individually_accessible_without_moving_prices(tmp_path):
    program = model_source() + declaration(TYPES, "PSLevelId") + r'''
using color=int;const int PS_CLR_ACCENT=1,PS_CLR_SHORT=2,PS_CLR_LONG=3,STYLE_SOLID=0,STYLE_DASH=1;
const int CHART_PRICE_MIN=0,CHART_PRICE_MAX=1;
string _Symbol="TEST";int _Period=0;
struct PSUIState{int chart_w=1000,chart_h=600,panel_x=16,panel_y=20,panel_w=438,panel_h=547;bool line_dirty=true;};
PSRect g_ps_handle_rects[3]{};bool g_ps_handle_visible[3]{};double recorded[3]{};double scale=1;
bool g_ps_exposure_labels_layout_dirty=false;
int PS_U(int n){return int(std::round(n*scale));}
int PS_ClampInt(int n,int lo,int hi){return std::min(std::max(n,lo),hi);}
void PS_UISetRect(PSRect& r,int x,int y,int w,int h){r={x,y,w,h};}
bool PS_RectContains(const PSRect& r,int x,int y){return x>=r.x&&x<r.x+r.w&&y>=r.y&&y<r.y+r.h;}
void PS_UISetLine(const PSUIState&,const string& name,double p,bool,color,int){recorded[name=="line.entry"?0:name=="line.stop"?1:2]=p;}
void PS_UISetHandle(const PSUIState&,PSLevelId id,int x,int y,const string&,color,bool show){
 g_ps_handle_rects[id]={x,y,PS_U(36),PS_U(26)};g_ps_handle_visible[id]=show;
}
double ChartGetDouble(int,int property,int){return property==CHART_PRICE_MIN?90:110;}
datetime iTime(const string&,int,int){return 1;}datetime TimeCurrent(){return 1;}
bool ChartTimePriceToXY(int,int,datetime,double p,int& x,int& y){x=100;y=int(std::round((110-p)*30));return true;}
''' + extract_functions(UI, "PS_UIRectIntersects", "PS_UIHandleX", "PS_UIUpdateLines", "PS_UIHitHandle") + r'''
bool overlaps(PSRect a,PSRect b){return a.x<b.x+b.w&&b.x<a.x+a.w&&a.y<b.y+b.h&&b.y<a.y+a.h;}
int main(){
  for(double dpi:{.82,1.,1.5,2.}){
    scale=dpi;PSUIState ui;PSMarketSnapshot m{};PSModel p{};
    p.order_mode=PS_ORDER_PENDING;p.entry=100;p.stop_loss=99.98;p.take_profit=100.02;p.lines_visible=true;
    PS_UIUpdateLines(ui,p,m);
    assert(g_ps_exposure_labels_layout_dirty);
    assert(recorded[0]==100 && recorded[1]==99.98 && recorded[2]==100.02);
    for(int i=0;i<3;i++){
      assert(g_ps_handle_visible[i]);auto r=g_ps_handle_rects[i];assert(r.x>=0&&r.x+r.w<=ui.chart_w);
      bool hit=false;assert(PS_UIHitHandle(r.x+r.w/2,r.y+r.h/2,hit)==i&&hit);
      for(int j=0;j<i;j++)assert(!overlaps(r,g_ps_handle_rects[j]));
    }
    g_ps_exposure_labels_layout_dirty=false;
    p.entry=101;p.stop_loss=100.98;p.take_profit=101.02;
    PS_UIUpdateLines(ui,p,m);
    assert(!g_ps_exposure_labels_layout_dirty); // Price motion alone keeps the label lane.
  }
}
'''
    compile_and_run(tmp_path, program)
