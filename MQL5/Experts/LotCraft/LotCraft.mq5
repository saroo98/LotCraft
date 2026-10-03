#property strict
#property copyright "LotCraft"
#property link      ""
#property version   "1.23"
#property description "LotCraft 1.2.3"
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
PSExposureSnapshot g_exposure;
PSExposureUIState  g_exposure_ui;

string g_persistence_base="";
bool   g_initialized=false;
bool   g_trade_in_flight=false;
bool   g_shift_down=false;
bool   g_ctrl_down=false;
bool   g_shift_state_known=false;
bool   g_ctrl_state_known=false;
uint   g_shift_pressed_keys=0;
uint   g_ctrl_pressed_keys=0;
uint   g_shortcut_keydowns=0;
bool   g_shortcut_ctrl_context=false;
bool   g_shortcut_shift_context=false;
PSFieldId g_shortcut_field=PS_FIELD_NONE;
ulong  g_last_market_refresh_ms=0;
ulong  g_last_exposure_refresh_ms=0;
ulong  g_exposure_retry_after_ms=0;
ulong  g_panel_retry_after_ms=0;
ulong  g_last_line_lock_ms=0;
ulong  g_last_submit_ms=0;
ulong  g_status_until_ms=0;
ulong  g_last_editor_click_ms=0;
int    g_last_editor_click_x=0;
int    g_last_editor_click_y=0;
ulong  g_copy_feedback_until_ms=0;
ulong  g_exposure_hover_until_ms=0;
ulong  g_last_chart_mouse_event_ms=0;
string g_active_symbol="";
string g_transition_target_symbol="";
bool   g_symbol_transition_pending=false;
bool   g_pointer_motion_pending=false;
int    g_pointer_motion_x=0;
int    g_pointer_motion_y=0;
bool   g_update_checks_enabled=false;
bool   g_exposure_dirty=true;
bool   g_panel_dirty=true;
bool   g_exposure_details_dirty=true;
bool   g_exposure_labels_dirty=true;
ulong  g_next_update_check_ms=0;
PSFieldId g_last_editor_click_field=PS_FIELD_NONE;
PSControlId g_copy_feedback_control=PS_CTRL_NONE;
PSExposureHit g_exposure_pressed_hit=PS_EXPOSURE_HIT_NONE;
int g_exposure_pressed_row=-1;
ulong  g_control_last_action[PS_CTRL_COUNT];
const int PS_PANEL_DRAG_THRESHOLD_PX=5;
const int PS_HANDLE_DRAG_THRESHOLD_PX=3;
const int PS_POINTER_TIMER_MS=8;

void PS_UpdateInteractionGuard(const int x,const int y);

void PS_RefreshExposure(const bool force=false)
  {
   if(!g_initialized || g_symbol_transition_pending) return;
   ulong now=GetTickCount64();
   if(!force && now<g_exposure_retry_after_ms) return;
   if(!force && !g_exposure_dirty && now-g_last_exposure_refresh_ms<1000) return;

   PSExposureSnapshot next;
   PS_ExposureReset(next);
   string error="";
   bool calculated=PS_ExposureCalculate(next,_Symbol,AccountInfoDouble(ACCOUNT_EQUITY),error);
   bool changed=false;
   if(calculated)
     {
      changed=PS_ExposureMeaningfullyChanged(g_exposure,next,g_market.currency_digits);
      calculated=PS_CopyExposureSnapshot(g_exposure,next);
      if(!calculated) error="Could not allocate the exposure display snapshot.";
     }
   if(!calculated)
     {
      // Old totals must not look current after an incomplete enumeration.
      PS_ExposureReset(g_exposure);
      g_last_exposure_refresh_ms=now;
      g_exposure_retry_after_ms=now+1000;
      g_exposure_dirty=true;
      g_ui.dirty=true;
      g_exposure_details_dirty=true;
      g_exposure_labels_dirty=true;
      g_ui.line_dirty=true;
      PS_LogWarningRateLimited("exposure.refresh",error,5000);
      return;
     }

   g_exposure_retry_after_ms=0;
   g_last_exposure_refresh_ms=now;
   g_exposure_dirty=false;
   if(changed)
     {
      g_ui.dirty=true;
      g_exposure_details_dirty=true;
      g_exposure_labels_dirty=true;
      g_ui.line_dirty=true;
     }
  }

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
      PS_PersistenceSave(g_persistence_base,g_market,g_model,g_exposure_ui);
  }

bool PS_BuildFreshPlan(string &error)
  {
   PSModel restored;
   PS_CopyModel(restored,g_model);
   if(PS_PersistenceLoadPlan(g_persistence_base,g_market,restored) &&
     PS_ModelStoredPlanStructurallyValid(restored,g_market))
     {
      restored.revision=g_model.revision+1;
      PS_ModelSyncInstantEntry(restored,g_market,false);
      PS_CopyModel(g_model,restored);
      error="";
      return(true);
     }
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
   g_keyboard_focus=PS_CTRL_NONE;
   g_pressed_control=PS_CTRL_NONE;
   g_hovered_control=PS_CTRL_NONE;
   PS_ResetKeyboardModifiers();
   PS_UIGuardExit(g_ui);
  }

