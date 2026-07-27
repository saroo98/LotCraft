#ifndef __LOTCRAFT_PS_EDITOR_MQH__
#define __LOTCRAFT_PS_EDITOR_MQH__

#include "PS_Risk.mqh"

enum PSEditKeyResult
  {
   PS_EDIT_KEY_NONE=0,
   PS_EDIT_KEY_CHANGED=1,
   PS_EDIT_KEY_COMMIT=2,
   PS_EDIT_KEY_CANCEL=3
  };

void PS_EditorReset(PSEditorState &editor)
  {
   editor.active=false;
   editor.field=PS_FIELD_NONE;
   editor.raw_text="";
   editor.original_text="";
   editor.cursor=0;
   editor.anchor=0;
   editor.has_selection=false;
  }

string PS_EditorModelText(const PSFieldId field,const PSModel &model,const PSMarketSnapshot &market)
  {
   switch(field)
     {
      case PS_FIELD_ENTRY:         return(PS_PriceText(model.entry,market));
      case PS_FIELD_STOP:          return(PS_PriceText(model.stop_loss,market));
      case PS_FIELD_TAKE:          return(PS_IsPositiveFinite(model.take_profit) ? PS_PriceText(model.take_profit,market) : "0");
      case PS_FIELD_COMMISSION:    return(DoubleToString(model.commission_per_lot,market.currency_digits));
      case PS_FIELD_ACCOUNT:       return(DoubleToString(model.manual_account_money,market.currency_digits));
      case PS_FIELD_RISK_PERCENT:  return(DoubleToString(model.requested_risk_percent,4));
      case PS_FIELD_RISK_MONEY:    return(DoubleToString(model.requested_risk_money,market.currency_digits));
      default:                     return("");
     }
  }

void PS_EditorBegin(PSEditorState &editor,const PSFieldId field,const PSModel &model,const PSMarketSnapshot &market)
  {
   editor.active=true;
   editor.field=field;
   editor.raw_text=PS_EditorModelText(field,model,market);
   editor.original_text=editor.raw_text;
   editor.cursor=StringLen(editor.raw_text);
   editor.anchor=editor.cursor;
   editor.has_selection=false;
   PS_CopyModel(editor.before,model);
  }

void PS_EditorSelectAll(PSEditorState &editor)
  {
   editor.anchor=0;
   editor.cursor=StringLen(editor.raw_text);
   editor.has_selection=(editor.cursor>0);
  }

int PS_EditorSelectionStart(const PSEditorState &editor)
  {
   return(MathMin(editor.cursor,editor.anchor));
  }

int PS_EditorSelectionEnd(const PSEditorState &editor)
  {
   return(MathMax(editor.cursor,editor.anchor));
  }

void PS_EditorRefreshSelection(PSEditorState &editor)
  {
   editor.has_selection=(editor.cursor!=editor.anchor);
  }

void PS_EditorDeleteSelection(PSEditorState &editor)
  {
   if(!editor.has_selection) return;
   int start=PS_EditorSelectionStart(editor);
   int finish=PS_EditorSelectionEnd(editor);
   string left=(start>0 ? StringSubstr(editor.raw_text,0,start) : "");
   string right=(finish<StringLen(editor.raw_text) ? StringSubstr(editor.raw_text,finish) : "");
   editor.raw_text=left+right;
   editor.cursor=start;
   editor.anchor=start;
   editor.has_selection=false;
  }

void PS_EditorInsert(PSEditorState &editor,const string text)
  {
   if(text=="" || StringLen(editor.raw_text)+StringLen(text)>32) return;
   PS_EditorDeleteSelection(editor);
   string left=(editor.cursor>0 ? StringSubstr(editor.raw_text,0,editor.cursor) : "");
   string right=(editor.cursor<StringLen(editor.raw_text) ? StringSubstr(editor.raw_text,editor.cursor) : "");
   editor.raw_text=left+text+right;
   editor.cursor+=StringLen(text);
   editor.anchor=editor.cursor;
   editor.has_selection=false;
  }

void PS_EditorMoveCursor(PSEditorState &editor,const int destination,const bool extend_selection)
  {
   int target=PS_ClampInt(destination,0,StringLen(editor.raw_text));
   if(!extend_selection)
     {
      editor.cursor=target;
      editor.anchor=target;
      editor.has_selection=false;
      return;
     }
   if(!editor.has_selection) editor.anchor=editor.cursor;
   editor.cursor=target;
   PS_EditorRefreshSelection(editor);
  }

