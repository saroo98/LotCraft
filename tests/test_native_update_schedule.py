"""Execute the EA scheduler with a stub detached launch, never network or MT5."""

from native_mql_harness import compile_and_run, extract_function


EA = "MQL5/Experts/LotCraft/LotCraft.mq5"


def scheduler_source():
    return r'''
#include <cassert>
#include <string>
using string=std::string;
#define ulong unsigned long long
bool g_initialized=true,g_update_checks_enabled=true,launch_ok=true;
ulong g_next_update_check_ms=15000;
int launches=0,warnings=0;
bool PS_PlatformLaunchUpdater(string& error){launches++;error="launch failed";return launch_ok;}
void PS_LogWarningRateLimited(const string&,const string&,int){warnings++;}
''' + extract_function(EA, "PS_CheckForUpdates")


def test_update_opportunities_continue_after_initial_launch(tmp_path):
    program = scheduler_source() + r'''
int main(){
  PS_CheckForUpdates(14999);assert(launches==0);
  PS_CheckForUpdates(15000);assert(launches==1);
  assert(g_next_update_check_ms==3615000);
  PS_CheckForUpdates(15001);PS_CheckForUpdates(3614999);assert(launches==1);
  PS_CheckForUpdates(3615000);assert(launches==2 && warnings==0);
  PS_CheckForUpdates(9015000);assert(launches==3); // Resume after an event gap; no catch-up loop.
  assert(g_next_update_check_ms==12615000);
}
'''
    compile_and_run(tmp_path, program)


def test_disabled_or_uninitialized_ea_never_launches(tmp_path):
    program = scheduler_source() + r'''
int main(){
  g_update_checks_enabled=false;
  PS_CheckForUpdates(15000);PS_CheckForUpdates(1000000000);assert(launches==0);
  g_update_checks_enabled=true;g_initialized=false;
  PS_CheckForUpdates(1000000000);assert(launches==0);
}
'''
    compile_and_run(tmp_path, program)


def test_failed_launch_does_not_retry_on_every_timer_tick(tmp_path):
    program = scheduler_source() + r'''
int main(){
  launch_ok=false;
  PS_CheckForUpdates(15000);assert(launches==1 && warnings==1);
  for(ulong now=15001;now<16000;now++)PS_CheckForUpdates(now);
  assert(launches==1 && warnings==1);
  PS_CheckForUpdates(3615000);assert(launches==2 && warnings==2);
}
'''
    compile_and_run(tmp_path, program)
