#property strict
#property copyright "LotCraft"
#property link      ""
#property version   "1.10"
#property description "LotCraft 1.1.0"
#property description "Discretionary position sizing and explicit MT5 order entry assistant."

#include "PS_Platform.mqh"
#include "PS_Persistence.mqh"
#include "PS_Trade.mqh"

PSModel          g_model;
PSMarketSnapshot g_market;
PSCalcResult     g_calc;
PSEditorState    g_editor;
PSPointerState   g_pointer;
PSUIState        g_ui;

string g_persistence_base="";
bool   g_initialized=false;
bool   g_trade_in_flight=false;
bool   g_shift_down=false;
bool   g_ctrl_down=false;
ulong  g_last_market_refresh_ms=0;
ulong  g_last_line_lock_ms=0;
ulong  g_last_submit_ms=0;
ulong  g_status_until_ms=0;
ulong  g_last_editor_click_ms=0;
int    g_last_editor_click_x=0;
int    g_last_editor_click_y=0;
ulong  g_copy_feedback_until_ms=0;
ulong  g_last_chart_mouse_event_ms=0;
string g_active_symbol="";
string g_transition_target_symbol="";
bool   g_symbol_transition_pending=false;
bool   g_pointer_motion_pending=false;
int    g_pointer_motion_x=0;
int    g_pointer_motion_y=0;
bool   g_update_check_launched=false;
ulong  g_update_check_start_ms=0;
PSFieldId g_last_editor_click_field=PS_FIELD_NONE;
PSControlId g_copy_feedback_control=PS_CTRL_NONE;
ulong  g_control_last_action[PS_CTRL_COUNT];
const int PS_PANEL_DRAG_THRESHOLD_PX=5;
const int PS_HANDLE_DRAG_THRESHOLD_PX=3;
const int PS_POINTER_TIMER_MS=8;

void PS_UpdateInteractionGuard(const int x,const int y);

void PS_SetStatus(const string text,const bool is_error,const ulong duration_ms=5000)
  {
   g_model.status=text;
   g_model.status_is_error=is_error;
   g_status_until_ms=(duration_ms>0 ? GetTickCount64()+duration_ms : 0);
   g_ui.dirty=true;
  }

void PS_ClearTransientStatus()
  {
   g_model.status="Ready.";
   g_model.status_is_error=false;
   g_status_until_ms=0;
  }

void PS_SaveState()
  {
   if(g_persistence_base!="" && !g_symbol_transition_pending)
      PS_PersistenceSave(g_persistence_base,g_market,g_model);
  }

bool PS_BuildFreshPlan(string &error)
  {
   double visible_min=ChartGetDouble(ChartID(),CHART_PRICE_MIN,0);
   double visible_max=ChartGetDouble(ChartID(),CHART_PRICE_MAX,0);
   int chart_height=(int)ChartGetInteger(ChartID(),CHART_HEIGHT_IN_PIXELS,0);
   return(PS_ModelBuildFreshSymbolPlan(g_model,g_market,visible_min,visible_max,
                                       chart_height,error));
  }

void PS_AbortInteractionForContextChange()
  {
   PS_EditorReset(g_editor);
   g_pointer.capture=PS_CAPTURE_NONE;
   g_pointer.control=PS_CTRL_NONE;
   g_pointer.drag_started=false;
   g_pointer.editor_double_click=false;
   g_pointer.native_pointer_calibrated=false;
   g_pointer.stepper_active=false;
   g_pointer.stepper_pointer_inside=false;
   g_pointer_motion_pending=false;
   PS_UIGuardExit(g_ui);
  }

void PS_Recalculate(const bool clear_status=false)
  {
   if(clear_status) PS_ClearTransientStatus();
   bool entry_active=(g_editor.active && g_editor.field==PS_FIELD_ENTRY);
   PS_ModelSyncInstantEntry(g_model,g_market,entry_active);
   PS_RiskCalculate(g_model,g_market,g_calc);
   g_ui.dirty=true;
   g_ui.line_dirty=true;
  }

void PS_RefreshMarket(const bool clear_status=false)
  {
   string previous_symbol=g_active_symbol;
   PSMarketSnapshot refreshed;
   PS_MarketAcquire(refreshed);
   bool symbol_changed=(previous_symbol!="" && refreshed.symbol!="" &&
                        refreshed.symbol!=previous_symbol);
   if(symbol_changed)
     {
      if(!g_symbol_transition_pending) PS_SaveState();
      PS_AbortInteractionForContextChange();
      PS_CopyMarketSnapshot(g_market,refreshed);
      g_transition_target_symbol=refreshed.symbol;
      string transition_error="";
      if(PS_BuildFreshPlan(transition_error))
        {
         g_symbol_transition_pending=false;
         g_transition_target_symbol="";
         g_active_symbol=refreshed.symbol;
         PS_SetStatus("Entry and planning levels were fitted to "+refreshed.symbol+".",false,3000);
        }
      else
        {
         g_symbol_transition_pending=true;
         PS_UIHidePanelContent(g_ui);
         PS_UIHidePlanningLines(g_ui);
         PS_LogWarningRateLimited("symbol-transition.wait",transition_error,5000);
         g_last_market_refresh_ms=GetTickCount64();
         return;
        }
     }
   else
     {
      PS_CopyMarketSnapshot(g_market,refreshed);
      if(g_symbol_transition_pending && refreshed.symbol==g_transition_target_symbol)
        {
         string transition_error="";
         if(!PS_BuildFreshPlan(transition_error))
           {
            PS_UIHidePanelContent(g_ui);
            PS_UIHidePlanningLines(g_ui);
            PS_LogWarningRateLimited("symbol-transition.wait",transition_error,5000);
            g_last_market_refresh_ms=GetTickCount64();
            return;
           }
         g_symbol_transition_pending=false;
         g_transition_target_symbol="";
         g_active_symbol=refreshed.symbol;
        }
      else PS_ModelEnsureInitialPrices(g_model,g_market);
     }
   if(g_active_symbol=="") g_active_symbol=refreshed.symbol;
   g_last_market_refresh_ms=GetTickCount64();
   PS_Recalculate(clear_status);
  }

