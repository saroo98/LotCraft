#ifndef __LOTCRAFT_PS_TRADE_MQH__
#define __LOTCRAFT_PS_TRADE_MQH__

#include "PS_UI.mqh"

ulong PS_TradeMagic(const PSMarketSnapshot &market)
  {
   string seed=PS_PRODUCT_NAME+"|"+market.account_server+"|"+market.symbol+"|"+IntegerToString(ChartID());
   return((ulong)100000000+(ulong)PS_HashString32(seed));
  }

bool PS_TradeRetcodeAccepted(const uint retcode)
  {
   return(retcode==TRADE_RETCODE_DONE || retcode==TRADE_RETCODE_PLACED || retcode==TRADE_RETCODE_DONE_PARTIAL);
  }

string PS_TradeRetcodeText(const uint retcode)
  {
   switch(retcode)
     {
      case TRADE_RETCODE_REQUOTE:          return("requote");
      case TRADE_RETCODE_REJECT:           return("request rejected");
      case TRADE_RETCODE_CANCEL:           return("request canceled by server");
      case TRADE_RETCODE_PLACED:           return("order placed");
      case TRADE_RETCODE_DONE:             return("request completed");
      case TRADE_RETCODE_DONE_PARTIAL:     return("request partially completed");
      case TRADE_RETCODE_ERROR:            return("request processing error");
      case TRADE_RETCODE_TIMEOUT:          return("request timed out");
      case TRADE_RETCODE_INVALID:          return("invalid request");
      case TRADE_RETCODE_INVALID_VOLUME:   return("invalid volume");
      case TRADE_RETCODE_INVALID_PRICE:    return("invalid price");
      case TRADE_RETCODE_INVALID_STOPS:    return("invalid stops");
      case TRADE_RETCODE_TRADE_DISABLED:   return("trading disabled");
      case TRADE_RETCODE_MARKET_CLOSED:    return("market closed");
      case TRADE_RETCODE_NO_MONEY:         return("insufficient funds");
      case TRADE_RETCODE_PRICE_CHANGED:    return("price changed");
      case TRADE_RETCODE_PRICE_OFF:        return("no executable quote");
      case TRADE_RETCODE_INVALID_EXPIRATION:return("invalid expiration");
      case TRADE_RETCODE_TOO_MANY_REQUESTS:return("too many requests");
      case TRADE_RETCODE_NO_CHANGES:       return("no changes");
      case TRADE_RETCODE_SERVER_DISABLES_AT:return("server disabled automated trading");
      case TRADE_RETCODE_CLIENT_DISABLES_AT:return("terminal disabled automated trading");
      case TRADE_RETCODE_LOCKED:           return("request locked for processing");
      case TRADE_RETCODE_FROZEN:           return("order or position frozen");
      case TRADE_RETCODE_INVALID_FILL:     return("unsupported filling policy");
      case TRADE_RETCODE_CONNECTION:       return("no trade-server connection");
      case TRADE_RETCODE_LIMIT_ORDERS:     return("pending-order limit reached");
      case TRADE_RETCODE_LIMIT_VOLUME:     return("symbol volume limit reached");
      case TRADE_RETCODE_INVALID_ORDER:    return("unsupported order type");
      default:                              return(StringFormat("server retcode %u",retcode));
     }
  }

bool PS_TradePermissions(const PSMarketSnapshot &market,const PSDirection direction,string &error)
  {
   error="";
   if(!market.terminal_connected)
     {
      error="The terminal is not connected to a trade server.";
      return(false);
     }
   if(!market.terminal_trade_allowed)
     {
      error="Automated trading is disabled in the terminal.";
      return(false);
     }
   if(!market.mql_trade_allowed)
     {
      error="Trading is not permitted for this EA instance.";
      return(false);
     }
   if(!market.account_trade_allowed || !market.account_expert_allowed)
     {
      error="The account does not permit Expert Advisor trading.";
      return(false);
     }
   if(market.session_known && !market.session_open)
     {
      error="No broker trading session is currently open for this symbol.";
      return(false);
     }
   return(PS_MarketDirectionPermitted(market,direction,error));
  }