void PS_AbortInteractionForRenderFailure()
  {
   // A failed paint must also cancel an interaction that started while the
   // panel was visible. Stop further plan changes; do not apply a release.
   PS_AbortInteractionForContextChange();
   g_exposure_pressed_hit=PS_EXPOSURE_HIT_NONE;
   g_exposure_pressed_row=-1;
   g_panel_dirty=true;
   g_panel_retry_after_ms=GetTickCount64()+1000;
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
   bool transition_completed=false;
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
         g_exposure_dirty=true;
         transition_completed=true;
         PS_SetStatus("Planning levels ready for "+refreshed.symbol+".",false,3000);
        }
      else
        {
         g_symbol_transition_pending=true;
         PS_UIHidePanelContent(g_ui);
         PS_UIHidePlanningLines(g_ui);
         PS_UIRenderWaitingPanel(g_ui,g_model,transition_error);
         PS_LogWarningRateLimited("symbol-transition.wait",transition_error,5000);
         g_last_market_refresh_ms=GetTickCount64();
         return;
        }
     }
   else
     {
      PS_CopyMarketSnapshot(g_market,refreshed);
      if(g_symbol_transition_pending && refreshed.symbol==g_active_symbol &&
         refreshed.symbol!=g_transition_target_symbol)
        {
         // A failed candidate never replaced the original plan. Returning to
         // its symbol cancels the wait and restores normal rendering.
         g_symbol_transition_pending=false;
         g_transition_target_symbol="";
         g_exposure_dirty=true;
         transition_completed=true;
        }
      if(g_symbol_transition_pending && refreshed.symbol==g_transition_target_symbol)
        {
         string transition_error="";
         if(!PS_BuildFreshPlan(transition_error))
           {
            PS_UIHidePanelContent(g_ui);
            PS_UIHidePlanningLines(g_ui);
            PS_UIRenderWaitingPanel(g_ui,g_model,transition_error);
            PS_LogWarningRateLimited("symbol-transition.wait",transition_error,5000);
            g_last_market_refresh_ms=GetTickCount64();
            return;
           }
         g_symbol_transition_pending=false;
         g_transition_target_symbol="";
         g_active_symbol=refreshed.symbol;
         g_exposure_dirty=true;
         transition_completed=true;
        }
      else PS_ModelEnsureInitialPrices(g_model,g_market);
     }
   if(g_active_symbol=="") g_active_symbol=refreshed.symbol;
   g_last_market_refresh_ms=GetTickCount64();
   PS_Recalculate(clear_status);
   if(transition_completed) PS_RefreshExposure(true);
  }

void PS_RenderIfDirty()
  {
   if(!g_initialized || !g_ui.created || g_symbol_transition_pending) return;
   if(!g_ps_panel_render_ready)
     {
      PS_AbortInteractionForContextChange();
      g_panel_dirty=true;
     }
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
      if(g_ps_exposure_labels_layout_dirty)
         PS_UIRenderExposureLabels(g_ui,g_model,g_exposure,g_market);
      return;
     }
   if(g_ui.dirty)
     {
      g_panel_dirty=true;
      g_ui.dirty=false;
     }
   bool redraw=false;
   if(g_panel_dirty)
     {
      if(GetTickCount64()<g_panel_retry_after_ms) return;
      if(!PS_UIRenderPanel(g_ui,g_model,g_calc,g_market,g_exposure,g_editor,g_copy_feedback_control))
        {
         PS_AbortInteractionForRenderFailure();
         return;
        }
      g_panel_retry_after_ms=0;
      g_panel_dirty=false;
      redraw=true;
     }
   // A direct panel render can also attempt the sidecar. Preserve that failed
   // work, but do not redraw the chart on every timer tick during its backoff.
   if(g_ps_exposure_retry_after_ms>0) g_exposure_details_dirty=true;
   if(g_exposure_details_dirty && GetTickCount64()>=g_ps_exposure_retry_after_ms)
     {
      g_exposure_details_dirty=!PS_UIRenderExposureDetails(g_ui,g_model,g_exposure,g_market);
      redraw=true;
     }
   if(g_ui.line_dirty)
     {
      PS_UIRenderLinesOnly(g_ui,g_model,g_market);
      redraw=true;
     }
   if(g_exposure_labels_dirty || g_ps_exposure_labels_layout_dirty)
     {
      PS_UIRenderExposureLabels(g_ui,g_model,g_exposure,g_market);
      g_exposure_labels_dirty=false;
      redraw=true;
     }
   if(redraw) ChartRedraw(ChartID());
  }

bool PS_CommitEditor()
  {
   PS_ResetShortcutContext();
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
   PS_ResetShortcutContext();
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
   g_copy_feedback_control=PS_CTRL_NONE;
   g_copy_feedback_until_ms=0;
   PS_SetStatus(error,true,6000);
   PS_LogWarningRateLimited("clipboard.copy",error,5000);
   return(false);
  }

