"""Regression for shortcut KEYUP-only delivery observed in both owner MT5s.

These execute production controller/editor bodies. Clipboard and platform APIs
use the established offline fixture; this does not replace native acceptance.
"""
import pytest

from native_mql_harness import compile_and_run
from test_native_clipboard import keyboard_source


CASES = [
    (65, 0x1E, "g_editor.has_selection=false;g_editor.anchor=g_editor.cursor;",
     "assert(g_editor.has_selection && g_editor.anchor==0 && g_editor.cursor==7);"),
    (67, 0x2E, "", 'assert(clipboard_calls==1 && clipboard_text=="1.12345");'),
    (86, 0x2F, 'clipboard_text="2.5";',
     'assert(clipboard_reads==1 && g_editor.raw_text=="2.5" && recalculations==1);'),
    (88, 0x2D, "",
     'assert(clipboard_calls==1 && clipboard_text=="1.12345" && g_editor.raw_text.empty() && recalculations==1);'),
    (90, 0x2C, "PressKey(50);PressKey(51);",
     'assert(g_editor.raw_text=="2" && g_editor.history_index==1 && recalculations==3);'),
]


@pytest.mark.parametrize("ctrl_released_first", [False, True])
@pytest.mark.parametrize(("key", "scan", "setup", "expected"), CASES)
def test_release_only_shortcut_executes_with_either_ctrl_release_order(
    tmp_path, key, scan, setup, expected, ctrl_released_first
):
    # Removing release dispatch, or using only current Ctrl, must fail this.
    releases = (
        f"ReleaseKey(17,0xC01D);ReleaseKey({key},{0xC000 | scan});"
        if ctrl_released_first else
        f"ReleaseKey({key},{0xC000 | scan});ReleaseKey(17,0xC01D);"
    )
    compile_and_run(tmp_path, keyboard_source() + f"""
int main(){{
  PS_ObserveMouseModifiers(0);{setup}
  PressKey(17,0x1D);
  {releases}
  {expected}
  assert(!g_ctrl_down);
}}
""")


@pytest.mark.parametrize("ctrl_released_first", [False, True])
@pytest.mark.parametrize(("key", "scan", "setup", "expected"), CASES)
def test_delivered_shortcut_press_is_not_executed_again_on_release(
    tmp_path, key, scan, setup, expected, ctrl_released_first
):
    # Losing the seen-press guard would duplicate copy/paste/undo on KEYUP.
    releases = (
        f"ReleaseKey(17,0xC01D);ReleaseKey({key},{0xC000 | scan});"
        if ctrl_released_first else
        f"ReleaseKey({key},{0xC000 | scan});ReleaseKey(17,0xC01D);"
    )
    compile_and_run(tmp_path, keyboard_source() + f"""
int main(){{
  PS_ObserveMouseModifiers(0);{setup}
  PressKey(17,0x1D);PressKey({key},{scan});
  {releases}
  {expected}
  assert(!g_ctrl_down);
}}
""")


def test_one_held_ctrl_can_select_and_copy_with_release_only_letter_events(tmp_path):
    compile_and_run(tmp_path, keyboard_source() + r'''
int main(){
  g_editor.has_selection=false;g_editor.anchor=g_editor.cursor;
  PS_ObserveMouseModifiers(0);PressKey(17,0x1D);
  ReleaseKey(65,0xC01E);ReleaseKey(67,0xC02E);ReleaseKey(17,0xC01D);
  assert(g_editor.has_selection && clipboard_calls==1 && clipboard_text=="1.12345");
}
''')


def test_plain_key_press_clears_a_released_ctrl_gesture(tmp_path):
    compile_and_run(tmp_path, keyboard_source() + r'''
int main(){
  PS_ObserveMouseModifiers(0);PressKey(17);ReleaseKey(17);
  PressKey(86);ReleaseKey(86);
  assert(clipboard_reads==0 && g_editor.raw_text=="1.12345");
  PressKey(50);ReleaseKey(50);
  assert(g_editor.raw_text=="2" && recalculations==1);
}
''')


