#ifndef __LOTCRAFT_PS_TYPES_MQH__
#define __LOTCRAFT_PS_TYPES_MQH__

#define PS_PRODUCT_NAME              "LotCraft"
#define PS_VERSION_TEXT              "1.0.0"
#define PS_SOURCE_NAME               "LotCraft.mq5"
#define PS_BINARY_NAME               "LotCraft.ex5"
#define PS_LOG_PREFIX                "LotCraft"
#define PS_OBJECT_NAMESPACE          "LotCraft.v100"
#define PS_STATE_NAMESPACE           "LotCraft.100"
#define PS_REQUEST_COMMENT           "LotCraft 1.0.0"

#define PS_DIAGNOSTICS               0
#define PS_POINTER_BUDGET_US         2000
#define PS_CALC_BUDGET_US            1500
#define PS_RENDER_BUDGET_US          8000
#define PS_TRADE_VALIDATE_BUDGET_US  20000

#define PS_QUOTE_STALE_SECONDS       60
#define PS_DOUBLE_EPS                1.0e-12
#define PS_MAX_STATUS_CHARS          160

enum PSDirection
  {
   PS_DIRECTION_LONG=0,
   PS_DIRECTION_SHORT=1
  };

enum PSOrderMode
  {
   PS_ORDER_INSTANT=0,
   PS_ORDER_PENDING=1
  };

enum PSCommissionMode
  {
   PS_COMMISSION_ONE_SIDE=0,
   PS_COMMISSION_ROUND_TRIP=1
  };

enum PSAccountMode
  {
   PS_ACCOUNT_EQUITY=0,
   PS_ACCOUNT_BALANCE=1,
   PS_ACCOUNT_MANUAL=2
  };

enum PSRiskAuthority
  {
   PS_RISK_PERCENT=0,
   PS_RISK_MONEY=1
  };

enum PSViewMode
  {
   PS_VIEW_FULL=0,
   PS_VIEW_COMPACT=1,
   PS_VIEW_MINI=2
  };

enum PSThemeMode
  {
   PS_THEME_DARK=0,
   PS_THEME_LIGHT=1
  };

enum PSFieldId
  {
   PS_FIELD_NONE=-1,
   PS_FIELD_ENTRY=0,
   PS_FIELD_STOP=1,
   PS_FIELD_TAKE=2,
   PS_FIELD_COMMISSION=3,
   PS_FIELD_ACCOUNT=4,
   PS_FIELD_RISK_PERCENT=5,
   PS_FIELD_RISK_MONEY=6
  };

enum PSControlId
  {
   PS_CTRL_NONE=-1,
   PS_CTRL_MANUAL=0,
   PS_CTRL_COMPACT,
   PS_CTRL_MINI,
   PS_CTRL_THEME,
   PS_CTRL_CLOSE,
   PS_CTRL_DIRECTION,
   PS_CTRL_ENTRY_FIELD,
   PS_CTRL_ENTRY_MINUS,
   PS_CTRL_ENTRY_PLUS,
   PS_CTRL_ENTRY_COPY,
   PS_CTRL_STOP_FIELD,
   PS_CTRL_STOP_MINUS,
   PS_CTRL_STOP_PLUS,
   PS_CTRL_STOP_COPY,
   PS_CTRL_TAKE_FIELD,
   PS_CTRL_TAKE_MINUS,
   PS_CTRL_TAKE_PLUS,
   PS_CTRL_TAKE_COPY,
   PS_CTRL_ORDER_MODE,
   PS_CTRL_LINES,
   PS_CTRL_COMMISSION_MODE,
   PS_CTRL_COMMISSION_FIELD,
   PS_CTRL_ACCOUNT_MODE,
   PS_CTRL_ACCOUNT_FIELD,
   PS_CTRL_RISK_PERCENT_FIELD,
   PS_CTRL_RISK_MONEY_FIELD,
   PS_CTRL_ACTUAL_PERCENT,
   PS_CTRL_ACTUAL_MONEY,
   PS_CTRL_POSITION_SIZE,
   PS_CTRL_POSITION_COPY,
   PS_CTRL_MOVE_SLS,
   PS_CTRL_CONFIRM,
   PS_CTRL_TRADE,
   PS_CTRL_COUNT
  };