void PS_RenderIfDirty()
  {
   if(!g_initialized || !g_ui.created || g_symbol_transition_pending) return;
   if(g_pointer.capture==PS_CAPTURE_PANEL) return;
   bool drag_capture=(g_pointer.capture==PS_CAPTURE_HANDLE_ENTRY ||
                      g_pointer.capture==PS_CAPTURE_HANDLE_STOP ||
                      g_pointer.capture==PS_CAPTURE_HANDLE_TAKE);
    if(drag_capture)
      {
       if(!g_pointer.drag_started) return;
       // Keep pointer motion lightweight. Dynamic panel values remain marked
      // dirty and are rendered once when capture ends.
      if(g_ui.line_dirty) PS_UIRenderLinesOnly(g_ui,g_model,g_market);
      return;
     }
   if(g_ui.dirty) PS_UIRender(g_ui,g_model,g_calc,g_market,g_editor,g_copy_feedback_control);
   else if(g_ui.line_dirty) PS_UIRenderLinesOnly(g_ui,g_model,g_market);
  }

bool PS_CommitEditor()
  {
   if(!g_editor.active) return(true);
   PSFieldId field=g_editor.field;
   string error="";
   bool committed=PS_EditorCommit(g_editor,g_model,g_market,error);
   if(!committed)
     {
      PS_SetStatus(error,true,6000);
      PS_Recalculate(false);
      PS_UpdateInteractionGuard(g_pointer.last_x,g_pointer.last_y);
      return(false);
     }

   if(field==PS_FIELD_ENTRY && g_model.order_mode==PS_ORDER_INSTANT)
     {
      PS_ModelSyncInstantEntry(g_model,g_market,false);
      PS_SetStatus("Instant Entry follows the latest executable market price. Select Pending for a durable manual Entry.",false,6000);
     }
   else if(field==PS_FIELD_STOP)
     {
      PS_ModelAlignDirectionToStop(g_model,g_market);
      PS_ClearTransientStatus();
     }
   else PS_ClearTransientStatus();
   PS_Recalculate(false);
   PS_SaveState();
   PS_UpdateInteractionGuard(g_pointer.last_x,g_pointer.last_y);
   return(true);
  }

void PS_CancelEditor()
  {
   if(!g_editor.active) return;
   PS_EditorCancel(g_editor,g_model);
   PS_ClearTransientStatus();
   PS_Recalculate(false);
   PS_UpdateInteractionGuard(g_pointer.last_x,g_pointer.last_y);
  }

bool PS_ControlIsStepper(const PSControlId control)
  {
   return(control==PS_CTRL_ENTRY_MINUS || control==PS_CTRL_ENTRY_PLUS ||
          control==PS_CTRL_STOP_MINUS || control==PS_CTRL_STOP_PLUS ||
          control==PS_CTRL_TAKE_MINUS || control==PS_CTRL_TAKE_PLUS);
  }

void PS_StepPrice(const PSControlId control,const int tick_multiplier=1)
  {
   if(!g_market.symbol_ready || !PS_IsPositiveFinite(g_market.tick_size))
     {
      PS_SetStatus("Cannot step price because the broker tick size is unavailable.",true);
      return;
     }

   bool plus=(control==PS_CTRL_ENTRY_PLUS || control==PS_CTRL_STOP_PLUS || control==PS_CTRL_TAKE_PLUS);
   int multiplier=MathMax(1,tick_multiplier);
   double distance=g_market.tick_size*multiplier;
   double delta=(plus ? distance : -distance);
   if(control==PS_CTRL_ENTRY_MINUS || control==PS_CTRL_ENTRY_PLUS)
     {
      if(g_model.order_mode==PS_ORDER_INSTANT)
        {
         g_pointer.stepper_active=false;
         PS_SetStatus("Entry is market-bound in Instant mode. Select Pending to adjust Entry.",false,5000);
         return;
        }
      g_model.entry=PS_NormalizePrice(MathMax(g_market.tick_size,g_model.entry+delta),g_market);
     }
   else if(control==PS_CTRL_STOP_MINUS || control==PS_CTRL_STOP_PLUS)
     {
      g_model.stop_loss=PS_NormalizePrice(MathMax(g_market.tick_size,g_model.stop_loss+delta),g_market);
      PS_ModelAlignDirectionToStop(g_model,g_market);
     }
   else
     {
      double base=(PS_IsPositiveFinite(g_model.take_profit) ? g_model.take_profit :
                   (g_calc.effective_entry>0.0 ? g_calc.effective_entry : g_model.entry));
      double stepped=base+delta;
      g_model.take_profit=(stepped<=0.0 ? 0.0 : PS_NormalizePrice(stepped,g_market));
     }
   g_model.revision++;
   PS_ClearTransientStatus();
   PS_Recalculate(false);
   PS_RenderIfDirty();
  }

bool PS_CopyText(const string text,const string description)
  {
   string error="";
   if(PS_PlatformClipboardSet(text,error))
     {
      PS_SetStatus(description+" copied to the clipboard.",false,3000);
      return(true);
     }
   PS_SetStatus(error,true,6000);
   return(false);
  }

void PS_DoCopy(const PSControlId control)
  {
   bool copied=false;
   if(control==PS_CTRL_ENTRY_COPY)
     {
      double value=(g_model.order_mode==PS_ORDER_INSTANT && g_market.tick_valid)
                   ? (g_model.direction==PS_DIRECTION_LONG ? g_market.tick.ask : g_market.tick.bid)
                   : g_model.entry;
      copied=PS_CopyText(PS_PriceText(PS_NormalizePrice(value,g_market),g_market),"Entry");
     }
   else if(control==PS_CTRL_STOP_COPY)
      copied=PS_CopyText(PS_PriceText(PS_NormalizePrice(g_model.stop_loss,g_market),g_market),"Stop-loss");
   else if(control==PS_CTRL_TAKE_COPY)
      copied=PS_CopyText(PS_PriceText(PS_IsPositiveFinite(g_model.take_profit) ? PS_NormalizePrice(g_model.take_profit,g_market) : 0.0,g_market),"Take-profit");
   else if(control==PS_CTRL_POSITION_COPY)
     {
      if(!g_calc.valid)
        {
         PS_SetStatus("Position size is unavailable until the configuration is valid.",true);
         return;
        }
      copied=PS_CopyText(PS_VolumeText(g_calc.volume,g_market),"Position size");
     }
   if(copied)
     {
      g_copy_feedback_control=control;
      g_copy_feedback_until_ms=GetTickCount64()+1200;
      g_ui.dirty=true;
     }
  }

