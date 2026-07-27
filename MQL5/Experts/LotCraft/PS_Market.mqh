#ifndef __LOTCRAFT_PS_MARKET_MQH__
#define __LOTCRAFT_PS_MARKET_MQH__

#include "PS_Logging.mqh"

bool PS_MarketSessionState(const string symbol,const datetime server_time,bool &known)
  {
   known=false;
   MqlDateTime parts;
   if(!TimeToStruct(server_time,parts)) return(false);

   int now_seconds=parts.hour*3600+parts.min*60+parts.sec;
   ENUM_DAY_OF_WEEK day=(ENUM_DAY_OF_WEEK)parts.day_of_week;

   for(uint index=0; index<32; index++)
     {
      datetime from=0;
      datetime to=0;
      ResetLastError();
      if(!SymbolInfoSessionTrade(symbol,day,index,from,to))
        {
         if(index==0) known=false;
         break;
        }

      known=true;
      int from_seconds=(int)from;
      int to_seconds=(int)to;
      if(from_seconds==to_seconds) return(true);
      if(from_seconds<to_seconds)
        {
         if(now_seconds>=from_seconds && now_seconds<to_seconds) return(true);
        }
      else
        {
         if(now_seconds>=from_seconds || now_seconds<to_seconds) return(true);
        }
     }
   return(false);
  }

void PS_MarketCalculateDirectionalExposure(PSMarketSnapshot &market)
  {
   market.exposure_long=0.0;
   market.exposure_short=0.0;
   market.current_symbol_positions=0;

   int positions=PositionsTotal();
   for(int i=0;i<positions;i++)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0) continue;
      if(PositionGetString(POSITION_SYMBOL)!=market.symbol) continue;
      market.current_symbol_positions++;
      double volume=PositionGetDouble(POSITION_VOLUME);
      ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type==POSITION_TYPE_BUY) market.exposure_long+=volume;
      else if(type==POSITION_TYPE_SELL) market.exposure_short+=volume;
     }

   int orders=OrdersTotal();
   for(int i=0;i<orders;i++)
     {
      ulong ticket=OrderGetTicket(i);
      if(ticket==0) continue;
      if(OrderGetString(ORDER_SYMBOL)!=market.symbol) continue;
      ENUM_ORDER_TYPE type=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      double volume=OrderGetDouble(ORDER_VOLUME_CURRENT);
      if(PS_IsBuyOrderType(type)) market.exposure_long+=volume;
      else if(PS_IsSellOrderType(type)) market.exposure_short+=volume;
     }
  }