enum PSCaptureMode
  {
   PS_CAPTURE_NONE=0,
   PS_CAPTURE_PANEL=1,
   PS_CAPTURE_HANDLE_ENTRY=2,
   PS_CAPTURE_HANDLE_STOP=3,
   PS_CAPTURE_HANDLE_TAKE=4,
   PS_CAPTURE_CONTROL=5,
   PS_CAPTURE_STEPPER=6
  };

enum PSLevelId
  {
   PS_LEVEL_ENTRY=0,
   PS_LEVEL_STOP=1,
   PS_LEVEL_TAKE=2
  };

struct PSRect
  {
   int x;
   int y;
   int w;
   int h;
  };

struct PSMarketSnapshot
  {
   string symbol;
   MqlTick tick;
   bool tick_valid;
   bool symbol_ready;
   bool session_open;
   bool session_known;
   bool terminal_connected;
   bool terminal_trade_allowed;
   bool mql_trade_allowed;
   bool dlls_allowed;
   bool account_trade_allowed;
   bool account_expert_allowed;
   int digits;
   int currency_digits;
   double point;
   double tick_size;
   double tick_value_profit;
   double tick_value_loss;
   double contract_size;
   double volume_min;
   double volume_max;
   double volume_step;
   double volume_limit;
   double exposure_long;
   double exposure_short;
   int current_symbol_positions;
   long stops_level_points;
   long freeze_level_points;
   long trade_mode;
   long execution_mode;
   long filling_mode;
   long expiration_mode;
   long order_mode;
   long calc_mode;
   long account_login;
   long account_margin_mode;
   long account_trade_mode;
   string account_currency;
   string account_server;
   double balance;
   double equity;
   datetime server_time;
   string error;
  };

struct PSModel
  {
   PSDirection direction;
   PSOrderMode order_mode;
   PSCommissionMode commission_mode;
   PSAccountMode account_mode;
   PSRiskAuthority risk_authority;
   PSViewMode view_mode;
   PSThemeMode theme_mode;
   bool ask_confirmation;
   bool lines_visible;
   double entry;
   double stop_loss;
   double take_profit;
   double commission_per_lot;
   double manual_account_money;
   double requested_risk_percent;
   double requested_risk_money;
   string status;
   bool status_is_error;
   ulong revision;
  };

struct PSCalcResult
  {
   bool valid;
   bool quote_valid;
   bool tp_enabled;
   bool volume_capped;
   bool pending_ambiguous;
   string error;
   string notice;
   double account_basis;
   double effective_entry;
   double requested_money;
   double requested_percent;
   double one_lot_loss;
   double commission_risk_per_lot;
   double raw_volume;
   double volume;
   double actual_money;
   double actual_percent;
   double directional_exposure;
   double remaining_volume_limit;
   ENUM_ORDER_TYPE resolved_order_type;
   string resolved_order_text;
  };

struct PSEditorState
  {
   bool active;
   PSFieldId field;
   string raw_text;
   string original_text;
   int cursor;
   int anchor;
   bool has_selection;
   PSModel before;
  };

struct PSPointerState
  {
   PSCaptureMode capture;
   PSControlId control;
   int start_x;
   int start_y;
   int last_x;
   int last_y;
   int panel_offset_x;
   int panel_offset_y;
   int applied_x;
   int applied_y;
   int native_offset_x;
   int native_offset_y;
   uint last_mouse_mask;
   bool pointer_inside_guard;
   bool drag_started;
   bool editor_double_click;
   bool native_pointer_calibrated;
   bool stepper_active;
   bool stepper_pointer_inside;
   ulong press_ms;
   ulong last_repeat_ms;
   ulong last_button_action_ms;
  };

struct PSUIState
  {
   int panel_x;
   int panel_y;
   int panel_w;
   int panel_h;
   int chart_w;
   int chart_h;
   bool created;
   bool dirty;
   bool line_dirty;
   bool guard_saved;
   bool saved_mouse_scroll;
   bool saved_context_menu;
   bool saved_crosshair;
   bool saved_drag_trade_levels;
   bool saved_keyboard_control;
   bool saved_quick_navigation;
   bool event_mouse_move_original;
   bool event_mouse_wheel_original;
   bool events_initialized;
   string prefix;
  };