void PS_DoCopy(const PSControlId control)
  {
   g_copy_feedback_control=PS_CTRL_NONE;
   g_copy_feedback_until_ms=0;
   g_ui.dirty=true;
   bool copied=false;
   if(control==PS_CTRL_ENTRY_COPY)
     {
      double value=(g_model.order_mode==PS_ORDER_INSTANT && g_market.tick_valid)
                   ? (g_model.direction==PS_DIRECTION_LONG ? g_market.tick.ask : g_market.tick.bid)
                   : g_model.entry;
      copied=PS_CopyText(PS_PriceText(value,g_market),"Entry");
     }
   else if(control==PS_CTRL_STOP_COPY)
      copied=PS_CopyText(PS_PriceText(g_model.stop_loss,g_market),"Stop-loss");
   else if(control==PS_CTRL_TAKE_COPY)
      copied=PS_CopyText(PS_PriceText(PS_IsPositiveFinite(g_model.take_profit) ? g_model.take_profit : 0.0,g_market),"Take-profit");
   else if(control==PS_CTRL_POSITION_COPY)
     {
      if(!g_calc.sizing_available)
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
   if(g_symbol_transition_pending)
     {
      error="Symbol data is still changing. No trade request was prepared.";
      return(false);
     }
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
   if(g_symbol_transition_pending)
     {
      PS_SetStatus("Symbol data is still changing. No stop-loss modification was prepared.",true,6000);
      return;
     }

   PSSlTarget targets[];
   int count=PS_TradeCollectSlTargets(g_model,g_market,targets);
   if(count<0)
     {
      PS_SetStatus("The complete stop-loss target set could not be read or allocated. No modification request was sent.",true,7000);
      return;
     }
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
      if(g_symbol_transition_pending || !g_market.symbol_ready)
        {
         PS_SetStatus("Symbol data changed during confirmation. No stop-loss modification was sent.",true,7000);
         return;
        }
      PSSlTarget refreshed[];
      if(PS_TradeCollectSlTargets(g_model,g_market,refreshed)<0)
        {
         PS_SetStatus("The complete stop-loss target set could not be refreshed. No modification request was sent.",true,7000);
         return;
        }
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
         if(g_symbol_transition_pending || !g_market.symbol_ready)
           {
            PS_SetStatus("Symbol data changed during confirmation. No stop-loss modification was sent.",true,7000);
            return;
           }
         PSSlTarget final_targets[];
         if(PS_TradeCollectSlTargets(g_model,g_market,final_targets)<0)
           {
            PS_SetStatus("The complete stop-loss target set could not be refreshed. No modification request was sent.",true,7000);
            return;
           }
         if(!PS_TradeSlTargetSetsEqual(refreshed,final_targets,g_market.tick_size))
           {
            PS_SetStatus("The eligible stop-loss target set changed again before send. No request was sent; click Move SLs to line to retry.",true,8000);
            return;
           }
         if(!PS_TradeCopySlTargets(targets,final_targets))
           {
            PS_SetStatus("The stop-loss target set could not be allocated. No modification request was sent.",true,7000);
            return;
           }
        }
      else if(!PS_TradeCopySlTargets(targets,refreshed))
        {
         PS_SetStatus("The stop-loss target set could not be allocated. No modification request was sent.",true,7000);
         return;
        }
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

void PS_SetViewModeState(const PSViewMode view_mode)
  {
   if(g_model.view_mode==view_mode) return;
   g_model.view_mode=view_mode;
   g_model.revision++;
   PS_SaveState();
   g_ui.dirty=true;
   g_exposure_details_dirty=true;
   g_exposure_labels_dirty=true;
  }

void PS_Action(const PSControlId control)
  {
   if(!g_initialized || g_symbol_transition_pending || !g_ps_panel_render_ready) return;
   if(control<0 || control>=PS_CTRL_COUNT || !g_ps_control_visible[(int)control]) return;
   switch(control)
     {
      case PS_CTRL_MANUAL:
        {
         string error="";
         if(PS_PlatformOpenNativeOrderDialog(error)) PS_SetStatus("MT5 New Order dialog requested for "+_Symbol+".",false,3000);
         else PS_SetStatus(error,true,6000);
         break;
        }
      case PS_CTRL_FULL:
         PS_SetViewModeState(PS_VIEW_FULL);
         break;
      case PS_CTRL_COMPACT:
         PS_SetViewModeState(PS_VIEW_COMPACT);
         break;
      case PS_CTRL_MINI:
         PS_SetViewModeState(PS_VIEW_MINI);
         break;
      case PS_CTRL_THEME:
         g_model.theme_mode=(g_model.theme_mode==PS_THEME_DARK ? PS_THEME_LIGHT : PS_THEME_DARK);
         g_model.revision++;
         PS_SaveState();
         g_ui.dirty=true;
         g_exposure_details_dirty=true;
         g_exposure_labels_dirty=true;
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
      case PS_CTRL_EXPOSURE_SUMMARY:
         g_exposure_ui.details_open=!g_exposure_ui.details_open;
         g_exposure_ui.scroll_offset=0;
         g_ui.dirty=true;
         g_exposure_details_dirty=true;
         g_exposure_labels_dirty=true;
         PS_SaveState();
         break;
      case PS_CTRL_MOVE_SLS:
         PS_DoMoveStops();
         break;
      case PS_CTRL_TRADE:
         if(g_calc.valid) PS_DoTrade();
         else PS_SetStatus(PS_CalcIssueText(g_calc.issue),false,2500);
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
     {
      PS_UIRender(g_ui,g_model,g_calc,g_market,g_exposure,g_editor,g_copy_feedback_control);
      if(!g_ps_panel_render_ready) PS_AbortInteractionForRenderFailure();
     }
   else
      PS_RenderIfDirty();
   return(true);
  }


void PS_UpdateInteractionGuard(const int x,const int y)
  {
   if(!g_initialized || g_symbol_transition_pending || !g_ps_panel_render_ready)
     {
      PS_UIGuardExit(g_ui);
      return;
     }
   bool handle_hit=false;
   PS_UIHitHandle(x,y,handle_hit);
   bool owns_input=(g_pointer.capture!=PS_CAPTURE_NONE || g_editor.active ||
                    PS_UIInPanel(g_ui,x,y) || handle_hit ||
                    (g_exposure_ui.details_open && PS_RectContains(g_exposure_ui.sidecar_rect,x,y)));
   if(owns_input) PS_UIGuardEnter(g_ui);
   else PS_UIGuardExit(g_ui);
  }

void PS_ExposureAction(const PSExposureHit hit,const int visible_row)
  {
   bool persist=false;
   if(hit==PS_EXPOSURE_HIT_CLOSE)
     {
      g_exposure_ui.details_open=false;
      persist=true;
     }
   else if(hit==PS_EXPOSURE_HIT_SCOPE_CHART)
     {
      g_exposure_ui.scope=PS_EXPOSURE_SCOPE_CHART;
      g_exposure_ui.scroll_offset=0;
      persist=true;
     }
   else if(hit==PS_EXPOSURE_HIT_SCOPE_ACCOUNT)
     {
      g_exposure_ui.scope=PS_EXPOSURE_SCOPE_ACCOUNT;
      g_exposure_ui.scroll_offset=0;
      persist=true;
     }
   else if(hit==PS_EXPOSURE_HIT_LABELS_TOGGLE)
     {
      g_exposure_ui.chart_labels_visible=!g_exposure_ui.chart_labels_visible;
      persist=true;
     }
   else if(hit==PS_EXPOSURE_HIT_SCROLL_UP)
      g_exposure_ui.scroll_offset=MathMax(0,g_exposure_ui.scroll_offset-1);
   else if(hit==PS_EXPOSURE_HIT_SCROLL_DOWN)
     {
      int maximum=MathMax(0,PS_UIExposureFilteredCount(g_exposure)-PS_UIExposurePageCapacity());
      g_exposure_ui.scroll_offset=MathMin(maximum,g_exposure_ui.scroll_offset+1);
     }
   else if(hit==PS_EXPOSURE_HIT_ROW && visible_row>=0)
     {
      int item_index=PS_UIExposureFilteredIndex(g_exposure,g_exposure_ui.scroll_offset+visible_row);
      if(item_index>=0)
        {
         g_exposure_ui.hovered_row=item_index;
         g_exposure_hover_until_ms=GetTickCount64()+1500;
        }
     }
   if(persist) PS_SaveState();
   g_exposure_details_dirty=true;
   g_exposure_labels_dirty=true;
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
   g_exposure_pressed_hit=PS_EXPOSURE_HIT_NONE;
   g_exposure_pressed_row=-1;
   if(g_pressed_control!=PS_CTRL_NONE)
     {
      g_pressed_control=PS_CTRL_NONE;
      g_panel_dirty=true;
     }
   PS_UpdateInteractionGuard(x,y);
  }

void PS_MousePress(const int x,const int y)
  {
   PS_ResetShortcutContext();
   if(!g_initialized || g_symbol_transition_pending || !g_ps_panel_render_ready) return;
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
       if(control==PS_CTRL_TRADE && !g_calc.valid)
         {
          // A closed or stale market keeps the panel usable, but the trade
          // action must not capture the pointer or submit a request.
          g_pointer.capture=PS_CAPTURE_NONE;
          g_pointer.control=PS_CTRL_NONE;
          g_pressed_control=PS_CTRL_NONE;
          g_keyboard_focus=PS_CTRL_NONE;
          g_panel_dirty=false;
          PS_PerfCheck("pointer",started,PS_POINTER_BUDGET_US);
          return;
         }
       g_pointer.control=control;
      g_pressed_control=control;
      g_keyboard_focus=control;
      g_panel_dirty=true;
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

   int exposure_row=-1;
   PSExposureHit exposure_hit=PS_UIExposureHitTest(x,y,exposure_row);
   if(exposure_hit!=PS_EXPOSURE_HIT_NONE)
     {
      if(g_editor.active && !PS_CommitEditor())
        {
         PS_PerfCheck("pointer",started,PS_POINTER_BUDGET_US);
         return;
        }
      PS_UIGuardEnter(g_ui);
      g_exposure_pressed_hit=exposure_hit;
      g_exposure_pressed_row=exposure_row;
      g_pointer.capture=PS_CAPTURE_CONTROL;
      PS_PerfCheck("pointer",started,PS_POINTER_BUDGET_US);
      return;
     }

   int label_item_index=PS_UIExposureLabelHitTest(x,y);
   if(label_item_index>=0)
     {
      if(g_editor.active && !PS_CommitEditor())
        {
         PS_PerfCheck("pointer",started,PS_POINTER_BUDGET_US);
         return;
        }
      int filtered_index=0;
      for(int i=0;i<label_item_index;i++)
         if(g_exposure.items[i].symbol==_Symbol) filtered_index++;
      g_exposure_ui.details_open=true;
      g_exposure_ui.scope=PS_EXPOSURE_SCOPE_CHART;
      int maximum=MathMax(0,PS_UIExposureFilteredCount(g_exposure)-PS_UIExposurePageCapacity());
      g_exposure_ui.scroll_offset=PS_ClampInt(filtered_index-3,0,maximum);
      g_exposure_ui.hovered_row=label_item_index;
      g_exposure_hover_until_ms=GetTickCount64()+1500;
      g_exposure_details_dirty=true;
      g_exposure_labels_dirty=true;
      PS_SaveState();
      PS_RenderIfDirty();
      PS_UIGuardEnter(g_ui);
      PS_PerfCheck("pointer",started,PS_POINTER_BUDGET_US);
      return;
     }

   if(g_editor.active) PS_CommitEditor();
   PS_UpdateInteractionGuard(x,y);
   PS_PerfCheck("pointer",started,PS_POINTER_BUDGET_US);
  }

void PS_MouseMoveCaptured(const int x,const int y)
  {
   if(!g_initialized || g_symbol_transition_pending || !g_ps_panel_render_ready)
     {
      PS_AbortInteractionForContextChange();
      return;
     }
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

bool PS_PointerAction(const PSControlId control,const int x,const int y)
  {
   if(g_model.view_mode==PS_VIEW_FULL &&
      (control==PS_CTRL_DIRECTION || control==PS_CTRL_ORDER_MODE))
     {
      PSRect left;
      PSRect right;
      PS_UISplitChoiceRects(g_ps_control_rects[(int)control],left,right);
      bool choose_left=(PS_RectContains(left,x,y) &&
                        PS_RectContains(left,g_pointer.start_x,g_pointer.start_y));
      bool choose_right=(PS_RectContains(right,x,y) &&
                         PS_RectContains(right,g_pointer.start_x,g_pointer.start_y));
      // Separate painted buttons need separate click ownership. The gap and a
      // press/release across two different choices must not change the model.
      if(!choose_left && !choose_right) return(false);
      bool left_active=(control==PS_CTRL_DIRECTION ? g_model.direction==PS_DIRECTION_LONG
                                                   : g_model.order_mode==PS_ORDER_INSTANT);
      if(choose_left==left_active) return(false);
     }
   // Compact and keyboard activation keep their existing single-control toggle.
   PS_Action(control);
   return(true);
  }

void PS_MouseRelease(const int x,const int y)
  {
   // Apply the newest pointer sample before deciding whether this was a click
   // or a drag. Normal movement is frame-paced by OnTimer, while release must
   // always land on the exact final coordinate.
   if(PS_IsMotionCapture()) PS_MouseMoveCaptured(x,y);
   if(!g_initialized || g_symbol_transition_pending || !g_ps_panel_render_ready)
     {
      PS_AbortInteractionForContextChange();
      return;
     }
   g_pointer_motion_pending=false;
   bool panel_dragged=(g_pointer.capture==PS_CAPTURE_PANEL && g_pointer.drag_started);
   if(panel_dragged)
     {
      PS_UISetPanelPosition(g_ui,x-g_pointer.panel_offset_x,y-g_pointer.panel_offset_y,g_model.view_mode);
      PS_UIPreparePanelDrop(g_ui);
      g_exposure_details_dirty=true;
      g_exposure_labels_dirty=true;
     }
   if(g_pointer.capture==PS_CAPTURE_CONTROL && g_pointer.control!=PS_CTRL_NONE)
     {
      PSControlId control=g_pointer.control;
      if(PS_RectContains(g_ps_control_rects[(int)control],x,y) && PS_UIFieldForControl(control)==PS_FIELD_NONE)
        {
         ulong now=GetTickCount64();
         if(now-g_control_last_action[(int)control]>=300)
           {
            if(PS_PointerAction(control,x,y))
               g_control_last_action[(int)control]=now;
           }
        }
     }
   else if(g_pointer.capture==PS_CAPTURE_CONTROL && g_exposure_pressed_hit!=PS_EXPOSURE_HIT_NONE)
     {
      int release_row=-1;
      PSExposureHit release_hit=PS_UIExposureHitTest(x,y,release_row);
      if(release_hit==g_exposure_pressed_hit &&
         (release_hit!=PS_EXPOSURE_HIT_ROW || release_row==g_exposure_pressed_row))
         PS_ExposureAction(release_hit,release_row);
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
   PS_ObserveMouseModifiers(mask);
   bool left=((mask & 1)==1);
   bool was_left=((g_pointer.last_mouse_mask & 1)==1);

   if(g_pointer.capture==PS_CAPTURE_NONE)
     {
      PSControlId next_hover=(PS_UIInPanel(g_ui,x,y) ? PS_UIHitControl(x,y) : PS_CTRL_NONE);
      if(next_hover!=g_hovered_control)
        {
         g_hovered_control=next_hover;
         g_panel_dirty=true;
         PS_RenderIfDirty();
        }
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

void PS_ResetShortcutContext()
  {
   g_shortcut_keydowns=0;
   g_shortcut_ctrl_context=false;
   g_shortcut_shift_context=false;
   g_shortcut_field=PS_FIELD_NONE;
  }

void PS_RecordShortcutContext()
  {
   g_shortcut_ctrl_context=g_ctrl_down;
   g_shortcut_shift_context=g_shift_down;
   g_shortcut_field=(g_editor.active ? g_editor.field : PS_FIELD_NONE);
  }

uint PS_KeyboardShortcutBit(const int key)
  {
   switch(key)
     {
      case 65: return(1);     // Select all.
      case 67: return(2);     // Copy.
      case 86: return(4);     // Paste.
      case 88: return(8);     // Cut.
      case 90: return(16);    // Undo / redo.
      case 89: return(32);    // Redo.
      case 45: return(64);    // Ctrl/Shift Insert.
      case 46: return(128);   // Ctrl/Shift Delete.
      case 8:  return(256);   // Ctrl Backspace.
      case 37: return(512);   // Modified caret movement / selection.
      case 39: return(1024);
      case 36: return(2048);
      case 35: return(4096);
      case 38: return(8192);
      case 40: return(16384);
     }
   return(0);
  }

void PS_ResetKeyboardModifiers()
  {
   PS_ResetShortcutContext();
   g_shift_down=false;
   g_ctrl_down=false;
   g_shift_state_known=false;
   g_ctrl_state_known=false;
   g_shift_pressed_keys=0;
   g_ctrl_pressed_keys=0;
  }

void PS_ObserveKeyboardModifier(const int key,const uint flags,const bool down)
  {
   uint side=PS_PlatformModifierSide(key,flags);
   if(side==0) return;
   // Bits 1/2 preserve independently delivered left/right presses. Bit 4 is
   // an aggregate seed or mouse snapshot with no side information; a delivered
   // release clears that seed, but not the other explicitly pressed side.
   if(key==16 || key==160 || key==161)
     {
      if(down) g_shift_pressed_keys|=side;
      else g_shift_pressed_keys&=~(side | (uint)4);
      g_shift_down=(g_shift_pressed_keys!=0);
      g_shift_state_known=true;
     }
   else
     {
      if(down) g_ctrl_pressed_keys|=side;
      else g_ctrl_pressed_keys&=~(side | (uint)4);
      g_ctrl_down=(g_ctrl_pressed_keys!=0);
      g_ctrl_state_known=true;
     }
  }

void PS_ObserveMouseModifiers(const uint mask)
  {
   // Mouse masks describe modifier state at event generation, not dispatch.
   g_shift_down=((mask & 4)!=0);
   g_ctrl_down=((mask & 8)!=0);
   g_shift_state_known=true;
   g_ctrl_state_known=true;
   // A held snapshot has no side information. Preserve delivered side identity;
   // only a released snapshot can clear every held side without ambiguity.
   if(g_shift_down) g_shift_pressed_keys|=4;
   else g_shift_pressed_keys=0;
   if(g_ctrl_down) g_ctrl_pressed_keys|=4;
   else g_ctrl_pressed_keys=0;
  }

void PS_KeyboardFocusNext(const bool reverse)
  {
   PS_ResetShortcutContext();
   PSControlId order[10];
   order[0]=PS_CTRL_ENTRY_FIELD;
   order[1]=PS_CTRL_STOP_FIELD;
   order[2]=PS_CTRL_TAKE_FIELD;
   order[3]=PS_CTRL_ACCOUNT_FIELD;
   order[4]=PS_CTRL_RISK_PERCENT_FIELD;
   order[5]=PS_CTRL_RISK_MONEY_FIELD;
   order[6]=PS_CTRL_CONFIRM;
   order[7]=PS_CTRL_MOVE_SLS;
   order[8]=PS_CTRL_EXPOSURE_SUMMARY;
   order[9]=PS_CTRL_TRADE;
   if(g_editor.active && !PS_CommitEditor()) return;
   int current=-1;
   for(int i=0;i<10;i++) if(order[i]==g_keyboard_focus) current=i;
   if(reverse && current<0) current=0;
   for(int step=1;step<=10;step++)
     {
      int index=(reverse ? current-step : current+step);
      while(index<0) index+=10;
      index%=10;
      PSControlId candidate=order[index];
      if(candidate==PS_CTRL_ENTRY_FIELD && g_model.order_mode==PS_ORDER_INSTANT) continue;
      if(candidate<0 || candidate>=PS_CTRL_COUNT || !g_ps_control_visible[(int)candidate]) continue;
      if(candidate==PS_CTRL_ACCOUNT_FIELD && !PS_UIControlIsEditable(candidate,g_model)) continue;
      g_keyboard_focus=candidate;
      PSFieldId field=PS_UIFieldForControl(candidate);
      if(field!=PS_FIELD_NONE && PS_UIControlIsEditable(candidate,g_model))
        {
         PS_EditorBegin(g_editor,field,g_model,g_market);
         PS_EditorSelectAll(g_editor);
        }
      g_panel_dirty=true;
      PS_UIGuardEnter(g_ui);
      PS_RenderIfDirty();
      return;
     }
  }

void PS_HandleKeyDown(const int key,const uint flags=0)
  {
   if(!g_initialized || g_symbol_transition_pending || !g_ps_panel_render_ready) return;
   // Seed unknown state once. Delivered modifier events then own both the
   // pressed and released state, even when this handler runs after release.
   if(!g_shift_state_known || !g_ctrl_state_known)
     {
      bool shift_down=false;
      bool ctrl_down=false;
      PS_PlatformKeyboardModifiers(shift_down,ctrl_down);
      if(!g_shift_state_known)
        {
         g_shift_down=shift_down; g_shift_state_known=true;
         g_shift_pressed_keys=(shift_down ? 4 : 0);
        }
      if(!g_ctrl_state_known)
        {
         g_ctrl_down=ctrl_down; g_ctrl_state_known=true;
         g_ctrl_pressed_keys=(ctrl_down ? 4 : 0);
        }
     }
   PS_ObserveKeyboardModifier(key,flags,true);
   // Modifier presses change no visible editor state. Keep this event short
   // so a following shortcut is not delayed by a needless panel repaint.
   if(key==16 || key==17 || (key>=160 && key<=163))
     {
      // Only a new modifier press starts a gesture. An auto-repeat must not
      // erase Shift/Ctrl already released before a swallowed letter press.
      if((flags & 0x4000)==0) PS_RecordShortcutContext();
      return;
     }
   // A delivered ordinary press starts its own context, so a previous Ctrl
   // tap cannot turn a later plain letter release into a clipboard command.
   PS_RecordShortcutContext();
   g_shortcut_keydowns|=PS_KeyboardShortcutBit(key);
   if(key==9)
     {
      PS_KeyboardFocusNext(g_shift_down);
      return;
     }
   if(key==27)
     {
      if(g_editor.active) PS_CancelEditor();
      else if(g_exposure_ui.details_open)
        {
         g_exposure_ui.details_open=false;
         g_exposure_details_dirty=true;
         g_exposure_labels_dirty=true;
         PS_SaveState();
        }
      g_panel_dirty=true;
      PS_RenderIfDirty();
      return;
     }
   if(!g_editor.active && (key==13 || key==32) && g_keyboard_focus>=0 &&
      g_keyboard_focus<PS_CTRL_COUNT && g_ps_control_visible[(int)g_keyboard_focus])
     {
      PS_Action(g_keyboard_focus);
      return;
     }
   PS_ExecuteEditorKey(key,g_shift_down,g_ctrl_down);
  }

void PS_ExecuteEditorKey(const int key,const bool shift_down,const bool ctrl_down)
  {
   if(!g_editor.active) return;
   PS_UIGuardEnter(g_ui);

   string before_text=g_editor.raw_text;
   int before_cursor=g_editor.cursor;
   int before_anchor=g_editor.anchor;
   PSEditKeyResult result=PS_EditorKey(g_editor,key,shift_down,ctrl_down);
   bool restoring_history=(result==PS_EDIT_KEY_UNDO || result==PS_EDIT_KEY_REDO);
   if(restoring_history)
     {
      int delta=(result==PS_EDIT_KEY_UNDO ? -1 : 1);
      result=(PS_EditorRestoreHistory(g_editor,g_model,delta) ? PS_EDIT_KEY_CHANGED : PS_EDIT_KEY_NONE);
     }
   if(result==PS_EDIT_KEY_CUT && g_editor.has_selection)
     {
      int first=PS_EditorSelectionStart(g_editor);
      int length=PS_EditorSelectionEnd(g_editor)-first;
      if(length>0 && PS_CopyText(StringSubstr(g_editor.raw_text,first,length),"Selection"))
        {
         PS_EditorDeleteSelection(g_editor);
         result=PS_EDIT_KEY_CHANGED;
        }
     }
   if(result==PS_EDIT_KEY_PASTE)
     {
      string pasted="";
      string error="";
      if(PS_PlatformClipboardGet(pasted,error) && PS_EditorPaste(g_editor,pasted,error))
         result=PS_EDIT_KEY_CHANGED;
      else
        {
         PS_SetStatus(error,true);
         PS_LogWarningRateLimited("clipboard.paste",error,5000);
        }
     }
   if(result==PS_EDIT_KEY_CHANGED && g_editor.raw_text!=before_text)
     {
      PSModel before_model;
      PS_CopyModel(before_model,g_model);
      string ignored="";
      if(!restoring_history) PS_EditorApplyRaw(g_editor,g_model,g_market,false,ignored);
      PS_ClearTransientStatus();
      PS_Recalculate(false);
      if(!restoring_history) PS_EditorRecordChange(g_editor,before_text,before_cursor,before_anchor,before_model,g_model);
     }
   else if(result==PS_EDIT_KEY_COMMIT) PS_CommitEditor();
   else if(result==PS_EDIT_KEY_CANCEL) PS_CancelEditor();
   else if(result==PS_EDIT_KEY_COPY && g_editor.has_selection)
     {
      int first=PS_EditorSelectionStart(g_editor);
      int length=PS_EditorSelectionEnd(g_editor)-first;
      if(length>0) PS_CopyText(StringSubstr(g_editor.raw_text,first,length),"Selection");
     }
   // The existing frame timer paints dirty editor state. Do not rasterize the
   // whole panel inside every key event while later chart keys are waiting.
   g_ui.dirty=true;
  }

void PS_HandleKeyUp(const int key,const uint flags=0)
  {
   PS_ObserveKeyboardModifier(key,flags,false);
   if(!g_initialized || g_symbol_transition_pending || !g_ps_panel_render_ready)
     {
      PS_ResetShortcutContext();
      return;
     }
   if(key==16 || key==17 || (key>=160 && key<=163)) return;

   uint bit=PS_KeyboardShortcutBit(key);
   bool press_seen=((g_shortcut_keydowns & bit)!=0);
   g_shortcut_keydowns&=~bit;
   bool same_editor=(g_editor.active && g_shortcut_field==g_editor.field);
   bool ctrl_context=g_shortcut_ctrl_context;
   bool shift_context=g_shortcut_shift_context;
   // Preserve held modifiers for another shortcut, but consume a released
   // modifier context once. Mouse/focus/lifecycle changes invalidate it.
   if(same_editor) PS_RecordShortcutContext();
   else PS_ResetShortcutContext();
   if(bit==0 || press_seen || !same_editor || (!ctrl_context && !shift_context)) return;
   // MT5 can consume a shortcut's KEYDOWN and deliver only its KEYUP. Use the
   // gesture context even when Ctrl was released before the letter. A seen
   // press above prevents duplicate copy, paste, cut or history operations.
   PS_ExecuteEditorKey(key,shift_context,ctrl_context);
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
   if(!g_initialized || g_symbol_transition_pending || !g_ps_panel_render_ready)
     {
      PS_AbortInteractionForContextChange();
      return;
     }
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
      string message="LotCraft 1.2.3 requires 'Allow DLL imports' for the required clipboard, native New Order dialog, and pointer-release safety integration. Enable the option and attach the EA again.";
      PS_LogError(message);
      MessageBox(message,PS_PRODUCT_NAME+" initialization",MB_OK|MB_ICONERROR);
      return(INIT_FAILED);
     }

   ZeroMemory(g_ui);
   ZeroMemory(g_pointer);
   PS_EditorReset(g_editor);
   PS_ExposureReset(g_exposure);
   PS_ExposureUIReset(g_exposure_ui);
   g_exposure_dirty=true;
   g_panel_dirty=true;
   g_exposure_details_dirty=true;
   g_exposure_labels_dirty=true;
   g_hovered_control=PS_CTRL_NONE;
   g_pressed_control=PS_CTRL_NONE;
   g_keyboard_focus=PS_CTRL_NONE;
   g_last_exposure_refresh_ms=0;
   PS_ResetKeyboardModifiers();
   g_exposure_retry_after_ms=0;
   g_panel_retry_after_ms=0;
   g_pointer.capture=PS_CAPTURE_NONE;
   g_pointer.control=PS_CTRL_NONE;

   PS_MarketAcquire(g_market);
   PS_ModelInitialize(g_model,g_market);
   g_persistence_base=PS_PersistenceBase(g_market);
   bool same_symbol_plan_loaded=PS_PersistenceLoad(g_persistence_base,g_market,g_model,g_exposure_ui);
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
   g_update_checks_enabled=!(bool)MQLInfoInteger(MQL_TESTER);
   g_next_update_check_ms=GetTickCount64()+10000;
   if(g_symbol_transition_pending)
     {
      PS_UIHidePanelContent(g_ui);
      PS_UIHidePlanningLines(g_ui);
      PS_UIRenderWaitingPanel(g_ui,g_model,
                              (g_market.error!="" ? g_market.error : "A current quote is required."));
     }
   else
     {
      PS_RefreshExposure(true);
      PS_Recalculate(false);
      PS_RenderIfDirty();
     }
   PS_LogInfo(StringFormat("%s %s initialized on %s chart %I64d.",PS_PRODUCT_NAME,PS_VERSION_TEXT,_Symbol,ChartID()));
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   g_initialized=false;
   PS_ResetKeyboardModifiers();
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

void PS_CheckForUpdates(const ulong now)
  {
   if(!g_initialized || !g_update_checks_enabled || now<g_next_update_check_ms) return;
   // Provide hourly opportunities while attached. The detached updater owns
   // its shared 24-hour network throttle, mutex, prompt and verification.
   // Schedule before launch so failures never retry on every UI timer tick.
   g_next_update_check_ms=now+3600000;
   string update_error="";
   if(!PS_PlatformLaunchUpdater(update_error))
      PS_LogWarningRateLimited("updater.launch",update_error,60000);
  }

void OnTimer()
  {
   if(!g_initialized) return;
   ulong now=GetTickCount64();
   PS_CheckForUpdates(now);

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
   if(!motion_capture && (g_exposure_dirty || now-g_last_exposure_refresh_ms>=1000))
      PS_RefreshExposure(false);
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
   if(g_exposure_hover_until_ms>0 && now>=g_exposure_hover_until_ms)
     {
      g_exposure_hover_until_ms=0;
      g_exposure_ui.hovered_row=-1;
      g_exposure_details_dirty=true;
      g_exposure_labels_dirty=true;
     }
   PS_RenderIfDirty();
  }

void OnTrade()
  {
   if(!g_initialized) return;
   g_exposure_dirty=true;
   PS_RefreshMarket(false);
   PS_RenderIfDirty();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
  {
   if(!g_initialized) return;
   g_exposure_dirty=true;
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
      PS_HandleKeyDown((int)lparam,(uint)StringToInteger(sparam));
      return;
     }
   if(id==CHARTEVENT_KEYUP)
     {
      PS_HandleKeyUp((int)lparam,(uint)StringToInteger(sparam));
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
      PS_ResetShortcutContext();
      PS_ObserveMouseModifiers((uint)(lparam>>32));
      int x=(int)(short)lparam;
      int y=(int)(short)(lparam>>16);
      if(g_exposure_ui.details_open && PS_RectContains(g_exposure_ui.sidecar_rect,x,y))
        {
         int maximum=MathMax(0,PS_UIExposureFilteredCount(g_exposure)-PS_UIExposurePageCapacity());
         if(dparam>0.0) g_exposure_ui.scroll_offset=MathMax(0,g_exposure_ui.scroll_offset-1);
         else if(dparam<0.0) g_exposure_ui.scroll_offset=MathMin(maximum,g_exposure_ui.scroll_offset+1);
         g_exposure_details_dirty=true;
         PS_RenderIfDirty();
         PS_UIGuardEnter(g_ui);
         return;
        }
      PS_UpdateInteractionGuard(x,y);
      return;
     }
   if(id==CHARTEVENT_CLICK)
     {
      PS_ResetShortcutContext();
      int x=(int)lparam;
      int y=(int)dparam;
      if(!PS_UIInPanel(g_ui,x,y) && g_editor.active) PS_CommitEditor();
      PS_UpdateInteractionGuard(x,y);
      return;
     }
   if(id==CHARTEVENT_CHART_CHANGE)
     {
      // A layout event can occur inside an active Ctrl+A gesture. Preserve
      // its context; actual symbol changes abort in PS_RefreshMarket.
      PS_RefreshMarket(false);
      PS_UIClampPanel(g_ui,g_model.view_mode);
      g_ui.dirty=true;
      g_exposure_details_dirty=true;
      g_exposure_labels_dirty=true;
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