bool PS_TradeChooseFilling(const PSMarketSnapshot &market,const bool pending,
                           ENUM_ORDER_TYPE_FILLING &filling,string &error)
  {
   error="";
   if(pending)
     {
      filling=ORDER_FILLING_RETURN;
      return(true);
     }

   ENUM_SYMBOL_TRADE_EXECUTION execution=(ENUM_SYMBOL_TRADE_EXECUTION)market.execution_mode;
   if(execution!=SYMBOL_TRADE_EXECUTION_MARKET)
     {
      filling=ORDER_FILLING_RETURN;
      return(true);
     }
   if((market.filling_mode & SYMBOL_FILLING_FOK)==SYMBOL_FILLING_FOK)
     {
      filling=ORDER_FILLING_FOK;
      return(true);
     }
   if((market.filling_mode & SYMBOL_FILLING_IOC)==SYMBOL_FILLING_IOC)
     {
      filling=ORDER_FILLING_IOC;
      return(true);
     }
   error="The symbol exposes no supported market filling policy.";
   return(false);
  }

bool PS_TradeChooseExpiration(const PSMarketSnapshot &market,ENUM_ORDER_TYPE_TIME &type_time,string &error)
  {
   error="";
   if((market.expiration_mode & SYMBOL_EXPIRATION_GTC)==SYMBOL_EXPIRATION_GTC)
     {
      type_time=ORDER_TIME_GTC;
      return(true);
     }
   if((market.expiration_mode & SYMBOL_EXPIRATION_DAY)==SYMBOL_EXPIRATION_DAY)
     {
      type_time=ORDER_TIME_DAY;
      return(true);
     }
   error="The symbol requires a specified pending-order expiration, but no expiration control is permitted.";
   return(false);
  }

bool PS_TradeBuildSnapshot(const PSModel &model,const PSMarketSnapshot &market,const PSCalcResult &calc,
                           PSTradeSnapshot &snapshot)
  {
   ZeroMemory(snapshot);
   snapshot.valid=false;
   snapshot.error="";
   if(!calc.valid)
     {
      snapshot.error=(calc.error!="" ? calc.error : "The sizing configuration is invalid.");
      return(false);
     }

   string error="";
   if(!PS_TradePermissions(market,model.direction,error))
     {
      snapshot.error=error;
      return(false);
     }

   snapshot.symbol=market.symbol;
   snapshot.direction=model.direction;
   snapshot.order_mode=model.order_mode;
   snapshot.order_type=calc.resolved_order_type;
   snapshot.order_text=calc.resolved_order_text;
   snapshot.entry=calc.effective_entry;
   snapshot.stop_loss=PS_NormalizePrice(model.stop_loss,market);
   snapshot.take_profit=(calc.tp_enabled ? PS_NormalizePrice(model.take_profit,market) : 0.0);
   snapshot.tp_enabled=calc.tp_enabled;
   snapshot.volume=calc.volume;
   snapshot.requested_money=calc.requested_money;
   snapshot.actual_money=calc.actual_money;
   snapshot.requested_percent=calc.requested_percent;
   snapshot.actual_percent=calc.actual_percent;
   snapshot.account_mode=model.account_mode;
   snapshot.account_basis=calc.account_basis;
   snapshot.commission_mode=model.commission_mode;
   snapshot.commission_per_lot=model.commission_per_lot;

   MqlTradeRequest request={};
   request.action=(model.order_mode==PS_ORDER_INSTANT ? TRADE_ACTION_DEAL : TRADE_ACTION_PENDING);
   request.magic=PS_TradeMagic(market);
   request.symbol=market.symbol;
   request.volume=calc.volume;
   request.type=calc.resolved_order_type;
   request.price=calc.effective_entry;
   request.sl=snapshot.stop_loss;
   request.tp=snapshot.take_profit;
   request.deviation=0;
   request.comment=PS_REQUEST_COMMENT;

   if(!PS_TradeChooseFilling(market,model.order_mode==PS_ORDER_PENDING,request.type_filling,error))
     {
      snapshot.error=error;
      return(false);
     }
   if(model.order_mode==PS_ORDER_PENDING)
     {
      if(!PS_TradeChooseExpiration(market,request.type_time,error))
        {
         snapshot.error=error;
         return(false);
        }
      request.expiration=0;
     }
   PS_CopyTradeRequest(snapshot.request,request);
   snapshot.valid=true;
   return(true);
  }