struct PSTradeSnapshot
  {
   bool valid;
   string error;
   string symbol;
   PSDirection direction;
   PSOrderMode order_mode;
   ENUM_ORDER_TYPE order_type;
   string order_text;
   double entry;
   double stop_loss;
   double take_profit;
   bool tp_enabled;
   double volume;
   double requested_money;
   double actual_money;
   double requested_percent;
   double actual_percent;
   PSAccountMode account_mode;
   double account_basis;
   PSCommissionMode commission_mode;
   double commission_per_lot;
   MqlTradeRequest request;
  };

struct PSSlTarget
  {
   bool is_position;
   ulong ticket;
   string symbol;
   PSDirection direction;
   double entry;
   double old_sl;
   double tp;
   double target_sl;
   double price;
   double stoplimit;
   datetime expiration;
   ENUM_ORDER_TYPE order_type;
   ENUM_ORDER_TYPE_TIME type_time;
   ENUM_ORDER_TYPE_FILLING type_filling;
  };

// Explicit copies avoid compiler-version-dependent implicit copy construction for
// structures that contain strings or nested trade structures.
void PS_CopyMqlTick(MqlTick &destination,const MqlTick &source)
  {
   destination.time=source.time;
   destination.bid=source.bid;
   destination.ask=source.ask;
   destination.last=source.last;
   destination.volume=source.volume;
   destination.time_msc=source.time_msc;
   destination.flags=source.flags;
   destination.volume_real=source.volume_real;
  }

void PS_CopyTradeRequest(MqlTradeRequest &destination,const MqlTradeRequest &source)
  {
   ZeroMemory(destination);
   destination.action=source.action;
   destination.magic=source.magic;
   destination.order=source.order;
   destination.symbol=source.symbol;
   destination.volume=source.volume;
   destination.price=source.price;
   destination.stoplimit=source.stoplimit;
   destination.sl=source.sl;
   destination.tp=source.tp;
   destination.deviation=source.deviation;
   destination.type=source.type;
   destination.type_filling=source.type_filling;
   destination.type_time=source.type_time;
   destination.expiration=source.expiration;
   destination.comment=source.comment;
   destination.position=source.position;
   destination.position_by=source.position_by;
  }

void PS_CopyMarketSnapshot(PSMarketSnapshot &destination,const PSMarketSnapshot &source)
  {
   destination.symbol=source.symbol;
   PS_CopyMqlTick(destination.tick,source.tick);
   destination.tick_valid=source.tick_valid;
   destination.symbol_ready=source.symbol_ready;
   destination.session_open=source.session_open;
   destination.session_known=source.session_known;
   destination.terminal_connected=source.terminal_connected;
   destination.terminal_trade_allowed=source.terminal_trade_allowed;
   destination.mql_trade_allowed=source.mql_trade_allowed;
   destination.dlls_allowed=source.dlls_allowed;
   destination.account_trade_allowed=source.account_trade_allowed;
   destination.account_expert_allowed=source.account_expert_allowed;
   destination.digits=source.digits;
   destination.currency_digits=source.currency_digits;
   destination.point=source.point;
   destination.tick_size=source.tick_size;
   destination.tick_value_profit=source.tick_value_profit;
   destination.tick_value_loss=source.tick_value_loss;
   destination.contract_size=source.contract_size;
   destination.volume_min=source.volume_min;
   destination.volume_max=source.volume_max;
   destination.volume_step=source.volume_step;
   destination.volume_limit=source.volume_limit;
   destination.exposure_long=source.exposure_long;
   destination.exposure_short=source.exposure_short;
   destination.current_symbol_positions=source.current_symbol_positions;
   destination.stops_level_points=source.stops_level_points;
   destination.freeze_level_points=source.freeze_level_points;
   destination.trade_mode=source.trade_mode;
   destination.execution_mode=source.execution_mode;
   destination.filling_mode=source.filling_mode;
   destination.expiration_mode=source.expiration_mode;
   destination.order_mode=source.order_mode;
   destination.calc_mode=source.calc_mode;
   destination.account_login=source.account_login;
   destination.account_margin_mode=source.account_margin_mode;
   destination.account_trade_mode=source.account_trade_mode;
   destination.account_currency=source.account_currency;
   destination.account_server=source.account_server;
   destination.balance=source.balance;
   destination.equity=source.equity;
   destination.server_time=source.server_time;
   destination.error=source.error;
  }