bool PS_MarketAcquire(PSMarketSnapshot &market)
  {
   ulong started=GetMicrosecondCount();
   ZeroMemory(market);
   market.symbol=_Symbol;
   market.error="";

   market.terminal_connected=(bool)TerminalInfoInteger(TERMINAL_CONNECTED);
   market.terminal_trade_allowed=(bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED);
   market.mql_trade_allowed=(bool)MQLInfoInteger(MQL_TRADE_ALLOWED);
   market.dlls_allowed=(bool)MQLInfoInteger(MQL_DLLS_ALLOWED);
   market.account_trade_allowed=(bool)AccountInfoInteger(ACCOUNT_TRADE_ALLOWED);
   market.account_expert_allowed=(bool)AccountInfoInteger(ACCOUNT_TRADE_EXPERT);
   market.account_login=AccountInfoInteger(ACCOUNT_LOGIN);
   market.account_margin_mode=AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   market.account_trade_mode=AccountInfoInteger(ACCOUNT_TRADE_MODE);
   market.account_currency=AccountInfoString(ACCOUNT_CURRENCY);
   market.account_server=AccountInfoString(ACCOUNT_SERVER);
   market.currency_digits=(int)AccountInfoInteger(ACCOUNT_CURRENCY_DIGITS);
   if(market.currency_digits<0 || market.currency_digits>8) market.currency_digits=2;
   market.balance=AccountInfoDouble(ACCOUNT_BALANCE);
   market.equity=AccountInfoDouble(ACCOUNT_EQUITY);
   market.server_time=TimeTradeServer();
   if(market.server_time<=0) market.server_time=TimeCurrent();

   market.symbol_ready=SymbolIsSynchronized(market.symbol);
   market.digits=(int)SymbolInfoInteger(market.symbol,SYMBOL_DIGITS);
   market.point=SymbolInfoDouble(market.symbol,SYMBOL_POINT);
   market.tick_size=SymbolInfoDouble(market.symbol,SYMBOL_TRADE_TICK_SIZE);
   market.tick_value_profit=SymbolInfoDouble(market.symbol,SYMBOL_TRADE_TICK_VALUE_PROFIT);
   market.tick_value_loss=SymbolInfoDouble(market.symbol,SYMBOL_TRADE_TICK_VALUE_LOSS);
   market.contract_size=SymbolInfoDouble(market.symbol,SYMBOL_TRADE_CONTRACT_SIZE);
   market.volume_min=SymbolInfoDouble(market.symbol,SYMBOL_VOLUME_MIN);
   market.volume_max=SymbolInfoDouble(market.symbol,SYMBOL_VOLUME_MAX);
   market.volume_step=SymbolInfoDouble(market.symbol,SYMBOL_VOLUME_STEP);
   market.volume_limit=SymbolInfoDouble(market.symbol,SYMBOL_VOLUME_LIMIT);
   market.stops_level_points=SymbolInfoInteger(market.symbol,SYMBOL_TRADE_STOPS_LEVEL);
   market.freeze_level_points=SymbolInfoInteger(market.symbol,SYMBOL_TRADE_FREEZE_LEVEL);
   market.trade_mode=SymbolInfoInteger(market.symbol,SYMBOL_TRADE_MODE);
   market.execution_mode=SymbolInfoInteger(market.symbol,SYMBOL_TRADE_EXEMODE);
   market.filling_mode=SymbolInfoInteger(market.symbol,SYMBOL_FILLING_MODE);
   market.expiration_mode=SymbolInfoInteger(market.symbol,SYMBOL_EXPIRATION_MODE);
   market.order_mode=SymbolInfoInteger(market.symbol,SYMBOL_ORDER_MODE);
   market.calc_mode=SymbolInfoInteger(market.symbol,SYMBOL_TRADE_CALC_MODE);

   ResetLastError();
   market.tick_valid=SymbolInfoTick(market.symbol,market.tick);
   if(!market.tick_valid)
     {
      market.error=StringFormat("No quote is available for %s (error %d).",market.symbol,GetLastError());
     }
   else if(!PS_IsPositiveFinite(market.tick.bid) || !PS_IsPositiveFinite(market.tick.ask) || market.tick.ask<market.tick.bid)
     {
      market.tick_valid=false;
      market.error="The current Bid/Ask quote is invalid.";
     }
   else if(market.tick.time<=0 || (market.server_time>market.tick.time && market.server_time-market.tick.time>PS_QUOTE_STALE_SECONDS))
     {
      market.tick_valid=false;
      market.error=StringFormat("The latest quote is older than %d seconds.",PS_QUOTE_STALE_SECONDS);
     }

   if(market.digits<0 || market.digits>12)
     {
      market.symbol_ready=false;
      market.error="The broker reported invalid symbol digits.";
     }
   else if(!PS_IsPositiveFinite(market.point) || !PS_IsPositiveFinite(market.tick_size))
     {
      market.symbol_ready=false;
      market.error="The broker reported an invalid point or tick size.";
     }
   else if(!PS_IsPositiveFinite(market.contract_size))
     {
      market.symbol_ready=false;
      market.error="The broker reported an invalid contract size.";
     }
   else if(!PS_IsPositiveFinite(market.volume_min) || !PS_IsPositiveFinite(market.volume_max) ||
           !PS_IsPositiveFinite(market.volume_step) || market.volume_max<market.volume_min)
     {
      market.symbol_ready=false;
      market.error="The broker reported invalid volume constraints.";
     }

   market.session_open=PS_MarketSessionState(market.symbol,market.server_time,market.session_known);
   PS_MarketCalculateDirectionalExposure(market);
   PS_PerfCheck("market",started,PS_CALC_BUDGET_US);
   return(market.symbol_ready && market.tick_valid);
  }

double PS_MarketProtectiveDistance(const PSMarketSnapshot &market,const bool include_freeze)
  {
   long points=market.stops_level_points;
   if(include_freeze && market.freeze_level_points>points) points=market.freeze_level_points;
   double distance=(double)points*market.point;
   if(distance<market.tick_size) distance=market.tick_size;
   return(distance);
  }

bool PS_MarketDirectionPermitted(const PSMarketSnapshot &market,const PSDirection direction,string &error)
  {
   error="";
   ENUM_SYMBOL_TRADE_MODE mode=(ENUM_SYMBOL_TRADE_MODE)market.trade_mode;
   if(mode==SYMBOL_TRADE_MODE_DISABLED)
     {
      error="Trading is disabled for this symbol.";
      return(false);
     }
   if(mode==SYMBOL_TRADE_MODE_CLOSEONLY)
     {
      error="The symbol is in close-only mode.";
      return(false);
     }
   if(direction==PS_DIRECTION_LONG && mode==SYMBOL_TRADE_MODE_SHORTONLY)
     {
      error="The symbol currently permits short trades only.";
      return(false);
     }
   if(direction==PS_DIRECTION_SHORT && mode==SYMBOL_TRADE_MODE_LONGONLY)
     {
      error="The symbol currently permits long trades only.";
      return(false);
     }
   return(true);
  }

#endif
