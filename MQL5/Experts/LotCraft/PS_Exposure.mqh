#ifndef __LOTCRAFT_PS_EXPOSURE_MQH__
#define __LOTCRAFT_PS_EXPOSURE_MQH__

#include "PS_Market.mqh"

void PS_ExposureResetItem(PSExposureItem &item)
  {
   item.kind=PS_EXPOSURE_POSITION;
   item.status=PS_EXPOSURE_UNAVAILABLE;
   item.ticket=0;
   item.symbol="";
   item.direction=PS_DIRECTION_LONG;
   item.volume=0.0;
   item.price_digits=8;
   item.volume_digits=8;
   item.entry=0.0;
   item.stop_loss=0.0;
   item.projected_result=0.0;
   item.loss_money=0.0;
   item.loss_percent=0.0;
  }

void PS_ExposureCopyItem(PSExposureItem &destination,const PSExposureItem &source)
  {
   destination.kind=source.kind;
   destination.status=source.status;
   destination.ticket=source.ticket;
   destination.symbol=source.symbol;
   destination.direction=source.direction;
   destination.volume=source.volume;
   destination.price_digits=source.price_digits;
   destination.volume_digits=source.volume_digits;
   destination.entry=source.entry;
   destination.stop_loss=source.stop_loss;
   destination.projected_result=source.projected_result;
   destination.loss_money=source.loss_money;
   destination.loss_percent=source.loss_percent;
  }

int PS_ExposureAppend(PSExposureSnapshot &snapshot)
  {
   int index=ArraySize(snapshot.items);
   if(ArrayResize(snapshot.items,index+1)!=index+1) return(-1);
   PS_ExposureResetItem(snapshot.items[index]);
   return(index);
  }