bool PS_BuildFreshTradeSnapshot(PSTradeSnapshot &snapshot,string &error)
  {
   error="";
   PS_RefreshMarket(false);
   if(!PS_TradeBuildSnapshot(g_model,g_market,g_calc,snapshot))
     {
      error=snapshot.error;
      return(false);
     }
   return(true);
  }

void PS_DoTrade()
  {
   ulong now=GetTickCount64();
   if(g_trade_in_flight)
     {
      PS_SetStatus("A LotCraft trade request is already in flight.",true);
      return;
     }
   if(now-g_last_submit_ms<750)
     {
      PS_SetStatus("Duplicate trade submission was blocked.",true,3000);
      return;
     }
   if(!PS_CommitEditor()) return;

   PSTradeSnapshot confirmed;
   string error="";
   if(!PS_BuildFreshTradeSnapshot(confirmed,error))
     {
      PS_SetStatus(error,true,7000);
      return;
     }

   if(g_model.ask_confirmation)
     {
      int answer=MessageBox(PS_TradeConfirmationText(confirmed,g_market),
                            PS_PRODUCT_NAME+" "+PS_VERSION_TEXT+" confirmation",
                            MB_YESNO|MB_ICONQUESTION);
      if(answer!=IDYES)
        {
         PS_SetStatus("Trade canceled. No request was sent.",false,4000);
         return;
        }

      PSTradeSnapshot refreshed;
      if(!PS_BuildFreshTradeSnapshot(refreshed,error))
        {
         PS_SetStatus("Trade changed or became invalid after confirmation: "+error,true,7000);
         return;
        }
      // Confirmation is intentionally one-stage. Quotes can move while the
      // dialog is open, so execute the freshly revalidated request without
      // asking the user to approve a second, near-identical dialog.
      PS_CopyTradeSnapshot(confirmed,refreshed);
     }

   g_trade_in_flight=true;
   g_last_submit_ms=GetTickCount64();
   MqlTradeResult result={};
   bool sent=PS_TradeSendSnapshot(confirmed,result,error);
   g_trade_in_flight=false;

   if(!sent)
      PS_SetStatus(error,true,9000);
   else
     {
      string ids="";
      if(result.order>0) ids+=StringFormat(" order #%I64u",result.order);
      if(result.deal>0) ids+=StringFormat(" deal #%I64u",result.deal);
      PS_SetStatus(StringFormat("Server response: %s (%u).%s",PS_TradeRetcodeText(result.retcode),result.retcode,ids),false,8000);
     }
   PS_RefreshMarket(false);
  }

void PS_DoMoveStops()
  {
   ulong now=GetTickCount64();
   if(g_trade_in_flight)
     {
      PS_SetStatus("A LotCraft trade request is already in flight.",true);
      return;
     }
   if(now-g_last_submit_ms<750)
     {
      PS_SetStatus("Duplicate trade modification was blocked.",true,3000);
      return;
     }
   if(!PS_CommitEditor()) return;
   PS_RefreshMarket(false);

   PSSlTarget targets[];
   int count=PS_TradeCollectSlTargets(g_model,g_market,targets);
   if(count<=0)
     {
      PS_SetStatus("No valid current-symbol positions or pending orders need to be moved to the red stop-loss line.",false,6000);
      return;
     }

   if(g_model.ask_confirmation)
     {
      int answer=MessageBox(PS_TradeSlConfirmationText(g_model,g_market,targets),
                            PS_PRODUCT_NAME+" stop-loss confirmation",
                            MB_YESNO|MB_ICONQUESTION);
      if(answer!=IDYES)
        {
         PS_SetStatus("Stop-loss batch canceled. No modification request was sent.",false,4000);
         return;
        }

      PS_RefreshMarket(false);
      PSSlTarget refreshed[];
      PS_TradeCollectSlTargets(g_model,g_market,refreshed);
      if(!PS_TradeSlTargetSetsEqual(targets,refreshed,g_market.tick_size))
        {
         if(ArraySize(refreshed)<=0)
           {
            PS_SetStatus("No targets remain eligible after confirmation. No modification request was sent.",false,5000);
            return;
           }
         int updated=MessageBox("The exact eligible target set changed after confirmation.\n\n"+
                                PS_TradeSlConfirmationText(g_model,g_market,refreshed),
                                PS_PRODUCT_NAME+" updated stop-loss confirmation",
                                MB_YESNO|MB_ICONQUESTION);
         if(updated!=IDYES)
           {
            PS_SetStatus("Updated stop-loss batch canceled. No modification request was sent.",false,4000);
            return;
           }

         PS_RefreshMarket(false);
         PSSlTarget final_targets[];
         PS_TradeCollectSlTargets(g_model,g_market,final_targets);
         if(!PS_TradeSlTargetSetsEqual(refreshed,final_targets,g_market.tick_size))
           {
            PS_SetStatus("The eligible stop-loss target set changed again before send. No request was sent; click Move SLs to line to retry.",true,8000);
            return;
           }
         PS_TradeCopySlTargets(targets,final_targets);
        }
      else PS_TradeCopySlTargets(targets,refreshed);
     }

   g_trade_in_flight=true;
   g_last_submit_ms=GetTickCount64();
   int succeeded=0;
   int failed=0;
   string details="";
   PS_TradeExecuteSlBatch(targets,succeeded,failed,details);
   g_trade_in_flight=false;

   string summary=StringFormat("Move SLs complete: %d succeeded, %d failed.",succeeded,failed);
   PS_SetStatus(summary,(failed>0),9000);
   PS_LogInfo(summary+"\n"+details);
   string visible=details;
   if(StringLen(visible)>1500) visible=StringSubstr(visible,0,1500)+"\n… See Experts log for remaining details.";
   MessageBox(summary+"\n\n"+visible,PS_PRODUCT_NAME+" stop-loss results",MB_OK|(failed>0 ? MB_ICONWARNING : MB_ICONINFORMATION));
   PS_RefreshMarket(false);
  }

