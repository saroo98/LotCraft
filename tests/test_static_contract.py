from __future__ import annotations

from pathlib import Path
import re

import pytest


ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "MQL5" / "Experts" / "LotCraft"
MAIN = SRC / "LotCraft.mq5"
ALL_SOURCE = "\n".join(p.read_text(encoding="utf-8") for p in sorted(SRC.glob("*.mq*")))


def strip_comments_and_strings(source: str) -> str:
    out: list[str] = []
    i = 0
    state = "code"
    while i < len(source):
        c = source[i]
        n = source[i + 1] if i + 1 < len(source) else ""
        if state == "code":
            if c == "/" and n == "/":
                state = "line"; out.extend("  "); i += 2; continue
            if c == "/" and n == "*":
                state = "block"; out.extend("  "); i += 2; continue
            if c == '"':
                state = "string"; out.append(" "); i += 1; continue
            if c == "'":
                state = "char"; out.append(" "); i += 1; continue
            out.append(c); i += 1; continue
        if state == "line":
            if c == "\n":
                state = "code"; out.append("\n")
            else:
                out.append(" ")
            i += 1; continue
        if state == "block":
            if c == "*" and n == "/":
                state = "code"; out.extend("  "); i += 2
            else:
                out.append("\n" if c == "\n" else " "); i += 1
            continue
        if c == "\\":
            out.extend("  "); i += 2
        elif (state == "string" and c == '"') or (state == "char" and c == "'"):
            state = "code"; out.append(" "); i += 1
        else:
            out.append("\n" if c == "\n" else " "); i += 1
    return "".join(out)


def test_product_identity_is_consistent():
    main = MAIN.read_text(encoding="utf-8")
    types = (SRC / "PS_Types.mqh").read_text(encoding="utf-8")
    assert '#property copyright "LotCraft"' in main
    # MetaEditor accepts only a two-part numeric #property version. The
    # user-facing semantic release is 1.1.0 while persistence remains schema v100.
    assert '#property version   "1.10"' in main
    assert '#property description "LotCraft 1.1.0"' in main
    assert '#define PS_PRODUCT_NAME              "LotCraft"' in types
    assert '#define PS_VERSION_TEXT              "1.1.0"' in types
    assert '#define PS_SOURCE_NAME               "LotCraft.mq5"' in types
    assert '#define PS_BINARY_NAME               "LotCraft.ex5"' in types
    assert '#define PS_LOG_PREFIX                "LotCraft"' in types
    assert '#define PS_OBJECT_NAMESPACE          "LotCraft.v100"' in types
    assert '#define PS_STATE_NAMESPACE           "LotCraft.100"' in types


def test_no_old_product_reference_in_runtime_source():
    assert "Position Sizer" not in ALL_SOURCE
    assert "PositionSizer" not in ALL_SOURCE


def test_no_ea_input_parameters_or_extra_visible_native_controls():
    code = strip_comments_and_strings(ALL_SOURCE)
    assert not re.search(r"(?m)^\s*(?:sinput|input)\s+", code)
    assert "OBJ_BUTTON" not in code
    assert "OBJ_EDIT" not in code
    assert "OBJ_BITMAP" not in code
    assert "OBJ_BITMAP_LABEL" not in code


def test_exact_internal_interactive_control_inventory():
    types = (SRC / "PS_Types.mqh").read_text(encoding="utf-8")
    body = re.search(r"enum PSControlId\s*\{(.*?)\};", types, re.S).group(1)
    controls = [part.strip().split("=")[0].strip() for part in body.split(",") if part.strip()]
    controls = [c for c in controls if c not in {"PS_CTRL_NONE", "PS_CTRL_COUNT"}]
    expected = [
        "PS_CTRL_MANUAL", "PS_CTRL_COMPACT", "PS_CTRL_MINI", "PS_CTRL_THEME", "PS_CTRL_CLOSE", "PS_CTRL_DIRECTION",
        "PS_CTRL_ENTRY_FIELD", "PS_CTRL_ENTRY_MINUS", "PS_CTRL_ENTRY_PLUS", "PS_CTRL_ENTRY_COPY",
        "PS_CTRL_STOP_FIELD", "PS_CTRL_STOP_MINUS", "PS_CTRL_STOP_PLUS", "PS_CTRL_STOP_COPY",
        "PS_CTRL_TAKE_FIELD", "PS_CTRL_TAKE_MINUS", "PS_CTRL_TAKE_PLUS", "PS_CTRL_TAKE_COPY",
        "PS_CTRL_ORDER_MODE", "PS_CTRL_LINES", "PS_CTRL_COMMISSION_MODE", "PS_CTRL_COMMISSION_FIELD",
        "PS_CTRL_ACCOUNT_MODE", "PS_CTRL_ACCOUNT_FIELD", "PS_CTRL_RISK_PERCENT_FIELD",
        "PS_CTRL_RISK_MONEY_FIELD", "PS_CTRL_ACTUAL_PERCENT", "PS_CTRL_ACTUAL_MONEY",
        "PS_CTRL_POSITION_SIZE", "PS_CTRL_POSITION_COPY", "PS_CTRL_MOVE_SLS", "PS_CTRL_CONFIRM",
        "PS_CTRL_TRADE",
    ]
    assert controls == expected


def test_required_user_facing_control_text_is_present():
    ui = (SRC / "PS_UI.mqh").read_text(encoding="utf-8")
    main = MAIN.read_text(encoding="utf-8")
    for text in [
        '"Manual"', '"Mini"', '"Full"', '"Long"', '"Short"', '"Instant"', '"Pending"',
        '"Hide lines"', '"Show lines"', '"Move SLs to line"', '"Confirmation: On"',
        '"Confirmation: Off"', '"Position size"',
    ]:
        assert text in ALL_SOURCE
    assert "PS_CTRL_TRADE" in main and "PS_DoTrade" in main


def test_compact_full_panel_omits_unneeded_summary_and_commission_rows():
    ui = (SRC / "PS_UI.mqh").read_text(encoding="utf-8")
    main = MAIN.read_text(encoding="utf-8")
    layout = re.search(r"void PS_UILayout.*?\n  \}", ui, re.S).group(0)
    render = re.search(r"void PS_UIRender\(.*?\n  \}", ui, re.S).group(0)
    init = re.search(r"int OnInit\(\).*?\n  \}", main, re.S).group(0)

    assert "ui.panel_w=390;" in ui and "ui.panel_h=92;" in ui
    assert "ui.panel_w=372;" in ui and "ui.panel_h=419;" in ui
    assert "ui.panel_w=438;" in ui and "ui.panel_h=469;" in ui
    assert "PS_CTRL_COMMISSION_MODE" not in layout
    assert "PS_CTRL_COMMISSION_FIELD" not in layout
    assert "PS_CTRL_ACTUAL_PERCENT" not in layout
    assert "PS_CTRL_ACTUAL_MONEY" not in layout
    assert '"Commission/lot",true' not in render
    assert '"Actual risk, %",true' not in render
    assert '"Actual, "+market.account_currency,true' not in render
    assert "g_model.commission_per_lot=0.0;" in init