bool PS_TradeCheckRequest(MqlTradeRequest &request,string &error)
  {
   ulong started=GetMicrosecondCount();
   error="";
   MqlTradeCheckResult check={};
   ResetLastError();
   bool local=OrderCheck(request,check);
   if(!local)
     {
      error=StringFormat("OrderCheck failed locally (error %d, retcode %u: %s).",
                         GetLastError(),check.retcode,check.comment);
      PS_PerfCheck("trade-check",started,PS_TRADE_VALIDATE_BUDGET_US);
      return(false);
     }
   if(check.retcode!=0 && !PS_TradeRetcodeAccepted(check.retcode))
     {
      error=StringFormat("OrderCheck rejected the request (%u: %s).",check.retcode,check.comment);
      PS_PerfCheck("trade-check",started,PS_TRADE_VALIDATE_BUDGET_US);
      return(false);
     }
   PS_PerfCheck("trade-check",started,PS_TRADE_VALIDATE_BUDGET_US);
   return(true);
  }

bool PS_TradeSendSnapshot(PSTradeSnapshot &snapshot,MqlTradeResult &result,string &error)
  {
   error="";
   ZeroMemory(result);
   if(!snapshot.valid)
     {
      error=(snapshot.error!="" ? snapshot.error : "Trade snapshot is invalid.");
      return(false);
     }
   if(!PS_TradeCheckRequest(snapshot.request,error)) return(false);

   ResetLastError();
   bool local=OrderSend(snapshot.request,result);
   PS_LogTradeResult("new order",local,result);
   if(!local)
     {
      error=StringFormat("OrderSend failed locally (error %d); server retcode %u: %s.",
                         GetLastError(),result.retcode,result.comment);
      return(false);
     }
   if(!PS_TradeRetcodeAccepted(result.retcode))
     {
      error=StringFormat("The server did not accept the order: %s (%u). %s",
                         PS_TradeRetcodeText(result.retcode),result.retcode,result.comment);
      return(false);
     }
   return(true);
  }

bool PS_TradeSnapshotsMateriallyEqual(const PSTradeSnapshot &a,const PSTradeSnapshot &b,
                                      const PSMarketSnapshot &market)
  {
   if(!a.valid || !b.valid) return(false);
   if(a.symbol!=b.symbol || a.direction!=b.direction || a.order_mode!=b.order_mode || a.order_type!=b.order_type) return(false);
   if(a.tp_enabled!=b.tp_enabled || a.account_mode!=b.account_mode || a.commission_mode!=b.commission_mode) return(false);
   if(a.request.type_filling!=b.request.type_filling || a.request.type_time!=b.request.type_time) return(false);
   if(MathAbs(a.entry-b.entry)>market.tick_size*0.5) return(false);
   if(MathAbs(a.stop_loss-b.stop_loss)>market.tick_size*0.5) return(false);
   if(MathAbs(a.take_profit-b.take_profit)>market.tick_size*0.5) return(false);
   if(MathAbs(a.volume-b.volume)>market.volume_step*0.5) return(false);

   double money_quantum=MathPow(10.0,-market.currency_digits);
   double money_tolerance=MathMax(1.0e-9,money_quantum*0.5);
   if(MathAbs(a.requested_money-b.requested_money)>money_tolerance) return(false);
   if(MathAbs(a.actual_money-b.actual_money)>money_tolerance) return(false);
   if(MathAbs(a.account_basis-b.account_basis)>money_tolerance) return(false);
   if(MathAbs(a.commission_per_lot-b.commission_per_lot)>money_tolerance) return(false);
   if(MathAbs(a.requested_percent-b.requested_percent)>0.005) return(false);
   if(MathAbs(a.actual_percent-b.actual_percent)>0.005) return(false);
   return(true);
  }

string PS_TradeConfirmationText(const PSTradeSnapshot &snapshot,const PSMarketSnapshot &market)
  {
   string tp=(snapshot.tp_enabled ? PS_PriceText(snapshot.take_profit,market) : "Disabled");
   string commission=(snapshot.commission_mode==PS_COMMISSION_ONE_SIDE
                      ? StringFormat("%s %s per lot, one side (counted twice)",PS_MoneyText(snapshot.commission_per_lot,market),market.account_currency)
                      : StringFormat("%s %s per lot, round trip",PS_MoneyText(snapshot.commission_per_lot,market),market.account_currency));
   return(StringFormat("Symbol: %s\nDirection: %s\nOrder: %s\nEntry: %s\nStop-loss: %s\nTake-profit: %s\nVolume: %s lots\n\nRequested risk: %s %s (%s%%)\nActual risk: %s %s (%s%%)\nAccount basis: %s, %s %s\nCommission: %s\n\nSend this trade request?",
                       snapshot.symbol,
                       PS_DirectionText(snapshot.direction),
                       snapshot.order_text,
                       PS_PriceText(snapshot.entry,market),
                       PS_PriceText(snapshot.stop_loss,market),
                       tp,
                       PS_VolumeText(snapshot.volume,market),
                       PS_MoneyText(snapshot.requested_money,market),market.account_currency,
                       PS_PercentText(snapshot.requested_percent),
                       PS_MoneyText(snapshot.actual_money,market),market.account_currency,
                       PS_PercentText(snapshot.actual_percent),
                       PS_AccountModeText(snapshot.account_mode),
                       PS_MoneyText(snapshot.account_basis,market),market.account_currency,
                       commission));
  }