void PS_Action(const PSControlId control)
  {
   switch(control)
     {
      case PS_CTRL_MANUAL:
        {
         string error="";
         if(PS_PlatformOpenNativeOrderDialog(error)) PS_SetStatus("MT5 New Order dialog requested for "+_Symbol+".",false,3000);
         else PS_SetStatus(error,true,6000);
         break;
        }
      case PS_CTRL_COMPACT:
         g_model.view_mode=(g_model.view_mode==PS_VIEW_COMPACT ? PS_VIEW_FULL : PS_VIEW_COMPACT);
         g_model.revision++;
         PS_SaveState();
         g_ui.dirty=true;
         break;
      case PS_CTRL_MINI:
         g_model.view_mode=(g_model.view_mode==PS_VIEW_MINI ? PS_VIEW_FULL : PS_VIEW_MINI);
         g_model.revision++;
         PS_SaveState();
         g_ui.dirty=true;
         break;
      case PS_CTRL_THEME:
         g_model.theme_mode=(g_model.theme_mode==PS_THEME_DARK ? PS_THEME_LIGHT : PS_THEME_DARK);
         g_model.revision++;
         PS_SaveState();
         g_ui.dirty=true;
         break;
      case PS_CTRL_CLOSE:
         ExpertRemove();
         break;
      case PS_CTRL_DIRECTION:
         PS_ModelChangeDirection(g_model,g_market,
                                 (g_model.direction==PS_DIRECTION_LONG ? PS_DIRECTION_SHORT : PS_DIRECTION_LONG));
         PS_ClearTransientStatus();
         PS_Recalculate(false);
         break;
      case PS_CTRL_ORDER_MODE:
        {
         if(!PS_CommitEditor()) break;
         string error="";
         PSOrderMode requested=(g_model.order_mode==PS_ORDER_INSTANT ? PS_ORDER_PENDING : PS_ORDER_INSTANT);
         if(!PS_ModelChangeOrderMode(g_model,g_market,requested,error))
           {
            PS_SetStatus(error,true,7000);
            break;
           }
         PS_ClearTransientStatus();
         PS_SaveState();
         PS_Recalculate(false);
         break;
        }
      case PS_CTRL_LINES:
         g_model.lines_visible=!g_model.lines_visible;
         PS_SaveState();
         PS_ClearTransientStatus();
         PS_Recalculate(false);
         break;
      case PS_CTRL_COMMISSION_MODE:
         g_model.commission_mode=(g_model.commission_mode==PS_COMMISSION_ONE_SIDE
                                  ? PS_COMMISSION_ROUND_TRIP : PS_COMMISSION_ONE_SIDE);
         g_model.revision++;
         PS_SaveState();
         PS_ClearTransientStatus();
         PS_Recalculate(false);
         break;
      case PS_CTRL_ACCOUNT_MODE:
         if(g_model.account_mode==PS_ACCOUNT_EQUITY) g_model.account_mode=PS_ACCOUNT_BALANCE;
         else if(g_model.account_mode==PS_ACCOUNT_BALANCE) g_model.account_mode=PS_ACCOUNT_MANUAL;
         else g_model.account_mode=PS_ACCOUNT_EQUITY;
         g_model.revision++;
         PS_SaveState();
         PS_ClearTransientStatus();
         PS_Recalculate(false);
         break;
      case PS_CTRL_CONFIRM:
         g_model.ask_confirmation=!g_model.ask_confirmation;
         g_model.revision++;
         PS_SaveState();
         PS_SetStatus(g_model.ask_confirmation ? "Confirmation enabled." : "Confirmation disabled.",false,3000);
         break;
      case PS_CTRL_ENTRY_COPY:
      case PS_CTRL_STOP_COPY:
      case PS_CTRL_TAKE_COPY:
      case PS_CTRL_POSITION_COPY:
         PS_DoCopy(control);
         break;
      case PS_CTRL_MOVE_SLS:
         PS_DoMoveStops();
         break;
      case PS_CTRL_TRADE:
         PS_DoTrade();
         break;
      default:
         break;
     }
   PS_RenderIfDirty();
  }

bool PS_UpdateLevelFromPointer(const PSCaptureMode capture,const int x,const int y,
                               const bool recalculate=true)
  {
   int subwindow=0;
   datetime time=0;
   double price=0.0;
   if(!ChartXYToTimePrice(ChartID(),x,y,subwindow,time,price)) return(false);
   price=PS_NormalizePrice(price,g_market);
   if(!PS_IsPositiveFinite(price)) return(false);

   double previous=0.0;
   bool direction_changed=false;
   if(capture==PS_CAPTURE_HANDLE_ENTRY)
     {
       if(g_model.order_mode==PS_ORDER_INSTANT)
         {
          string mode_error="";
          if(!PS_ModelChangeOrderMode(g_model,g_market,PS_ORDER_PENDING,mode_error))
            {
             PS_SetStatus(mode_error,true,7000);
             return(false);
            }
         }
       previous=g_model.entry;
       g_model.entry=price;
     }
   else if(capture==PS_CAPTURE_HANDLE_STOP)
     {
      previous=g_model.stop_loss;
      g_model.stop_loss=price;
      direction_changed=PS_ModelAlignDirectionToStop(g_model,g_market);
     }
   else if(capture==PS_CAPTURE_HANDLE_TAKE)
     {
      previous=g_model.take_profit;
      g_model.take_profit=price;
     }
   else return(false);

   double tolerance=(PS_IsPositiveFinite(g_market.tick_size) ? g_market.tick_size*0.5 : 0.0);
   if(MathAbs(previous-price)<=tolerance) return(false);

   g_model.revision++;
   PS_ClearTransientStatus();
   if(recalculate || direction_changed) PS_Recalculate(false);
   else g_ui.line_dirty=true;
   // A direction flip happens only when the stop crosses Entry. Refresh the
   // panel once at that boundary so Long/Short changes immediately, while
   // keeping the rest of pointer motion on the lightweight line-only path.
   if(direction_changed)
      PS_UIRender(g_ui,g_model,g_calc,g_market,g_editor,g_copy_feedback_control);
   else
      PS_RenderIfDirty();
   return(true);
  }


void PS_UpdateInteractionGuard(const int x,const int y)
  {
   bool handle_hit=false;
   PS_UIHitHandle(x,y,handle_hit);
   bool owns_input=(g_pointer.capture!=PS_CAPTURE_NONE || g_editor.active ||
                    PS_UIInPanel(g_ui,x,y) || handle_hit);
   if(owns_input) PS_UIGuardEnter(g_ui);
   else PS_UIGuardExit(g_ui);
  }