def test_one_new_order_creation_control_path_and_separate_sl_modification_path():
    trade = (SRC / "PS_Trade.mqh").read_text(encoding="utf-8")
    main = MAIN.read_text(encoding="utf-8")
    assert trade.count("OrderSend(") == 2
    assert main.count("PS_DoTrade();") == 1
    assert main.count("PS_DoMoveStops();") == 1
    assert "TRADE_ACTION_DEAL" in trade
    assert "TRADE_ACTION_PENDING" in trade
    assert "TRADE_ACTION_SLTP" in trade
    assert "TRADE_ACTION_MODIFY" in trade


def test_broker_profit_and_preflight_apis_are_used():
    assert "OrderCalcProfit(" in ALL_SOURCE
    assert "OrderCheck(" in ALL_SOURCE
    assert "OrderSend(" in ALL_SOURCE
    assert "PS_TradeRetcodeAccepted" in ALL_SOURCE


def test_volume_is_floor_normalized_and_postcondition_checked():
    risk = (SRC / "PS_Risk.mqh").read_text(encoding="utf-8")
    types = (SRC / "PS_Types.mqh").read_text(encoding="utf-8")
    assert "MathFloor" in types
    assert "PS_FloorVolume" in risk
    assert "calc.actual_money>calc.requested_money+risk_tolerance" in risk
    assert "could not be proven within requested risk" in risk


def test_persistence_contains_configuration_and_symbol_scoped_planning_state():
    persistence = (SRC / "PS_Persistence.mqh").read_text(encoding="utf-8")
    for allowed in [
        "acct", "manual", "riska", "riskp", "riskm", "commt", "commv",
        "confirm", "mini", "lines", "plansym", "direction", "ordermode",
        "entry", "stop", "take",
    ]:
        assert f'"{allowed}"' in persistence
    load = persistence.split("bool PS_PersistenceLoad", 1)[1]
    same_symbol_block = load.index("if(same_planning_symbol)")
    assert load.index('PS_PersistenceKey(base,"direction")') < same_symbol_block
    assert load.index('PS_PersistenceKey(base,"ordermode")') < same_symbol_block
    assert load.index('PS_PersistenceKey(base,"entry")') > same_symbol_block
    assert "same_symbol_plan_loaded=true;" in load
    assert "return(same_symbol_plan_loaded);" in load
    assert "PS_STATE_NAMESPACE" in persistence


def test_lines_are_hlines_locked_and_handles_are_separate_hit_tested_objects():
    ui = (SRC / "PS_UI.mqh").read_text(encoding="utf-8")
    assert "OBJ_HLINE" in ui
    assert "OBJPROP_SELECTABLE,false" in ui
    assert "OBJPROP_SELECTED,false" in ui
    assert "PS_UIApplyLineLock" in ui
    assert '"handle."+id+".box"' in ui
    assert "PS_UIHitHandle" in ui
    assert "PS_UISetRect(rect,x,y,36,26);" in ui
    assert "PS_UISetRect(candidate,x,y-13,36,26);" in ui
    assert "ChartXYToTimePrice" in ALL_SOURCE
    assert "CHARTEVENT_OBJECT_DRAG" in ALL_SOURCE


def test_stop_marker_owns_overlapping_pixels_in_hit_order_zorder_and_paint_order():
    ui = (SRC / "PS_UI.mqh").read_text(encoding="utf-8")
    hit = re.search(r"PSLevelId PS_UIHitHandle.*?\n  \}", ui, re.S).group(0)
    ensure = re.search(r"bool PS_UIEnsureHandleCanvas.*?\n  \}", ui, re.S).group(0)
    update = re.search(r"void PS_UIUpdateLines.*?\n  \}", ui, re.S).group(0)
    assert "int hit_priority[3]={1,0,2};" in hit
    assert hit.index("hit_priority") < hit.index("g_ps_handle_visible[i]")
    assert "level==PS_LEVEL_STOP ? 50020" in ensure
    assert "level==PS_LEVEL_ENTRY ? 50010" in ensure
    assert "int paint_order[3]={2,0,1};" in update
    assert "visual overlap does not change long/short" in hit.lower()


def test_level_lines_are_painted_behind_the_interface():
    ui = (SRC / "PS_UI.mqh").read_text(encoding="utf-8")
    line_lock = re.search(r"void PS_UIApplyLineLock.*?\n  \}", ui, re.S).group(0)
    create = re.search(r"bool PS_UICreate.*?\n  \}", ui, re.S).group(0)
    assert "OBJPROP_BACK,true" in line_lock
    assert create.index('PS_UIEnsureLine(ui,"line.entry"') < create.index("PS_UIPanelCanvasEnsure(ui)")


def test_top_row_uses_direct_symmetric_controls_without_redundant_labels():
    ui = (SRC / "PS_UI.mqh").read_text(encoding="utf-8")
    assert "PS_CTRL_DIRECTION],x+20,y+54,190,34" in ui
    assert "PS_CTRL_ORDER_MODE],x+228,y+54,190,34" in ui
    assert 'PS_PremiumText(227,76,"Type"' not in ui
    assert 'PS_PremiumText(20,76,"Direction"' not in ui
    assert "const int gap=8;" in ui


def test_full_mode_uses_one_inset_grid_without_touching_or_crossing_borders():
    ui = (SRC / "PS_UI.mqh").read_text(encoding="utf-8")
    for geometry in [
        "PS_CTRL_LINES],x+20,y+213,120,22",
        "PS_CTRL_ACCOUNT_MODE],x+92,y+255,121,28",
        "PS_CTRL_ACCOUNT_FIELD],x+219,y+255,199,28",
        "PS_CTRL_RISK_PERCENT_FIELD],x+92,y+291,121,28",
        "PS_CTRL_RISK_MONEY_FIELD],x+291,y+291,127,28",
        "PS_CTRL_POSITION_SIZE],x+92,y+327,281,28",
        "PS_CTRL_POSITION_COPY],x+379,y+327,39,28",
        "PS_CTRL_TRADE],x+10,y+419,418,40",
    ]:
        assert geometry in ui
    assert "ui.panel_h=469;" in ui
    assert "g_ps_panel_canvas.Line(11,338" not in ui
    assert "g_ps_panel_canvas.Line(11,382" not in ui
    assert "g_ps_panel_canvas.Line(224,339" not in ui