bool PS_TradeSlNeedsChange(const double old_sl,const double target,const double tick_size)
  {
   if(old_sl<=0.0) return(true);
   return(MathAbs(old_sl-target)>tick_size*0.5);
  }

bool PS_TradeValidateTargetSL(const PSDirection direction,const double target,const bool pending,
                              const double pending_entry,const PSMarketSnapshot &market,string &error)
  {
   error="";
   if(!PS_IsPositiveFinite(target))
     {
      error="Target stop-loss is not a positive finite price.";
      return(false);
     }
   double minimum=PS_MarketProtectiveDistance(market,true);
   if(direction==PS_DIRECTION_LONG)
     {
      if(target>market.tick.bid-minimum+PS_DOUBLE_EPS)
        {
         error="Long target SL is inside the current Bid stop/freeze distance.";
         return(false);
        }
      if(pending && target>pending_entry-minimum+PS_DOUBLE_EPS)
        {
         error="Long pending-order target SL is inside the Entry stop/freeze distance.";
         return(false);
        }
     }
   else
     {
      if(target<market.tick.ask+minimum-PS_DOUBLE_EPS)
        {
         error="Short target SL is inside the current Ask stop/freeze distance.";
         return(false);
        }
      if(pending && target<pending_entry+minimum-PS_DOUBLE_EPS)
        {
         error="Short pending-order target SL is inside the Entry stop/freeze distance.";
         return(false);
        }
     }
   return(true);
  }

int PS_TradeCollectSlTargets(const PSModel &model,const PSMarketSnapshot &market,PSSlTarget &targets[])
  {
   ArrayResize(targets,0);
   double target=PS_NormalizePrice(model.stop_loss,market);

   int positions=PositionsTotal();
   for(int i=0;i<positions;i++)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0) continue;
      string symbol=PositionGetString(POSITION_SYMBOL);
      if(symbol!=market.symbol) continue;
      ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      PSDirection direction=(type==POSITION_TYPE_BUY ? PS_DIRECTION_LONG : PS_DIRECTION_SHORT);
      double old_sl=PositionGetDouble(POSITION_SL);
      if(!PS_TradeSlNeedsChange(old_sl,target,market.tick_size)) continue;
      string error="";
      if(!PS_TradeValidateTargetSL(direction,target,false,0.0,market,error)) continue;

      int index=ArraySize(targets);
      ArrayResize(targets,index+1);
      ZeroMemory(targets[index]);
      targets[index].is_position=true;
      targets[index].ticket=ticket;
      targets[index].symbol=symbol;
      targets[index].direction=direction;
      targets[index].entry=PositionGetDouble(POSITION_PRICE_OPEN);
      targets[index].old_sl=old_sl;
      targets[index].tp=PositionGetDouble(POSITION_TP);
      targets[index].target_sl=target;
     }

   int orders=OrdersTotal();
   for(int i=0;i<orders;i++)
     {
      ulong ticket=OrderGetTicket(i);
      if(ticket==0) continue;
      string symbol=OrderGetString(ORDER_SYMBOL);
      if(symbol!=market.symbol) continue;
      ENUM_ORDER_TYPE type=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(!PS_IsBuyOrderType(type) && !PS_IsSellOrderType(type)) continue;
      if(type==ORDER_TYPE_BUY || type==ORDER_TYPE_SELL) continue;
      PSDirection direction=(PS_IsBuyOrderType(type) ? PS_DIRECTION_LONG : PS_DIRECTION_SHORT);
      double entry=OrderGetDouble(ORDER_PRICE_OPEN);
      double old_sl=OrderGetDouble(ORDER_SL);
      if(!PS_TradeSlNeedsChange(old_sl,target,market.tick_size)) continue;
      string error="";
      if(!PS_TradeValidateTargetSL(direction,target,true,entry,market,error)) continue;

      int index=ArraySize(targets);
      ArrayResize(targets,index+1);
      ZeroMemory(targets[index]);
      targets[index].is_position=false;
      targets[index].ticket=ticket;
      targets[index].symbol=symbol;
      targets[index].direction=direction;
      targets[index].entry=entry;
      targets[index].old_sl=old_sl;
      targets[index].tp=OrderGetDouble(ORDER_TP);
      targets[index].target_sl=target;
      targets[index].price=entry;
      targets[index].stoplimit=OrderGetDouble(ORDER_PRICE_STOPLIMIT);
      targets[index].expiration=(datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
      targets[index].order_type=type;
      targets[index].type_time=(ENUM_ORDER_TYPE_TIME)OrderGetInteger(ORDER_TYPE_TIME);
      targets[index].type_filling=(ENUM_ORDER_TYPE_FILLING)OrderGetInteger(ORDER_TYPE_FILLING);
     }
   return(ArraySize(targets));
  }

