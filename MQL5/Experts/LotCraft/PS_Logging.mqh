#ifndef __LOTCRAFT_PS_LOGGING_MQH__
#define __LOTCRAFT_PS_LOGGING_MQH__

#include "PS_Types.mqh"

string g_ps_log_keys[16];
ulong  g_ps_log_times[16];
int    g_ps_log_cursor=0;

void PS_LogInfo(const string message)
  {
   Print(PS_LOG_PREFIX," INFO: ",message);
  }

void PS_LogWarning(const string message)
  {
   Print(PS_LOG_PREFIX," WARNING: ",message);
  }

void PS_LogError(const string message)
  {
   Print(PS_LOG_PREFIX," ERROR: ",message);
  }

bool PS_LogMayEmit(const string key,const ulong interval_ms)
  {
   ulong now=GetTickCount64();
   for(int i=0;i<ArraySize(g_ps_log_keys);i++)
     {
      if(g_ps_log_keys[i]==key)
        {
         if(now-g_ps_log_times[i]<interval_ms) return(false);
         g_ps_log_times[i]=now;
         return(true);
        }
     }

   int slot=g_ps_log_cursor%ArraySize(g_ps_log_keys);
   g_ps_log_cursor++;
   g_ps_log_keys[slot]=key;
   g_ps_log_times[slot]=now;
   return(true);
  }

void PS_LogErrorRateLimited(const string key,const string message,const ulong interval_ms=5000)
  {
   if(PS_LogMayEmit(key,interval_ms)) PS_LogError(message);
  }

void PS_LogWarningRateLimited(const string key,const string message,const ulong interval_ms=5000)
  {
   if(PS_LogMayEmit(key,interval_ms)) PS_LogWarning(message);
  }

void PS_LogTradeResult(const string operation,const bool local_result,const MqlTradeResult &result)
  {
   PrintFormat("%s TRADE: %s local=%s retcode=%u external=%d order=%I64u deal=%I64u price=%.*f volume=%g comment=%s",
               PS_LOG_PREFIX,
               operation,
               (local_result ? "true" : "false"),
               result.retcode,
               result.retcode_external,
               result.order,
               result.deal,
               _Digits,
               result.price,
               result.volume,
               result.comment);
  }

void PS_PerfCheck(const string subsystem,const ulong started_us,const ulong budget_us)
  {
   if(PS_DIAGNOSTICS==0) return;
   ulong elapsed=GetMicrosecondCount()-started_us;
   if(elapsed>budget_us)
      PS_LogWarningRateLimited("perf."+subsystem,
                               StringFormat("%s exceeded budget: %I64u us > %I64u us",subsystem,elapsed,budget_us),
                               2000);
  }

#endif