def test_full_mode_uses_compact_visual_language_without_decorative_control_icons():
    ui = (SRC / "PS_UI.mqh").read_text(encoding="utf-8")
    premium = re.search(r"void PS_UIPremiumRender.*?\n  \}\n\nvoid PS_UIRender", ui, re.S).group(0)
    full = premium.split("g_ps_panel_canvas.Erase(PS_PremiumColor(PS_ThemeBackground()));", 1)[1]
    assert 'PS_PremiumControlButton(ui,PS_CTRL_MANUAL,"Manual"' in full
    assert 'PS_PremiumControlButton(ui,PS_CTRL_COMPACT,"Compact"' in full
    assert 'PS_PremiumControlButton(ui,PS_CTRL_MINI,"Mini"' in full
    assert 'PS_PremiumRoundRect(10,47,418,48' in full
    assert 'PS_PremiumRoundRect(10,102,418,139' in full
    assert 'PS_PremiumRoundRect(10,247,418,120' in full
    assert "PS_PremiumCompactField(ui,PS_CTRL_ENTRY_FIELD" in full
    assert "PS_PremiumRoundRect(10,488,436,27" not in full
    assert "PS_CTRL_TRADE],x+10,y+419,418,40" in ui
    for token in [
        "PS_PremiumLogo(",
        "PS_PremiumSlidersIcon(",
        "PS_PremiumBoltIcon(",
        "PS_PremiumClockIcon(",
        "PS_PremiumInfoIcon(",
        "PS_PremiumEyeIcon(",
        "PS_PremiumTargetIcon(",
        "PS_PremiumCartIcon(",
        "PS_PremiumSection(",
    ]:
        assert token not in full


def test_full_and_compact_use_the_requested_short_labels():
    ui = (SRC / "PS_UI.mqh").read_text(encoding="utf-8")
    compact = re.search(r"void PS_PremiumRenderCompact.*?\n  \}", ui, re.S).group(0)
    premium = re.search(r"void PS_UIPremiumRender.*?\n  \}\n\nvoid PS_UIRender", ui, re.S).group(0)
    full = premium.split("g_ps_panel_canvas.Erase(PS_PremiumColor(PS_ThemeBackground()));", 1)[1]
    for render in [compact, full]:
        for label in ['"SL"', '"TP"', '"Size"']:
            assert label in render
        for old_label in ['"Stop-loss"', '"Take-profit"', '"Order type"', '"Position size"', '"Direction"', '"Type"', '"Chart levels"']:
            assert old_label not in render
        assert '(model.lines_visible ? "Hide lines" : "Show lines")' in render
        assert '(model.lines_visible ? PS_CLR_WARNING : PS_PREMIUM_GREEN)' in render
    for glyph in ['"☷', '"ϟ', '"◷', '"•••', '"×']:
        assert glyph not in premium


def test_handle_visibility_is_bound_to_line_visibility_and_viewport():
    ui = (SRC / "PS_UI.mqh").read_text(encoding="utf-8")
    assert "model.lines_visible" in ui
    assert "prices[i]>=price_min && prices[i]<=price_max" in ui
    assert "g_ps_handle_visible" in ui


def test_symbol_change_builds_one_fresh_mode_aware_plan_before_activation():
    main = MAIN.read_text(encoding="utf-8")
    risk = (SRC / "PS_Risk.mqh").read_text(encoding="utf-8")
    refresh = re.search(r"void PS_RefreshMarket.*?\n  \}", main, re.S).group(0)
    chart_event = re.search(r"void OnChartEvent.*", main, re.S).group(0)
    fresh = risk.split("bool PS_ModelBuildFreshSymbolPlan", 2)[2]

    assert "string g_active_symbol" in main
    assert "refreshed.symbol!=previous_symbol" in refresh
    assert refresh.index("PS_SaveState();") < refresh.index("PS_CopyMarketSnapshot(g_market,refreshed);")
    assert "PS_AbortInteractionForContextChange();" in refresh
    assert "PS_BuildFreshPlan(transition_error)" in refresh
    assert refresh.index("PS_BuildFreshPlan(transition_error)") < refresh.index("g_active_symbol=refreshed.symbol;")
    assert "PS_RefreshMarket(false);" in chart_event.split("if(id==CHARTEVENT_CHART_CHANGE)", 1)[1]
    assert "PSModel candidate;" in fresh
    assert "candidate.order_mode==PS_ORDER_PENDING" in fresh
    assert "PS_ModelValidateCandidate(candidate,market,error)" in fresh
    assert "PS_CopyModel(model,candidate);" in fresh


def test_automatic_planning_levels_have_a_price_relative_minimum_sl_gap():
    risk = (SRC / "PS_Risk.mqh").read_text(encoding="utf-8")
    helper = re.search(r"double PS_ModelDefaultLevelDistance.*?\n  \}", risk, re.S).group(0)
    initialize = re.search(r"void PS_ModelInitialize.*?\n  \}", risk, re.S).group(0)
    ensure = re.search(r"bool PS_ModelEnsureInitialPrices.*?\n  \}", risk, re.S).group(0)
    fresh_gap = re.search(r"double PS_ModelRequiredFreshGap.*?\n  \}", risk, re.S).group(0)
    direction = re.search(r"void PS_ModelChangeDirection.*?\n  \}", risk, re.S).group(0)
    assert "reference*0.002" in helper
    assert "100.0*market.tick_size" in helper
    assert "PS_MarketProtectiveDistance(market,true)+market.tick_size" in helper
    assert "PS_ModelDefaultLevelDistance(model.entry,market)" in initialize
    assert "PS_ModelDefaultLevelDistance(executable,market)" in ensure
    assert "PS_ModelDefaultLevelDistance(reference,market)" in fresh_gap
    assert "34.0/(double)chart_height" in fresh_gap
    assert "visual/=0.60" in fresh_gap
    assert "PS_ModelDefaultLevelDistance(old_entry,market)" in direction


def test_timeframe_reinitialization_restores_same_symbol_planning_state_only():
    persistence = (SRC / "PS_Persistence.mqh").read_text(encoding="utf-8")
    main = MAIN.read_text(encoding="utf-8")
    for key in ['"plansym"', '"direction"', '"ordermode"', '"entry"', '"stop"', '"take"']:
        assert key in persistence
    assert "PS_HashString32(market.symbol)" in persistence
    assert "same_planning_symbol" in persistence
    assert "PS_PersistenceSave(g_persistence_base,g_market,g_model);" in main
    assert "bool same_symbol_plan_loaded=PS_PersistenceLoad(g_persistence_base,g_market,g_model);" in main
    assert "same_symbol_plan_loaded &&" in main
    assert "PS_ModelStoredPlanStructurallyValid(g_model,g_market)" in main
    assert "if(!coherent_plan)" in main
    assert "coherent_plan=PS_BuildFreshPlan(transition_error);" in main


def test_pointer_guard_preserves_and_restores_chart_properties():
    ui = (SRC / "PS_UI.mqh").read_text(encoding="utf-8")
    for prop in [
        "CHART_MOUSE_SCROLL", "CHART_CONTEXT_MENU", "CHART_CROSSHAIR_TOOL",
        "CHART_DRAG_TRADE_LEVELS", "CHART_KEYBOARD_CONTROL", "CHART_QUICK_NAVIGATION",
    ]:
        assert ui.count(prop) >= 4
    assert "PS_UIGuardEnter" in ui
    assert "PS_UIGuardExit" in ui
    assert "PS_LogErrorRateLimited" in ui


