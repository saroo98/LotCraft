#ifndef __LOTCRAFT_PS_PERSISTENCE_MQH__
#define __LOTCRAFT_PS_PERSISTENCE_MQH__

#include "PS_Types.mqh"

string PS_PersistenceBase(const PSMarketSnapshot &market)
  {
   uint server_hash=PS_HashString32(market.account_server);
   uint chart_hash=PS_HashString32(IntegerToString(ChartID()));
   return(StringFormat("%s.%I64d.%08X.%08X",PS_STATE_NAMESPACE,market.account_login,server_hash,chart_hash));
  }

string PS_PersistenceKey(const string base,const string suffix)
  {
   return(base+"."+suffix);
  }

bool PS_PersistenceRead(const string key,double &value)
  {
   if(!GlobalVariableCheck(key)) return(false);
   value=GlobalVariableGet(key);
   return(PS_IsFinite(value));
  }

void PS_PersistenceSave(const string base,const PSModel &model)
  {
   GlobalVariableSet(PS_PersistenceKey(base,"acct"),(double)model.account_mode);
   GlobalVariableSet(PS_PersistenceKey(base,"manual"),model.manual_account_money);
   GlobalVariableSet(PS_PersistenceKey(base,"riska"),(double)model.risk_authority);
   GlobalVariableSet(PS_PersistenceKey(base,"riskp"),model.requested_risk_percent);
   GlobalVariableSet(PS_PersistenceKey(base,"riskm"),model.requested_risk_money);
   GlobalVariableSet(PS_PersistenceKey(base,"commt"),(double)model.commission_mode);
   GlobalVariableSet(PS_PersistenceKey(base,"commv"),model.commission_per_lot);
   GlobalVariableSet(PS_PersistenceKey(base,"confirm"),(model.ask_confirmation ? 1.0 : 0.0));
   GlobalVariableSet(PS_PersistenceKey(base,"view"),(double)model.view_mode);
   GlobalVariableSet(PS_PersistenceKey(base,"theme"),(double)model.theme_mode);
   // Keep the legacy flag synchronized so an older binary can still reopen
   // the same chart safely after a rollback.
   GlobalVariableSet(PS_PersistenceKey(base,"mini"),(model.view_mode==PS_VIEW_MINI ? 1.0 : 0.0));
   GlobalVariableSet(PS_PersistenceKey(base,"lines"),(model.lines_visible ? 1.0 : 0.0));
  }

void PS_PersistenceLoad(const string base,PSModel &model)
  {
   double value=0.0;
   if(PS_PersistenceRead(PS_PersistenceKey(base,"acct"),value))
     {
      int mode=(int)value;
      if(mode>=PS_ACCOUNT_EQUITY && mode<=PS_ACCOUNT_MANUAL) model.account_mode=(PSAccountMode)mode;
     }
   if(PS_PersistenceRead(PS_PersistenceKey(base,"manual"),value) && PS_IsPositiveFinite(value))
      model.manual_account_money=value;
   if(PS_PersistenceRead(PS_PersistenceKey(base,"riska"),value))
     {
      int authority=(int)value;
      if(authority==PS_RISK_PERCENT || authority==PS_RISK_MONEY) model.risk_authority=(PSRiskAuthority)authority;
     }
   if(PS_PersistenceRead(PS_PersistenceKey(base,"riskp"),value) && PS_IsPositiveFinite(value))
      model.requested_risk_percent=value;
   if(PS_PersistenceRead(PS_PersistenceKey(base,"riskm"),value) && PS_IsPositiveFinite(value))
      model.requested_risk_money=value;
   if(PS_PersistenceRead(PS_PersistenceKey(base,"commt"),value))
     {
      int mode=(int)value;
      if(mode==PS_COMMISSION_ONE_SIDE || mode==PS_COMMISSION_ROUND_TRIP) model.commission_mode=(PSCommissionMode)mode;
     }
   if(PS_PersistenceRead(PS_PersistenceKey(base,"commv"),value) && PS_IsFinite(value) && value>=0.0)
      model.commission_per_lot=value;
   if(PS_PersistenceRead(PS_PersistenceKey(base,"confirm"),value)) model.ask_confirmation=(value>=0.5);
   if(PS_PersistenceRead(PS_PersistenceKey(base,"view"),value))
     {
      int view=(int)value;
      if(view>=PS_VIEW_FULL && view<=PS_VIEW_MINI) model.view_mode=(PSViewMode)view;
     }
   else if(PS_PersistenceRead(PS_PersistenceKey(base,"mini"),value))
      model.view_mode=(value>=0.5 ? PS_VIEW_MINI : PS_VIEW_FULL);
   if(PS_PersistenceRead(PS_PersistenceKey(base,"theme"),value))
     {
      int theme=(int)value;
      if(theme==PS_THEME_DARK || theme==PS_THEME_LIGHT) model.theme_mode=(PSThemeMode)theme;
     }
   if(PS_PersistenceRead(PS_PersistenceKey(base,"lines"),value)) model.lines_visible=(value>=0.5);
   model.revision++;
  }

#endif