def test_reset_clears_pending_release_only_shortcuts(tmp_path):
    compile_and_run(tmp_path, keyboard_source() + r'''
int main(){
  PS_ObserveMouseModifiers(0);PressKey(17);ReleaseKey(17);
  PS_ResetKeyboardModifiers();ReleaseKey(67);
  assert(clipboard_calls==0 && g_editor.raw_text=="1.12345");
}
''')


@pytest.mark.parametrize("blocked", [
    "g_initialized=false;", "g_symbol_transition_pending=true;",
    "g_ps_panel_render_ready=false;", "g_editor.active=false;",
    "g_editor.field=PS_FIELD_RISK_PERCENT;",
])
def test_release_only_shortcut_cannot_edit_a_blocked_or_different_editor(tmp_path, blocked):
    compile_and_run(tmp_path, keyboard_source() + f"""
int main(){{
  PS_ObserveMouseModifiers(0);PressKey(17);ReleaseKey(17);
  {blocked}ReleaseKey(67);
  assert(clipboard_calls==0);
}}
""")


def test_release_only_copy_uses_shared_handler_for_every_numeric_field(tmp_path):
    compile_and_run(tmp_path, keyboard_source() + r'''
int main(){
  PSFieldId fields[]={PS_FIELD_ENTRY,PS_FIELD_STOP,PS_FIELD_TAKE,PS_FIELD_ACCOUNT,
                     PS_FIELD_RISK_PERCENT,PS_FIELD_RISK_MONEY,PS_FIELD_COMMISSION};
  for(auto field:fields){
    PS_ResetKeyboardModifiers();g_editor.field=field;clipboard_calls=0;
    PressKey(17);ReleaseKey(17);ReleaseKey(67);
    assert(clipboard_calls==1 && clipboard_text=="1.12345" && recalculations==0);
  }
}
''')


@pytest.mark.parametrize("ctrl_released_first", [False, True])
def test_release_only_redo_restores_one_history_step(tmp_path, ctrl_released_first):
    releases = (
        "ReleaseKey(17);ReleaseKey(89);" if ctrl_released_first else
        "ReleaseKey(89);ReleaseKey(17);"
    )
    compile_and_run(tmp_path, keyboard_source() + f"""
int main(){{
  PressKey(50);PressKey(51);PressKey(17);PressKey(90);ReleaseKey(90);ReleaseKey(17);
  assert(g_editor.raw_text=="2" && g_editor.history_index==1);
  PressKey(17);{releases}
  assert(g_editor.raw_text=="23" && g_editor.history_index==2 && recalculations==4);
}}
""")


@pytest.mark.parametrize(("key", "setup", "expected"), [
    (45, 'clipboard_text="2.5";', 'assert(clipboard_reads==1 && g_editor.raw_text=="2.5");'),
    (46, "", 'assert(clipboard_calls==1 && g_editor.raw_text.empty());'),
])
def test_release_only_shift_insert_and_delete_keep_existing_shortcuts(tmp_path, key, setup, expected):
    compile_and_run(tmp_path, keyboard_source() + f"""
int main(){{
  {setup}PS_ObserveMouseModifiers(0);
  PressKey(16);ReleaseKey(16);ReleaseKey({key});
  {expected}
}}
""")


def test_release_only_ctrl_shift_z_redoes_after_modifiers_are_released(tmp_path):
    compile_and_run(tmp_path, keyboard_source() + r'''
int main(){
  PressKey(50);PressKey(51);PressKey(17);PressKey(90);ReleaseKey(90);ReleaseKey(17);
  PressKey(17);PressKey(16);ReleaseKey(16);ReleaseKey(17);ReleaseKey(90);
  assert(g_editor.raw_text=="23" && g_editor.history_index==2 && recalculations==4);
}
''')