def test_cleanup_is_prefix_guarded_and_safe_after_early_init_failure():
    ui = (SRC / "PS_UI.mqh").read_text(encoding="utf-8")
    types = (SRC / "PS_Types.mqh").read_text(encoding="utf-8")
    assert "bool events_initialized;" in types
    assert "PS_UIHasOwnedPrefix" in ui
    assert 'ui.prefix!="" && StringFind(ui.prefix,PS_OBJECT_NAMESPACE+".")==0' in ui
    restore = re.search(r"void PS_UIRestoreEvents[\s\S]*?\n  \}", ui).group(0)
    delete = re.search(r"void PS_UIDeleteOwned[\s\S]*?\n  \}", ui).group(0)
    assert "if(!ui.events_initialized) return;" in restore
    assert "ui.events_initialized=false;" in restore
    assert "if(PS_UIHasOwnedPrefix(ui))" in delete
    assert "ObjectsDeleteAll(ChartID(),ui.prefix)" in delete


def test_custom_editor_supports_required_commit_cancel_and_navigation_paths():
    editor = (SRC / "PS_Editor.mqh").read_text(encoding="utf-8")
    main = MAIN.read_text(encoding="utf-8")
    for token in ["PS_EditorCommit", "PS_EditorCancel", "PS_EditorBackspace", "PS_EditorDelete", "PS_EditorSelectAll", "TranslateKey"]:
        assert token in editor
    assert "CHARTEVENT_KEYDOWN" in main
    assert "CHARTEVENT_KEYUP" in main
    assert "PS_EditorApplyRaw" in main
    assert 'StringReplace(canonical,",",".")' in editor


def test_field_editor_supports_precise_caret_drag_selection_and_double_click_select_all():
    editor = (SRC / "PS_Editor.mqh").read_text(encoding="utf-8")
    platform = (SRC / "PS_Platform.mqh").read_text(encoding="utf-8")
    ui = (SRC / "PS_UI.mqh").read_text(encoding="utf-8")
    main = MAIN.read_text(encoding="utf-8")
    begin = re.search(r"void PS_EditorBegin.*?\n  \}", editor, re.S).group(0)
    mouse_press = re.search(r"void PS_MousePress.*?\n  \}", main, re.S).group(0)
    mouse_move = re.search(r"void PS_MouseMoveCaptured.*?\n  \}", main, re.S).group(0)
    hit_test = re.search(r"int PS_UIEditorCursorIndex.*?\n  \}", ui, re.S).group(0)
    compact_field = re.search(r"void PS_PremiumCompactField.*?\n  \}", ui, re.S).group(0)
    assert "editor.anchor=editor.cursor;" in begin
    assert "editor.has_selection=false;" in begin
    assert "PS_UIEditorCursorIndex" in mouse_press
    assert "PS_EditorSetCursorIndex(g_editor,cursor,false);" in mouse_press
    assert "TextWidth(StringSubstr(text,0,index+1))" in hit_test
    assert "(previous_width+next_width)/2" in hit_test
    assert "PS_EditorSetCursorIndex(g_editor,cursor,true);" in mouse_move
    assert "MathMax(dx,dy)<2" in mouse_move
    assert "if(double_click) PS_EditorSelectAll(g_editor);" in mouse_press
    assert "click_ms-g_last_editor_click_ms<=PS_PlatformDoubleClickTime()" in mouse_press
    assert "inside_double_click_area" in mouse_press
    assert "PS_PlatformDoubleClickWidth()/2" in mouse_press
    assert "PS_PlatformDoubleClickHeight()/2" in mouse_press
    assert "uint  GetDoubleClickTime();" in platform
    assert "int   GetSystemMetrics(int nIndex);" in platform
    assert "#define PS_SM_CXDOUBLECLK 36" in platform
    assert "#define PS_SM_CYDOUBLECLK 37" in platform
    assert "return(interval>0 ? interval : 500);" in platform
    assert "PS_CLR_FIELD_FOCUS" in ui
    assert "PS_CLR_FOCUS" in ui
    assert "PS_CLR_SELECTION" in ui
    assert "PS_EditorSelectionStart(editor)" in compact_field
    assert "PS_EditorSelectionEnd(editor)" in compact_field
    assert "FillRectangle(selection_x" in compact_field
    assert "selected ? PS_ThemeSelection()" not in compact_field
    assert 'string rendered_text=(text=="" ? " " : text);' in ui
    render_editor = re.search(r"void PS_UIRenderEditor.*?\n  \}", ui, re.S).group(0)
    assert 'PS_UIShow(ui,"ui.edit.selection",false);' in render_editor


def test_panel_drag_uses_thresholded_single_canvas_without_click_flash():
    ui = (SRC / "PS_UI.mqh").read_text(encoding="utf-8")
    main = MAIN.read_text(encoding="utf-8")
    begin_drag = re.search(r"bool PS_UIBeginPanelDrag.*?\n  \}", ui, re.S).group(0)
    set_position = re.search(r"void PS_UISetPanelPosition.*?\n  \}", ui, re.S).group(0)
    end_drag = re.search(r"void PS_UIEndPanelDrag.*?\n  \}", ui, re.S).group(0)
    mouse_press = re.search(r"void PS_MousePress.*?\n  \}", main, re.S).group(0)
    mouse_move = re.search(r"void PS_MouseMoveCaptured.*?\n  \}", main, re.S).group(0)
    render_if_dirty = re.search(r"void PS_RenderIfDirty.*?\n  \}", main, re.S).group(0)
    release = re.search(r"void PS_MouseRelease.*?\n  \}", main, re.S).group(0)
    assert "PS_UIPanelCanvasEnsure(ui)" in begin_drag
    assert "PS_UIHidePanelContent(ui)" not in begin_drag
    assert "g_ps_panel_canvas_name,OBJPROP_XDISTANCE" in set_position
    assert "g_ps_panel_canvas_name,OBJPROP_YDISTANCE" in set_position
    assert "PS_UITranslatePanelObjects" not in ui
    assert "ui.dirty=true" not in set_position
    assert "g_ps_panel_canvas_name,OBJPROP_XDISTANCE" in end_drag
    assert "g_ps_panel_canvas_name,OBJPROP_YDISTANCE" in end_drag
    assert "if(g_pointer.capture==PS_CAPTURE_PANEL) return;" in render_if_dirty
    assert "PS_UIBeginPanelDrag" not in mouse_press
    assert "MathMax(dx,dy)<PS_PANEL_DRAG_THRESHOLD_PX" in mouse_move
    assert "PS_UIBeginPanelDrag(g_ui,g_model.view_mode)" in mouse_move
    assert "g_last_drag_frame_ms" not in main
    assert "panel_dragged" in release
    assert "PS_UIEndPanelDrag(g_ui)" in release
    assert "PS_ResetCapture(x,y);" in release
    assert release.index("PS_ResetCapture(x,y);") < release.rindex("PS_RenderIfDirty();")
    assert release.index("PS_RenderIfDirty();") < release.index("PS_UIEndPanelDrag(g_ui)")


