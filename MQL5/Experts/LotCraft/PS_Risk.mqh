#ifndef __LOTCRAFT_PS_RISK_MQH__
#define __LOTCRAFT_PS_RISK_MQH__

#include "PS_Market.mqh"

void PS_ModelInitialize(PSModel &model,const PSMarketSnapshot &market)
  {
   ZeroMemory(model);
   model.direction=PS_DIRECTION_LONG;
   model.order_mode=PS_ORDER_INSTANT;
   model.commission_mode=PS_COMMISSION_ROUND_TRIP;
   model.account_mode=PS_ACCOUNT_EQUITY;
   model.risk_authority=PS_RISK_PERCENT;
   model.view_mode=PS_VIEW_FULL;
   model.theme_mode=PS_THEME_DARK;
   model.ask_confirmation=true;
   model.lines_visible=true;
   model.entry=(market.tick_valid ? PS_NormalizePrice(market.tick.ask,market) : 0.0);

   double distance=MathMax(100.0*market.tick_size,PS_MarketProtectiveDistance(market,true)+market.tick_size);
   if(market.tick_valid)
      model.stop_loss=PS_NormalizePrice(market.tick.bid-distance,market);
   else
      model.stop_loss=0.0;
   model.take_profit=0.0;
   model.commission_per_lot=0.0;
   model.manual_account_money=(PS_IsPositiveFinite(market.balance) ? market.balance : 10000.0);
   model.requested_risk_percent=1.0;
   model.requested_risk_money=0.0;
   model.status="Ready.";
   model.status_is_error=false;
   model.revision=1;
  }

bool PS_ModelEnsureInitialPrices(PSModel &model,const PSMarketSnapshot &market)
  {
   if(!market.tick_valid || !PS_IsPositiveFinite(market.tick_size)) return(false);
   bool changed=false;
   double executable=(model.direction==PS_DIRECTION_LONG ? market.tick.ask : market.tick.bid);
   executable=PS_NormalizePrice(executable,market);
   if(!PS_IsPositiveFinite(model.entry))
     {
      model.entry=executable;
      changed=true;
     }

   if(!PS_IsPositiveFinite(model.stop_loss))
     {
      double minimum=PS_MarketProtectiveDistance(market,true);
      double distance=MathMax(100.0*market.tick_size,minimum+market.tick_size);
      double stop=0.0;
      if(model.direction==PS_DIRECTION_LONG)
        {
         stop=market.tick.bid-distance;
         if(stop<=0.0 && market.tick.bid>minimum+market.tick_size) stop=market.tick_size;
        }
      else stop=market.tick.ask+distance;
      stop=PS_NormalizePrice(stop,market);
      if(PS_IsPositiveFinite(stop))
        {
         model.stop_loss=stop;
         changed=true;
        }
     }

   if(changed) model.revision++;
   return(changed);
  }

bool PS_ModelReanchorForSymbol(PSModel &model,const PSMarketSnapshot &market,
                               const double visible_min,const double visible_max)
  {
   if(!market.tick_valid || !PS_IsPositiveFinite(market.tick_size)) return(false);

   double entry=(model.direction==PS_DIRECTION_LONG ? market.tick.ask : market.tick.bid);
   entry=PS_NormalizePrice(entry,market);
   if(!PS_IsPositiveFinite(entry)) return(false);

   double minimum=MathMax(market.tick_size,
                          PS_MarketProtectiveDistance(market,true)+market.tick_size);
   double distance=MathMax(100.0*market.tick_size,entry*0.002);
   bool viewport_valid=(PS_IsFinite(visible_min) && PS_IsFinite(visible_max) &&
                        visible_max>visible_min && entry>=visible_min && entry<=visible_max);
   if(viewport_valid)
     {
      double span=visible_max-visible_min;
      distance=MathMax(minimum,span*0.18);
      double available=(model.direction==PS_DIRECTION_LONG ? entry-visible_min : visible_max-entry);
      if(available>minimum*1.25) distance=MathMin(distance,available*0.70);
     }
   distance=MathMax(minimum,distance);

   bool had_take_profit=PS_IsPositiveFinite(model.take_profit);
   double stop=entry+(model.direction==PS_DIRECTION_LONG ? -distance : distance);
   if(viewport_valid)
     {
      double span=visible_max-visible_min;
      double margin=span*0.06;
      if(model.direction==PS_DIRECTION_LONG)
         stop=MathMax(stop,visible_min+margin);
      else
         stop=MathMin(stop,visible_max-margin);
     }

   stop=PS_NormalizePrice(stop,market);
   if(!PS_IsPositiveFinite(stop) ||
      (model.direction==PS_DIRECTION_LONG && stop>=entry) ||
      (model.direction==PS_DIRECTION_SHORT && stop<=entry))
      stop=PS_NormalizePrice(entry+(model.direction==PS_DIRECTION_LONG ? -minimum : minimum),market);

   model.entry=entry;
   model.stop_loss=stop;
   if(had_take_profit)
      model.take_profit=PS_NormalizePrice(entry+
                                         (model.direction==PS_DIRECTION_LONG ? distance : -distance),
                                         market);
   model.revision++;
   return(true);
  }