bool PS_TradeSlTargetEqual(const PSSlTarget &a,const PSSlTarget &b,const double tick_size)
  {
   if(a.is_position!=b.is_position || a.ticket!=b.ticket || a.symbol!=b.symbol || a.direction!=b.direction) return(false);
   if(MathAbs(a.old_sl-b.old_sl)>tick_size*0.5) return(false);
   if(MathAbs(a.target_sl-b.target_sl)>tick_size*0.5) return(false);
   if(!a.is_position && MathAbs(a.entry-b.entry)>tick_size*0.5) return(false);
   return(true);
  }

bool PS_TradeSlTargetSetsEqual(const PSSlTarget &a[],const PSSlTarget &b[],const double tick_size)
  {
   int count=ArraySize(a);
   if(count!=ArraySize(b)) return(false);
   for(int i=0;i<count;i++)
      if(!PS_TradeSlTargetEqual(a[i],b[i],tick_size)) return(false);
   return(true);
  }

void PS_TradeCopySlTargets(PSSlTarget &destination[],const PSSlTarget &source[])
  {
   int count=ArraySize(source);
   ArrayResize(destination,count);
   for(int i=0;i<count;i++) PS_CopySlTarget(destination[i],source[i]);
  }

string PS_TradeSlConfirmationText(const PSModel &model,const PSMarketSnapshot &market,const PSSlTarget &targets[])
  {
   int count=ArraySize(targets);
   string detail="";
   for(int i=0;i<count;i++)
     {
      string kind=(targets[i].is_position ? "Position" : "Pending order");
      string old_text=(targets[i].old_sl>0.0 ? PS_PriceText(targets[i].old_sl,market) : "none");
      detail+=StringFormat("\n%s #%I64u: SL %s -> %s",kind,targets[i].ticket,old_text,
                           PS_PriceText(targets[i].target_sl,market));
     }

   return(StringFormat("Symbol: %s\nDirection scope: all valid positions and pending orders\nTarget stop-loss: %s\nEligible positions/pending orders: %d%s\n\nEvery eligible stop that differs from the red line will be moved to that exact price. Take-profits, entries and volumes remain unchanged.\n\nApply these stop-loss modifications?",
                       market.symbol,PS_PriceText(model.stop_loss,market),count,detail));
  }