def test_full_compact_and_mini_modes_are_explicit_persisted_states():
    types = (SRC / "PS_Types.mqh").read_text(encoding="utf-8")
    risk = (SRC / "PS_Risk.mqh").read_text(encoding="utf-8")
    persistence = (SRC / "PS_Persistence.mqh").read_text(encoding="utf-8")
    main = MAIN.read_text(encoding="utf-8")

    for token in ["PS_VIEW_FULL=0", "PS_VIEW_COMPACT=1", "PS_VIEW_MINI=2", "PSViewMode view_mode;"]:
        assert token in types
    assert "model.view_mode=PS_VIEW_FULL;" in risk
    assert 'PS_PersistenceKey(base,"view")' in persistence
    assert "model.view_mode=(PSViewMode)view;" in persistence
    assert "model.view_mode=(value>=0.5 ? PS_VIEW_MINI : PS_VIEW_FULL);" in persistence
    assert "case PS_CTRL_COMPACT:" in main
    assert "case PS_CTRL_MINI:" in main
    assert "g_model.view_mode==PS_VIEW_COMPACT ? PS_VIEW_FULL : PS_VIEW_COMPACT" in main
    assert "g_model.view_mode==PS_VIEW_MINI ? PS_VIEW_FULL : PS_VIEW_MINI" in main


def test_compact_geometry_is_materially_smaller_and_single_canvas_renderer_is_preserved():
    ui = (SRC / "PS_UI.mqh").read_text(encoding="utf-8")
    layout = re.search(r"void PS_UILayout.*?\n  \}", ui, re.S).group(0)
    compact = re.search(r"void PS_PremiumRenderCompact.*?\n  \}", ui, re.S).group(0)
    premium = re.search(r"void PS_UIPremiumRender.*?\n  \}", ui, re.S).group(0)

    for geometry in [
        "x+154,y+6,61,28", "x+218,y+6,38,28", "x+261,y+6,38,28",
        "x+304,y+6,26,28", "x+335,y+6,27,28",
        "x+16,y+51,166,26", "x+190,y+51,166,26",
        "int compact_row=99;", "x+75,y+compact_row,157,26", "x+238,y+compact_row,30,26",
        "x+274,y+compact_row,32,26", "x+312,y+compact_row,43,26",
        "x+16,y+189,112,22",
        "x+75,y+231,101,26", "x+182,y+231,173,26",
        "x+75,y+261,101,26", "x+261,y+261,94,26",
        "x+75,y+291,237,26", "x+318,y+291,37,26",
        "x+8,y+337,174,32", "x+188,y+337,176,32", "x+8,y+377,356,34",
    ]:
        assert geometry in layout
    for geometry in [
        "PS_PremiumRoundRect(8,43,356,42", "PS_PremiumRoundRect(8,91,356,126",
        "PS_PremiumRoundRect(8,223,356,106",
    ]:
        assert geometry in compact
    assert "g_ps_panel_canvas.Line(9,278" not in compact
    assert "g_ps_panel_canvas.Line(9,319" not in compact
    assert "g_ps_panel_canvas.Line(181,279" not in compact
    assert 'PS_PremiumControlButton(ui,PS_CTRL_MINI,"Mini"' in compact
    assert "PS_PremiumRenderCompact(ui,model,calc,market,editor,copy_feedback_control);" in premium
    assert "g_ps_panel_canvas.Update(false);" in premium
    assert "OBJ_RECTANGLE_LABEL" not in compact
    assert "ChartRedraw" not in compact
    assert 'PS_PremiumControlButton(ui,PS_CTRL_MANUAL,"Manual",false,PS_PREMIUM_BLUE,19);' in compact
    assert 'PS_PremiumText(14,21,PS_PRODUCT_NAME,13' in compact
    assert 'PS_PremiumText(16,70,"Direction",9' not in compact
    assert 'editor,PS_FIELD_ENTRY,false,false,11,12);' in compact
    assert 'PS_PremiumText(trade_rect.x+trade_rect.w/2,trade_rect.y+trade_rect.h/2,trade_text,13' in compact


def test_stop_loss_position_automatically_controls_direction_in_every_input_path():
    risk = (SRC / "PS_Risk.mqh").read_text(encoding="utf-8")
    main = MAIN.read_text(encoding="utf-8")
    align = re.search(r"bool PS_ModelAlignDirectionToStop.*?\n  \}", risk, re.S).group(0)
    update = re.search(r"bool PS_UpdateLevelFromPointer.*?\n  \}", main, re.S).group(0)
    commit = re.search(r"bool PS_CommitEditor.*?\n  \}", main, re.S).group(0)
    step = re.search(r"void PS_StepPrice.*?\n  \}", main, re.S).group(0)

    assert "model.stop_loss<reference-tolerance" in align
    assert "model.stop_loss>reference+tolerance" in align
    assert "PS_DIRECTION_LONG" in align and "PS_DIRECTION_SHORT" in align
    assert "direction_changed=PS_ModelAlignDirectionToStop" in update
    assert "if(direction_changed)" in update
    assert "PS_UIRender(g_ui,g_model,g_calc,g_market,g_editor,g_copy_feedback_control);" in update
    assert "PS_ModelAlignDirectionToStop(g_model,g_market);" in commit
    assert "PS_ModelAlignDirectionToStop(g_model,g_market);" in step


def test_mini_mode_edits_risk_percentage_and_offers_full_and_compact_navigation():
    ui = (SRC / "PS_UI.mqh").read_text(encoding="utf-8")
    layout = re.search(r"void PS_UILayout.*?\n  \}", ui, re.S).group(0)
    mini = re.search(r"void PS_PremiumRenderMini.*?\n  \}", ui, re.S).group(0)

    assert "PS_CTRL_RISK_PERCENT_FIELD],x+72,y+52,82,28" in layout
    assert "g_ps_control_visible[PS_CTRL_RISK_PERCENT_FIELD]=true;" in layout
    mini_layout = layout.split("if(view_mode==PS_VIEW_MINI)", 1)[1].split("if(view_mode==PS_VIEW_COMPACT)", 1)[0]
    assert "g_ps_control_visible[PS_CTRL_POSITION_SIZE]" not in mini_layout
    assert 'PS_PremiumText(12,66,"Risk, %"' in mini
    assert "PS_PremiumCompactField(ui,PS_CTRL_RISK_PERCENT_FIELD" in mini
    assert 'PS_PremiumControlButton(ui,PS_CTRL_MINI,"Full"' in mini
    assert 'PS_PremiumControlButton(ui,PS_CTRL_COMPACT,"Compact"' in mini


def test_rounded_rectangles_use_antialiased_corners_and_solid_accent_fills():
    ui = (SRC / "PS_UI.mqh").read_text(encoding="utf-8")
    rounded = re.search(r"void PS_PremiumRoundRect.*?\n  \}", ui, re.S).group(0)
    button = re.search(r"void PS_PremiumButton.*?\n  \}", ui, re.S).group(0)
    assert rounded.count("CircleAA(") >= 8
    assert "inner_top" not in button
    assert "FillRectangle(x+2" not in button