bool PS_IsMotionCapture()
  {
   return(g_pointer.capture==PS_CAPTURE_PANEL ||
          g_pointer.capture==PS_CAPTURE_HANDLE_ENTRY ||
          g_pointer.capture==PS_CAPTURE_HANDLE_STOP ||
          g_pointer.capture==PS_CAPTURE_HANDLE_TAKE ||
          (g_pointer.capture==PS_CAPTURE_CONTROL &&
           PS_UIFieldForControl(g_pointer.control)!=PS_FIELD_NONE &&
           g_editor.active));
  }

void PS_QueueCapturedMove(const int x,const int y)
  {
   if(!PS_IsMotionCapture()) return;
   g_pointer_motion_x=x;
   g_pointer_motion_y=y;
   g_pointer_motion_pending=true;
   g_pointer.last_x=x;
   g_pointer.last_y=y;
  }

void PS_FlushCapturedMove()
  {
   if(!g_pointer_motion_pending || !PS_IsMotionCapture()) return;
   int x=g_pointer_motion_x;
   int y=g_pointer_motion_y;
   g_pointer_motion_pending=false;
   PS_MouseMoveCaptured(x,y);
  }

void PS_ResetCapture(const int x,const int y)
  {
   g_pointer.capture=PS_CAPTURE_NONE;
   g_pointer.control=PS_CTRL_NONE;
   g_pointer.drag_started=false;
   g_pointer.editor_double_click=false;
   g_pointer.native_pointer_calibrated=false;
   g_pointer.native_offset_x=0;
   g_pointer.native_offset_y=0;
   g_pointer.applied_x=x;
   g_pointer.applied_y=y;
   g_pointer_motion_pending=false;
   g_pointer_motion_x=x;
   g_pointer_motion_y=y;
   g_pointer.stepper_active=false;
   g_pointer.stepper_pointer_inside=false;
   PS_UpdateInteractionGuard(x,y);
  }

void PS_MousePress(const int x,const int y)
  {
   ulong started=GetMicrosecondCount();
   int native_x=0;
   int native_y=0;
   g_pointer.native_pointer_calibrated=PS_PlatformPointerPosition(native_x,native_y);
   if(g_pointer.native_pointer_calibrated)
     {
      // CHARTEVENT_MOUSE_MOVE is relative to the chart drawing area, while
      // ScreenToClient can be relative to the chart window including its
      // client border. Calibrate the fallback source at capture start so the
      // two streams cannot alternate between nearby coordinates.
      g_pointer.native_offset_x=x-native_x;
      g_pointer.native_offset_y=y-native_y;
     }
   else
     {
      g_pointer.native_offset_x=0;
      g_pointer.native_offset_y=0;
     }
   g_pointer.start_x=x;
   g_pointer.start_y=y;
   g_pointer.last_x=x;
   g_pointer.last_y=y;
   g_pointer.applied_x=x;
   g_pointer.applied_y=y;
   g_pointer.drag_started=false;
   g_pointer.editor_double_click=false;
   g_pointer.press_ms=GetTickCount64();
   g_pointer.last_repeat_ms=g_pointer.press_ms;

   if(PS_UIInPanel(g_ui,x,y))
     {
      PS_UIGuardEnter(g_ui);
      PSControlId control=PS_UIHitControl(x,y);
      g_pointer.control=control;
      PSFieldId field=PS_UIFieldForControl(control);
      if(field!=PS_FIELD_NONE && PS_UIControlIsEditable(control,g_model))
        {
         if(g_editor.active && g_editor.field!=field && !PS_CommitEditor())
           {
            PS_PerfCheck("pointer",started,PS_POINTER_BUDGET_US);
            return;
           }
         ulong click_ms=GetTickCount64();
         bool same_field=(g_editor.active && g_editor.field==field);
         bool inside_double_click_area=
            (MathAbs(x-g_last_editor_click_x)<=PS_PlatformDoubleClickWidth()/2 &&
             MathAbs(y-g_last_editor_click_y)<=PS_PlatformDoubleClickHeight()/2);
         bool double_click=(same_field && g_last_editor_click_field==field &&
                            inside_double_click_area &&
                            click_ms-g_last_editor_click_ms<=PS_PlatformDoubleClickTime());
          if(!g_editor.active) PS_EditorBegin(g_editor,field,g_model,g_market);
          if(double_click) PS_EditorSelectAll(g_editor);
          else
            {
             int cursor=PS_UIEditorCursorIndex(g_ui,control,g_editor.raw_text,x);
             PS_EditorSetCursorIndex(g_editor,cursor,false);
            }
          g_pointer.editor_double_click=double_click;
         g_last_editor_click_field=field;
         g_last_editor_click_ms=click_ms;
         g_last_editor_click_x=x;
         g_last_editor_click_y=y;
         g_pointer.capture=PS_CAPTURE_CONTROL;
         g_ui.dirty=true;
         PS_RenderIfDirty();
         PS_PerfCheck("pointer",started,PS_POINTER_BUDGET_US);
         return;
        }

      if(g_editor.active && !PS_CommitEditor())
        {
         PS_PerfCheck("pointer",started,PS_POINTER_BUDGET_US);
         return;
        }
      if(PS_ControlIsStepper(control))
        {
         g_pointer.capture=PS_CAPTURE_STEPPER;
         g_pointer.stepper_active=true;
         g_pointer.stepper_pointer_inside=true;
         PS_StepPrice(control);
        }
      else if(control!=PS_CTRL_NONE)
        {
         g_pointer.capture=PS_CAPTURE_CONTROL;
        }
       else
         {
          g_pointer.capture=PS_CAPTURE_PANEL;
          g_pointer.panel_offset_x=x-g_ui.panel_x;
          g_pointer.panel_offset_y=y-g_ui.panel_y;
         }
      PS_PerfCheck("pointer",started,PS_POINTER_BUDGET_US);
      return;
     }

   bool handle_hit=false;
   PSLevelId level=PS_UIHitHandle(x,y,handle_hit);
   if(handle_hit)
     {
      if(g_editor.active && !PS_CommitEditor())
        {
         PS_PerfCheck("pointer",started,PS_POINTER_BUDGET_US);
         return;
        }
      PS_UIGuardEnter(g_ui);
       if(level==PS_LEVEL_ENTRY) g_pointer.capture=PS_CAPTURE_HANDLE_ENTRY;
       else if(level==PS_LEVEL_STOP) g_pointer.capture=PS_CAPTURE_HANDLE_STOP;
       else g_pointer.capture=PS_CAPTURE_HANDLE_TAKE;
       PS_PerfCheck("pointer",started,PS_POINTER_BUDGET_US);
      return;
     }

   if(g_editor.active) PS_CommitEditor();
   PS_UpdateInteractionGuard(x,y);
   PS_PerfCheck("pointer",started,PS_POINTER_BUDGET_US);
  }