bool PS_TradeBuildSlRequest(const PSSlTarget &target,MqlTradeRequest &request,string &error)
  {
   ZeroMemory(request);
   error="";
   if(target.is_position)
     {
      if(!PositionSelectByTicket(target.ticket))
        {
         error="Position no longer exists.";
         return(false);
        }

      string live_symbol=PositionGetString(POSITION_SYMBOL);
      ENUM_POSITION_TYPE live_type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(live_type!=POSITION_TYPE_BUY && live_type!=POSITION_TYPE_SELL)
        {
         error="Position type is no longer eligible.";
         return(false);
        }
      PSDirection live_direction=(live_type==POSITION_TYPE_BUY ? PS_DIRECTION_LONG : PS_DIRECTION_SHORT);
      if(live_symbol!=target.symbol || live_direction!=target.direction)
        {
         error="Position symbol or direction changed after eligibility was established.";
         return(false);
        }

      request.action=TRADE_ACTION_SLTP;
      request.position=target.ticket;
      request.symbol=live_symbol;
      request.sl=target.target_sl;
      request.tp=PositionGetDouble(POSITION_TP);
      return(true);
     }

   if(!OrderSelect(target.ticket))
     {
      error="Pending order no longer exists.";
      return(false);
     }

   string live_symbol=OrderGetString(ORDER_SYMBOL);
   ENUM_ORDER_TYPE live_type=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
   bool live_buy=PS_IsBuyOrderType(live_type);
   bool live_sell=PS_IsSellOrderType(live_type);
   if((!live_buy && !live_sell) || live_type==ORDER_TYPE_BUY || live_type==ORDER_TYPE_SELL)
     {
      error="Order is no longer an eligible pending order.";
      return(false);
     }
   PSDirection live_direction=(live_buy ? PS_DIRECTION_LONG : PS_DIRECTION_SHORT);
   if(live_symbol!=target.symbol || live_direction!=target.direction)
     {
      error="Pending-order symbol or direction changed after eligibility was established.";
      return(false);
     }

   request.action=TRADE_ACTION_MODIFY;
   request.order=target.ticket;
   request.symbol=live_symbol;
   request.price=OrderGetDouble(ORDER_PRICE_OPEN);
   request.stoplimit=OrderGetDouble(ORDER_PRICE_STOPLIMIT);
   request.sl=target.target_sl;
   request.tp=OrderGetDouble(ORDER_TP);
   request.type=live_type;
   request.type_time=(ENUM_ORDER_TYPE_TIME)OrderGetInteger(ORDER_TYPE_TIME);
   request.expiration=(datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
   request.type_filling=(ENUM_ORDER_TYPE_FILLING)OrderGetInteger(ORDER_TYPE_FILLING);
   return(true);
  }

void PS_TradeExecuteSlBatch(PSSlTarget &targets[],int &succeeded,int &failed,string &details)
  {
   succeeded=0;
   failed=0;
   details="";
   for(int i=0;i<ArraySize(targets);i++)
     {
      PSMarketSnapshot current;
      if(!PS_MarketAcquire(current))
        {
         failed++;
         details+=StringFormat("#%I64u: market refresh failed: %s\n",targets[i].ticket,current.error);
         continue;
        }
      if(current.symbol!=targets[i].symbol)
        {
         failed++;
         details+=StringFormat("#%I64u: symbol changed; skipped.\n",targets[i].ticket);
         continue;
        }
      string error="";
      if(!PS_TradePermissions(current,targets[i].direction,error))
        {
         failed++;
         details+=StringFormat("#%I64u: %s\n",targets[i].ticket,error);
         continue;
        }

      MqlTradeRequest request={};
      if(!PS_TradeBuildSlRequest(targets[i],request,error))
        {
         failed++;
         details+=StringFormat("#%I64u: %s\n",targets[i].ticket,error);
         continue;
        }

      double live_old_sl=(targets[i].is_position ? PositionGetDouble(POSITION_SL) : OrderGetDouble(ORDER_SL));
      double live_entry=(targets[i].is_position ? PositionGetDouble(POSITION_PRICE_OPEN) : OrderGetDouble(ORDER_PRICE_OPEN));
      if(!PS_TradeSlNeedsChange(live_old_sl,targets[i].target_sl,current.tick_size) ||
         !PS_TradeValidateTargetSL(targets[i].direction,targets[i].target_sl,!targets[i].is_position,live_entry,current,error))
        {
         failed++;
         details+=StringFormat("#%I64u: no longer eligible: %s\n",targets[i].ticket,error);
         continue;
        }
      if(!PS_TradeCheckRequest(request,error))
        {
         failed++;
         details+=StringFormat("#%I64u: %s\n",targets[i].ticket,error);
         continue;
        }

      MqlTradeResult result={};
      ResetLastError();
      bool local=OrderSend(request,result);
      PS_LogTradeResult("move SL",local,result);
      if(local && (PS_TradeRetcodeAccepted(result.retcode) || result.retcode==TRADE_RETCODE_NO_CHANGES))
        {
         succeeded++;
         details+=StringFormat("#%I64u: %s.\n",targets[i].ticket,PS_TradeRetcodeText(result.retcode));
        }
      else
        {
         failed++;
         details+=StringFormat("#%I64u: %s (%u). %s\n",targets[i].ticket,
                               PS_TradeRetcodeText(result.retcode),result.retcode,result.comment);
        }
     }
  }

#endif