def test_dark_and_light_themes_are_explicit_persisted_states():
    types = (SRC / "PS_Types.mqh").read_text(encoding="utf-8")
    risk = (SRC / "PS_Risk.mqh").read_text(encoding="utf-8")
    persistence = (SRC / "PS_Persistence.mqh").read_text(encoding="utf-8")
    main = MAIN.read_text(encoding="utf-8")
    ui = (SRC / "PS_UI.mqh").read_text(encoding="utf-8")

    for token in ["PS_THEME_DARK=0", "PS_THEME_LIGHT=1", "PSThemeMode theme_mode;", "PS_CTRL_THEME"]:
        assert token in types
    assert "model.theme_mode=PS_THEME_DARK;" in risk
    assert 'PS_PersistenceKey(base,"theme")' in persistence
    assert "model.theme_mode=(PSThemeMode)theme;" in persistence
    assert "case PS_CTRL_THEME:" in main
    assert "g_model.theme_mode==PS_THEME_DARK ? PS_THEME_LIGHT : PS_THEME_DARK" in main
    assert "PS_UISelectTheme(model.theme_mode);" in ui
    assert "PS_PremiumThemeIcon" in ui


def test_all_canvas_vcenter_text_uses_one_optical_alignment_correction():
    ui = (SRC / "PS_UI.mqh").read_text(encoding="utf-8")
    text = re.search(r"void PS_PremiumText.*?\n  \}", ui, re.S).group(0)
    assert "PS_PremiumOpticalCenterOffset(size)" in text
    assert "(alignment & TA_VCENTER)==TA_VCENTER" in text
    assert "g_ps_panel_canvas.TextOut(x,draw_y,text" in text


def test_theme_control_is_visible_in_full_compact_and_mini_modes():
    ui = (SRC / "PS_UI.mqh").read_text(encoding="utf-8")
    layout = re.search(r"void PS_UILayout.*?\n  \}", ui, re.S).group(0)
    for geometry in ["x+328,y+7,25,28", "x+304,y+6,26,28", "x+366,y+7,27,30"]:
        assert geometry in layout
    assert "g_ps_control_visible[PS_CTRL_THEME]=true;" in layout


def test_level_handles_require_motion_and_skip_redundant_pointer_updates():
    main = MAIN.read_text(encoding="utf-8")
    mouse_press = re.search(r"void PS_MousePress.*?\n  \}", main, re.S).group(0)
    mouse_move = re.search(r"void PS_MouseMoveCaptured.*?\n  \}", main, re.S).group(0)
    update = re.search(r"bool PS_UpdateLevelFromPointer.*?\n  \}", main, re.S).group(0)
    release = re.search(r"void PS_MouseRelease.*?\n  \}", main, re.S).group(0)
    assert "PS_UpdateLevelFromPointer(g_pointer.capture,x,y);" not in mouse_press
    assert "MathMax(dx,dy)<PS_HANDLE_DRAG_THRESHOLD_PX" in mouse_move
    assert "x!=g_pointer.applied_x || y!=g_pointer.applied_y" in mouse_move
    assert "MathAbs(previous-price)<=tolerance" in update
    assert "PS_UpdateLevelFromPointer(g_pointer.capture,x,y,false);" in mouse_move
    assert "if(recalculate || direction_changed) PS_Recalculate(false);" in update
    assert "else g_ui.line_dirty=true;" in update
    assert "PS_Recalculate(false);" in release


def test_native_pointer_fallback_is_calibrated_to_chart_event_coordinates():
    types = (SRC / "PS_Types.mqh").read_text(encoding="utf-8")
    main = MAIN.read_text(encoding="utf-8")
    mouse_press = re.search(r"void PS_MousePress.*?\n  \}", main, re.S).group(0)
    timer = re.search(r"void OnTimer\(\).*?\n  \}", main, re.S).group(0)
    reset = re.search(r"void PS_ResetCapture.*?\n  \}", main, re.S).group(0)
    for token in ["native_offset_x", "native_offset_y", "native_pointer_calibrated"]:
        assert token in types
    assert "PS_PlatformPointerPosition(native_x,native_y)" in mouse_press
    assert "g_pointer.native_offset_x=x-native_x;" in mouse_press
    assert "g_pointer.native_offset_y=y-native_y;" in mouse_press
    assert "pointer_x+=g_pointer.native_offset_x;" in timer
    assert "pointer_y+=g_pointer.native_offset_y;" in timer
    assert "pointer_x=g_pointer.last_x;" in timer
    assert "pointer_y=g_pointer.last_y;" in timer
    assert "g_pointer.native_pointer_calibrated=false;" in reset


def test_fast_drag_uses_one_native_pointer_source_for_handles_and_panel():
    main = MAIN.read_text(encoding="utf-8")
    timer = re.search(r"void OnTimer\(\).*?\n  \}", main, re.S).group(0)
    chart_event = re.search(r"void OnChartEvent.*", main, re.S).group(0)
    mouse_event = re.search(r"void PS_HandleMouseEvent.*?\n  \}", main, re.S).group(0)
    queue = re.search(r"void PS_QueueCapturedMove.*?\n  \}", main, re.S).group(0)
    flush = re.search(r"void PS_FlushCapturedMove.*?\n  \}", main, re.S).group(0)
    release = re.search(r"void PS_MouseRelease.*?\n  \}", main, re.S).group(0)
    on_tick = re.search(r"void OnTick\(\).*?\n  \}", main, re.S).group(0)
    assert "g_last_chart_mouse_event_ms=GetTickCount64();" in chart_event
    assert "PS_PlatformPointerPosition(native_x,native_y)" in chart_event
    assert "pointer_x=native_x+g_pointer.native_offset_x;" in chart_event
    assert "pointer_y=native_y+g_pointer.native_offset_y;" in chart_event
    assert "PS_NATIVE_POINTER_FALLBACK_DELAY_MS" not in main
    assert "EventSetMillisecondTimer(PS_POINTER_TIMER_MS)" in main
    assert "const int PS_POINTER_TIMER_MS=8;" in main
    assert "else if(PS_IsMotionCapture()) PS_QueueCapturedMove(x,y);" in mouse_event
    assert "else PS_MouseMoveCaptured(x,y);" in mouse_event
    assert "g_pointer_motion_pending=true;" in queue
    assert "PS_MouseMoveCaptured(x,y);" in flush
    assert "PS_FlushCapturedMove();" in timer
    assert timer.index("PS_FlushCapturedMove();") < timer.index("PS_TimerStepper();")
    assert "if(PS_IsMotionCapture()) PS_MouseMoveCaptured(x,y);" in release
    assert "if(!motion_capture && now-g_last_market_refresh_ms>=250)" in timer
    for capture in [
        "g_pointer.capture==PS_CAPTURE_PANEL",
        "g_pointer.capture==PS_CAPTURE_HANDLE_ENTRY",
        "g_pointer.capture==PS_CAPTURE_HANDLE_STOP",
        "g_pointer.capture==PS_CAPTURE_HANDLE_TAKE",
    ]:
        assert capture in on_tick
        assert capture in timer