void PS_ModelSyncInstantEntry(PSModel &model,const PSMarketSnapshot &market,const bool entry_editor_active)
  {
   if(model.order_mode!=PS_ORDER_INSTANT || entry_editor_active || !market.tick_valid) return;
   double executable=(model.direction==PS_DIRECTION_LONG ? market.tick.ask : market.tick.bid);
   executable=PS_NormalizePrice(executable,market);
   if(MathAbs(model.entry-executable)>market.tick_size*0.25)
     {
      model.entry=executable;
      model.revision++;
     }
  }

void PS_ModelChangeDirection(PSModel &model,const PSMarketSnapshot &market,const PSDirection new_direction)
  {
   if(model.direction==new_direction) return;
   double old_entry=(model.order_mode==PS_ORDER_INSTANT && market.tick_valid)
                    ? (model.direction==PS_DIRECTION_LONG ? market.tick.ask : market.tick.bid)
                    : model.entry;
   double stop_distance=MathAbs(old_entry-model.stop_loss);
   if(!PS_IsPositiveFinite(model.stop_loss) || stop_distance<market.tick_size)
      stop_distance=MathMax(100.0*market.tick_size,PS_MarketProtectiveDistance(market,true)+market.tick_size);
   bool tp_enabled=PS_IsPositiveFinite(model.take_profit);
   double take_distance=(tp_enabled ? MathAbs(model.take_profit-old_entry) : 0.0);

   model.direction=new_direction;
   double new_entry=(model.order_mode==PS_ORDER_INSTANT && market.tick_valid)
                    ? (new_direction==PS_DIRECTION_LONG ? market.tick.ask : market.tick.bid)
                    : model.entry;
   model.entry=PS_NormalizePrice(new_entry,market);
   model.stop_loss=PS_NormalizePrice(new_entry+(new_direction==PS_DIRECTION_LONG ? -stop_distance : stop_distance),market);
   if(tp_enabled)
      model.take_profit=PS_NormalizePrice(new_entry+(new_direction==PS_DIRECTION_LONG ? take_distance : -take_distance),market);
   model.revision++;
  }

bool PS_ModelAlignDirectionToStop(PSModel &model,const PSMarketSnapshot &market)
  {
   if(!PS_IsPositiveFinite(model.stop_loss)) return(false);
   double reference=model.entry;
   if(model.order_mode==PS_ORDER_INSTANT && market.tick_valid)
      reference=(model.direction==PS_DIRECTION_LONG ? market.tick.ask : market.tick.bid);
   if(!PS_IsPositiveFinite(reference)) return(false);

   double tolerance=(PS_IsPositiveFinite(market.tick_size) ? market.tick_size*0.5 : 0.0);
   PSDirection inferred=model.direction;
   if(model.stop_loss<reference-tolerance) inferred=PS_DIRECTION_LONG;
   else if(model.stop_loss>reference+tolerance) inferred=PS_DIRECTION_SHORT;
   else return(false);
   if(inferred==model.direction) return(false);

   bool tp_enabled=PS_IsPositiveFinite(model.take_profit);
   double take_distance=(tp_enabled ? MathAbs(model.take_profit-reference) : 0.0);
   model.direction=inferred;
   if(model.order_mode==PS_ORDER_INSTANT && market.tick_valid)
      model.entry=PS_NormalizePrice(inferred==PS_DIRECTION_LONG ? market.tick.ask : market.tick.bid,market);
   if(tp_enabled && take_distance>tolerance)
      model.take_profit=PS_NormalizePrice(model.entry+
                                         (inferred==PS_DIRECTION_LONG ? take_distance : -take_distance),
                                         market);
   model.revision++;
   return(true);
  }