bool PS_ExposureProject(const string symbol,const PSDirection direction,const double volume,
                        const double entry,const double stop_loss,const double known_swap,
                        double &projected_result)
  {
   projected_result=0.0;
   if(symbol=="" || !PS_IsPositiveFinite(volume) || !PS_IsPositiveFinite(entry) ||
      !PS_IsPositiveFinite(stop_loss)) return(false);
   ENUM_ORDER_TYPE order_type=(direction==PS_DIRECTION_LONG ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   double price_result=0.0;
   ResetLastError();
   if(!OrderCalcProfit(order_type,symbol,volume,entry,stop_loss,price_result)) return(false);
   if(!PS_IsFinite(price_result) || !PS_IsFinite(known_swap)) return(false);
   projected_result=price_result+known_swap;
   return(PS_IsFinite(projected_result));
  }

void PS_ExposureReadPrecision(PSExposureItem &item)
  {
   // Formatting metadata belongs to the cached row, not the render hot path.
   long digits=0;
   if(SymbolInfoInteger(item.symbol,SYMBOL_DIGITS,digits) && digits>=0 && digits<=8)
      item.price_digits=(int)digits;
   double step=SymbolInfoDouble(item.symbol,SYMBOL_VOLUME_STEP);
   if(PS_IsPositiveFinite(step)) item.volume_digits=PS_DecimalsForStep(step);
  }

bool PS_ExposureAddPosition(PSExposureSnapshot &snapshot,const int position_index,string &error)
  {
   ulong ticket=PositionGetTicket(position_index);
   if(ticket==0)
     {
      error=StringFormat("Could not select position at index %d (error %d).",position_index,GetLastError());
      return(false);
     }

   ENUM_POSITION_TYPE position_type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   if(position_type!=POSITION_TYPE_BUY && position_type!=POSITION_TYPE_SELL) return(true);

   int index=PS_ExposureAppend(snapshot);
   if(index<0)
     {
      error="Could not allocate position exposure row.";
      return(false);
     }
   PSExposureItem item;
   PS_ExposureResetItem(item);
   item.kind=PS_EXPOSURE_POSITION;
   item.ticket=ticket;
   item.symbol=PositionGetString(POSITION_SYMBOL);
   PS_ExposureReadPrecision(item);
   item.direction=(position_type==POSITION_TYPE_BUY ? PS_DIRECTION_LONG : PS_DIRECTION_SHORT);
   item.volume=PositionGetDouble(POSITION_VOLUME);
   item.entry=PositionGetDouble(POSITION_PRICE_OPEN);
   item.stop_loss=PositionGetDouble(POSITION_SL);
   double projected_result=0.0;
   if(!PS_IsPositiveFinite(item.stop_loss))
      item.status=PS_EXPOSURE_NO_SL;
   else if(PS_ExposureProject(item.symbol,item.direction,item.volume,item.entry,item.stop_loss,
                              PositionGetDouble(POSITION_SWAP),projected_result))
     {
      item.status=PS_EXPOSURE_VALID;
      item.projected_result=projected_result;
      item.loss_money=MathMax(0.0,-projected_result);
     }
   else
      item.status=PS_EXPOSURE_UNAVAILABLE;
   PS_ExposureCopyItem(snapshot.items[index],item);
   return(true);
  }

bool PS_ExposureAddPending(PSExposureSnapshot &snapshot,const int order_index,string &error)
  {
   ulong ticket=OrderGetTicket(order_index);
   if(ticket==0)
     {
      error=StringFormat("Could not select pending order at index %d (error %d).",order_index,GetLastError());
      return(false);
     }
   ENUM_ORDER_TYPE order_type=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
   if(!PS_IsBuyOrderType(order_type) && !PS_IsSellOrderType(order_type)) return(true);

   int index=PS_ExposureAppend(snapshot);
   if(index<0)
     {
      error="Could not allocate pending-order exposure row.";
      return(false);
     }
   PSExposureItem item;
   PS_ExposureResetItem(item);
   item.kind=PS_EXPOSURE_PENDING;
   item.ticket=ticket;
   item.symbol=OrderGetString(ORDER_SYMBOL);
   PS_ExposureReadPrecision(item);
   item.direction=(PS_IsBuyOrderType(order_type) ? PS_DIRECTION_LONG : PS_DIRECTION_SHORT);
   item.volume=OrderGetDouble(ORDER_VOLUME_CURRENT);
   // A Stop Limit trigger places a limit order. Its limit leg, not its trigger,
   // is the planned fill used for Entry-to-SL exposure. Invalid data stays unavailable.
   bool stop_limit=(order_type==ORDER_TYPE_BUY_STOP_LIMIT || order_type==ORDER_TYPE_SELL_STOP_LIMIT);
   item.entry=OrderGetDouble(stop_limit ? ORDER_PRICE_STOPLIMIT : ORDER_PRICE_OPEN);
   item.stop_loss=OrderGetDouble(ORDER_SL);
   double projected_result=0.0;
   if(!PS_IsPositiveFinite(item.stop_loss))
      item.status=PS_EXPOSURE_NO_SL;
   else if(PS_ExposureProject(item.symbol,item.direction,item.volume,item.entry,item.stop_loss,
                              0.0,projected_result))
     {
      item.status=PS_EXPOSURE_VALID;
      item.projected_result=projected_result;
      item.loss_money=MathMax(0.0,-projected_result);
     }
   else
      item.status=PS_EXPOSURE_UNAVAILABLE;
   PS_ExposureCopyItem(snapshot.items[index],item);
   return(true);
  }

bool PS_ExposureSortBefore(const PSExposureItem &left,const PSExposureItem &right)
  {
   if(MathAbs(left.loss_money-right.loss_money)>PS_DOUBLE_EPS)
      return(left.loss_money>right.loss_money);
   if(left.kind!=right.kind) return(left.kind<right.kind);
   return(left.ticket<right.ticket);
  }

void PS_ExposureSort(PSExposureSnapshot &snapshot)
  {
   int count=ArraySize(snapshot.items);
   for(int i=1;i<count;i++)
     {
      PSExposureItem key;
      PS_ExposureCopyItem(key,snapshot.items[i]);
      int j=i-1;
      while(j>=0 && PS_ExposureSortBefore(key,snapshot.items[j]))
        {
         PS_ExposureCopyItem(snapshot.items[j+1],snapshot.items[j]);
         j--;
        }
      PS_ExposureCopyItem(snapshot.items[j+1],key);
     }
  }

ulong PS_ExposureHashText(ulong hash,const string text)
  {
   uchar bytes[];
   int count=StringToCharArray(text,bytes,0,WHOLE_ARRAY,CP_UTF8);
   for(int i=0;i<count;i++)
     {
      if(bytes[i]==0) break;
      hash^=(ulong)bytes[i];
      hash*=1099511628211;
     }
   return(hash);
  }

ulong PS_ExposureFingerprint(const PSExposureSnapshot &snapshot,const int currency_digits)
  {
   ulong hash=1469598103934665603;
   int digits=PS_ClampInt(currency_digits,0,8);
   for(int i=0;i<ArraySize(snapshot.items);i++)
     {
      const PSExposureItem item=snapshot.items[i];
      string row=StringFormat("%I64u|%d|%d|%s|%d|%s|%s|%s|%s|%d|%d",
                              item.ticket,(int)item.kind,(int)item.status,item.symbol,
                              (int)item.direction,DoubleToString(item.volume,8),
                              DoubleToString(item.entry,10),DoubleToString(item.stop_loss,10),
                              DoubleToString(NormalizeDouble(item.projected_result,digits),digits),
                              item.price_digits,item.volume_digits);
      hash=PS_ExposureHashText(hash,row);
     }
   return(hash);
  }

void PS_ExposureAggregate(PSExposureSnapshot &snapshot,const string current_symbol,const double equity)
  {
   snapshot.equity_basis=(PS_IsPositiveFinite(equity) ? equity : 0.0);
   for(int i=0;i<ArraySize(snapshot.items);i++)
     {
      bool on_chart=(snapshot.items[i].symbol==current_symbol);
      if(snapshot.items[i].status==PS_EXPOSURE_VALID)
        {
         snapshot.account_protected++;
         snapshot.account_loss_money+=snapshot.items[i].loss_money;
         if(on_chart)
           {
            snapshot.chart_protected++;
            snapshot.chart_loss_money+=snapshot.items[i].loss_money;
           }
         if(snapshot.equity_basis>0.0)
            snapshot.items[i].loss_percent=snapshot.items[i].loss_money/snapshot.equity_basis*100.0;
        }
      else if(snapshot.items[i].status==PS_EXPOSURE_NO_SL)
        {
         snapshot.account_no_sl++;
         if(on_chart) snapshot.chart_no_sl++;
        }
      else
        {
         snapshot.account_unavailable++;
         if(on_chart) snapshot.chart_unavailable++;
        }
     }
   if(snapshot.equity_basis>0.0)
     {
      snapshot.chart_loss_percent=snapshot.chart_loss_money/snapshot.equity_basis*100.0;
      snapshot.account_loss_percent=snapshot.account_loss_money/snapshot.equity_basis*100.0;
     }
  }

bool PS_ExposureCalculate(PSExposureSnapshot &snapshot,const string current_symbol,
                          const double equity,string &error)
  {
   PS_ExposureReset(snapshot);
   error="";
   int positions=PositionsTotal();
   for(int i=0;i<positions;i++)
      if(!PS_ExposureAddPosition(snapshot,i,error)) return(false);
   int orders=OrdersTotal();
   for(int i=0;i<orders;i++)
      if(!PS_ExposureAddPending(snapshot,i,error)) return(false);

   if(positions!=PositionsTotal() || orders!=OrdersTotal())
     {
      error="Position or order inventory changed during exposure refresh.";
      return(false);
     }
   PS_ExposureAggregate(snapshot,current_symbol,equity);
   PS_ExposureSort(snapshot);
   int currency_digits=(int)AccountInfoInteger(ACCOUNT_CURRENCY_DIGITS);
   snapshot.fingerprint=PS_ExposureFingerprint(snapshot,currency_digits);
   snapshot.calculated_at_ms=GetTickCount64();
   snapshot.enumeration_valid=true;
   return(true);
  }

bool PS_ExposureMeaningfullyChanged(const PSExposureSnapshot &before,
                                    const PSExposureSnapshot &after,
                                    const int currency_digits)
  {
   if(before.enumeration_valid!=after.enumeration_valid) return(true);
   if(PS_IsPositiveFinite(before.equity_basis)!=PS_IsPositiveFinite(after.equity_basis)) return(true);
   double unit=MathPow(10.0,-MathMax(0,currency_digits));
   if(MathAbs(before.chart_loss_money-after.chart_loss_money)>=unit) return(true);
   if(MathAbs(before.account_loss_money-after.account_loss_money)>=unit) return(true);
   if(MathAbs(before.chart_loss_percent-after.chart_loss_percent)>=0.005) return(true);
   if(MathAbs(before.account_loss_percent-after.account_loss_percent)>=0.005) return(true);
   if(before.chart_no_sl!=after.chart_no_sl || before.account_no_sl!=after.account_no_sl) return(true);
   if(before.chart_unavailable!=after.chart_unavailable ||
      before.account_unavailable!=after.account_unavailable) return(true);
   if(ArraySize(before.items)!=ArraySize(after.items)) return(true);
   if(before.fingerprint!=after.fingerprint) return(true);
   // Locked profits add zero to loss totals, but their detail percentages still
   // depend on equity. Repaint only when a displayed two-decimal value changes.
   if(before.equity_basis>0.0 && after.equity_basis>0.0 &&
      before.equity_basis!=after.equity_basis)
      for(int i=0;i<ArraySize(after.items);i++)
        {
         if(after.items[i].status!=PS_EXPOSURE_VALID) continue;
         double old_percent=before.items[i].projected_result/before.equity_basis*100.0;
         double new_percent=after.items[i].projected_result/after.equity_basis*100.0;
         if(NormalizeDouble(old_percent,2)!=NormalizeDouble(new_percent,2)) return(true);
        }
   return(false);
  }

#endif