def test_price_stepper_accelerates_exponentially_while_preserving_single_click_precision():
    main = MAIN.read_text(encoding="utf-8")
    step_price = re.search(r"void PS_StepPrice.*?\n  \}", main, re.S).group(0)
    stage = re.search(r"int PS_StepperAccelerationStage.*?\n  \}", main, re.S).group(0)
    multiplier = re.search(r"int PS_StepperTickMultiplier.*?\n  \}", main, re.S).group(0)
    interval = re.search(r"ulong PS_StepperRepeatInterval.*?\n  \}", main, re.S).group(0)
    timer = re.search(r"void PS_TimerStepper.*?\n  \}", main, re.S).group(0)
    mouse_press = re.search(r"void PS_MousePress.*?\n  \}", main, re.S).group(0)

    assert "const int tick_multiplier=1" in step_price
    assert "g_market.tick_size*multiplier" in step_price
    assert "(elapsed-350)/750" in stage
    assert "MathMin(stage,8)" in stage
    assert "multiplier*=2" in multiplier
    assert "interval/=2" in interval
    assert "MathMax((ulong)15,interval)" in interval
    assert "PS_StepPrice(g_pointer.control,PS_StepperTickMultiplier(elapsed));" in timer
    assert "PS_StepPrice(control);" in mouse_press


def test_level_handle_is_one_composited_canvas_object():
    ui = (SRC / "PS_UI.mqh").read_text(encoding="utf-8")
    set_handle = re.search(r"void PS_UISetHandle.*?\n  \}", ui, re.S).group(0)
    ensure = re.search(r"bool PS_UIEnsureHandleCanvas.*?\n  \}", ui, re.S).group(0)
    assert "CCanvas g_ps_handle_canvas[3];" in ui
    assert "CreateBitmapLabel" in ensure
    assert "TextOut" in ensure
    assert "Update(false)" in ensure
    assert 'PS_UIShow(ui,"handle."+id+".box",false);' in set_handle
    assert 'PS_UIShow(ui,"handle."+id+".text",false);' in set_handle
    assert "OBJPROP_XDISTANCE" in set_handle
    assert "OBJPROP_YDISTANCE" in set_handle


def test_copy_buttons_flash_success_on_the_control_that_was_copied():
    ui = (SRC / "PS_UI.mqh").read_text(encoding="utf-8")
    main = MAIN.read_text(encoding="utf-8")
    copy = re.search(r"void PS_DoCopy.*?\n  \}", main, re.S).group(0)
    timer = re.search(r"void OnTimer\(\).*?\n  \}", main, re.S).group(0)
    assert "g_copy_feedback_control=control;" in copy
    assert "g_copy_feedback_until_ms=GetTickCount64()+1200;" in copy
    assert 'entry_copied ? "✓" : "C"' in ui
    assert 'position_copied ? "✓" : "C"' in ui
    assert "g_copy_feedback_control=PS_CTRL_NONE;" in timer


def test_read_only_outputs_are_never_mapped_to_editable_fields():
    ui = (SRC / "PS_UI.mqh").read_text(encoding="utf-8")
    mapping = re.search(r"PSFieldId PS_UIFieldForControl.*?\n  \}", ui, re.S).group(0)
    for control in ["PS_CTRL_ACTUAL_PERCENT", "PS_CTRL_ACTUAL_MONEY", "PS_CTRL_POSITION_SIZE"]:
        assert control not in mapping


def test_confirmation_toggle_has_no_refresh_side_effect_assignment():
    main = MAIN.read_text(encoding="utf-8")
    toggle = "g_model.ask_confirmation=!g_model.ask_confirmation;"
    assert main.count(toggle) == 1
    # Other assignments are initialization/persistence load into model, not refresh/timer behavior.
    assert "case PS_CTRL_CONFIRM" in main
    timer = re.search(r"void OnTimer\(\).*?\n  \}", main, re.S).group(0)
    assert "ask_confirmation" not in timer


def test_trade_confirmation_is_single_stage_and_refreshed_before_send():
    trade = (SRC / "PS_Trade.mqh").read_text(encoding="utf-8")
    main = MAIN.read_text(encoding="utf-8")
    confirmation = re.search(r"string PS_TradeConfirmationText.*?\n  \}", trade, re.S).group(0)
    assert "REQUESTED RISK" in confirmation
    assert "ACTUAL RISK" in confirmation
    assert "Send this trade request?" in confirmation
    for field in ["Symbol:", "Direction:", "Order:", "Entry:", "Stop-loss:", "Take-profit:", "Volume:", "Account basis:", "Commission:"]:
        assert field not in confirmation
    assert main.count("PS_PRODUCT_NAME+\" \"+PS_VERSION_TEXT+\" confirmation\"") == 1
    assert "updated confirmation" not in main
    assert "PS_CopyTradeSnapshot(confirmed,refreshed);" in main


def test_sl_confirmations_are_complete_and_revalidated():
    trade = (SRC / "PS_Trade.mqh").read_text(encoding="utf-8")
    main = MAIN.read_text(encoding="utf-8")
    sl_confirmation = re.search(r"string PS_TradeSlConfirmationText.*?\n  \}", trade, re.S).group(0)
    for field in ["Symbol:", "Direction scope:", "Target stop-loss:", "Eligible positions/pending orders:"]:
        assert field in sl_confirmation
    assert "PS_TradeSlTargetSetsEqual" in main


def test_instant_entry_handle_drag_switches_to_pending_and_remains_movable():
    main = MAIN.read_text(encoding="utf-8")
    update = re.search(r"bool PS_UpdateLevelFromPointer.*?\n  \}", main, re.S).group(0)
    move = re.search(r"void PS_MouseMoveCaptured.*?\n  \}", main, re.S).group(0)
    assert "PS_ModelChangeOrderMode(g_model,g_market,PS_ORDER_PENDING,mode_error)" in update
    assert "if(!PS_ModelChangeOrderMode" in update
    assert "Entry handle is market-bound" not in update
    assert "Entry handle is market-bound" not in move


def test_order_mode_transition_is_candidate_based_failure_aware_and_recalculated_once():
    risk = (SRC / "PS_Risk.mqh").read_text(encoding="utf-8")
    main = MAIN.read_text(encoding="utf-8")
    transition = risk.split("bool PS_ModelChangeOrderMode", 2)[2]
    action = re.search(r"void PS_Action.*?\n  \}", main, re.S).group(0)
    order_case = action.split("case PS_CTRL_ORDER_MODE:", 1)[1].split("case PS_CTRL_LINES:", 1)[0]
    assert "PSModel candidate;" in transition
    assert "PS_CopyModel(candidate,model);" in transition
    assert "candidate.stop_loss" in transition
    assert "PS_ModelValidateCandidate(candidate,market,error)" in transition
    assert "PS_CopyModel(model,candidate);" in transition
    assert "bool PS_ModelChangeOrderMode" in risk
    assert "if(!PS_ModelChangeOrderMode" in order_case
    assert order_case.count("PS_Recalculate(false);") == 1
    assert "PS_SaveState();" in order_case