void PS_MouseMoveCaptured(const int x,const int y)
  {
   if(g_pointer.capture==PS_CAPTURE_PANEL)
     {
      if(!g_pointer.drag_started)
        {
         int dx=MathAbs(x-g_pointer.start_x);
         int dy=MathAbs(y-g_pointer.start_y);
         if(MathMax(dx,dy)<PS_PANEL_DRAG_THRESHOLD_PX) return;
         if(!PS_UIBeginPanelDrag(g_ui,g_model.view_mode)) return;
         g_pointer.drag_started=true;
        }
      PS_UISetPanelPosition(g_ui,x-g_pointer.panel_offset_x,y-g_pointer.panel_offset_y,g_model.view_mode);
      }
   else if(g_pointer.capture==PS_CAPTURE_HANDLE_ENTRY ||
           g_pointer.capture==PS_CAPTURE_HANDLE_STOP ||
           g_pointer.capture==PS_CAPTURE_HANDLE_TAKE)
     {
      if(!g_pointer.drag_started)
        {
         int dx=MathAbs(x-g_pointer.start_x);
         int dy=MathAbs(y-g_pointer.start_y);
         if(MathMax(dx,dy)<PS_HANDLE_DRAG_THRESHOLD_PX) return;
         g_pointer.drag_started=true;
        }
      if(x!=g_pointer.applied_x || y!=g_pointer.applied_y)
        {
         g_pointer.applied_x=x;
         g_pointer.applied_y=y;
         PS_UpdateLevelFromPointer(g_pointer.capture,x,y,false);
        }
      }
   else if(g_pointer.capture==PS_CAPTURE_STEPPER)
     {
      PSRect rect=g_ps_control_rects[(int)g_pointer.control];
      if(!PS_RectContains(rect,x,y))
        {
         g_pointer.stepper_pointer_inside=false;
         g_pointer.stepper_active=false;
         }
      }
   else if(g_pointer.capture==PS_CAPTURE_CONTROL &&
           PS_UIFieldForControl(g_pointer.control)!=PS_FIELD_NONE &&
           g_editor.active && !g_pointer.editor_double_click)
     {
      if(!g_pointer.drag_started)
        {
         int dx=MathAbs(x-g_pointer.start_x);
         int dy=MathAbs(y-g_pointer.start_y);
         if(MathMax(dx,dy)<2) return;
         g_pointer.drag_started=true;
        }
      int cursor=PS_UIEditorCursorIndex(g_ui,g_pointer.control,g_editor.raw_text,x);
      PS_EditorSetCursorIndex(g_editor,cursor,true);
      g_ui.dirty=true;
      PS_RenderIfDirty();
     }
   g_pointer.last_x=x;
   g_pointer.last_y=y;
  }

void PS_MouseRelease(const int x,const int y)
  {
   // Apply the newest pointer sample before deciding whether this was a click
   // or a drag. Normal movement is frame-paced by OnTimer, while release must
   // always land on the exact final coordinate.
   if(PS_IsMotionCapture()) PS_MouseMoveCaptured(x,y);
   g_pointer_motion_pending=false;
   bool panel_dragged=(g_pointer.capture==PS_CAPTURE_PANEL && g_pointer.drag_started);
   if(panel_dragged)
     {
      PS_UISetPanelPosition(g_ui,x-g_pointer.panel_offset_x,y-g_pointer.panel_offset_y,g_model.view_mode);
      PS_UIPreparePanelDrop(g_ui);
     }
   if(g_pointer.capture==PS_CAPTURE_CONTROL && g_pointer.control!=PS_CTRL_NONE)
     {
      PSControlId control=g_pointer.control;
      if(PS_RectContains(g_ps_control_rects[(int)control],x,y) && PS_UIFieldForControl(control)==PS_FIELD_NONE)
        {
         ulong now=GetTickCount64();
         if(now-g_control_last_action[(int)control]>=300)
           {
            g_control_last_action[(int)control]=now;
            PS_Action(control);
           }
        }
     }
   if((g_pointer.capture==PS_CAPTURE_HANDLE_ENTRY ||
       g_pointer.capture==PS_CAPTURE_HANDLE_STOP ||
       g_pointer.capture==PS_CAPTURE_HANDLE_TAKE) && g_pointer.drag_started)
     {
      if(x!=g_pointer.applied_x || y!=g_pointer.applied_y)
         PS_UpdateLevelFromPointer(g_pointer.capture,x,y,false);
      // Intermediate pointer updates only move the chart line and handle.
      // Calculate position sizing once from the final price.
      PS_Recalculate(false);
       PS_UIApplyLineLock(g_ui,"line.entry");
       PS_UIApplyLineLock(g_ui,"line.stop");
       PS_UIApplyLineLock(g_ui,"line.take");
       PS_SaveState();
      }
   PS_ResetCapture(x,y);
   PS_RenderIfDirty();
   if(panel_dragged) PS_UIEndPanelDrag(g_ui);
  }

void PS_HandleMouseEvent(const int x,const int y,const uint mask)
  {
   bool left=((mask & 1)==1);
   bool was_left=((g_pointer.last_mouse_mask & 1)==1);

   if(g_pointer.capture==PS_CAPTURE_NONE)
     {
      PS_UpdateInteractionGuard(x,y);
      if(left && !was_left) PS_MousePress(x,y);
     }
   else
     {
      PS_UIGuardEnter(g_ui);
      if(!left) PS_MouseRelease(x,y);
      else if(PS_IsMotionCapture()) PS_QueueCapturedMove(x,y);
      else PS_MouseMoveCaptured(x,y);
     }

   g_pointer.last_x=x;
   g_pointer.last_y=y;
   g_pointer.last_mouse_mask=mask;
  }