void PS_EditorBackspace(PSEditorState &editor)
  {
   if(editor.has_selection)
     {
      PS_EditorDeleteSelection(editor);
      return;
     }
   if(editor.cursor<=0) return;
   int remove_at=editor.cursor-1;
   string left=(remove_at>0 ? StringSubstr(editor.raw_text,0,remove_at) : "");
   string right=(editor.cursor<StringLen(editor.raw_text) ? StringSubstr(editor.raw_text,editor.cursor) : "");
   editor.raw_text=left+right;
   editor.cursor=remove_at;
   editor.anchor=editor.cursor;
  }

void PS_EditorDelete(PSEditorState &editor)
  {
   if(editor.has_selection)
     {
      PS_EditorDeleteSelection(editor);
      return;
     }
   int length=StringLen(editor.raw_text);
   if(editor.cursor>=length) return;
   string left=(editor.cursor>0 ? StringSubstr(editor.raw_text,0,editor.cursor) : "");
   string right=(editor.cursor+1<length ? StringSubstr(editor.raw_text,editor.cursor+1) : "");
   editor.raw_text=left+right;
   editor.anchor=editor.cursor;
  }

bool PS_EditorParseNumber(const string raw,double &value,bool &incomplete)
  {
   value=0.0;
   incomplete=false;
   int length=StringLen(raw);
   if(length==0)
     {
      incomplete=true;
      return(false);
     }

   if(raw=="." || raw=="," || raw=="-" || raw=="+" || raw=="-." || raw=="-," || raw=="+." || raw=="+,")
     {
      incomplete=true;
      return(false);
     }

   bool digit_seen=false;
   bool separator_seen=false;
   for(int i=0;i<length;i++)
     {
      ushort ch=StringGetCharacter(raw,i);
      if(ch>='0' && ch<='9')
        {
         digit_seen=true;
         continue;
        }
      if(ch=='.' || ch==',')
        {
         if(separator_seen) return(false);
         separator_seen=true;
         continue;
        }
      if((ch=='-' || ch=='+') && i==0) continue;
      return(false);
     }
   if(!digit_seen)
     {
      incomplete=true;
      return(false);
     }

   string canonical=raw;
   StringReplace(canonical,",",".");
   value=StringToDouble(canonical);
   if(!PS_IsFinite(value)) return(false);
   return(true);
  }

bool PS_EditorApplyRaw(PSEditorState &editor,PSModel &model,const PSMarketSnapshot &market,const bool committing,string &error)
  {
   error="";
   if(!editor.active) return(false);

   double value=0.0;
   bool incomplete=false;
   bool parsed=PS_EditorParseNumber(editor.raw_text,value,incomplete);
   if(!parsed)
     {
      if(committing && editor.field==PS_FIELD_TAKE && StringLen(editor.raw_text)==0)
        {
         model.take_profit=0.0;
         model.revision++;
         return(true);
        }
      if(committing)
         error=(incomplete ? "The numeric entry is incomplete." : "The numeric entry is invalid.");
      return(false);
     }

   switch(editor.field)
     {
      case PS_FIELD_ENTRY:
         if(!PS_IsPositiveFinite(value)) error="Entry must be positive and finite.";
         else
           {
            double normalized=PS_NormalizePrice(value,market);
            if(!PS_IsPositiveFinite(normalized)) error="Entry cannot be normalized because the broker tick size is unavailable or invalid.";
            else model.entry=normalized;
           }
         break;
      case PS_FIELD_STOP:
         if(!PS_IsPositiveFinite(value)) error="Stop-loss must be positive and finite.";
         else
           {
            double normalized=PS_NormalizePrice(value,market);
            if(!PS_IsPositiveFinite(normalized)) error="Stop-loss cannot be normalized because the broker tick size is unavailable or invalid.";
            else model.stop_loss=normalized;
           }
         break;
      case PS_FIELD_TAKE:
         if(!PS_IsFinite(value) || value<0.0) error="Take-profit must be zero or a positive finite price.";
         else if(value==0.0) model.take_profit=0.0;
         else
           {
            double normalized=PS_NormalizePrice(value,market);
            if(!PS_IsPositiveFinite(normalized)) error="Take-profit cannot be normalized because the broker tick size is unavailable or invalid.";
            else model.take_profit=normalized;
           }
         break;
      case PS_FIELD_COMMISSION:
         if(!PS_IsFinite(value) || value<0.0) error="Commission/lot must be zero or positive.";
         else model.commission_per_lot=value;
         break;
      case PS_FIELD_ACCOUNT:
         if(model.account_mode!=PS_ACCOUNT_MANUAL) error="Account money is editable only in Manual mode.";
         else if(!PS_IsPositiveFinite(value)) error="Manual account money must be positive and finite.";
         else model.manual_account_money=value;
         break;
      case PS_FIELD_RISK_PERCENT:
         if(!PS_IsPositiveFinite(value)) error="Risk, % must be positive and finite.";
         else
           {
            model.risk_authority=PS_RISK_PERCENT;
            model.requested_risk_percent=value;
           }
         break;
      case PS_FIELD_RISK_MONEY:
         if(!PS_IsPositiveFinite(value)) error="Risk, money must be positive and finite.";
         else
           {
            model.risk_authority=PS_RISK_MONEY;
            model.requested_risk_money=value;
           }
         break;
      default:
         error="No editable field is active.";
         break;
     }

   if(error!="") return(false);
   model.revision++;
   return(true);
  }