def test_captured_handle_motion_never_retests_handle_identity():
    main = MAIN.read_text(encoding="utf-8")
    press = re.search(r"void PS_MousePress.*?\n  \}", main, re.S).group(0)
    move = re.search(r"void PS_MouseMoveCaptured.*?\n  \}", main, re.S).group(0)
    release = re.search(r"void PS_MouseRelease.*?\n  \}", main, re.S).group(0)
    assert "PS_UIHitHandle" in press
    assert "PS_UIHitHandle" not in move
    assert "PS_UIHitHandle" not in release


def test_risk_money_field_shows_actual_risk_in_parentheses_when_different():
    ui = (SRC / "PS_UI.mqh").read_text(encoding="utf-8")
    display = re.search(r"string PS_UIRiskMoneyDisplay.*?\n  \}", ui, re.S).group(0)
    assert 'return(requested+" ("+actual+")");' in display
    assert ui.count("PS_UIRiskMoneyDisplay(model,calc,market,editor)") >= 3


def test_move_sl_scope_is_all_valid_current_symbol_targets_at_exact_line():
    trade = (SRC / "PS_Trade.mqh").read_text(encoding="utf-8")
    assert "symbol!=market.symbol" in trade
    collect = re.search(r"int PS_TradeCollectSlTargets.*?\n  \}", trade, re.S).group(0)
    assert "direction!=model.direction" not in collect
    assert "PS_TradeSlNeedsChange" in collect
    assert "target=PS_NormalizePrice(model.stop_loss,market)" in collect
    assert "request.tp=PositionGetDouble(POSITION_TP)" in trade
    assert "request.tp=OrderGetDouble(ORDER_TP)" in trade


def test_move_sl_revalidates_live_entity_identity_before_each_request():
    trade = (SRC / "PS_Trade.mqh").read_text(encoding="utf-8")
    assert "PositionSelectByTicket(target.ticket)" in trade
    assert "live_symbol=PositionGetString(POSITION_SYMBOL)" in trade
    assert "live_type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)" in trade
    assert "live_symbol!=target.symbol || live_direction!=target.direction" in trade
    assert "OrderSelect(target.ticket)" in trade
    assert "live_symbol=OrderGetString(ORDER_SYMBOL)" in trade
    assert "live_type=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)" in trade
    assert "Order is no longer an eligible pending order." in trade
    assert "Pending-order symbol or direction changed" in trade


def test_dll_permission_is_fail_closed_for_required_native_features():
    main = MAIN.read_text(encoding="utf-8")
    platform = (SRC / "PS_Platform.mqh").read_text(encoding="utf-8")
    assert "if(!MQLInfoInteger(MQL_DLLS_ALLOWED))" in main
    assert 'requires \'Allow DLL imports\'' in main
    assert '#import "user32.dll"' in platform
    assert '#import "kernel32.dll"' in platform



def test_string_bearing_struct_copies_are_explicit():
    types = (SRC / "PS_Types.mqh").read_text(encoding="utf-8")
    editor = (SRC / "PS_Editor.mqh").read_text(encoding="utf-8")
    trade = (SRC / "PS_Trade.mqh").read_text(encoding="utf-8")
    main = MAIN.read_text(encoding="utf-8")
    for helper in [
        "PS_CopyMqlTick", "PS_CopyTradeRequest", "PS_CopyMarketSnapshot",
        "PS_CopyModel", "PS_CopyTradeSnapshot", "PS_CopySlTarget",
    ]:
        assert f"void {helper}" in types
    forbidden = [
        "editor.before=model;", "PSModel candidate=model;", "model=editor.before;",
        "model=candidate;", "snapshot.request=request;", "destination[i]=source[i];",
        "g_market=refreshed;", "confirmed=final_snapshot;", "confirmed=refreshed;",
    ]
    combined = "\n".join([editor, trade, main])
    for expression in forbidden:
        assert expression not in combined


def test_source_delimiters_and_preprocessor_guards_are_balanced():
    for path in sorted(SRC.glob("*.mq*")):
        code = strip_comments_and_strings(path.read_text(encoding="utf-8"))
        for left, right in [("{", "}"), ("(", ")"), ("[", "]")]:
            balance = 0
            for char in code:
                if char == left:
                    balance += 1
                elif char == right:
                    balance -= 1
                    assert balance >= 0, f"{path.name}: unmatched {right}"
            assert balance == 0, f"{path.name}: unbalanced {left}{right}"
        depth = 0
        for line in path.read_text(encoding="utf-8").splitlines():
            if re.match(r"^\s*#if(?:n?def)?\b", line):
                depth += 1
            elif re.match(r"^\s*#endif\b", line):
                depth -= 1
                assert depth >= 0
        assert depth == 0


def test_release_source_uses_metaeditor_compatible_constant_forms():
    main = MAIN.read_text(encoding="utf-8")
    logging = (SRC / "PS_Logging.mqh").read_text(encoding="utf-8")
    ui = (SRC / "PS_UI.mqh").read_text(encoding="utf-8")
    assert '#property version   "1.10"' in main
    assert not re.search(r"(?m)^\s*#if\s+(?!def\b|ndef\b)", logging)
    assert "const color text_color=C'154,164,181'" in ui


def test_all_internal_function_calls_resolve_to_definitions_or_forward_declarations():
    code = strip_comments_and_strings(ALL_SOURCE)
    defs = set(re.findall(r"(?m)^\s*(?:bool|void|int|uint|ulong|long|double|string|short|ushort|color|datetime|PS\w+|ENUM_\w+)\s+(PS_[A-Za-z0-9_]+)\s*\(", code))
    calls = set(re.findall(r"\b(PS_[A-Za-z0-9_]+)\s*\(", code))
    assert calls == defs


def test_no_unresolved_todo_or_fixme_markers():
    assert "TODO" not in ALL_SOURCE
    assert "FIXME" not in ALL_SOURCE


def test_native_pointer_fallback_preserves_capture_and_restores_on_pointer_exit():
    main = MAIN.read_text(encoding="utf-8")
    platform = (SRC / "PS_Platform.mqh").read_text(encoding="utf-8")
    assert "GetCursorPos" in platform
    assert "ScreenToClient" in platform
    assert "PS_PlatformPointerPosition" in platform
    timer = re.search(r"void OnTimer\(\).*?\n  \}", main, re.S).group(0)
    assert "PS_QueueCapturedMove(pointer_x,pointer_y)" in timer
    assert "PS_FlushCapturedMove();" in timer
    assert "g_ui.guard_saved && !g_editor.active && pointer_known" in timer
    assert "PS_UpdateInteractionGuard(pointer_x,pointer_y)" in timer


def test_all_new_trade_requests_use_zero_magic_number():
    trade = (SRC / "PS_Trade.mqh").read_text(encoding="utf-8")
    assert "request.magic=0;" in trade
    assert "PS_TradeMagic" not in trade