void PS_CopyModel(PSModel &destination,const PSModel &source)
  {
   destination.direction=source.direction;
   destination.order_mode=source.order_mode;
   destination.commission_mode=source.commission_mode;
   destination.account_mode=source.account_mode;
   destination.risk_authority=source.risk_authority;
   destination.view_mode=source.view_mode;
   destination.theme_mode=source.theme_mode;
   destination.ask_confirmation=source.ask_confirmation;
   destination.lines_visible=source.lines_visible;
   destination.entry=source.entry;
   destination.stop_loss=source.stop_loss;
   destination.take_profit=source.take_profit;
   destination.commission_per_lot=source.commission_per_lot;
   destination.manual_account_money=source.manual_account_money;
   destination.requested_risk_percent=source.requested_risk_percent;
   destination.requested_risk_money=source.requested_risk_money;
   destination.status=source.status;
   destination.status_is_error=source.status_is_error;
   destination.revision=source.revision;
  }

void PS_CopyTradeSnapshot(PSTradeSnapshot &destination,const PSTradeSnapshot &source)
  {
   destination.valid=source.valid;
   destination.error=source.error;
   destination.symbol=source.symbol;
   destination.direction=source.direction;
   destination.order_mode=source.order_mode;
   destination.order_type=source.order_type;
   destination.order_text=source.order_text;
   destination.entry=source.entry;
   destination.stop_loss=source.stop_loss;
   destination.take_profit=source.take_profit;
   destination.tp_enabled=source.tp_enabled;
   destination.volume=source.volume;
   destination.requested_money=source.requested_money;
   destination.actual_money=source.actual_money;
   destination.requested_percent=source.requested_percent;
   destination.actual_percent=source.actual_percent;
   destination.account_mode=source.account_mode;
   destination.account_basis=source.account_basis;
   destination.commission_mode=source.commission_mode;
   destination.commission_per_lot=source.commission_per_lot;
   PS_CopyTradeRequest(destination.request,source.request);
  }

void PS_CopySlTarget(PSSlTarget &destination,const PSSlTarget &source)
  {
   destination.is_position=source.is_position;
   destination.ticket=source.ticket;
   destination.symbol=source.symbol;
   destination.direction=source.direction;
   destination.entry=source.entry;
   destination.old_sl=source.old_sl;
   destination.tp=source.tp;
   destination.target_sl=source.target_sl;
   destination.price=source.price;
   destination.stoplimit=source.stoplimit;
   destination.expiration=source.expiration;
   destination.order_type=source.order_type;
   destination.type_time=source.type_time;
   destination.type_filling=source.type_filling;
  }

bool PS_RectContains(const PSRect &r,const int x,const int y)
  {
   return(x>=r.x && y>=r.y && x<r.x+r.w && y<r.y+r.h);
  }

int PS_ClampInt(const int value,const int low,const int high)
  {
   if(value<low) return(low);
   if(value>high) return(high);
   return(value);
  }

double PS_ClampDouble(const double value,const double low,const double high)
  {
   if(value<low) return(low);
   if(value>high) return(high);
   return(value);
  }

bool PS_IsFinite(const double value)
  {
   return(MathIsValidNumber(value));
  }

bool PS_IsPositiveFinite(const double value)
  {
   return(MathIsValidNumber(value) && value>0.0);
  }

int PS_DecimalsForStep(const double step)
  {
   if(!PS_IsPositiveFinite(step)) return(2);
   for(int digits=0; digits<=8; digits++)
     {
      if(MathAbs(step-NormalizeDouble(step,digits))<=MathMax(PS_DOUBLE_EPS,step*1.0e-9))
         return(digits);
     }
   return(8);
  }

double PS_NormalizePrice(const double price,const PSMarketSnapshot &market)
  {
   if(!PS_IsFinite(price) || !PS_IsPositiveFinite(market.tick_size)) return(0.0);
   double steps=MathRound(price/market.tick_size);
   double normalized=steps*market.tick_size;
   return(NormalizeDouble(normalized,market.digits));
  }