string PS_EditorNormalizedText(const PSEditorState &editor,const PSModel &model,const PSMarketSnapshot &market)
  {
   return(PS_EditorModelText(editor.field,model,market));
  }

bool PS_EditorCommit(PSEditorState &editor,PSModel &model,const PSMarketSnapshot &market,string &error)
  {
   error="";
   if(!editor.active) return(true);
   PSModel candidate;
   PS_CopyModel(candidate,model);
   if(!PS_EditorApplyRaw(editor,candidate,market,true,error))
     {
      PS_CopyModel(model,editor.before);
      PS_EditorReset(editor);
      return(false);
     }
   PS_CopyModel(model,candidate);
   editor.raw_text=PS_EditorNormalizedText(editor,model,market);
   PS_EditorReset(editor);
   return(true);
  }

void PS_EditorCancel(PSEditorState &editor,PSModel &model)
  {
   if(editor.active) PS_CopyModel(model,editor.before);
   PS_EditorReset(editor);
  }

void PS_EditorSetCursorIndex(PSEditorState &editor,const int index,const bool extend_selection=false)
  {
   if(!editor.active) return;
   PS_EditorMoveCursor(editor,index,extend_selection);
  }

PSEditKeyResult PS_EditorKey(PSEditorState &editor,const int key,const bool shift_down,const bool ctrl_down)
  {
   if(!editor.active) return(PS_EDIT_KEY_NONE);

   if(key==13) return(PS_EDIT_KEY_COMMIT);
   if(key==27) return(PS_EDIT_KEY_CANCEL);
   if(ctrl_down && key==65)
     {
      PS_EditorSelectAll(editor);
      return(PS_EDIT_KEY_NONE);
     }

   if(key==37)
     {
      if(editor.has_selection && !shift_down)
         PS_EditorMoveCursor(editor,PS_EditorSelectionStart(editor),false);
      else
         PS_EditorMoveCursor(editor,editor.cursor-1,shift_down);
      return(PS_EDIT_KEY_NONE);
     }
   if(key==39)
     {
      if(editor.has_selection && !shift_down)
         PS_EditorMoveCursor(editor,PS_EditorSelectionEnd(editor),false);
      else
         PS_EditorMoveCursor(editor,editor.cursor+1,shift_down);
      return(PS_EDIT_KEY_NONE);
     }
   if(key==36)
     {
      PS_EditorMoveCursor(editor,0,shift_down);
      return(PS_EDIT_KEY_NONE);
     }
   if(key==35)
     {
      PS_EditorMoveCursor(editor,StringLen(editor.raw_text),shift_down);
      return(PS_EDIT_KEY_NONE);
     }
   if(key==8)
     {
      PS_EditorBackspace(editor);
      return(PS_EDIT_KEY_CHANGED);
     }
   if(key==46)
     {
      PS_EditorDelete(editor);
      return(PS_EDIT_KEY_CHANGED);
     }

   short translated=TranslateKey(key);
   if(translated<=0) return(PS_EDIT_KEY_NONE);
   string character=ShortToString(translated);
   if(StringLen(character)!=1) return(PS_EDIT_KEY_NONE);
   ushort ch=StringGetCharacter(character,0);
   if((ch>='0' && ch<='9') || ch=='.' || ch==',' || ch=='-' || ch=='+')
     {
      PS_EditorInsert(editor,character);
      return(PS_EDIT_KEY_CHANGED);
     }
   return(PS_EDIT_KEY_NONE);
  }

#endif