void PS_ModelChangeOrderMode(PSModel &model,const PSMarketSnapshot &market,const PSOrderMode new_mode)
  {
   if(model.order_mode==new_mode) return;
   model.order_mode=new_mode;
   if(new_mode==PS_ORDER_INSTANT && market.tick_valid)
     {
      double old_entry=model.entry;
      double new_entry=(model.direction==PS_DIRECTION_LONG ? market.tick.ask : market.tick.bid);
      double delta=new_entry-old_entry;
      model.entry=PS_NormalizePrice(new_entry,market);
      model.stop_loss=PS_NormalizePrice(model.stop_loss+delta,market);
      if(PS_IsPositiveFinite(model.take_profit))
         model.take_profit=PS_NormalizePrice(model.take_profit+delta,market);
     }
   model.revision++;
  }

bool PS_RiskResolveOrder(const PSModel &model,const PSMarketSnapshot &market,PSCalcResult &calc,string &error)
  {
   error="";
   calc.pending_ambiguous=false;
   if(model.order_mode==PS_ORDER_INSTANT)
     {
      if(!market.tick_valid)
        {
         error=(market.error!="" ? market.error : "A current quote is required for an Instant order.");
         return(false);
        }
      calc.effective_entry=PS_NormalizePrice(model.direction==PS_DIRECTION_LONG ? market.tick.ask : market.tick.bid,market);
      calc.resolved_order_type=(model.direction==PS_DIRECTION_LONG ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
      calc.resolved_order_text=PS_OrderTypeText(calc.resolved_order_type);
      if((market.order_mode & SYMBOL_ORDER_MARKET)!=SYMBOL_ORDER_MARKET)
        {
         error="The broker does not allow market orders for this symbol.";
         return(false);
        }
      return(true);
     }

   if(!PS_IsPositiveFinite(model.entry))
     {
      error="Pending Entry must be a positive finite price.";
      return(false);
     }
   if(!market.tick_valid)
     {
      error=(market.error!="" ? market.error : "A current quote is required to infer the pending-order subtype.");
      return(false);
     }

   calc.effective_entry=PS_NormalizePrice(model.entry,market);
   double tolerance=market.tick_size*0.5;
   double minimum=PS_MarketProtectiveDistance(market,true);

   if(model.direction==PS_DIRECTION_LONG)
     {
      if(calc.effective_entry<market.tick.ask-tolerance)
        {
         calc.resolved_order_type=ORDER_TYPE_BUY_LIMIT;
         if(market.tick.ask-calc.effective_entry+PS_DOUBLE_EPS<minimum)
           {
            error="Buy Limit Entry is inside the broker stop/freeze distance.";
            return(false);
           }
         if((market.order_mode & SYMBOL_ORDER_LIMIT)!=SYMBOL_ORDER_LIMIT)
           {
            error="The broker does not allow limit orders for this symbol.";
            return(false);
           }
        }
      else if(calc.effective_entry>market.tick.ask+tolerance)
        {
         calc.resolved_order_type=ORDER_TYPE_BUY_STOP;
         if(calc.effective_entry-market.tick.ask+PS_DOUBLE_EPS<minimum)
           {
            error="Buy Stop Entry is inside the broker stop/freeze distance.";
            return(false);
           }
         if((market.order_mode & SYMBOL_ORDER_STOP)!=SYMBOL_ORDER_STOP)
           {
            error="The broker does not allow stop orders for this symbol.";
            return(false);
           }
        }
      else
        {
         calc.pending_ambiguous=true;
         error="Long Pending Entry must be clearly below Ask (Buy Limit) or above Ask (Buy Stop).";
         return(false);
        }
     }
   else
     {
      if(calc.effective_entry>market.tick.bid+tolerance)
        {
         calc.resolved_order_type=ORDER_TYPE_SELL_LIMIT;
         if(calc.effective_entry-market.tick.bid+PS_DOUBLE_EPS<minimum)
           {
            error="Sell Limit Entry is inside the broker stop/freeze distance.";
            return(false);
           }
         if((market.order_mode & SYMBOL_ORDER_LIMIT)!=SYMBOL_ORDER_LIMIT)
           {
            error="The broker does not allow limit orders for this symbol.";
            return(false);
           }
        }
      else if(calc.effective_entry<market.tick.bid-tolerance)
        {
         calc.resolved_order_type=ORDER_TYPE_SELL_STOP;
         if(market.tick.bid-calc.effective_entry+PS_DOUBLE_EPS<minimum)
           {
            error="Sell Stop Entry is inside the broker stop/freeze distance.";
            return(false);
           }
         if((market.order_mode & SYMBOL_ORDER_STOP)!=SYMBOL_ORDER_STOP)
           {
            error="The broker does not allow stop orders for this symbol.";
            return(false);
           }
        }
      else
        {
         calc.pending_ambiguous=true;
         error="Short Pending Entry must be clearly above Bid (Sell Limit) or below Bid (Sell Stop).";
         return(false);
        }
     }

   calc.resolved_order_text=PS_OrderTypeText(calc.resolved_order_type);
   return(true);
  }

bool PS_RiskValidateProtectivePrices(const PSModel &model,const PSMarketSnapshot &market,PSCalcResult &calc,string &error)
  {
   error="";
   double tolerance=market.tick_size*0.5;
   calc.tp_enabled=PS_IsPositiveFinite(model.take_profit);

   if(!PS_IsPositiveFinite(model.stop_loss))
     {
      error="Stop-loss must be a positive finite price.";
      return(false);
     }

   if(model.direction==PS_DIRECTION_LONG)
     {
      if(model.stop_loss>=calc.effective_entry-tolerance)
        {
         error="Long stop-loss must be below the effective entry.";
         return(false);
        }
      if(calc.tp_enabled && model.take_profit<=calc.effective_entry+tolerance)
        {
         error="Long take-profit must be above the effective entry.";
         return(false);
        }
     }
   else
     {
      if(model.stop_loss<=calc.effective_entry+tolerance)
        {
         error="Short stop-loss must be above the effective entry.";
         return(false);
        }
      if(calc.tp_enabled && model.take_profit>=calc.effective_entry-tolerance)
        {
         error="Short take-profit must be below the effective entry.";
         return(false);
        }
     }

   if((market.order_mode & SYMBOL_ORDER_SL)!=SYMBOL_ORDER_SL)
     {
      error="The broker does not allow Stop Loss for this symbol.";
      return(false);
     }
   if(calc.tp_enabled && (market.order_mode & SYMBOL_ORDER_TP)!=SYMBOL_ORDER_TP)
     {
      error="The broker does not allow Take Profit for this symbol.";
      return(false);
     }

   double minimum=PS_MarketProtectiveDistance(market,true);
   if(model.order_mode==PS_ORDER_PENDING)
     {
      if(model.direction==PS_DIRECTION_LONG)
        {
         if(calc.effective_entry-model.stop_loss+PS_DOUBLE_EPS<minimum)
           {
            error="Stop-loss is inside the broker stop/freeze distance from pending Entry.";
            return(false);
           }
         if(calc.tp_enabled && model.take_profit-calc.effective_entry+PS_DOUBLE_EPS<minimum)
           {
            error="Take-profit is inside the broker stop/freeze distance from pending Entry.";
            return(false);
           }
        }
      else
        {
         if(model.stop_loss-calc.effective_entry+PS_DOUBLE_EPS<minimum)
           {
            error="Stop-loss is inside the broker stop/freeze distance from pending Entry.";
            return(false);
           }
         if(calc.tp_enabled && calc.effective_entry-model.take_profit+PS_DOUBLE_EPS<minimum)
           {
            error="Take-profit is inside the broker stop/freeze distance from pending Entry.";
            return(false);
           }
        }
      return(true);
     }

   if(model.direction==PS_DIRECTION_LONG)
     {
      if(market.tick.bid-model.stop_loss+PS_DOUBLE_EPS<minimum)
        {
         error="Long stop-loss is inside the broker stop/freeze distance from Bid.";
         return(false);
        }
      if(calc.tp_enabled && model.take_profit-market.tick.bid+PS_DOUBLE_EPS<minimum)
        {
         error="Long take-profit is inside the broker stop/freeze distance from Bid.";
         return(false);
        }
     }
   else
     {
      if(model.stop_loss-market.tick.ask+PS_DOUBLE_EPS<minimum)
        {
         error="Short stop-loss is inside the broker stop/freeze distance from Ask.";
         return(false);
        }
      if(calc.tp_enabled && market.tick.ask-model.take_profit+PS_DOUBLE_EPS<minimum)
        {
         error="Short take-profit is inside the broker stop/freeze distance from Ask.";
         return(false);
        }
     }
   return(true);
  }

bool PS_RiskCalculate(PSModel &model,const PSMarketSnapshot &market,PSCalcResult &calc)
  {
   ulong started=GetMicrosecondCount();
   ZeroMemory(calc);
   calc.valid=false;
   calc.quote_valid=market.tick_valid;
   calc.error="";
   calc.notice="";

   if(!market.symbol_ready)
     {
      calc.error=(market.error!="" ? market.error : "Symbol properties are not ready.");
      PS_PerfCheck("risk",started,PS_CALC_BUDGET_US);
      return(false);
     }

   if(market.account_margin_mode!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING && market.current_symbol_positions>0)
     {
      calc.error="A netting/exchange position already exists on this symbol. New LotCraft orders are blocked because they would aggregate, reduce, or reverse that position and apply SL/TP to the combined position.";
      PS_PerfCheck("risk",started,PS_CALC_BUDGET_US);
      return(false);
     }

   if(model.account_mode==PS_ACCOUNT_EQUITY) calc.account_basis=market.equity;
   else if(model.account_mode==PS_ACCOUNT_BALANCE) calc.account_basis=market.balance;
   else calc.account_basis=model.manual_account_money;

   if(!PS_IsPositiveFinite(calc.account_basis))
     {
      calc.error="The selected account-money basis must be positive and finite.";
      PS_PerfCheck("risk",started,PS_CALC_BUDGET_US);
      return(false);
     }

   if(model.risk_authority==PS_RISK_PERCENT)
     {
      if(!PS_IsPositiveFinite(model.requested_risk_percent))
        {
         calc.error="Requested Risk, % must be positive and finite.";
         PS_PerfCheck("risk",started,PS_CALC_BUDGET_US);
         return(false);
        }
      calc.requested_percent=model.requested_risk_percent;
      calc.requested_money=calc.account_basis*calc.requested_percent/100.0;
      model.requested_risk_money=calc.requested_money;
     }
   else
     {
      if(!PS_IsPositiveFinite(model.requested_risk_money))
        {
         calc.error="Requested Risk, money must be positive and finite.";
         PS_PerfCheck("risk",started,PS_CALC_BUDGET_US);
         return(false);
        }
      calc.requested_money=model.requested_risk_money;
      calc.requested_percent=calc.requested_money/calc.account_basis*100.0;
      model.requested_risk_percent=calc.requested_percent;
     }

   string error="";
   if(!PS_RiskResolveOrder(model,market,calc,error))
     {
      calc.error=error;
      PS_PerfCheck("risk",started,PS_CALC_BUDGET_US);
      return(false);
     }
   if(!PS_RiskValidateProtectivePrices(model,market,calc,error))
     {
      calc.error=error;
      PS_PerfCheck("risk",started,PS_CALC_BUDGET_US);
      return(false);
     }

   if(!PS_IsFinite(model.commission_per_lot) || model.commission_per_lot<0.0)
     {
      calc.error="Commission/lot must be zero or a positive finite amount.";
      PS_PerfCheck("risk",started,PS_CALC_BUDGET_US);
      return(false);
     }
   calc.commission_risk_per_lot=(model.commission_mode==PS_COMMISSION_ONE_SIDE
                                 ? model.commission_per_lot*2.0
                                 : model.commission_per_lot);

   double profit=0.0;
   ENUM_ORDER_TYPE profit_type=(model.direction==PS_DIRECTION_LONG ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   ResetLastError();
   if(!OrderCalcProfit(profit_type,market.symbol,1.0,calc.effective_entry,model.stop_loss,profit))
     {
      calc.error=StringFormat("OrderCalcProfit failed for one lot (error %d).",GetLastError());
      PS_PerfCheck("risk",started,PS_CALC_BUDGET_US);
      return(false);
     }
   double price_loss=MathAbs(profit);
   if(!PS_IsPositiveFinite(price_loss))
     {
      calc.error="The one-lot loss from Entry to Stop is zero or invalid.";
      PS_PerfCheck("risk",started,PS_CALC_BUDGET_US);
      return(false);
     }
   calc.one_lot_loss=price_loss+calc.commission_risk_per_lot;
   if(!PS_IsPositiveFinite(calc.one_lot_loss))
     {
      calc.error="The one-lot risk including commission is invalid.";
      PS_PerfCheck("risk",started,PS_CALC_BUDGET_US);
      return(false);
     }

   calc.raw_volume=calc.requested_money/calc.one_lot_loss;
   calc.directional_exposure=(model.direction==PS_DIRECTION_LONG ? market.exposure_long : market.exposure_short);
   calc.remaining_volume_limit=market.volume_max;
   double volume_cap=market.volume_max;
   if(PS_IsPositiveFinite(market.volume_limit))
     {
      calc.remaining_volume_limit=MathMax(0.0,market.volume_limit-calc.directional_exposure);
      volume_cap=MathMin(volume_cap,calc.remaining_volume_limit);
     }
   if(volume_cap+market.volume_step*1.0e-9<market.volume_min)
     {
      calc.error="No broker-valid volume remains under the symbol maximum or aggregate directional volume limit.";
      PS_PerfCheck("risk",started,PS_CALC_BUDGET_US);
      return(false);
     }

   calc.volume_capped=(calc.raw_volume>volume_cap+market.volume_step*1.0e-9);
   calc.volume=PS_FloorVolume(calc.raw_volume,market.volume_min,volume_cap,market.volume_step);
   if(calc.volume<=0.0)
     {
      calc.error=StringFormat("Requested risk produces less than the broker minimum volume of %s lots.",
                              DoubleToString(market.volume_min,PS_DecimalsForStep(market.volume_step)));
      PS_PerfCheck("risk",started,PS_CALC_BUDGET_US);
      return(false);
     }

   calc.actual_money=calc.one_lot_loss*calc.volume;
   double risk_tolerance=MathMax(1.0e-9,MathAbs(calc.requested_money)*1.0e-12);
   if(calc.actual_money>calc.requested_money+risk_tolerance)
     {
      double reduced=PS_FloorVolume(calc.volume-market.volume_step,market.volume_min,volume_cap,market.volume_step);
      if(reduced<=0.0)
        {
         calc.error="The minimum broker volume would exceed requested risk after rounding.";
         PS_PerfCheck("risk",started,PS_CALC_BUDGET_US);
         return(false);
        }
      calc.volume=reduced;
      calc.actual_money=calc.one_lot_loss*calc.volume;
      if(calc.actual_money>calc.requested_money+risk_tolerance)
        {
         calc.error="A broker-valid downward-normalized volume could not be proven within requested risk.";
         PS_PerfCheck("risk",started,PS_CALC_BUDGET_US);
         return(false);
        }
     }
   calc.actual_percent=calc.actual_money/calc.account_basis*100.0;
   if(calc.volume_capped)
      calc.notice="Position size was capped downward by broker maximum or aggregate directional volume limit.";

   calc.valid=true;
   PS_PerfCheck("risk",started,PS_CALC_BUDGET_US);
   return(true);
  }

#endif