double PS_FloorVolume(const double requested,const double minimum,const double maximum,const double step)
  {
   if(!PS_IsPositiveFinite(requested) || !PS_IsPositiveFinite(minimum) ||
      !PS_IsPositiveFinite(maximum) || !PS_IsPositiveFinite(step) || maximum<minimum)
      return(0.0);

   double capped=MathMin(requested,maximum);
   double epsilon=step*1.0e-9;
   if(capped+epsilon<minimum) return(0.0);

   double count=MathFloor((capped-minimum+epsilon)/step);
   double volume=minimum+count*step;
   if(volume>capped+epsilon) volume-=step;
   if(volume+epsilon<minimum) return(0.0);
   if(volume>maximum) volume=maximum;

   int digits=PS_DecimalsForStep(step);
   volume=NormalizeDouble(volume,digits);
   if(volume>capped+epsilon) volume=NormalizeDouble(volume-step,digits);
   if(volume+epsilon<minimum) return(0.0);
   return(volume);
  }

string PS_DirectionText(const PSDirection direction)
  {
   return(direction==PS_DIRECTION_LONG ? "Long" : "Short");
  }

string PS_OrderModeText(const PSOrderMode mode)
  {
   return(mode==PS_ORDER_INSTANT ? "Instant" : "Pending");
  }

string PS_CommissionModeText(const PSCommissionMode mode)
  {
   return(mode==PS_COMMISSION_ONE_SIDE ? "One side" : "Round trip");
  }

string PS_AccountModeText(const PSAccountMode mode)
  {
   if(mode==PS_ACCOUNT_EQUITY) return("Equity");
   if(mode==PS_ACCOUNT_BALANCE) return("Balance");
   return("Manual");
  }

string PS_PriceText(const double value,const PSMarketSnapshot &market)
  {
   if(!PS_IsFinite(value)) return("—");
   return(DoubleToString(value,market.digits));
  }

string PS_MoneyText(const double value,const PSMarketSnapshot &market)
  {
   if(!PS_IsFinite(value)) return("—");
   return(DoubleToString(value,market.currency_digits));
  }

string PS_PercentText(const double value)
  {
   if(!PS_IsFinite(value)) return("—");
   return(DoubleToString(value,2));
  }

string PS_VolumeText(const double value,const PSMarketSnapshot &market)
  {
   if(!PS_IsFinite(value) || value<=0.0) return("0");
   return(DoubleToString(value,PS_DecimalsForStep(market.volume_step)));
  }

uint PS_HashString32(const string text)
  {
   uint hash=2166136261;
   int length=StringLen(text);
   for(int i=0;i<length;i++)
     {
      uint ch=(uint)StringGetCharacter(text,i);
      hash^=ch;
      hash*=16777619;
     }
   return(hash);
  }

string PS_Upper(const string text)
  {
   string value=text;
   StringToUpper(value);
   return(value);
  }

string PS_TruncateStatus(const string text)
  {
   if(StringLen(text)<=PS_MAX_STATUS_CHARS) return(text);
   return(StringSubstr(text,0,PS_MAX_STATUS_CHARS-1)+"…");
  }

bool PS_IsBuyOrderType(const ENUM_ORDER_TYPE type)
  {
   return(type==ORDER_TYPE_BUY || type==ORDER_TYPE_BUY_LIMIT || type==ORDER_TYPE_BUY_STOP ||
          type==ORDER_TYPE_BUY_STOP_LIMIT);
  }

bool PS_IsSellOrderType(const ENUM_ORDER_TYPE type)
  {
   return(type==ORDER_TYPE_SELL || type==ORDER_TYPE_SELL_LIMIT || type==ORDER_TYPE_SELL_STOP ||
          type==ORDER_TYPE_SELL_STOP_LIMIT);
  }

string PS_OrderTypeText(const ENUM_ORDER_TYPE type)
  {
   switch(type)
     {
      case ORDER_TYPE_BUY:             return("Buy market");
      case ORDER_TYPE_SELL:            return("Sell market");
      case ORDER_TYPE_BUY_LIMIT:       return("Buy Limit");
      case ORDER_TYPE_SELL_LIMIT:      return("Sell Limit");
      case ORDER_TYPE_BUY_STOP:        return("Buy Stop");
      case ORDER_TYPE_SELL_STOP:       return("Sell Stop");
      case ORDER_TYPE_BUY_STOP_LIMIT:  return("Buy Stop Limit");
      case ORDER_TYPE_SELL_STOP_LIMIT: return("Sell Stop Limit");
      default:                          return("Unknown");
     }
  }

#endif