void PS_HandleKeyDown(const int key)
  {
   if(key==16) g_shift_down=true;
   if(key==17) g_ctrl_down=true;
   if(!g_editor.active) return;
   PS_UIGuardEnter(g_ui);

   PSEditKeyResult result=PS_EditorKey(g_editor,key,g_shift_down,g_ctrl_down);
   if(result==PS_EDIT_KEY_CHANGED)
     {
      string ignored="";
      PS_EditorApplyRaw(g_editor,g_model,g_market,false,ignored);
      PS_ClearTransientStatus();
      PS_Recalculate(false);
     }
   else if(result==PS_EDIT_KEY_COMMIT) PS_CommitEditor();
   else if(result==PS_EDIT_KEY_CANCEL) PS_CancelEditor();
   g_ui.dirty=true;
   PS_RenderIfDirty();
  }

void PS_HandleKeyUp(const int key)
  {
   if(key==16) g_shift_down=false;
   if(key==17) g_ctrl_down=false;
  }

int PS_StepperAccelerationStage(const ulong elapsed)
  {
   if(elapsed<350) return(0);
   int stage=(int)((elapsed-350)/750);
   return(MathMin(stage,8));
  }

int PS_StepperTickMultiplier(const ulong elapsed)
  {
   int multiplier=1;
   int stage=PS_StepperAccelerationStage(elapsed);
   for(int index=0;index<stage;index++) multiplier*=2;
   return(multiplier);
  }

ulong PS_StepperRepeatInterval(const ulong elapsed)
  {
   ulong interval=120;
   int stage=MathMin(PS_StepperAccelerationStage(elapsed),3);
   for(int index=0;index<stage;index++) interval/=2;
   return(MathMax((ulong)15,interval));
  }

void PS_TimerStepper()
  {
   if(g_pointer.capture!=PS_CAPTURE_STEPPER || !g_pointer.stepper_active || !g_pointer.stepper_pointer_inside) return;
   ulong now=GetTickCount64();
   ulong elapsed=now-g_pointer.press_ms;
   if(elapsed<350) return;
   ulong interval=PS_StepperRepeatInterval(elapsed);
   if(now-g_pointer.last_repeat_ms<interval) return;
   g_pointer.last_repeat_ms=now;
   PS_StepPrice(g_pointer.control,PS_StepperTickMultiplier(elapsed));
  }

int OnInit()
  {
   if(!MQLInfoInteger(MQL_DLLS_ALLOWED))
     {
      string message="LotCraft 1.1.0 requires 'Allow DLL imports' for the required clipboard, native New Order dialog, and pointer-release safety integration. Enable the option and attach the EA again.";
      PS_LogError(message);
      MessageBox(message,PS_PRODUCT_NAME+" initialization",MB_OK|MB_ICONERROR);
      return(INIT_FAILED);
     }

   ZeroMemory(g_ui);
   ZeroMemory(g_pointer);
   PS_EditorReset(g_editor);
   g_pointer.capture=PS_CAPTURE_NONE;
   g_pointer.control=PS_CTRL_NONE;

   PS_MarketAcquire(g_market);
   PS_ModelInitialize(g_model,g_market);
   g_persistence_base=PS_PersistenceBase(g_market);
   bool same_symbol_plan_loaded=PS_PersistenceLoad(g_persistence_base,g_market,g_model);
   // Commission controls are intentionally absent from the compact panel.
   // Do not let a previously persisted hidden value affect position sizing.
   g_model.commission_mode=PS_COMMISSION_ROUND_TRIP;
   g_model.commission_per_lot=0.0;

   bool coherent_plan=(same_symbol_plan_loaded &&
                       PS_ModelStoredPlanStructurallyValid(g_model,g_market));
   if(coherent_plan && g_model.order_mode==PS_ORDER_INSTANT)
      PS_ModelSyncInstantEntry(g_model,g_market,false);
   if(!coherent_plan)
     {
      string transition_error="";
      coherent_plan=PS_BuildFreshPlan(transition_error);
      if(!coherent_plan)
        {
         g_symbol_transition_pending=true;
         g_transition_target_symbol=g_market.symbol;
         PS_LogWarningRateLimited("symbol-transition.init",transition_error,5000);
        }
     }
   if(coherent_plan) g_active_symbol=g_market.symbol;

   uint instance_hash=PS_HashString32(g_market.account_server+"|"+IntegerToString(g_market.account_login)+"|"+IntegerToString(ChartID()));
   g_ui.prefix=StringFormat("%s.%08X.",PS_OBJECT_NAMESPACE,instance_hash);
   g_ui.panel_x=16;
   g_ui.panel_y=28;
   PS_UIInitializeEvents(g_ui);
   if(!PS_UICreate(g_ui))
     {
      PS_UIDeleteOwned(g_ui);
      return(INIT_FAILED);
     }
   if(!EventSetMillisecondTimer(PS_POINTER_TIMER_MS))
     {
      PS_LogError(StringFormat("Cannot start UI timer (error %d).",GetLastError()));
      PS_UIDeleteOwned(g_ui);
      return(INIT_FAILED);
     }

   g_initialized=true;
   g_update_check_launched=(bool)MQLInfoInteger(MQL_TESTER);
   g_update_check_start_ms=GetTickCount64();
   if(g_symbol_transition_pending)
     {
      PS_UIHidePanelContent(g_ui);
      PS_UIHidePlanningLines(g_ui);
     }
   else
     {
      PS_Recalculate(false);
      PS_RenderIfDirty();
     }
   PS_LogInfo(StringFormat("%s %s initialized on %s chart %I64d.",PS_PRODUCT_NAME,PS_VERSION_TEXT,_Symbol,ChartID()));
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   g_initialized=false;
   EventKillTimer();
   if(g_editor.active)
     {
      string ignored="";
      PS_EditorCommit(g_editor,g_model,g_market,ignored);
     }
   PS_SaveState();
   GlobalVariablesFlush();
   PS_UIDeleteOwned(g_ui);
   PS_LogInfo(StringFormat("%s %s deinitialized (reason %d).",PS_PRODUCT_NAME,PS_VERSION_TEXT,reason));
  }

void OnTick()
  {
   if(!g_initialized) return;
   if(g_pointer.capture==PS_CAPTURE_PANEL ||
      g_pointer.capture==PS_CAPTURE_HANDLE_ENTRY ||
      g_pointer.capture==PS_CAPTURE_HANDLE_STOP ||
      g_pointer.capture==PS_CAPTURE_HANDLE_TAKE) return;
   ulong now=GetTickCount64();
   if(now-g_last_market_refresh_ms>=100)
     {
      PS_RefreshMarket(false);
      PS_RenderIfDirty();
     }
  }

void OnTimer()
  {
   if(!g_initialized) return;
   ulong now=GetTickCount64();
   if(!g_update_check_launched && now-g_update_check_start_ms>=10000)
     {
      // Launch once and return immediately. The detached updater owns all
      // network, prompting, verification, and installation work.
      g_update_check_launched=true;
      string update_error="";
      if(!PS_PlatformLaunchUpdater(update_error))
         PS_LogWarningRateLimited("updater.launch",update_error,60000);
     }

   int pointer_x=g_pointer.last_x;
   int pointer_y=g_pointer.last_y;
   bool pointer_known=PS_PlatformPointerPosition(pointer_x,pointer_y);
   if(pointer_known && g_pointer.native_pointer_calibrated)
     {
      pointer_x+=g_pointer.native_offset_x;
      pointer_y+=g_pointer.native_offset_y;
     }
   else if(pointer_known && g_pointer.capture!=PS_CAPTURE_NONE)
     {
      // An uncalibrated native point is useful for detecting button release,
      // but not for moving chart objects because its origin may differ.
      pointer_x=g_pointer.last_x;
      pointer_y=g_pointer.last_y;
     }
   if(g_pointer.capture!=PS_CAPTURE_NONE)
     {
      if(!PS_PlatformLeftButtonDown())
        {
         PS_MouseRelease((pointer_known ? pointer_x : g_pointer.last_x),
                         (pointer_known ? pointer_y : g_pointer.last_y));
         g_pointer.last_mouse_mask=0;
        }
      else if(pointer_known &&
              (pointer_x!=g_pointer.last_x || pointer_y!=g_pointer.last_y))
        {
         PS_QueueCapturedMove(pointer_x,pointer_y);
        }
     }
   else if(g_ui.guard_saved && !g_editor.active && pointer_known)
     {
      // Restore chart interaction immediately when the pointer leaves all owned
      // hit regions, including a pointer exit that produces no chart mouse event.
      PS_UpdateInteractionGuard(pointer_x,pointer_y);
     }
   // Chart events only publish the newest pointer coordinate. Applying panel
   // and handle movement once per timer frame prevents redraw backlogs during
   // fast motion and gives both interaction paths identical pacing.
   PS_FlushCapturedMove();
   PS_TimerStepper();

   bool motion_capture=(g_pointer.capture==PS_CAPTURE_PANEL ||
                        g_pointer.capture==PS_CAPTURE_HANDLE_ENTRY ||
                        g_pointer.capture==PS_CAPTURE_HANDLE_STOP ||
                        g_pointer.capture==PS_CAPTURE_HANDLE_TAKE);
   if(!motion_capture && now-g_last_market_refresh_ms>=250) PS_RefreshMarket(false);
   if(now-g_last_line_lock_ms>=1000)
     {
      PS_UIApplyLineLock(g_ui,"line.entry");
      PS_UIApplyLineLock(g_ui,"line.stop");
      PS_UIApplyLineLock(g_ui,"line.take");
      g_ui.line_dirty=true;
      g_last_line_lock_ms=now;
     }
   if(g_status_until_ms>0 && now>=g_status_until_ms) PS_ClearTransientStatus();
   if(g_copy_feedback_until_ms>0 && now>=g_copy_feedback_until_ms)
     {
      g_copy_feedback_until_ms=0;
      g_copy_feedback_control=PS_CTRL_NONE;
      g_ui.dirty=true;
     }
   PS_RenderIfDirty();
  }

void OnTrade()
  {
   if(!g_initialized) return;
   PS_RefreshMarket(false);
   PS_RenderIfDirty();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
  {
   if(!g_initialized) return;
   if(trans.symbol==_Symbol)
     {
      PS_RefreshMarket(false);
      PS_RenderIfDirty();
     }
  }

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
  {
   if(!g_initialized) return;
   if(id==CHARTEVENT_KEYDOWN)
     {
      PS_HandleKeyDown((int)lparam);
      return;
     }
   if(id==CHARTEVENT_KEYUP)
     {
      PS_HandleKeyUp((int)lparam);
      return;
     }
   if(id==CHARTEVENT_MOUSE_MOVE)
     {
      int pointer_x=(int)lparam;
      int pointer_y=(int)dparam;
      if(g_pointer.capture!=PS_CAPTURE_NONE && g_pointer.native_pointer_calibrated)
        {
         int native_x=0;
         int native_y=0;
         if(PS_PlatformPointerPosition(native_x,native_y))
           {
            pointer_x=native_x+g_pointer.native_offset_x;
            pointer_y=native_y+g_pointer.native_offset_y;
           }
        }
      g_last_chart_mouse_event_ms=GetTickCount64();
      PS_HandleMouseEvent(pointer_x,pointer_y,(uint)StringToInteger(sparam));
      return;
     }
   if(id==CHARTEVENT_MOUSE_WHEEL)
     {
      int x=(int)(short)lparam;
      int y=(int)(short)(lparam>>16);
      PS_UpdateInteractionGuard(x,y);
      return;
     }
   if(id==CHARTEVENT_CLICK)
     {
      int x=(int)lparam;
      int y=(int)dparam;
      if(!PS_UIInPanel(g_ui,x,y) && g_editor.active) PS_CommitEditor();
      PS_UpdateInteractionGuard(x,y);
      return;
     }
   if(id==CHARTEVENT_CHART_CHANGE)
     {
      PS_RefreshMarket(false);
      PS_UIClampPanel(g_ui,g_model.view_mode);
      g_ui.dirty=true;
      g_ui.line_dirty=true;
      PS_RenderIfDirty();
      return;
     }
   if(id==CHARTEVENT_OBJECT_DRAG || id==CHARTEVENT_OBJECT_CHANGE || id==CHARTEVENT_OBJECT_CLICK)
     {
      if(StringFind(sparam,g_ui.prefix+"line.")==0)
        {
         PS_UIApplyLineLock(g_ui,"line.entry");
         PS_UIApplyLineLock(g_ui,"line.stop");
         PS_UIApplyLineLock(g_ui,"line.take");
         g_ui.line_dirty=true;
         PS_RenderIfDirty();
        }
     }
  }
