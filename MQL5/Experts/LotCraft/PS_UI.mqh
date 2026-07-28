#ifndef __LOTCRAFT_PS_UI_MQH__
#define __LOTCRAFT_PS_UI_MQH__

#include "PS_Editor.mqh"
#include <Canvas\Canvas.mqh>

const color PS_CLR_PANEL       = C'29,33,40';
const color PS_CLR_PANEL_ALT   = C'35,40,49';
const color PS_CLR_FIELD       = C'18,21,27';
const color PS_CLR_FIELD_RO    = C'24,28,35';
const color PS_CLR_BORDER      = C'70,78,92';
const color PS_CLR_BORDER_HI   = C'103,116,138';
const color PS_CLR_TEXT        = C'232,236,242';
const color PS_CLR_MUTED       = C'154,164,181';
const color PS_CLR_ACCENT      = C'77,145,255';
const color PS_CLR_LONG        = C'47,184,130';
const color PS_CLR_SHORT       = C'224,86,95';
const color PS_CLR_WARNING     = C'242,180,72';
const color PS_CLR_ERROR       = C'244,104,112';
const color PS_CLR_DISABLED    = C'62,68,80';
const color PS_CLR_SELECTION   = C'48,83,135';
const color PS_CLR_FIELD_FOCUS = C'27,44,69';
const color PS_CLR_FOCUS       = C'116,181,255';
const color PS_PREMIUM_BG      = C'13,18,23';
const color PS_PREMIUM_PANEL   = C'19,25,32';
const color PS_PREMIUM_SECTION = C'17,23,29';
const color PS_PREMIUM_CONTROL = C'25,32,41';
const color PS_PREMIUM_FIELD   = C'10,15,20';
const color PS_PREMIUM_BORDER  = C'45,57,70';
const color PS_PREMIUM_DIVIDER = C'32,42,52';
const color PS_PREMIUM_TEXT    = C'236,240,246';
const color PS_PREMIUM_MUTED   = C'178,187,201';
const color PS_PREMIUM_GREEN   = C'46,190,101';
const color PS_PREMIUM_GREEN_2 = C'28,139,72';
const color PS_PREMIUM_BLUE    = C'71,145,255';
const color PS_PREMIUM_PURPLE  = C'125,94,255';
const color PS_PREMIUM_NOTICE  = C'14,45,75';

bool g_ps_light_theme=false;

void PS_UISelectTheme(const PSThemeMode theme_mode)
  {
   g_ps_light_theme=(theme_mode==PS_THEME_LIGHT);
  }

color PS_ThemeBackground()   { return(g_ps_light_theme ? C'226,232,239' : PS_PREMIUM_BG); }
color PS_ThemePanel()        { return(g_ps_light_theme ? C'250,252,255' : PS_PREMIUM_PANEL); }
color PS_ThemeSection()      { return(g_ps_light_theme ? C'244,247,251' : PS_PREMIUM_SECTION); }
color PS_ThemeControl()      { return(g_ps_light_theme ? C'255,255,255' : PS_PREMIUM_CONTROL); }
color PS_ThemeField()        { return(g_ps_light_theme ? C'255,255,255' : PS_PREMIUM_FIELD); }
color PS_ThemeBorder()       { return(g_ps_light_theme ? C'184,197,211' : PS_PREMIUM_BORDER); }
color PS_ThemeDivider()      { return(g_ps_light_theme ? C'216,224,233' : PS_PREMIUM_DIVIDER); }
color PS_ThemeText()         { return(g_ps_light_theme ? C'24,32,42' : PS_PREMIUM_TEXT); }
color PS_ThemeMuted()        { return(g_ps_light_theme ? C'92,105,121' : PS_PREMIUM_MUTED); }
color PS_ThemeOnAccent()     { return(C'248,251,255'); }
color PS_ThemeSelection()    { return(g_ps_light_theme ? C'190,215,246' : PS_CLR_SELECTION); }
color PS_ThemeFieldFocus()   { return(g_ps_light_theme ? C'234,243,255' : PS_CLR_FIELD_FOCUS); }
color PS_ThemeReadOnly()     { return(g_ps_light_theme ? C'247,249,252' : C'13,19,25'); }
color PS_ThemeReadOnlyText() { return(g_ps_light_theme ? C'50,61,75' : C'204,212,223'); }
color PS_ThemeVersion()      { return(g_ps_light_theme ? C'101,115,132' : C'126,151,184'); }
color PS_ThemeLabelBlue()    { return(g_ps_light_theme ? C'49,91,140' : C'175,205,242'); }
color PS_ThemeSectionTitle() { return(g_ps_light_theme ? C'92,105,121' : C'180,189,203'); }
color PS_ThemeNotice()       { return(g_ps_light_theme ? C'230,241,253' : PS_PREMIUM_NOTICE); }
color PS_ThemeNoticeBorder() { return(g_ps_light_theme ? C'119,169,221' : C'31,87,140'); }
color PS_ThemeNoticeText()   { return(g_ps_light_theme ? C'45,78,112' : C'181,203,232'); }
color PS_ThemeErrorPanel()   { return(g_ps_light_theme ? C'255,235,237' : C'67,25,31'); }
color PS_ThemeErrorText()    { return(g_ps_light_theme ? C'145,38,46' : C'255,178,183'); }

PSRect g_ps_control_rects[PS_CTRL_COUNT];
bool   g_ps_control_visible[PS_CTRL_COUNT];
PSRect g_ps_handle_rects[3];
bool   g_ps_handle_visible[3];
CCanvas g_ps_handle_canvas[3];
bool    g_ps_handle_canvas_created[3];
string  g_ps_handle_canvas_name[3];
color   g_ps_handle_canvas_color[3];
string  g_ps_handle_canvas_text[3];
CCanvas g_ps_drag_canvas;
bool    g_ps_drag_canvas_created=false;
string  g_ps_drag_canvas_name="";
CCanvas g_ps_panel_canvas;
bool    g_ps_panel_canvas_created=false;
string  g_ps_panel_canvas_name="";

string PS_UIName(const PSUIState &ui,const string suffix)
  {
   return(ui.prefix+suffix);
  }

void PS_UIResetRect(PSRect &rect)
  {
   rect.x=0;
   rect.y=0;
   rect.w=0;
   rect.h=0;
  }

void PS_UISetRect(PSRect &rect,const int x,const int y,const int w,const int h)
  {
   rect.x=x;
   rect.y=y;
   rect.w=w;
   rect.h=h;
  }

bool PS_UIEnsureBox(const PSUIState &ui,const string suffix,const long zorder=20000)
  {
   string name=PS_UIName(ui,suffix);
   if(ObjectFind(ChartID(),name)>=0) return(true);
   ResetLastError();
   if(!ObjectCreate(ChartID(),name,OBJ_RECTANGLE_LABEL,0,0,0))
     {
      PS_LogError(StringFormat("Cannot create UI box %s (error %d).",name,GetLastError()));
      return(false);
     }
   ObjectSetInteger(ChartID(),name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(ChartID(),name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(ChartID(),name,OBJPROP_SELECTED,false);
   ObjectSetInteger(ChartID(),name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(ChartID(),name,OBJPROP_BACK,false);
   ObjectSetInteger(ChartID(),name,OBJPROP_ZORDER,zorder);
   ObjectSetInteger(ChartID(),name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetString(ChartID(),name,OBJPROP_TOOLTIP,"\n");
   return(true);
  }

bool PS_UIEnsureLabel(const PSUIState &ui,const string suffix,const long zorder=20010)
  {
   string name=PS_UIName(ui,suffix);
   if(ObjectFind(ChartID(),name)>=0) return(true);
   ResetLastError();
   if(!ObjectCreate(ChartID(),name,OBJ_LABEL,0,0,0))
     {
      PS_LogError(StringFormat("Cannot create UI label %s (error %d).",name,GetLastError()));
      return(false);
     }
   ObjectSetInteger(ChartID(),name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(ChartID(),name,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
   ObjectSetInteger(ChartID(),name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(ChartID(),name,OBJPROP_SELECTED,false);
   ObjectSetInteger(ChartID(),name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(ChartID(),name,OBJPROP_BACK,false);
   ObjectSetInteger(ChartID(),name,OBJPROP_ZORDER,zorder);
   ObjectSetString(ChartID(),name,OBJPROP_FONT,"Segoe UI");
   ObjectSetString(ChartID(),name,OBJPROP_TOOLTIP,"\n");
   return(true);
  }

void PS_UIShow(const PSUIState &ui,const string suffix,const bool show)
  {
   string name=PS_UIName(ui,suffix);
   if(ObjectFind(ChartID(),name)<0) return;
   ObjectSetInteger(ChartID(),name,OBJPROP_TIMEFRAMES,(show ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS));
  }

void PS_UIBox(const PSUIState &ui,const string suffix,const PSRect &rect,const color background,
              const color border,const bool show,const long zorder=20000)
  {
   if(!PS_UIEnsureBox(ui,suffix,zorder)) return;
   string name=PS_UIName(ui,suffix);
   ObjectSetInteger(ChartID(),name,OBJPROP_XDISTANCE,rect.x);
   ObjectSetInteger(ChartID(),name,OBJPROP_YDISTANCE,rect.y);
   ObjectSetInteger(ChartID(),name,OBJPROP_XSIZE,MathMax(1,rect.w));
   ObjectSetInteger(ChartID(),name,OBJPROP_YSIZE,MathMax(1,rect.h));
   ObjectSetInteger(ChartID(),name,OBJPROP_BGCOLOR,background);
   ObjectSetInteger(ChartID(),name,OBJPROP_BORDER_COLOR,border);
   ObjectSetInteger(ChartID(),name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(ChartID(),name,OBJPROP_SELECTED,false);
   ObjectSetInteger(ChartID(),name,OBJPROP_ZORDER,zorder);
   PS_UIShow(ui,suffix,show);
  }

void PS_UILabel(const PSUIState &ui,const string suffix,const int x,const int y,const string text,
                const int size,const color text_color,const bool show,const long zorder=20010,
                const string font="Segoe UI")
  {
   if(!PS_UIEnsureLabel(ui,suffix,zorder)) return;
   string name=PS_UIName(ui,suffix);
   ObjectSetInteger(ChartID(),name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(ChartID(),name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(ChartID(),name,OBJPROP_FONTSIZE,size);
   ObjectSetInteger(ChartID(),name,OBJPROP_COLOR,text_color);
   ObjectSetInteger(ChartID(),name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(ChartID(),name,OBJPROP_SELECTED,false);
   ObjectSetInteger(ChartID(),name,OBJPROP_ZORDER,zorder);
   ObjectSetString(ChartID(),name,OBJPROP_FONT,font);
   ObjectSetString(ChartID(),name,OBJPROP_TEXT,text);
   PS_UIShow(ui,suffix,show);
  }

string PS_UIControlSuffix(const PSControlId control,const string part)
  {
   return(StringFormat("ui.ctrl.%d.%s",(int)control,part));
  }

void PS_UIControl(const PSUIState &ui,const PSControlId control,const string text,
                  const color background,const color border,const color text_color,
                  const bool show,const int font_size=9,const string font="Segoe UI")
  {
   PSRect rect=g_ps_control_rects[(int)control];
   string box_suffix=PS_UIControlSuffix(control,"box");
   string text_suffix=PS_UIControlSuffix(control,"text");
   PS_UIBox(ui,box_suffix,rect,background,border,show,21000);
   int char_height=font_size+4;
   int text_y=rect.y+MathMax(2,(rect.h-char_height)/2);
   // MT5 assigns an object-name fallback such as "Label 1" when OBJ_LABEL
   // text is empty. A single space keeps an intentionally empty editor empty.
   string rendered_text=(text=="" ? " " : text);
   PS_UILabel(ui,text_suffix,rect.x+8,text_y,rendered_text,font_size,text_color,show,21010,font);
  }

void PS_UIStaticLabel(const PSUIState &ui,const string id,const int x,const int y,const string text,
                      const bool show,const color text_color=C'154,164,181',const int size=9)
  {
   PS_UILabel(ui,"ui.lbl."+id,x,y,text,size,text_color,show,20500);
  }

void PS_UIReadChartSize(PSUIState &ui)
  {
   ui.chart_w=(int)ChartGetInteger(ChartID(),CHART_WIDTH_IN_PIXELS,0);
   ui.chart_h=(int)ChartGetInteger(ChartID(),CHART_HEIGHT_IN_PIXELS,0);
   if(ui.chart_w<200) ui.chart_w=200;
   if(ui.chart_h<100) ui.chart_h=100;
  }

void PS_UIClampPanel(PSUIState &ui,const PSViewMode view_mode)
  {
   // Keep each mode meaningfully distinct: Full remains comprehensive,
   // Compact retains every trading control at a reduced scale, and Mini
   // exposes only risk input, mode navigation, theme, close, and trade.
   if(view_mode==PS_VIEW_MINI)
     {
      ui.panel_w=390;
      ui.panel_h=92;
     }
   else if(view_mode==PS_VIEW_COMPACT)
     {
      ui.panel_w=372;
      ui.panel_h=419;
     }
   else
     {
      ui.panel_w=438;
      ui.panel_h=469;
     }
   PS_UIReadChartSize(ui);
   int max_x=MathMax(0,ui.chart_w-ui.panel_w);
   int max_y=MathMax(0,ui.chart_h-ui.panel_h);
   ui.panel_x=PS_ClampInt(ui.panel_x,0,max_x);
   ui.panel_y=PS_ClampInt(ui.panel_y,0,max_y);
  }

void PS_UILayout(PSUIState &ui,const PSViewMode view_mode)
  {
   PS_UIClampPanel(ui,view_mode);
   for(int i=0;i<PS_CTRL_COUNT;i++)
     {
      PS_UIResetRect(g_ps_control_rects[i]);
      g_ps_control_visible[i]=false;
     }

   int x=ui.panel_x;
   int y=ui.panel_y;
   if(view_mode==PS_VIEW_MINI)
     {
      PS_UISetRect(g_ps_control_rects[PS_CTRL_MINI],x+210,y+7,42,28);
      PS_UISetRect(g_ps_control_rects[PS_CTRL_COMPACT],x+257,y+7,66,28);
      PS_UISetRect(g_ps_control_rects[PS_CTRL_THEME],x+328,y+7,25,28);
      PS_UISetRect(g_ps_control_rects[PS_CTRL_CLOSE],x+358,y+7,25,28);
      PS_UISetRect(g_ps_control_rects[PS_CTRL_RISK_PERCENT_FIELD],x+72,y+52,82,28);
      PS_UISetRect(g_ps_control_rects[PS_CTRL_TRADE],x+162,y+50,221,32);
      g_ps_control_visible[PS_CTRL_MINI]=true;
      g_ps_control_visible[PS_CTRL_COMPACT]=true;
      g_ps_control_visible[PS_CTRL_THEME]=true;
      g_ps_control_visible[PS_CTRL_CLOSE]=true;
      g_ps_control_visible[PS_CTRL_RISK_PERCENT_FIELD]=true;
      g_ps_control_visible[PS_CTRL_TRADE]=true;
      return;
     }

   if(view_mode==PS_VIEW_COMPACT)
     {
      PS_UISetRect(g_ps_control_rects[PS_CTRL_MANUAL],x+154,y+6,61,28);
      PS_UISetRect(g_ps_control_rects[PS_CTRL_COMPACT],x+218,y+6,38,28);
      PS_UISetRect(g_ps_control_rects[PS_CTRL_MINI],x+261,y+6,38,28);
      PS_UISetRect(g_ps_control_rects[PS_CTRL_THEME],x+304,y+6,26,28);
      PS_UISetRect(g_ps_control_rects[PS_CTRL_CLOSE],x+335,y+6,27,28);
      PS_UISetRect(g_ps_control_rects[PS_CTRL_DIRECTION],x+16,y+51,166,26);
      PS_UISetRect(g_ps_control_rects[PS_CTRL_ORDER_MODE],x+190,y+51,166,26);

      int compact_row=99;
      PS_UISetRect(g_ps_control_rects[PS_CTRL_ENTRY_FIELD],x+75,y+compact_row,157,26);
      PS_UISetRect(g_ps_control_rects[PS_CTRL_ENTRY_MINUS],x+238,y+compact_row,30,26);
      PS_UISetRect(g_ps_control_rects[PS_CTRL_ENTRY_PLUS],x+274,y+compact_row,32,26);
      PS_UISetRect(g_ps_control_rects[PS_CTRL_ENTRY_COPY],x+312,y+compact_row,43,26);
      compact_row+=30;
      PS_UISetRect(g_ps_control_rects[PS_CTRL_STOP_FIELD],x+75,y+compact_row,157,26);
      PS_UISetRect(g_ps_control_rects[PS_CTRL_STOP_MINUS],x+238,y+compact_row,30,26);
      PS_UISetRect(g_ps_control_rects[PS_CTRL_STOP_PLUS],x+274,y+compact_row,32,26);
      PS_UISetRect(g_ps_control_rects[PS_CTRL_STOP_COPY],x+312,y+compact_row,43,26);
      compact_row+=30;
      PS_UISetRect(g_ps_control_rects[PS_CTRL_TAKE_FIELD],x+75,y+compact_row,157,26);
      PS_UISetRect(g_ps_control_rects[PS_CTRL_TAKE_MINUS],x+238,y+compact_row,30,26);
      PS_UISetRect(g_ps_control_rects[PS_CTRL_TAKE_PLUS],x+274,y+compact_row,32,26);
      PS_UISetRect(g_ps_control_rects[PS_CTRL_TAKE_COPY],x+312,y+compact_row,43,26);
      PS_UISetRect(g_ps_control_rects[PS_CTRL_LINES],x+16,y+189,112,22);

      PS_UISetRect(g_ps_control_rects[PS_CTRL_ACCOUNT_MODE],x+75,y+231,101,26);
      PS_UISetRect(g_ps_control_rects[PS_CTRL_ACCOUNT_FIELD],x+182,y+231,173,26);
      PS_UISetRect(g_ps_control_rects[PS_CTRL_RISK_PERCENT_FIELD],x+75,y+261,101,26);
      PS_UISetRect(g_ps_control_rects[PS_CTRL_RISK_MONEY_FIELD],x+261,y+261,94,26);
      PS_UISetRect(g_ps_control_rects[PS_CTRL_POSITION_SIZE],x+75,y+291,237,26);
      PS_UISetRect(g_ps_control_rects[PS_CTRL_POSITION_COPY],x+318,y+291,37,26);
      PS_UISetRect(g_ps_control_rects[PS_CTRL_CONFIRM],x+8,y+337,174,32);
      PS_UISetRect(g_ps_control_rects[PS_CTRL_MOVE_SLS],x+188,y+337,176,32);
      PS_UISetRect(g_ps_control_rects[PS_CTRL_TRADE],x+8,y+377,356,34);

      for(int i=0;i<PS_CTRL_COUNT;i++)
         g_ps_control_visible[i]=(g_ps_control_rects[i].w>0 && g_ps_control_rects[i].h>0);
      return;
     }

   PS_UISetRect(g_ps_control_rects[PS_CTRL_MANUAL],x+172,y+7,64,30);
   PS_UISetRect(g_ps_control_rects[PS_CTRL_COMPACT],x+242,y+7,68,30);
   PS_UISetRect(g_ps_control_rects[PS_CTRL_MINI],x+316,y+7,44,30);
   PS_UISetRect(g_ps_control_rects[PS_CTRL_THEME],x+366,y+7,27,30);
   PS_UISetRect(g_ps_control_rects[PS_CTRL_CLOSE],x+399,y+7,27,30);
   PS_UISetRect(g_ps_control_rects[PS_CTRL_DIRECTION],x+20,y+54,190,34);
   PS_UISetRect(g_ps_control_rects[PS_CTRL_ORDER_MODE],x+228,y+54,190,34);

   int row=109;
   PS_UISetRect(g_ps_control_rects[PS_CTRL_ENTRY_FIELD],x+92,y+row,192,28);
   PS_UISetRect(g_ps_control_rects[PS_CTRL_ENTRY_MINUS],x+290,y+row,36,28);
   PS_UISetRect(g_ps_control_rects[PS_CTRL_ENTRY_PLUS],x+332,y+row,38,28);
   PS_UISetRect(g_ps_control_rects[PS_CTRL_ENTRY_COPY],x+376,y+row,43,28);
   row+=35;
   PS_UISetRect(g_ps_control_rects[PS_CTRL_STOP_FIELD],x+92,y+row,192,28);
   PS_UISetRect(g_ps_control_rects[PS_CTRL_STOP_MINUS],x+290,y+row,36,28);
   PS_UISetRect(g_ps_control_rects[PS_CTRL_STOP_PLUS],x+332,y+row,38,28);
   PS_UISetRect(g_ps_control_rects[PS_CTRL_STOP_COPY],x+376,y+row,43,28);
   row+=35;
   PS_UISetRect(g_ps_control_rects[PS_CTRL_TAKE_FIELD],x+92,y+row,192,28);
   PS_UISetRect(g_ps_control_rects[PS_CTRL_TAKE_MINUS],x+290,y+row,36,28);
   PS_UISetRect(g_ps_control_rects[PS_CTRL_TAKE_PLUS],x+332,y+row,38,28);
   PS_UISetRect(g_ps_control_rects[PS_CTRL_TAKE_COPY],x+376,y+row,43,28);

   PS_UISetRect(g_ps_control_rects[PS_CTRL_LINES],x+20,y+213,120,22);
   PS_UISetRect(g_ps_control_rects[PS_CTRL_ACCOUNT_MODE],x+92,y+255,121,28);
   PS_UISetRect(g_ps_control_rects[PS_CTRL_ACCOUNT_FIELD],x+219,y+255,199,28);
   PS_UISetRect(g_ps_control_rects[PS_CTRL_RISK_PERCENT_FIELD],x+92,y+291,121,28);
   PS_UISetRect(g_ps_control_rects[PS_CTRL_RISK_MONEY_FIELD],x+291,y+291,127,28);
   PS_UISetRect(g_ps_control_rects[PS_CTRL_POSITION_SIZE],x+92,y+327,281,28);
   PS_UISetRect(g_ps_control_rects[PS_CTRL_POSITION_COPY],x+379,y+327,39,28);
   PS_UISetRect(g_ps_control_rects[PS_CTRL_CONFIRM],x+10,y+375,205,36);
   PS_UISetRect(g_ps_control_rects[PS_CTRL_MOVE_SLS],x+221,y+375,207,36);
   PS_UISetRect(g_ps_control_rects[PS_CTRL_TRADE],x+10,y+419,418,40);

   for(int i=0;i<PS_CTRL_COUNT;i++)
      g_ps_control_visible[i]=(g_ps_control_rects[i].w>0 && g_ps_control_rects[i].h>0);
  }

PSFieldId PS_UIFieldForControl(const PSControlId control)
  {
   switch(control)
     {
      case PS_CTRL_ENTRY_FIELD:          return(PS_FIELD_ENTRY);
      case PS_CTRL_STOP_FIELD:           return(PS_FIELD_STOP);
      case PS_CTRL_TAKE_FIELD:           return(PS_FIELD_TAKE);
      case PS_CTRL_COMMISSION_FIELD:     return(PS_FIELD_COMMISSION);
      case PS_CTRL_ACCOUNT_FIELD:        return(PS_FIELD_ACCOUNT);
      case PS_CTRL_RISK_PERCENT_FIELD:   return(PS_FIELD_RISK_PERCENT);
      case PS_CTRL_RISK_MONEY_FIELD:     return(PS_FIELD_RISK_MONEY);
      default:                            return(PS_FIELD_NONE);
     }
  }

bool PS_UIControlIsEditable(const PSControlId control,const PSModel &model)
  {
   if(control==PS_CTRL_ACCOUNT_FIELD) return(model.account_mode==PS_ACCOUNT_MANUAL);
   return(PS_UIFieldForControl(control)!=PS_FIELD_NONE);
  }

PSControlId PS_UIHitControl(const int x,const int y)
  {
   for(int i=PS_CTRL_COUNT-1;i>=0;i--)
     {
      if(g_ps_control_visible[i] && PS_RectContains(g_ps_control_rects[i],x,y))
         return((PSControlId)i);
     }
   return(PS_CTRL_NONE);
  }

bool PS_UIInPanel(const PSUIState &ui,const int x,const int y)
  {
   PSRect panel;
   PS_UISetRect(panel,ui.panel_x,ui.panel_y,ui.panel_w,ui.panel_h);
   return(PS_RectContains(panel,x,y));
  }

void PS_UIApplyLineLock(const PSUIState &ui,const string suffix)
  {
   string name=PS_UIName(ui,suffix);
   if(ObjectFind(ChartID(),name)<0) return;
   ObjectSetInteger(ChartID(),name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(ChartID(),name,OBJPROP_SELECTED,false);
   ObjectSetInteger(ChartID(),name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(ChartID(),name,OBJPROP_BACK,true);
   ObjectSetInteger(ChartID(),name,OBJPROP_ZORDER,1000);
   ObjectSetString(ChartID(),name,OBJPROP_TOOLTIP,"\n");
  }

bool PS_UIEnsureLine(const PSUIState &ui,const string suffix,const color line_color,const ENUM_LINE_STYLE style)
  {
   string name=PS_UIName(ui,suffix);
   if(ObjectFind(ChartID(),name)<0)
     {
      if(!ObjectCreate(ChartID(),name,OBJ_HLINE,0,0,0.0))
        {
         PS_LogError(StringFormat("Cannot create level line %s (error %d).",name,GetLastError()));
         return(false);
        }
     }
   ObjectSetInteger(ChartID(),name,OBJPROP_COLOR,line_color);
   ObjectSetInteger(ChartID(),name,OBJPROP_STYLE,style);
   ObjectSetInteger(ChartID(),name,OBJPROP_WIDTH,1);
   PS_UIApplyLineLock(ui,suffix);
   return(true);
  }

void PS_UISetLine(const PSUIState &ui,const string suffix,const double price,const bool show,
                  const color line_color,const ENUM_LINE_STYLE style)
  {
   if(!PS_UIEnsureLine(ui,suffix,line_color,style)) return;
   string name=PS_UIName(ui,suffix);
   if(PS_IsPositiveFinite(price)) ObjectSetDouble(ChartID(),name,OBJPROP_PRICE,price);
   ObjectSetInteger(ChartID(),name,OBJPROP_TIMEFRAMES,(show ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS));
   PS_UIApplyLineLock(ui,suffix);
  }

void PS_UIHandleCanvasDestroy(const int index)
  {
   if(index<0 || index>=3) return;
   if(g_ps_handle_canvas_created[index]) g_ps_handle_canvas[index].Destroy();
   g_ps_handle_canvas_created[index]=false;
   g_ps_handle_canvas_name[index]="";
   g_ps_handle_canvas_color[index]=clrNONE;
   g_ps_handle_canvas_text[index]="";
  }

void PS_UIHandleCanvasesDestroy()
  {
   for(int i=0;i<3;i++) PS_UIHandleCanvasDestroy(i);
  }

bool PS_UIEnsureHandleCanvas(const PSUIState &ui,const PSLevelId level,
                             const string text,const color background)
  {
   int index=(int)level;
   string id=(level==PS_LEVEL_ENTRY ? "entry" : (level==PS_LEVEL_STOP ? "stop" : "take"));
   string name=PS_UIName(ui,"handle."+id+".canvas");
   if(g_ps_handle_canvas_created[index] && g_ps_handle_canvas_name[index]!=name)
      PS_UIHandleCanvasDestroy(index);

   bool repaint=false;
   if(!g_ps_handle_canvas_created[index])
     {
      if(!g_ps_handle_canvas[index].CreateBitmapLabel(ChartID(),0,name,0,0,36,26,
                                                      COLOR_FORMAT_XRGB_NOALPHA))
        {
         PS_LogError(StringFormat("Cannot create handle canvas %s (error %d).",name,GetLastError()));
         return(false);
        }
      g_ps_handle_canvas_created[index]=true;
      g_ps_handle_canvas_name[index]=name;
      ObjectSetInteger(ChartID(),name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(ChartID(),name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(ChartID(),name,OBJPROP_SELECTED,false);
      ObjectSetInteger(ChartID(),name,OBJPROP_HIDDEN,true);
      ObjectSetInteger(ChartID(),name,OBJPROP_BACK,false);
      ObjectSetInteger(ChartID(),name,OBJPROP_ZORDER,50000);
      ObjectSetString(ChartID(),name,OBJPROP_TOOLTIP,"\n");
      repaint=true;
     }

   if(g_ps_handle_canvas_color[index]!=background || g_ps_handle_canvas_text[index]!=text)
      repaint=true;
   if(repaint)
     {
      g_ps_handle_canvas[index].Erase(COLOR2RGB(background));
      g_ps_handle_canvas[index].Rectangle(0,0,35,25,COLOR2RGB(C'10,12,16'));
      g_ps_handle_canvas[index].FontSet("Segoe UI Semibold",-100);
      g_ps_handle_canvas[index].TextOut(18,13,text,COLOR2RGB(PS_CLR_TEXT),TA_CENTER|TA_VCENTER);
      g_ps_handle_canvas[index].Update(false);
      g_ps_handle_canvas_color[index]=background;
      g_ps_handle_canvas_text[index]=text;
     }
   return(true);
  }

void PS_UISetHandle(const PSUIState &ui,const PSLevelId level,const int x,const int y,
                     const string text,const color background,const bool show)
  {
   PSRect rect;
   PS_UISetRect(rect,x,y,36,26);
   int index=(int)level;
   g_ps_handle_rects[index]=rect;
   g_ps_handle_visible[index]=show;
   string id=(level==PS_LEVEL_ENTRY ? "entry" : (level==PS_LEVEL_STOP ? "stop" : "take"));
   PS_UIShow(ui,"handle."+id+".box",false);
   PS_UIShow(ui,"handle."+id+".text",false);
   if(!show && !g_ps_handle_canvas_created[index]) return;
   if(!PS_UIEnsureHandleCanvas(ui,level,text,background)) return;

   string name=g_ps_handle_canvas_name[index];
   if(show)
     {
      if((int)ObjectGetInteger(ChartID(),name,OBJPROP_XDISTANCE)!=x)
         ObjectSetInteger(ChartID(),name,OBJPROP_XDISTANCE,x);
      if((int)ObjectGetInteger(ChartID(),name,OBJPROP_YDISTANCE)!=y)
         ObjectSetInteger(ChartID(),name,OBJPROP_YDISTANCE,y);
     }
   ObjectSetInteger(ChartID(),name,OBJPROP_TIMEFRAMES,(show ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS));
  }

int PS_UIHandleX(const PSUIState &ui,const int y)
  {
   int x=ui.chart_w-54;
   PSRect candidate;
   PS_UISetRect(candidate,x,y-13,36,26);
   PSRect panel;
   PS_UISetRect(panel,ui.panel_x,ui.panel_y,ui.panel_w,ui.panel_h);
   bool intersects=!(candidate.x+candidate.w<=panel.x || candidate.x>=panel.x+panel.w ||
                     candidate.y+candidate.h<=panel.y || candidate.y>=panel.y+panel.h);
   if(!intersects) return(x);
   if(panel.x>=42) return(panel.x-40);
   if(panel.x+panel.w+42<ui.chart_w) return(panel.x+panel.w+6);
   return(4);
  }

void PS_UIUpdateLines(PSUIState &ui,const PSModel &model,const PSMarketSnapshot &market)
  {
   double entry=(model.order_mode==PS_ORDER_INSTANT && market.tick_valid)
                ? PS_NormalizePrice(model.direction==PS_DIRECTION_LONG ? market.tick.ask : market.tick.bid,market)
                : model.entry;
   double stop=model.stop_loss;
   double take=model.take_profit;
   bool show_entry=model.lines_visible && PS_IsPositiveFinite(entry);
   bool show_stop=model.lines_visible && PS_IsPositiveFinite(stop);
   bool show_take=model.lines_visible && PS_IsPositiveFinite(take);

   color entry_color=PS_CLR_ACCENT;
   color stop_color=PS_CLR_SHORT;
   color take_color=PS_CLR_LONG;
   PS_UISetLine(ui,"line.entry",entry,show_entry,entry_color,STYLE_SOLID);
   PS_UISetLine(ui,"line.stop",stop,show_stop,stop_color,STYLE_DASH);
   PS_UISetLine(ui,"line.take",take,show_take,take_color,STYLE_DASH);

   double price_min=ChartGetDouble(ChartID(),CHART_PRICE_MIN,0);
   double price_max=ChartGetDouble(ChartID(),CHART_PRICE_MAX,0);
   datetime time=iTime(_Symbol,_Period,0);
   if(time<=0) time=TimeCurrent();

   double prices[3];
   prices[0]=entry;
   prices[1]=stop;
   prices[2]=take;
   bool requested[3];
   requested[0]=show_entry;
   requested[1]=show_stop;
   requested[2]=show_take;
   string letters[3];
   letters[0]="E";
   letters[1]="S";
   letters[2]="T";
   color colors[3];
   colors[0]=entry_color;
   colors[1]=stop_color;
   colors[2]=take_color;

   for(int i=0;i<3;i++)
     {
      bool viewport=requested[i] && prices[i]>=price_min && prices[i]<=price_max;
      int px=0;
      int py=0;
      bool converted=false;
      if(viewport) converted=ChartTimePriceToXY(ChartID(),0,time,prices[i],px,py);
      bool visible=viewport && converted && py>=0 && py<ui.chart_h;
      int hx=(visible ? PS_UIHandleX(ui,py) : 0);
      PS_UISetHandle(ui,(PSLevelId)i,hx,(visible ? py-13 : 0),letters[i],colors[i],visible);
     }
   ui.line_dirty=false;
  }

PSLevelId PS_UIHitHandle(const int x,const int y,bool &hit)
  {
   hit=false;
   for(int i=0;i<3;i++)
     {
      if(g_ps_handle_visible[i] && PS_RectContains(g_ps_handle_rects[i],x,y))
        {
         hit=true;
         return((PSLevelId)i);
        }
     }
   return(PS_LEVEL_ENTRY);
  }

bool PS_UIHasOwnedPrefix(const PSUIState &ui)
  {
   return(ui.prefix!="" && StringFind(ui.prefix,PS_OBJECT_NAMESPACE+".")==0);
  }

uint PS_PremiumColor(const color value)
  {
   return(COLOR2RGB(value));
  }

void PS_UIPanelCanvasDestroy()
  {
   if(g_ps_panel_canvas_created) g_ps_panel_canvas.Destroy();
   g_ps_panel_canvas_created=false;
   g_ps_panel_canvas_name="";
  }

bool PS_UIPanelCanvasEnsure(const PSUIState &ui)
  {
   string name=PS_UIName(ui,"ui.premium.canvas");
   if(g_ps_panel_canvas_created && g_ps_panel_canvas_name!=name) PS_UIPanelCanvasDestroy();
   if(!g_ps_panel_canvas_created)
     {
      if(!g_ps_panel_canvas.CreateBitmapLabel(ChartID(),0,name,ui.panel_x,ui.panel_y,
                                              ui.panel_w,ui.panel_h,COLOR_FORMAT_XRGB_NOALPHA))
        {
         PS_LogError(StringFormat("Cannot create premium panel canvas %s (error %d).",name,GetLastError()));
         return(false);
        }
      g_ps_panel_canvas_created=true;
      g_ps_panel_canvas_name=name;
      ObjectSetInteger(ChartID(),name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(ChartID(),name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(ChartID(),name,OBJPROP_SELECTED,false);
      ObjectSetInteger(ChartID(),name,OBJPROP_HIDDEN,true);
      ObjectSetInteger(ChartID(),name,OBJPROP_BACK,false);
      ObjectSetInteger(ChartID(),name,OBJPROP_ZORDER,40000);
      ObjectSetString(ChartID(),name,OBJPROP_TOOLTIP,"\n");
     }
   else if(g_ps_panel_canvas.Width()!=ui.panel_w || g_ps_panel_canvas.Height()!=ui.panel_h)
     {
      if(!g_ps_panel_canvas.Resize(ui.panel_w,ui.panel_h))
        {
         PS_LogError("Cannot resize the premium panel canvas.");
         return(false);
        }
     }
   ObjectSetInteger(ChartID(),name,OBJPROP_XDISTANCE,ui.panel_x);
   ObjectSetInteger(ChartID(),name,OBJPROP_YDISTANCE,ui.panel_y);
   ObjectSetInteger(ChartID(),name,OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);
   return(true);
  }

void PS_PremiumRoundRect(const int x,const int y,const int w,const int h,const int radius,
                         const color fill,const color border)
  {
   int r=PS_ClampInt(radius,1,MathMin(w,h)/2);
   uint outer=PS_PremiumColor(border);
   uint inner=PS_PremiumColor(fill);
   g_ps_panel_canvas.FillRectangle(x+r,y,x+w-r-1,y+h-1,outer);
   g_ps_panel_canvas.FillRectangle(x,y+r,x+w-1,y+h-r-1,outer);
   g_ps_panel_canvas.FillCircle(x+r,y+r,r,outer);
   g_ps_panel_canvas.FillCircle(x+w-r-1,y+r,r,outer);
   g_ps_panel_canvas.FillCircle(x+r,y+h-r-1,r,outer);
   g_ps_panel_canvas.FillCircle(x+w-r-1,y+h-r-1,r,outer);
   g_ps_panel_canvas.CircleAA(x+r,y+r,(double)r,outer);
   g_ps_panel_canvas.CircleAA(x+w-r-1,y+r,(double)r,outer);
   g_ps_panel_canvas.CircleAA(x+r,y+h-r-1,(double)r,outer);
   g_ps_panel_canvas.CircleAA(x+w-r-1,y+h-r-1,(double)r,outer);
   if(w<=2 || h<=2) return;
   int ir=MathMax(1,r-1);
   int ix=x+1;
   int iy=y+1;
   int iw=w-2;
   int ih=h-2;
   g_ps_panel_canvas.FillRectangle(ix+ir,iy,ix+iw-ir-1,iy+ih-1,inner);
   g_ps_panel_canvas.FillRectangle(ix,iy+ir,ix+iw-1,iy+ih-ir-1,inner);
   g_ps_panel_canvas.FillCircle(ix+ir,iy+ir,ir,inner);
   g_ps_panel_canvas.FillCircle(ix+iw-ir-1,iy+ir,ir,inner);
   g_ps_panel_canvas.FillCircle(ix+ir,iy+ih-ir-1,ir,inner);
   g_ps_panel_canvas.FillCircle(ix+iw-ir-1,iy+ih-ir-1,ir,inner);
   g_ps_panel_canvas.CircleAA(ix+ir,iy+ir,(double)ir,inner);
   g_ps_panel_canvas.CircleAA(ix+iw-ir-1,iy+ir,(double)ir,inner);
   g_ps_panel_canvas.CircleAA(ix+ir,iy+ih-ir-1,(double)ir,inner);
   g_ps_panel_canvas.CircleAA(ix+iw-ir-1,iy+ih-ir-1,(double)ir,inner);
  }

int PS_PremiumOpticalCenterOffset(const int size)
  {
   return(size>=13 ? 2 : 1);
  }

void PS_PremiumText(const int x,const int y,const string text,const int size,const color clr,
                     const uint alignment=TA_LEFT|TA_TOP,const string font="Segoe UI")
  {
   int draw_y=y;
   if((alignment & TA_VCENTER)==TA_VCENTER) draw_y-=PS_PremiumOpticalCenterOffset(size);
   g_ps_panel_canvas.FontSet(font,-10*MathMax(1,size));
   g_ps_panel_canvas.TextOut(x,draw_y,text,PS_PremiumColor(clr),alignment);
  }

void PS_PremiumButton(const PSRect &absolute,const string text,const bool active=false,
                      const color accent=C'46,190,101',const int font_size=16,
                      const bool centered=true)
  {
   int x=absolute.x;
   int y=absolute.y;
   color fill=(active ? accent : PS_ThemeControl());
   color border=(active ? accent : PS_ThemeBorder());
   PS_PremiumRoundRect(x,y,absolute.w,absolute.h,4,fill,border);
   int rendered_size=MathMax(8,(font_size+1)/2);
   PS_PremiumText((centered ? x+absolute.w/2 : x+9),y+absolute.h/2,text,rendered_size,
                   (active ? PS_ThemeOnAccent() : PS_ThemeMuted()),
                   (centered ? TA_CENTER|TA_VCENTER : TA_LEFT|TA_VCENTER),
                   "Segoe UI Semibold");
  }

void PS_PremiumInfoIcon(const int x,const int y)
  {
   color ring=(g_ps_light_theme ? C'105,121,141' : C'105,123,146');
   color text=(g_ps_light_theme ? C'72,89,110' : C'125,143,166');
   g_ps_panel_canvas.Circle(x,y,5,PS_PremiumColor(ring));
   PS_PremiumText(x,y,"i",7,text,TA_CENTER|TA_VCENTER,"Segoe UI Semibold");
  }

void PS_PremiumEyeIcon(const int x,const int y,const color clr)
  {
   g_ps_panel_canvas.Circle(x,y,4,PS_PremiumColor(clr));
   g_ps_panel_canvas.FillCircle(x,y,2,PS_PremiumColor(clr));
   g_ps_panel_canvas.Line(x-6,y,x-4,y-3,PS_PremiumColor(clr));
   g_ps_panel_canvas.Line(x-6,y,x-4,y+3,PS_PremiumColor(clr));
   g_ps_panel_canvas.Line(x+6,y,x+4,y-3,PS_PremiumColor(clr));
   g_ps_panel_canvas.Line(x+6,y,x+4,y+3,PS_PremiumColor(clr));
  }

void PS_PremiumTargetIcon(const int x,const int y,const color clr)
  {
   uint c=PS_PremiumColor(clr);
   g_ps_panel_canvas.Circle(x,y,4,c);
   g_ps_panel_canvas.Circle(x,y,2,c);
   g_ps_panel_canvas.Line(x-7,y,x-4,y,c);
   g_ps_panel_canvas.Line(x+4,y,x+7,y,c);
   g_ps_panel_canvas.Line(x,y-7,x,y-4,c);
   g_ps_panel_canvas.Line(x,y+4,x,y+7,c);
  }

void PS_PremiumSlidersIcon(const int x,const int y,const color clr)
  {
   uint c=PS_PremiumColor(clr);
   g_ps_panel_canvas.Line(x-8,y-5,x+8,y-5,c);
   g_ps_panel_canvas.Line(x-8,y,x+8,y,c);
   g_ps_panel_canvas.Line(x-8,y+5,x+8,y+5,c);
   g_ps_panel_canvas.FillCircle(x-2,y-5,2,c);
   g_ps_panel_canvas.FillCircle(x+4,y,2,c);
   g_ps_panel_canvas.FillCircle(x-4,y+5,2,c);
  }

void PS_PremiumBoltIcon(const int x,const int y,const color clr)
  {
   uint c=PS_PremiumColor(clr);
   g_ps_panel_canvas.Line(x+1,y-8,x-5,y+1,c);
   g_ps_panel_canvas.Line(x-5,y+1,x,y+1,c);
   g_ps_panel_canvas.Line(x,y,x-1,y+8,c);
   g_ps_panel_canvas.Line(x-1,y+8,x+6,y-2,c);
   g_ps_panel_canvas.Line(x+6,y-2,x+1,y-2,c);
   g_ps_panel_canvas.Line(x+1,y-2,x+1,y-8,c);
  }

void PS_PremiumDotsIcon(const int x,const int y,const color clr)
  {
   uint c=PS_PremiumColor(clr);
   g_ps_panel_canvas.FillCircle(x-6,y,1,c);
   g_ps_panel_canvas.FillCircle(x,y,1,c);
   g_ps_panel_canvas.FillCircle(x+6,y,1,c);
  }

void PS_PremiumCloseIcon(const int x,const int y,const color clr)
  {
   uint c=PS_PremiumColor(clr);
   g_ps_panel_canvas.Line(x-5,y-5,x+5,y+5,c);
   g_ps_panel_canvas.Line(x+5,y-5,x-5,y+5,c);
  }

void PS_PremiumThemeIcon(const int x,const int y)
  {
   uint c=PS_PremiumColor(PS_ThemeMuted());
   if(g_ps_light_theme)
     {
      g_ps_panel_canvas.Circle(x,y,4,c);
      g_ps_panel_canvas.Line(x,y-8,x,y-6,c);
      g_ps_panel_canvas.Line(x,y+6,x,y+8,c);
      g_ps_panel_canvas.Line(x-8,y,x-6,y,c);
      g_ps_panel_canvas.Line(x+6,y,x+8,y,c);
      g_ps_panel_canvas.Line(x-6,y-6,x-4,y-4,c);
      g_ps_panel_canvas.Line(x+4,y+4,x+6,y+6,c);
      g_ps_panel_canvas.Line(x+4,y-4,x+6,y-6,c);
      g_ps_panel_canvas.Line(x-6,y+6,x-4,y+4,c);
      return;
     }
   g_ps_panel_canvas.FillCircle(x-1,y,6,c);
   g_ps_panel_canvas.FillCircle(x+3,y-3,6,PS_PremiumColor(PS_ThemeControl()));
  }

void PS_PremiumDirectionIcon(const int x,const int y,const bool is_long,const color clr)
  {
   uint c=PS_PremiumColor(clr);
   if(is_long)
     {
      g_ps_panel_canvas.Line(x-5,y+5,x+5,y-5,c);
      g_ps_panel_canvas.Line(x+5,y-5,x-1,y-5,c);
      g_ps_panel_canvas.Line(x+5,y-5,x+5,y+1,c);
     }
   else
     {
      g_ps_panel_canvas.Line(x-5,y-5,x+5,y+5,c);
      g_ps_panel_canvas.Line(x+5,y+5,x-1,y+5,c);
      g_ps_panel_canvas.Line(x+5,y+5,x+5,y-1,c);
     }
  }

void PS_PremiumClockIcon(const int x,const int y,const color clr)
  {
   uint c=PS_PremiumColor(clr);
   g_ps_panel_canvas.Circle(x,y,6,c);
   g_ps_panel_canvas.Line(x,y-4,x,y,c);
   g_ps_panel_canvas.Line(x,y,x+3,y+2,c);
  }

void PS_PremiumChevronDown(const int x,const int y,const color clr)
  {
   uint c=PS_PremiumColor(clr);
   g_ps_panel_canvas.Line(x-3,y-2,x,y+1,c);
   g_ps_panel_canvas.Line(x,y+1,x+3,y-2,c);
  }

void PS_PremiumCartIcon(const int x,const int y,const color clr)
  {
   uint c=PS_PremiumColor(clr);
   g_ps_panel_canvas.Line(x-8,y-7,x-5,y-7,c);
   g_ps_panel_canvas.Line(x-5,y-7,x-3,y+3,c);
   g_ps_panel_canvas.Line(x-3,y+3,x+7,y+3,c);
   g_ps_panel_canvas.Line(x+7,y+3,x+9,y-4,c);
   g_ps_panel_canvas.Line(x-4,y-4,x+9,y-4,c);
   g_ps_panel_canvas.Line(x-2,y+6,x+6,y+6,c);
   g_ps_panel_canvas.Circle(x-1,y+9,1,c);
   g_ps_panel_canvas.Circle(x+6,y+9,1,c);
  }

void PS_PremiumLogo()
  {
   color outer=(g_ps_light_theme ? C'158,171,185' : C'100,113,128');
   color inner=(g_ps_light_theme ? C'235,239,244' : C'42,51,61');
   color axis=(g_ps_light_theme ? C'101,115,132' : C'137,151,168');
   g_ps_panel_canvas.Circle(20,19,12,PS_PremiumColor(outer));
   g_ps_panel_canvas.Circle(20,19,11,PS_PremiumColor(inner));
   g_ps_panel_canvas.FillRectangle(15,16,17,29,PS_PremiumColor(PS_PREMIUM_GREEN));
   g_ps_panel_canvas.FillRectangle(19,14,22,23,PS_PremiumColor(PS_PREMIUM_GREEN));
   g_ps_panel_canvas.FillRectangle(24,12,27,19,PS_PremiumColor(PS_PREMIUM_GREEN));
   g_ps_panel_canvas.Line(14,30,14,15,PS_PremiumColor(axis));
  }

void PS_PremiumSection(const int y,const int h,const string title,const color accent)
  {
   PS_PremiumRoundRect(6,y,394,h,4,PS_ThemeSection(),PS_ThemeBorder());
   g_ps_panel_canvas.Line(7,y+22,399,y+22,PS_PremiumColor(PS_ThemeDivider()));
   g_ps_panel_canvas.FillRectangle(13,y+10,24,y+12,PS_PremiumColor(accent));
   PS_PremiumText(31,y+11,title,8,PS_ThemeSectionTitle(),TA_LEFT|TA_VCENTER,"Segoe UI Semibold");
  }

bool PS_UICreate(PSUIState &ui)
  {
   if(!PS_UIHasOwnedPrefix(ui))
     {
      PS_LogError("Refusing to create or delete chart objects with an invalid ownership prefix.");
      return(false);
     }
   ObjectsDeleteAll(ChartID(),ui.prefix);
   bool ok=true;
   // Price lines are created first and kept in the chart background so they
   // can never paint over the fixed interface, regardless of object z-order.
   ok=PS_UIEnsureLine(ui,"line.entry",PS_CLR_ACCENT,STYLE_SOLID) && ok;
   ok=PS_UIEnsureLine(ui,"line.stop",PS_CLR_SHORT,STYLE_DASH) && ok;
   ok=PS_UIEnsureLine(ui,"line.take",PS_CLR_LONG,STYLE_DASH) && ok;
   PS_UILayout(ui,PS_VIEW_FULL);
   ok=PS_UIPanelCanvasEnsure(ui) && ok;
   ui.created=ok;
   ui.dirty=true;
   ui.line_dirty=true;
   return(ok);
  }

string PS_UIFieldDisplay(const PSFieldId field,const PSModel &model,const PSCalcResult &calc,
                         const PSMarketSnapshot &market,const PSEditorState &editor)
  {
   if(editor.active && editor.field==field) return(editor.raw_text);
   switch(field)
     {
      case PS_FIELD_ENTRY:
         if(model.order_mode==PS_ORDER_INSTANT && market.tick_valid)
            return(PS_PriceText(model.direction==PS_DIRECTION_LONG ? market.tick.ask : market.tick.bid,market));
         return(PS_PriceText(model.entry,market));
      case PS_FIELD_STOP: return(PS_PriceText(model.stop_loss,market));
      case PS_FIELD_TAKE: return(PS_IsPositiveFinite(model.take_profit) ? PS_PriceText(model.take_profit,market) : "0");
      case PS_FIELD_COMMISSION: return(DoubleToString(model.commission_per_lot,market.currency_digits));
      case PS_FIELD_ACCOUNT:
         if(model.account_mode==PS_ACCOUNT_EQUITY) return(PS_MoneyText(market.equity,market));
         if(model.account_mode==PS_ACCOUNT_BALANCE) return(PS_MoneyText(market.balance,market));
         return(PS_MoneyText(model.manual_account_money,market));
      case PS_FIELD_RISK_PERCENT:
         return(PS_PercentText(calc.requested_percent>0.0 ? calc.requested_percent : model.requested_risk_percent));
      case PS_FIELD_RISK_MONEY:
         return(PS_MoneyText(calc.requested_money>0.0 ? calc.requested_money : model.requested_risk_money,market));
      default: return("");
     }
  }

string PS_UIGroupDecimalText(const string source)
  {
   if(source=="") return(source);
   int point=StringFind(source,".");
   string whole=(point>=0 ? StringSubstr(source,0,point) : source);
   string fraction=(point>=0 ? StringSubstr(source,point) : "");
   string sign="";
   if(StringLen(whole)>0 && StringSubstr(whole,0,1)=="-")
     {
      sign="-";
      whole=StringSubstr(whole,1);
     }
   int length=StringLen(whole);
   string grouped="";
   for(int i=0;i<length;i++)
     {
      if(i>0 && ((length-i)%3)==0) grouped+=",";
      grouped+=StringSubstr(whole,i,1);
     }
   return(sign+grouped+fraction);
  }

string PS_UIRiskMoneyDisplay(const PSModel &model,const PSCalcResult &calc,
                             const PSMarketSnapshot &market,const PSEditorState &editor)
  {
   if(editor.active && editor.field==PS_FIELD_RISK_MONEY)
      return(PS_UIFieldDisplay(PS_FIELD_RISK_MONEY,model,calc,market,editor));

   string requested=PS_UIGroupDecimalText(
      PS_MoneyText(calc.requested_money>0.0 ? calc.requested_money : model.requested_risk_money,market));
   if(!calc.valid) return(requested);

   string actual=PS_UIGroupDecimalText(PS_MoneyText(calc.actual_money,market));
   if(actual==requested) return(requested);
   return(requested+" ("+actual+")");
  }

void PS_UIRenderEditor(const PSUIState &ui,const PSEditorState &editor)
  {
   if(!editor.active)
     {
      PS_UIShow(ui,"ui.edit.selection",false);
      PS_UIShow(ui,"ui.edit.caret",false);
      return;
     }

   PSControlId control=PS_CTRL_NONE;
   switch(editor.field)
     {
      case PS_FIELD_ENTRY:        control=PS_CTRL_ENTRY_FIELD; break;
      case PS_FIELD_STOP:         control=PS_CTRL_STOP_FIELD; break;
      case PS_FIELD_TAKE:         control=PS_CTRL_TAKE_FIELD; break;
      case PS_FIELD_COMMISSION:   control=PS_CTRL_COMMISSION_FIELD; break;
      case PS_FIELD_ACCOUNT:      control=PS_CTRL_ACCOUNT_FIELD; break;
      case PS_FIELD_RISK_PERCENT: control=PS_CTRL_RISK_PERCENT_FIELD; break;
      case PS_FIELD_RISK_MONEY:   control=PS_CTRL_RISK_MONEY_FIELD; break;
      default: break;
     }
   if(control==PS_CTRL_NONE || !g_ps_control_visible[(int)control])
     {
      PS_UIShow(ui,"ui.edit.selection",false);
      PS_UIShow(ui,"ui.edit.caret",false);
      return;
     }

   PSRect field=g_ps_control_rects[(int)control];
   int char_width=7;
   // Selection is represented by the field background. A separate rectangle
   // can paint above OBJ_LABEL text on some MT5 builds and obscure the value.
   PS_UIShow(ui,"ui.edit.selection",false);
   if(editor.has_selection)
     {
      PS_UIShow(ui,"ui.edit.caret",false);
      return;
     }

   PSRect caret;
   PS_UISetRect(caret,field.x+7+editor.cursor*char_width,field.y+5,1,field.h-10);
   PS_UIBox(ui,"ui.edit.caret",caret,PS_CLR_TEXT,PS_CLR_TEXT,true,21030);
  }

void PS_UIRenderLegacyReference(PSUIState &ui,const PSModel &model,const PSCalcResult &calc,
                                const PSMarketSnapshot &market,const PSEditorState &editor,
                                const PSControlId copy_feedback_control)
  {
   ulong started=GetMicrosecondCount();
   PS_UILayout(ui,model.view_mode);
   PSRect panel;
   PS_UISetRect(panel,ui.panel_x,ui.panel_y,ui.panel_w,ui.panel_h);
   PS_UIBox(ui,"ui.panel",panel,PS_CLR_PANEL,PS_CLR_BORDER,true,20000);

   int x=ui.panel_x;
   int y=ui.panel_y;
   PS_UIStaticLabel(ui,"title",x+12,y+10,PS_PRODUCT_NAME,true,PS_CLR_TEXT,12);
   PS_UIStaticLabel(ui,"version",x+12,y+27,"v"+PS_VERSION_TEXT,model.view_mode!=PS_VIEW_MINI,PS_CLR_MUTED,8);

   color direction_color=(model.direction==PS_DIRECTION_LONG ? PS_CLR_LONG : PS_CLR_SHORT);
   string volume=PS_VolumeText(calc.volume,market);
   string trade_text;
   if(calc.valid)
     {
      if(model.order_mode==PS_ORDER_INSTANT)
         trade_text=(model.direction==PS_DIRECTION_LONG ? "BUY " : "SELL ")+volume+" MARKET";
      else
         trade_text="PLACE "+PS_Upper(calc.resolved_order_text)+" "+volume;
     }
   else trade_text="Cannot trade";

   if(model.view_mode==PS_VIEW_MINI)
     {
      PS_UIStaticLabel(ui,"mini_size",x+12,y+50,"Size",true,PS_CLR_MUTED,9);
      PS_UIControl(ui,PS_CTRL_MINI,"Full",PS_CLR_PANEL_ALT,PS_CLR_BORDER,PS_CLR_TEXT,true);
      PS_UIControl(ui,PS_CTRL_CLOSE,"×",PS_CLR_PANEL_ALT,PS_CLR_BORDER,PS_CLR_TEXT,true,11);
      PS_UIControl(ui,PS_CTRL_POSITION_SIZE,volume,PS_CLR_FIELD_RO,PS_CLR_BORDER,PS_CLR_TEXT,true);
      PS_UIControl(ui,PS_CTRL_TRADE,trade_text,(calc.valid ? direction_color : PS_CLR_DISABLED),
                   (calc.valid ? direction_color : PS_CLR_BORDER),PS_CLR_TEXT,true,10);
      for(int i=0;i<PS_CTRL_COUNT;i++)
        {
         if(g_ps_control_visible[i]) continue;
         PS_UIShow(ui,PS_UIControlSuffix((PSControlId)i,"box"),false);
         PS_UIShow(ui,PS_UIControlSuffix((PSControlId)i,"text"),false);
        }
      string full_labels[] = {"direction","order","entry","stop","take","lines","commission","account",
                              "riskp","riskm","actualp","actualm","size","status","version"};
      for(int i=0;i<ArraySize(full_labels);i++) PS_UIShow(ui,"ui.lbl."+full_labels[i],false);
      PS_UIRenderEditor(ui,editor);
      PS_UIUpdateLines(ui,model,market);
      ChartRedraw(ChartID());
      ui.dirty=false;
      PS_PerfCheck("render",started,PS_RENDER_BUDGET_US);
      return;
     }

   PS_UIStaticLabel(ui,"mini_size",0,0,"",false);
   PS_UIStaticLabel(ui,"direction",x+12,y+57,"Direction",true);
   PS_UIStaticLabel(ui,"order",x+230,y+57,"Type",true);
   PS_UIStaticLabel(ui,"entry",x+12,y+95,"Entry",true);
   PS_UIStaticLabel(ui,"stop",x+12,y+131,"SL",true);
   PS_UIStaticLabel(ui,"take",x+12,y+167,"TP",true);
   PS_UIStaticLabel(ui,"lines",x+12,y+203,"Chart levels",true);
   PS_UIStaticLabel(ui,"commission",0,0,"",false);
   PS_UIStaticLabel(ui,"account",x+12,y+241,"Account money",true);
   PS_UIStaticLabel(ui,"riskp",x+12,y+277,"Risk, %",true);
   PS_UIStaticLabel(ui,"riskm",x+12,y+313,"Risk, "+market.account_currency,true);
   PS_UIStaticLabel(ui,"actualp",0,0,"",false);
   PS_UIStaticLabel(ui,"actualm",0,0,"",false);
   PS_UIStaticLabel(ui,"size",x+12,y+349,"Size",true);

   PS_UIControl(ui,PS_CTRL_MANUAL,"Manual",PS_CLR_PANEL_ALT,PS_CLR_BORDER,PS_CLR_TEXT,true);
   PS_UIControl(ui,PS_CTRL_MINI,"Mini",PS_CLR_PANEL_ALT,PS_CLR_BORDER,PS_CLR_TEXT,true);
   PS_UIControl(ui,PS_CTRL_CLOSE,"×",PS_CLR_PANEL_ALT,PS_CLR_BORDER,PS_CLR_TEXT,true,11);
   PS_UIControl(ui,PS_CTRL_DIRECTION,PS_DirectionText(model.direction),direction_color,direction_color,PS_CLR_TEXT,true);
   PS_UIControl(ui,PS_CTRL_ORDER_MODE,PS_OrderModeText(model.order_mode),PS_CLR_PANEL_ALT,PS_CLR_BORDER_HI,PS_CLR_TEXT,true);

   color editable_border=PS_CLR_BORDER_HI;
   bool entry_focus=(editor.active && editor.field==PS_FIELD_ENTRY);
   bool stop_focus=(editor.active && editor.field==PS_FIELD_STOP);
   bool take_focus=(editor.active && editor.field==PS_FIELD_TAKE);
   bool account_focus=(editor.active && editor.field==PS_FIELD_ACCOUNT);
   bool risk_percent_focus=(editor.active && editor.field==PS_FIELD_RISK_PERCENT);
   bool risk_money_focus=(editor.active && editor.field==PS_FIELD_RISK_MONEY);
   bool entry_selected=(entry_focus && editor.has_selection);
   bool stop_selected=(stop_focus && editor.has_selection);
   bool take_selected=(take_focus && editor.has_selection);
   bool account_selected=(account_focus && editor.has_selection);
   bool risk_percent_selected=(risk_percent_focus && editor.has_selection);
   bool risk_money_selected=(risk_money_focus && editor.has_selection);
   bool entry_copied=(copy_feedback_control==PS_CTRL_ENTRY_COPY);
   bool stop_copied=(copy_feedback_control==PS_CTRL_STOP_COPY);
   bool take_copied=(copy_feedback_control==PS_CTRL_TAKE_COPY);
   bool position_copied=(copy_feedback_control==PS_CTRL_POSITION_COPY);
   color instant_entry_border=(model.order_mode==PS_ORDER_INSTANT ? PS_CLR_WARNING : editable_border);
   PS_UIControl(ui,PS_CTRL_ENTRY_FIELD,PS_UIFieldDisplay(PS_FIELD_ENTRY,model,calc,market,editor),
                (entry_selected ? PS_CLR_SELECTION : (entry_focus ? PS_CLR_FIELD_FOCUS : PS_CLR_FIELD)),
                (entry_focus ? PS_CLR_FOCUS : instant_entry_border),
                PS_CLR_TEXT,true,9,"Consolas");
   PS_UIControl(ui,PS_CTRL_ENTRY_MINUS,"−",PS_CLR_PANEL_ALT,PS_CLR_BORDER,PS_CLR_TEXT,true,11);
   PS_UIControl(ui,PS_CTRL_ENTRY_PLUS,"+",PS_CLR_PANEL_ALT,PS_CLR_BORDER,PS_CLR_TEXT,true,11);
   PS_UIControl(ui,PS_CTRL_ENTRY_COPY,(entry_copied ? "✓" : "C"),
                (entry_copied ? PS_CLR_LONG : PS_CLR_PANEL_ALT),(entry_copied ? PS_CLR_LONG : PS_CLR_BORDER),PS_CLR_TEXT,true);
   PS_UIControl(ui,PS_CTRL_STOP_FIELD,PS_UIFieldDisplay(PS_FIELD_STOP,model,calc,market,editor),
                (stop_selected ? PS_CLR_SELECTION : (stop_focus ? PS_CLR_FIELD_FOCUS : PS_CLR_FIELD)),
                (stop_focus ? PS_CLR_FOCUS : editable_border),
                PS_CLR_TEXT,true,9,"Consolas");
   PS_UIControl(ui,PS_CTRL_STOP_MINUS,"−",PS_CLR_PANEL_ALT,PS_CLR_BORDER,PS_CLR_TEXT,true,11);
   PS_UIControl(ui,PS_CTRL_STOP_PLUS,"+",PS_CLR_PANEL_ALT,PS_CLR_BORDER,PS_CLR_TEXT,true,11);
   PS_UIControl(ui,PS_CTRL_STOP_COPY,(stop_copied ? "✓" : "C"),
                (stop_copied ? PS_CLR_LONG : PS_CLR_PANEL_ALT),(stop_copied ? PS_CLR_LONG : PS_CLR_BORDER),PS_CLR_TEXT,true);
   PS_UIControl(ui,PS_CTRL_TAKE_FIELD,PS_UIFieldDisplay(PS_FIELD_TAKE,model,calc,market,editor),
                (take_selected ? PS_CLR_SELECTION : (take_focus ? PS_CLR_FIELD_FOCUS : PS_CLR_FIELD)),
                (take_focus ? PS_CLR_FOCUS : editable_border),
                PS_CLR_TEXT,true,9,"Consolas");
   PS_UIControl(ui,PS_CTRL_TAKE_MINUS,"−",PS_CLR_PANEL_ALT,PS_CLR_BORDER,PS_CLR_TEXT,true,11);
   PS_UIControl(ui,PS_CTRL_TAKE_PLUS,"+",PS_CLR_PANEL_ALT,PS_CLR_BORDER,PS_CLR_TEXT,true,11);
   PS_UIControl(ui,PS_CTRL_TAKE_COPY,(take_copied ? "✓" : "C"),
                (take_copied ? PS_CLR_LONG : PS_CLR_PANEL_ALT),(take_copied ? PS_CLR_LONG : PS_CLR_BORDER),PS_CLR_TEXT,true);

   PS_UIControl(ui,PS_CTRL_LINES,(model.lines_visible ? "Hide lines" : "Show lines"),PS_CLR_PANEL_ALT,PS_CLR_BORDER,PS_CLR_TEXT,true);
   PS_UIControl(ui,PS_CTRL_ACCOUNT_MODE,PS_AccountModeText(model.account_mode),PS_CLR_PANEL_ALT,PS_CLR_BORDER,PS_CLR_TEXT,true);
   bool manual=(model.account_mode==PS_ACCOUNT_MANUAL);
   PS_UIControl(ui,PS_CTRL_ACCOUNT_FIELD,PS_UIFieldDisplay(PS_FIELD_ACCOUNT,model,calc,market,editor),
                (account_selected ? PS_CLR_SELECTION : (account_focus ? PS_CLR_FIELD_FOCUS : (manual ? PS_CLR_FIELD : PS_CLR_FIELD_RO))),
                (account_focus ? PS_CLR_FOCUS : (manual ? editable_border : PS_CLR_BORDER)),
                (manual ? PS_CLR_TEXT : PS_CLR_MUTED),true,9,"Consolas");
   PS_UIControl(ui,PS_CTRL_RISK_PERCENT_FIELD,PS_UIFieldDisplay(PS_FIELD_RISK_PERCENT,model,calc,market,editor),
                (risk_percent_selected ? PS_CLR_SELECTION : (risk_percent_focus ? PS_CLR_FIELD_FOCUS : PS_CLR_FIELD)),
                (risk_percent_focus ? PS_CLR_FOCUS : (model.risk_authority==PS_RISK_PERCENT ? PS_CLR_ACCENT : editable_border)),
                PS_CLR_TEXT,true,9,"Consolas");
   PS_UIControl(ui,PS_CTRL_RISK_MONEY_FIELD,PS_UIRiskMoneyDisplay(model,calc,market,editor),
                (risk_money_selected ? PS_CLR_SELECTION : (risk_money_focus ? PS_CLR_FIELD_FOCUS : PS_CLR_FIELD)),
                (risk_money_focus ? PS_CLR_FOCUS : (model.risk_authority==PS_RISK_MONEY ? PS_CLR_ACCENT : editable_border)),
                PS_CLR_TEXT,true,9,"Consolas");
   PS_UIControl(ui,PS_CTRL_POSITION_SIZE,volume,PS_CLR_FIELD_RO,PS_CLR_BORDER,PS_CLR_TEXT,true);
   PS_UIControl(ui,PS_CTRL_POSITION_COPY,(position_copied ? "✓" : "C"),
                (position_copied ? PS_CLR_LONG : PS_CLR_PANEL_ALT),(position_copied ? PS_CLR_LONG : PS_CLR_BORDER),PS_CLR_TEXT,true);
   PS_UIControl(ui,PS_CTRL_CONFIRM,(model.ask_confirmation ? "Confirmation: On" : "Confirmation: Off"),
                (model.ask_confirmation ? PS_CLR_ACCENT : PS_CLR_PANEL_ALT),PS_CLR_BORDER,PS_CLR_TEXT,true);
   PS_UIControl(ui,PS_CTRL_MOVE_SLS,"Move SLs to line",PS_CLR_PANEL_ALT,PS_CLR_BORDER,PS_CLR_TEXT,true);
   PS_UIControl(ui,PS_CTRL_TRADE,trade_text,(calc.valid ? direction_color : PS_CLR_DISABLED),
                (calc.valid ? direction_color : PS_CLR_BORDER),PS_CLR_TEXT,true,11);

   string status=model.status;
   bool status_error=model.status_is_error;
   if(status=="" || status=="Ready.")
     {
      if(!calc.valid)
        {
         status=calc.error;
         status_error=true;
        }
      else if(calc.notice!="")
        {
         status=calc.notice;
         status_error=false;
        }
      else
        {
         status="Ready. "+calc.resolved_order_text+" at "+PS_PriceText(calc.effective_entry,market)+".";
         status_error=false;
        }
     }
   PS_UIStaticLabel(ui,"status",x+12,y+428,PS_TruncateStatus(status),true,(status_error ? PS_CLR_ERROR : PS_CLR_MUTED),9);

   for(int i=0;i<PS_CTRL_COUNT;i++)
     {
      if(g_ps_control_visible[i]) continue;
      PS_UIShow(ui,PS_UIControlSuffix((PSControlId)i,"box"),false);
      PS_UIShow(ui,PS_UIControlSuffix((PSControlId)i,"text"),false);
     }
   PS_UIRenderEditor(ui,editor);
   PS_UIUpdateLines(ui,model,market);
   ChartRedraw(ChartID());
   ui.dirty=false;
   PS_PerfCheck("render",started,PS_RENDER_BUDGET_US);
  }

void PS_PremiumControlRect(const PSUIState &ui,const PSControlId control,PSRect &rect)
  {
   rect=g_ps_control_rects[(int)control];
   rect.x-=ui.panel_x;
   rect.y-=ui.panel_y;
  }

int PS_UIEditorCursorIndex(const PSUIState &ui,const PSControlId control,
                           const string text,const int chart_x)
  {
   if(control<0 || control>=PS_CTRL_COUNT) return(0);
   PSRect rect=g_ps_control_rects[(int)control];
   int padding=(ui.panel_w==390 ? 10 : (ui.panel_w==372 ? 12 : 13));
   int local_x=chart_x-rect.x-padding;
   if(local_x<=0) return(0);

   g_ps_panel_canvas.FontSet("Segoe UI Semibold",-110);
   int length=StringLen(text);
   int previous_width=0;
   for(int index=0;index<length;index++)
     {
      int next_width=g_ps_panel_canvas.TextWidth(StringSubstr(text,0,index+1));
      if(local_x<(previous_width+next_width)/2) return(index);
      previous_width=next_width;
     }
   return(length);
  }

void PS_PremiumControlButton(const PSUIState &ui,const PSControlId control,const string text,
                             const bool active=false,const color accent=C'46,190,101',
                             const int font_size=16)
  {
   PSRect rect;
   PS_PremiumControlRect(ui,control,rect);
   PS_PremiumButton(rect,text,active,accent,font_size,true);
  }

void PS_PremiumField(const PSUIState &ui,const PSControlId control,const string text,
                     const PSEditorState &editor,const PSFieldId field,const bool read_only=false,
                     const bool authority=false)
  {
   PSRect rect;
   PS_PremiumControlRect(ui,control,rect);
   bool focused=(editor.active && editor.field==field);
   bool selected=(focused && editor.has_selection);
   color fill=(focused ? PS_ThemeFieldFocus() :
                (read_only ? PS_ThemeReadOnly() : PS_ThemeField()));
   color border=(focused ? PS_PREMIUM_BLUE : (authority ? PS_PREMIUM_BLUE : PS_ThemeBorder()));
   PS_PremiumRoundRect(rect.x,rect.y,rect.w,rect.h,3,fill,border);
   if(selected)
     {
      g_ps_panel_canvas.FontSet("Segoe UI Semibold",-100);
      int selection_start=PS_EditorSelectionStart(editor);
      int selection_end=PS_EditorSelectionEnd(editor);
      int selection_x=rect.x+9+
                      g_ps_panel_canvas.TextWidth(StringSubstr(text,0,selection_start));
      int selection_right=rect.x+9+
                          g_ps_panel_canvas.TextWidth(StringSubstr(text,0,selection_end));
      if(selection_right>selection_x)
         g_ps_panel_canvas.FillRectangle(selection_x,rect.y+4,selection_right,rect.y+rect.h-4,
                                         PS_PremiumColor(PS_ThemeSelection()));
     }
   PS_PremiumText(rect.x+9,rect.y+rect.h/2,text,10,
                   (read_only ? PS_ThemeReadOnlyText() : PS_ThemeText()),
                   TA_LEFT|TA_VCENTER,"Segoe UI Semibold");
   if(focused && !editor.has_selection)
     {
      g_ps_panel_canvas.FontSet("Segoe UI Semibold",-100);
       string prefix=StringSubstr(editor.raw_text,0,editor.cursor);
       int caret_x=rect.x+9+g_ps_panel_canvas.TextWidth(prefix);
       g_ps_panel_canvas.FillRectangle(caret_x,rect.y+5,caret_x,rect.y+rect.h-5,
                                       PS_PremiumColor(PS_ThemeText()));
     }
  }

void PS_PremiumSmallControl(const PSUIState &ui,const PSControlId control,const string text,
                            const bool copied=false)
  {
   PSRect rect;
   PS_PremiumControlRect(ui,control,rect);
   PS_PremiumButton(rect,(copied ? "✓" : text),copied,
                    (copied ? PS_PREMIUM_GREEN : PS_PREMIUM_BLUE),20,true);
  }

void PS_PremiumDrawDirection(const PSUIState &ui,const PSModel &model)
  {
   PSRect rect;
   PS_PremiumControlRect(ui,PS_CTRL_DIRECTION,rect);
   const int gap=8;
   int half=(rect.w-gap)/2;
   PSRect left;
   PS_UISetRect(left,rect.x,rect.y,half,rect.h);
   PSRect right;
   PS_UISetRect(right,rect.x+half+gap,rect.y,rect.w-half-gap,rect.h);
   bool long_active=(model.direction==PS_DIRECTION_LONG);
   bool short_active=(model.direction==PS_DIRECTION_SHORT);
   PS_PremiumButton(left,"",long_active,PS_PREMIUM_GREEN,27,true);
   PS_PremiumButton(right,"",short_active,PS_CLR_SHORT,27,true);
   color long_color=(long_active ? PS_ThemeOnAccent() : PS_ThemeMuted());
   color short_color=(short_active ? PS_ThemeOnAccent() : PS_ThemeMuted());
   PS_PremiumText(left.x+left.w/2,left.y+left.h/2,"Long",11,long_color,
                  TA_CENTER|TA_VCENTER,"Segoe UI Semibold");
   PS_PremiumText(right.x+right.w/2,right.y+right.h/2,"Short",11,short_color,
                  TA_CENTER|TA_VCENTER,"Segoe UI Semibold");
  }

void PS_PremiumDrawOrderMode(const PSUIState &ui,const PSModel &model)
  {
   PSRect rect;
   PS_PremiumControlRect(ui,PS_CTRL_ORDER_MODE,rect);
   const int gap=8;
   int half=(rect.w-gap)/2;
   PSRect left;
   PS_UISetRect(left,rect.x,rect.y,half,rect.h);
   PSRect right;
   PS_UISetRect(right,rect.x+half+gap,rect.y,rect.w-half-gap,rect.h);
   bool instant_active=(model.order_mode==PS_ORDER_INSTANT);
   bool pending_active=(model.order_mode==PS_ORDER_PENDING);
   PS_PremiumButton(left,"",instant_active,PS_PREMIUM_GREEN,27,true);
   PS_PremiumButton(right,"",pending_active,PS_PREMIUM_BLUE,27,true);
   color instant_color=(instant_active ? PS_ThemeOnAccent() : PS_ThemeMuted());
   color pending_color=(pending_active ? PS_ThemeOnAccent() : PS_ThemeMuted());
   PS_PremiumText(left.x+left.w/2,left.y+left.h/2,"Instant",11,instant_color,
                  TA_CENTER|TA_VCENTER,"Segoe UI Semibold");
   PS_PremiumText(right.x+right.w/2,right.y+right.h/2,"Pending",11,pending_color,
                  TA_CENTER|TA_VCENTER,"Segoe UI Semibold");
  }

void PS_PremiumDrawSwitch(const PSUIState &ui,const bool enabled)
  {
   PSRect rect;
   PS_PremiumControlRect(ui,PS_CTRL_CONFIRM,rect);
   color track=(enabled ? C'39,107,211' : (g_ps_light_theme ? C'202,211,221' : C'45,53,65'));
   PS_PremiumRoundRect(rect.x,rect.y+3,36,16,8,track,(enabled ? PS_PREMIUM_BLUE : PS_ThemeBorder()));
   int knob_x=(enabled ? rect.x+28 : rect.x+8);
   g_ps_panel_canvas.FillCircle(knob_x,rect.y+11,6,PS_PremiumColor(PS_ThemeOnAccent()));
   PS_PremiumText(rect.x+44,rect.y+11,(enabled ? "ON" : "OFF"),8,PS_ThemeMuted(),
                   TA_LEFT|TA_VCENTER,"Segoe UI Semibold");
  }

void PS_PremiumCheckIcon(const int x,const int y,const color value)
  {
   uint c=PS_PremiumColor(value);
   g_ps_panel_canvas.Line(x-8,y,x-2,y+6,c);
   g_ps_panel_canvas.Line(x-7,y,x-2,y+5,c);
   g_ps_panel_canvas.Line(x-2,y+6,x+9,y-7,c);
   g_ps_panel_canvas.Line(x-2,y+5,x+8,y-7,c);
  }

void PS_PremiumCompactField(const PSUIState &ui,const PSControlId control,const string text,
                            const PSEditorState &editor,const PSFieldId field,
                            const bool read_only=false,const bool authority=false,
                            const int font_size=15,const int padding=17)
  {
   PSRect rect;
   PS_PremiumControlRect(ui,control,rect);
   bool focused=(editor.active && editor.field==field);
   bool selected=(focused && editor.has_selection);
   color fill=(focused ? PS_ThemeFieldFocus() :
                (read_only ? PS_ThemeReadOnly() : PS_ThemeField()));
   color border=(focused ? PS_PREMIUM_BLUE : (authority ? PS_PREMIUM_BLUE : PS_ThemeBorder()));
   PS_PremiumRoundRect(rect.x,rect.y,rect.w,rect.h,4,fill,border);
   if(selected)
     {
      g_ps_panel_canvas.FontSet("Segoe UI Semibold",-10*MathMax(1,font_size));
      int selection_start=PS_EditorSelectionStart(editor);
      int selection_end=PS_EditorSelectionEnd(editor);
      int selection_x=rect.x+padding+
                      g_ps_panel_canvas.TextWidth(StringSubstr(text,0,selection_start));
      int selection_right=rect.x+padding+
                          g_ps_panel_canvas.TextWidth(StringSubstr(text,0,selection_end));
      if(selection_right>selection_x)
         g_ps_panel_canvas.FillRectangle(selection_x,rect.y+4,selection_right,rect.y+rect.h-4,
                                         PS_PremiumColor(PS_ThemeSelection()));
     }
   PS_PremiumText(rect.x+padding,rect.y+rect.h/2,text,font_size,
                   (read_only ? PS_ThemeReadOnlyText() : PS_ThemeText()),
                   TA_LEFT|TA_VCENTER,"Segoe UI Semibold");
   if(focused && !editor.has_selection)
     {
      g_ps_panel_canvas.FontSet("Segoe UI Semibold",-10*MathMax(1,font_size));
       string prefix=StringSubstr(editor.raw_text,0,editor.cursor);
       int caret_x=rect.x+padding+g_ps_panel_canvas.TextWidth(prefix);
       g_ps_panel_canvas.FillRectangle(caret_x,rect.y+7,caret_x,rect.y+rect.h-7,
                                       PS_PremiumColor(PS_ThemeText()));
     }
  }

void PS_PremiumCompactSmallControl(const PSUIState &ui,const PSControlId control,
                                   const string text,const bool copied=false,
                                   const int font_size=36)
  {
   PSRect rect;
   PS_PremiumControlRect(ui,control,rect);
   PS_PremiumButton(rect,(copied ? "✓" : text),copied,
                    (copied ? PS_PREMIUM_GREEN : PS_PREMIUM_BLUE),font_size,true);
  }

void PS_PremiumRenderCompact(PSUIState &ui,const PSModel &model,const PSCalcResult &calc,
                             const PSMarketSnapshot &market,const PSEditorState &editor,
                             const PSControlId copy_feedback_control)
  {
   g_ps_panel_canvas.Erase(PS_PremiumColor(PS_ThemeBackground()));
   PS_PremiumRoundRect(1,1,ui.panel_w-2,ui.panel_h-2,9,PS_ThemePanel(),PS_ThemeBorder());

   PS_PremiumText(14,21,PS_PRODUCT_NAME,13,PS_ThemeText(),
                   TA_LEFT|TA_VCENTER,"Segoe UI Semibold");
   PS_PremiumText(120,21,"v"+PS_VERSION_TEXT,7,PS_ThemeVersion(),
                   TA_LEFT|TA_VCENTER,"Segoe UI Semibold");
   PS_PremiumControlButton(ui,PS_CTRL_MANUAL,"Manual",false,PS_PREMIUM_BLUE,19);
   PS_PremiumControlButton(ui,PS_CTRL_COMPACT,"Full",false,PS_PREMIUM_BLUE,18);
   PS_PremiumControlButton(ui,PS_CTRL_MINI,"Mini",false,PS_PREMIUM_BLUE,18);
   PS_PremiumControlButton(ui,PS_CTRL_THEME,"",false,PS_PREMIUM_BLUE,20);
   PSRect theme_rect;
   PS_PremiumControlRect(ui,PS_CTRL_THEME,theme_rect);
   PS_PremiumThemeIcon(theme_rect.x+theme_rect.w/2,theme_rect.y+theme_rect.h/2);
   PS_PremiumControlButton(ui,PS_CTRL_CLOSE,"",false,PS_CLR_SHORT,20);
   PSRect close_rect;
   PS_PremiumControlRect(ui,PS_CTRL_CLOSE,close_rect);
   PS_PremiumCloseIcon(close_rect.x+close_rect.w/2,close_rect.y+close_rect.h/2,PS_ThemeMuted());

   PS_PremiumRoundRect(8,43,356,42,5,PS_ThemeSection(),PS_ThemeBorder());

   PSRect direction_rect;
   PS_PremiumControlRect(ui,PS_CTRL_DIRECTION,direction_rect);
   color direction_color=(model.direction==PS_DIRECTION_LONG ? PS_PREMIUM_GREEN : PS_CLR_SHORT);
   PS_PremiumButton(direction_rect,"",true,direction_color,16,true);
   PS_PremiumText(direction_rect.x+direction_rect.w/2-5,direction_rect.y+direction_rect.h/2,
                    (model.direction==PS_DIRECTION_LONG ? "Long" : "Short"),11,PS_ThemeOnAccent(),
                   TA_CENTER|TA_VCENTER,"Segoe UI Semibold");
   PS_PremiumChevronDown(direction_rect.x+direction_rect.w-13,
                          direction_rect.y+direction_rect.h/2,PS_ThemeOnAccent());

   PSRect order_rect;
   PS_PremiumControlRect(ui,PS_CTRL_ORDER_MODE,order_rect);
   PS_PremiumButton(order_rect,"",false,PS_PREMIUM_BLUE,16,true);
   PS_PremiumText(order_rect.x+13,order_rect.y+order_rect.h/2,
                    (model.order_mode==PS_ORDER_INSTANT ? "Instant" : "Pending"),11,PS_ThemeText(),
                   TA_LEFT|TA_VCENTER,"Segoe UI Semibold");
   PS_PremiumChevronDown(order_rect.x+order_rect.w-14,order_rect.y+order_rect.h/2,PS_ThemeMuted());

   PS_PremiumRoundRect(8,91,356,126,5,PS_ThemeSection(),PS_ThemeBorder());
   PS_PremiumText(16,112,"Entry",9,PS_ThemeMuted(),TA_LEFT|TA_VCENTER);
   PS_PremiumText(16,142,"SL",9,PS_ThemeMuted(),TA_LEFT|TA_VCENTER);
   PS_PremiumText(16,172,"TP",9,PS_ThemeMuted(),TA_LEFT|TA_VCENTER);
   PS_PremiumCompactField(ui,PS_CTRL_ENTRY_FIELD,
                          PS_UIFieldDisplay(PS_FIELD_ENTRY,model,calc,market,editor),
                           editor,PS_FIELD_ENTRY,false,false,11,12);
   PS_PremiumCompactField(ui,PS_CTRL_STOP_FIELD,
                          PS_UIFieldDisplay(PS_FIELD_STOP,model,calc,market,editor),
                           editor,PS_FIELD_STOP,false,false,11,12);
   PS_PremiumCompactField(ui,PS_CTRL_TAKE_FIELD,
                          PS_UIFieldDisplay(PS_FIELD_TAKE,model,calc,market,editor),
                           editor,PS_FIELD_TAKE,false,false,11,12);
   PS_PremiumCompactSmallControl(ui,PS_CTRL_ENTRY_MINUS,"−",false,23);
   PS_PremiumCompactSmallControl(ui,PS_CTRL_ENTRY_PLUS,"+",false,23);
   PS_PremiumCompactSmallControl(ui,PS_CTRL_ENTRY_COPY,"C",copy_feedback_control==PS_CTRL_ENTRY_COPY,21);
   PS_PremiumCompactSmallControl(ui,PS_CTRL_STOP_MINUS,"−",false,23);
   PS_PremiumCompactSmallControl(ui,PS_CTRL_STOP_PLUS,"+",false,23);
   PS_PremiumCompactSmallControl(ui,PS_CTRL_STOP_COPY,"C",copy_feedback_control==PS_CTRL_STOP_COPY,21);
   PS_PremiumCompactSmallControl(ui,PS_CTRL_TAKE_MINUS,"−",false,23);
   PS_PremiumCompactSmallControl(ui,PS_CTRL_TAKE_PLUS,"+",false,23);
   PS_PremiumCompactSmallControl(ui,PS_CTRL_TAKE_COPY,"C",copy_feedback_control==PS_CTRL_TAKE_COPY,21);
   PSRect compact_lines_rect;
   PS_PremiumControlRect(ui,PS_CTRL_LINES,compact_lines_rect);
   PS_PremiumButton(compact_lines_rect,(model.lines_visible ? "Hide lines" : "Show lines"),true,
                    (model.lines_visible ? PS_CLR_WARNING : PS_PREMIUM_GREEN),17,true);

   PS_PremiumRoundRect(8,223,356,106,5,PS_ThemeSection(),PS_ThemeBorder());
   PS_PremiumText(16,244,"Account",9,PS_ThemeMuted(),TA_LEFT|TA_VCENTER);
   PS_PremiumText(16,274,"Risk, %",9,PS_ThemeMuted(),TA_LEFT|TA_VCENTER);
   PS_PremiumText(182,274,"Risk, "+market.account_currency,9,PS_ThemeMuted(),TA_LEFT|TA_VCENTER);
   PS_PremiumText(16,304,"Size",9,PS_ThemeMuted(),TA_LEFT|TA_VCENTER);

   PSRect account_mode_rect;
   PS_PremiumControlRect(ui,PS_CTRL_ACCOUNT_MODE,account_mode_rect);
   PS_PremiumButton(account_mode_rect,"",false,PS_PREMIUM_BLUE,16,true);
   PS_PremiumText(account_mode_rect.x+12,account_mode_rect.y+account_mode_rect.h/2,
                    PS_AccountModeText(model.account_mode),11,PS_ThemeText(),
                   TA_LEFT|TA_VCENTER,"Segoe UI Semibold");
   PS_PremiumChevronDown(account_mode_rect.x+account_mode_rect.w-13,
                          account_mode_rect.y+account_mode_rect.h/2,PS_ThemeMuted());
   bool manual=(model.account_mode==PS_ACCOUNT_MANUAL);
   PS_PremiumCompactField(ui,PS_CTRL_ACCOUNT_FIELD,
                          (editor.active && editor.field==PS_FIELD_ACCOUNT
                           ? PS_UIFieldDisplay(PS_FIELD_ACCOUNT,model,calc,market,editor)
                           : PS_UIGroupDecimalText(PS_UIFieldDisplay(PS_FIELD_ACCOUNT,model,calc,market,editor))),
                           editor,PS_FIELD_ACCOUNT,!manual,false,11,12);
   PS_PremiumCompactField(ui,PS_CTRL_RISK_PERCENT_FIELD,
                          PS_UIFieldDisplay(PS_FIELD_RISK_PERCENT,model,calc,market,editor),
                           editor,PS_FIELD_RISK_PERCENT,false,model.risk_authority==PS_RISK_PERCENT,11,12);
   PS_PremiumCompactField(ui,PS_CTRL_RISK_MONEY_FIELD,
                          PS_UIRiskMoneyDisplay(model,calc,market,editor),
                           editor,PS_FIELD_RISK_MONEY,false,model.risk_authority==PS_RISK_MONEY,11,12);
   PS_PremiumCompactField(ui,PS_CTRL_POSITION_SIZE,
                          PS_UIGroupDecimalText(PS_VolumeText(calc.volume,market)),
                           editor,PS_FIELD_NONE,true,false,11,12);
   PS_PremiumCompactSmallControl(ui,PS_CTRL_POSITION_COPY,"C",
                                  copy_feedback_control==PS_CTRL_POSITION_COPY,21);

   PSRect confirm_rect;
   PS_PremiumControlRect(ui,PS_CTRL_CONFIRM,confirm_rect);
   PS_PremiumButton(confirm_rect,"",model.ask_confirmation,PS_PREMIUM_BLUE,16,true);
   color confirm_color=(model.ask_confirmation ? PS_ThemeOnAccent() : PS_ThemeMuted());
   PS_PremiumCheckIcon(confirm_rect.x+22,confirm_rect.y+confirm_rect.h/2,confirm_color);
   PS_PremiumText(confirm_rect.x+confirm_rect.w/2+8,confirm_rect.y+confirm_rect.h/2,
                  (model.ask_confirmation ? "Confirmation: On" : "Confirmation: Off"),
                   11,confirm_color,TA_CENTER|TA_VCENTER,"Segoe UI Semibold");

   PS_PremiumControlButton(ui,PS_CTRL_MOVE_SLS,"Move SLs to line",false,PS_PREMIUM_BLUE,21);

   color trade_color=(model.direction==PS_DIRECTION_LONG ? PS_PREMIUM_GREEN : PS_CLR_SHORT);
   string volume=PS_VolumeText(calc.volume,market);
   string trade_text;
   if(calc.valid)
     {
      if(model.order_mode==PS_ORDER_INSTANT)
         trade_text=(model.direction==PS_DIRECTION_LONG ? "BUY " : "SELL ")+volume+" MARKET";
      else
         trade_text="PLACE "+PS_Upper(calc.resolved_order_text)+" "+volume;
     }
   else trade_text="Cannot trade";
   PSRect trade_rect;
   PS_PremiumControlRect(ui,PS_CTRL_TRADE,trade_rect);
   PS_PremiumButton(trade_rect,"",calc.valid,trade_color,18,true);
   color trade_text_color=(calc.valid ? PS_ThemeOnAccent() : PS_ThemeMuted());
   PS_PremiumText(trade_rect.x+trade_rect.w/2,trade_rect.y+trade_rect.h/2,trade_text,13,
                  trade_text_color,TA_CENTER|TA_VCENTER,"Segoe UI Semibold");
  }

void PS_PremiumRenderMini(PSUIState &ui,const PSModel &model,const PSCalcResult &calc,
                          const PSMarketSnapshot &market,const PSEditorState &editor)
  {
   color direction_color=(model.direction==PS_DIRECTION_LONG ? PS_PREMIUM_GREEN : PS_CLR_SHORT);
   string volume=PS_VolumeText(calc.volume,market);
   string trade_text=(calc.valid
                      ? (model.direction==PS_DIRECTION_LONG ? "BUY " : "SELL ")+volume+" MARKET"
                      : "Cannot trade");
   g_ps_panel_canvas.Erase(PS_PremiumColor(PS_ThemeBackground()));
   PS_PremiumRoundRect(1,1,ui.panel_w-2,ui.panel_h-2,8,PS_ThemePanel(),PS_ThemeBorder());
   PS_PremiumText(12,21,PS_PRODUCT_NAME,14,PS_ThemeText(),TA_LEFT|TA_VCENTER,"Segoe UI Semibold");
   PS_PremiumControlButton(ui,PS_CTRL_MINI,"Full",false,PS_PREMIUM_BLUE,18);
   PS_PremiumControlButton(ui,PS_CTRL_COMPACT,"Compact",false,PS_PREMIUM_BLUE,16);
   PS_PremiumControlButton(ui,PS_CTRL_THEME,"",false,PS_PREMIUM_BLUE,14);
   PSRect mini_theme_rect;
   PS_PremiumControlRect(ui,PS_CTRL_THEME,mini_theme_rect);
   PS_PremiumThemeIcon(mini_theme_rect.x+mini_theme_rect.w/2,mini_theme_rect.y+mini_theme_rect.h/2);
   PS_PremiumControlButton(ui,PS_CTRL_CLOSE,"",false,PS_CLR_SHORT,18);
   PSRect mini_close_rect;
   PS_PremiumControlRect(ui,PS_CTRL_CLOSE,mini_close_rect);
   PS_PremiumCloseIcon(mini_close_rect.x+mini_close_rect.w/2,mini_close_rect.y+mini_close_rect.h/2,
                       PS_ThemeMuted());
   PS_PremiumText(12,66,"Risk, %",9,PS_ThemeMuted(),TA_LEFT|TA_VCENTER);
   PS_PremiumCompactField(ui,PS_CTRL_RISK_PERCENT_FIELD,
                          PS_UIFieldDisplay(PS_FIELD_RISK_PERCENT,model,calc,market,editor),
                          editor,PS_FIELD_RISK_PERCENT,false,
                          model.risk_authority==PS_RISK_PERCENT,11,10);
   PS_PremiumControlButton(ui,PS_CTRL_TRADE,trade_text,calc.valid,direction_color,18);
  }

void PS_UIPremiumRender(PSUIState &ui,const PSModel &model,const PSCalcResult &calc,
                        const PSMarketSnapshot &market,const PSEditorState &editor,
                        const PSControlId copy_feedback_control)
  {
   PS_UISelectTheme(model.theme_mode);
   if(!PS_UIPanelCanvasEnsure(ui)) return;
   if(model.view_mode==PS_VIEW_MINI)
     {
      PS_PremiumRenderMini(ui,model,calc,market,editor);
      g_ps_panel_canvas.Update(false);
      return;
     }
   if(model.view_mode==PS_VIEW_COMPACT)
     {
      PS_PremiumRenderCompact(ui,model,calc,market,editor,copy_feedback_control);
      g_ps_panel_canvas.Update(false);
      return;
     }

   g_ps_panel_canvas.Erase(PS_PremiumColor(PS_ThemeBackground()));
   PS_PremiumRoundRect(1,1,ui.panel_w-2,ui.panel_h-2,9,PS_ThemePanel(),PS_ThemeBorder());

   PS_PremiumText(14,23,PS_PRODUCT_NAME,14,PS_ThemeText(),
                   TA_LEFT|TA_VCENTER,"Segoe UI Semibold");
   PS_PremiumText(134,23,"v"+PS_VERSION_TEXT,8,PS_ThemeVersion(),
                   TA_LEFT|TA_VCENTER,"Segoe UI Semibold");
   PS_PremiumControlButton(ui,PS_CTRL_MANUAL,"Manual",false,PS_PREMIUM_BLUE,20);
   PS_PremiumControlButton(ui,PS_CTRL_COMPACT,"Compact",false,PS_PREMIUM_BLUE,18);
   PS_PremiumControlButton(ui,PS_CTRL_MINI,"Mini",false,PS_PREMIUM_BLUE,18);
   PS_PremiumControlButton(ui,PS_CTRL_THEME,"",false,PS_PREMIUM_BLUE,20);
   PSRect full_theme_rect;
   PS_PremiumControlRect(ui,PS_CTRL_THEME,full_theme_rect);
   PS_PremiumThemeIcon(full_theme_rect.x+full_theme_rect.w/2,full_theme_rect.y+full_theme_rect.h/2);
   PS_PremiumControlButton(ui,PS_CTRL_CLOSE,"",false,PS_CLR_SHORT,20);
   PSRect close_rect;
   PS_PremiumControlRect(ui,PS_CTRL_CLOSE,close_rect);
   PS_PremiumCloseIcon(close_rect.x+close_rect.w/2,close_rect.y+close_rect.h/2,PS_ThemeMuted());

   PS_PremiumRoundRect(10,47,418,48,5,PS_ThemeSection(),PS_ThemeBorder());
   PS_PremiumDrawDirection(ui,model);
   PS_PremiumDrawOrderMode(ui,model);

   PS_PremiumRoundRect(10,102,418,139,5,PS_ThemeSection(),PS_ThemeBorder());
   PS_PremiumText(20,123,"Entry",10,PS_ThemeMuted(),TA_LEFT|TA_VCENTER);
   PS_PremiumText(20,158,"SL",10,PS_ThemeMuted(),TA_LEFT|TA_VCENTER);
   PS_PremiumText(20,193,"TP",10,PS_ThemeMuted(),TA_LEFT|TA_VCENTER);

   PS_PremiumCompactField(ui,PS_CTRL_ENTRY_FIELD,
                          PS_UIFieldDisplay(PS_FIELD_ENTRY,model,calc,market,editor),
                           editor,PS_FIELD_ENTRY,false,false,11,13);
   PS_PremiumCompactField(ui,PS_CTRL_STOP_FIELD,
                          PS_UIFieldDisplay(PS_FIELD_STOP,model,calc,market,editor),
                           editor,PS_FIELD_STOP,false,false,11,13);
   PS_PremiumCompactField(ui,PS_CTRL_TAKE_FIELD,
                          PS_UIFieldDisplay(PS_FIELD_TAKE,model,calc,market,editor),
                           editor,PS_FIELD_TAKE,false,false,11,13);
   PS_PremiumCompactSmallControl(ui,PS_CTRL_ENTRY_MINUS,"−",false,29);
   PS_PremiumCompactSmallControl(ui,PS_CTRL_ENTRY_PLUS,"+",false,29);
   PS_PremiumCompactSmallControl(ui,PS_CTRL_ENTRY_COPY,"C",
                                 copy_feedback_control==PS_CTRL_ENTRY_COPY,27);
   PS_PremiumCompactSmallControl(ui,PS_CTRL_STOP_MINUS,"−",false,29);
   PS_PremiumCompactSmallControl(ui,PS_CTRL_STOP_PLUS,"+",false,29);
   PS_PremiumCompactSmallControl(ui,PS_CTRL_STOP_COPY,"C",
                                 copy_feedback_control==PS_CTRL_STOP_COPY,27);
   PS_PremiumCompactSmallControl(ui,PS_CTRL_TAKE_MINUS,"−",false,29);
   PS_PremiumCompactSmallControl(ui,PS_CTRL_TAKE_PLUS,"+",false,29);
   PS_PremiumCompactSmallControl(ui,PS_CTRL_TAKE_COPY,"C",
                                 copy_feedback_control==PS_CTRL_TAKE_COPY,27);
   PSRect full_lines_rect;
   PS_PremiumControlRect(ui,PS_CTRL_LINES,full_lines_rect);
   PS_PremiumButton(full_lines_rect,(model.lines_visible ? "Hide lines" : "Show lines"),true,
                    (model.lines_visible ? PS_CLR_WARNING : PS_PREMIUM_GREEN),17,true);

   PS_PremiumRoundRect(10,247,418,120,5,PS_ThemeSection(),PS_ThemeBorder());
   PS_PremiumText(20,269,"Account",10,PS_ThemeMuted(),TA_LEFT|TA_VCENTER);
   PS_PremiumText(20,305,"Risk, %",10,PS_ThemeMuted(),TA_LEFT|TA_VCENTER);
   PS_PremiumText(219,305,"Risk, "+market.account_currency,10,PS_ThemeMuted(),
                    TA_LEFT|TA_VCENTER);
   PS_PremiumText(20,341,"Size",10,PS_ThemeMuted(),TA_LEFT|TA_VCENTER);
   PS_PremiumControlButton(ui,PS_CTRL_ACCOUNT_MODE,"",false,PS_PREMIUM_BLUE,20);
   PSRect account_mode_rect;
   PS_PremiumControlRect(ui,PS_CTRL_ACCOUNT_MODE,account_mode_rect);
   PS_PremiumText(account_mode_rect.x+14,account_mode_rect.y+account_mode_rect.h/2,
                    PS_AccountModeText(model.account_mode),11,PS_ThemeText(),
                   TA_LEFT|TA_VCENTER,"Segoe UI Semibold");
   PS_PremiumChevronDown(account_mode_rect.x+account_mode_rect.w-16,
                          account_mode_rect.y+account_mode_rect.h/2,PS_ThemeMuted());
   bool manual=(model.account_mode==PS_ACCOUNT_MANUAL);
   PS_PremiumCompactField(ui,PS_CTRL_ACCOUNT_FIELD,
                          (editor.active && editor.field==PS_FIELD_ACCOUNT
                           ? PS_UIFieldDisplay(PS_FIELD_ACCOUNT,model,calc,market,editor)
                           : PS_UIGroupDecimalText(PS_UIFieldDisplay(PS_FIELD_ACCOUNT,model,calc,market,editor))),
                           editor,PS_FIELD_ACCOUNT,!manual,false,11,13);
   PS_PremiumCompactField(ui,PS_CTRL_RISK_PERCENT_FIELD,
                          PS_UIFieldDisplay(PS_FIELD_RISK_PERCENT,model,calc,market,editor),
                          editor,PS_FIELD_RISK_PERCENT,false,
                           model.risk_authority==PS_RISK_PERCENT,11,13);
   PS_PremiumCompactField(ui,PS_CTRL_RISK_MONEY_FIELD,
                          PS_UIRiskMoneyDisplay(model,calc,market,editor),
                          editor,PS_FIELD_RISK_MONEY,false,
                           model.risk_authority==PS_RISK_MONEY,11,13);
   PS_PremiumCompactField(ui,PS_CTRL_POSITION_SIZE,
                          PS_UIGroupDecimalText(PS_VolumeText(calc.volume,market)),
                           editor,PS_FIELD_NONE,true,false,11,13);
   PS_PremiumCompactSmallControl(ui,PS_CTRL_POSITION_COPY,"C",
                                 copy_feedback_control==PS_CTRL_POSITION_COPY,27);

   PSRect confirm_rect;
   PS_PremiumControlRect(ui,PS_CTRL_CONFIRM,confirm_rect);
   PS_PremiumButton(confirm_rect,
                    (model.ask_confirmation ? "Confirmation: On" : "Confirmation: Off"),
                     model.ask_confirmation,PS_PREMIUM_BLUE,21,true);
   PS_PremiumControlButton(ui,PS_CTRL_MOVE_SLS,"Move SLs to line",false,PS_PREMIUM_BLUE,21);

   color direction_color=(model.direction==PS_DIRECTION_LONG ? PS_PREMIUM_GREEN : PS_CLR_SHORT);
   string volume=PS_VolumeText(calc.volume,market);
   string trade_text;
   if(calc.valid)
     {
      if(model.order_mode==PS_ORDER_INSTANT)
         trade_text=(model.direction==PS_DIRECTION_LONG ? "BUY " : "SELL ")+volume+" MARKET";
      else
         trade_text="PLACE "+PS_Upper(calc.resolved_order_text)+" "+volume;
     }
   else trade_text="Cannot trade";
   PSRect trade_rect;
   PS_PremiumControlRect(ui,PS_CTRL_TRADE,trade_rect);
   PS_PremiumButton(trade_rect,"",calc.valid,direction_color,29,true);
   color trade_color=(calc.valid ? PS_ThemeOnAccent() : PS_ThemeMuted());
   PS_PremiumText(trade_rect.x+trade_rect.w/2,trade_rect.y+trade_rect.h/2,trade_text,13,trade_color,
                  TA_CENTER|TA_VCENTER,"Segoe UI Semibold");

   g_ps_panel_canvas.Update(false);
  }

void PS_UIRender(PSUIState &ui,const PSModel &model,const PSCalcResult &calc,
                 const PSMarketSnapshot &market,const PSEditorState &editor,
                 const PSControlId copy_feedback_control)
  {
   ulong started=GetMicrosecondCount();
   PS_UILayout(ui,model.view_mode);
   PS_UIPremiumRender(ui,model,calc,market,editor,copy_feedback_control);
   PS_UIUpdateLines(ui,model,market);
   ChartRedraw(ChartID());
   ui.dirty=false;
   PS_PerfCheck("render-premium",started,PS_RENDER_BUDGET_US);
  }

void PS_UIHidePanelContent(const PSUIState &ui)
  {
   PS_UIShow(ui,"ui.panel",false);
   for(int i=0;i<PS_CTRL_COUNT;i++)
     {
      PS_UIShow(ui,PS_UIControlSuffix((PSControlId)i,"box"),false);
      PS_UIShow(ui,PS_UIControlSuffix((PSControlId)i,"text"),false);
     }
   string labels[] = {"title","version","direction","order","entry","stop","take","lines",
                      "commission","account","riskp","riskm","actualp","actualm","size","status","mini_size"};
   for(int i=0;i<ArraySize(labels);i++) PS_UIShow(ui,"ui.lbl."+labels[i],false);
   PS_UIShow(ui,"ui.edit.selection",false);
   PS_UIShow(ui,"ui.edit.caret",false);
  }

uint PS_UICanvasColor(const color value)
  {
   return(COLOR2RGB(value));
  }

bool PS_UIObjectShown(const string name)
  {
   if(ObjectFind(ChartID(),name)<0) return(false);
   return((long)ObjectGetInteger(ChartID(),name,OBJPROP_TIMEFRAMES)!=OBJ_NO_PERIODS);
  }

void PS_UIDragCanvasDestroy()
  {
   if(g_ps_drag_canvas_created) g_ps_drag_canvas.Destroy();
   g_ps_drag_canvas_created=false;
   g_ps_drag_canvas_name="";
  }

bool PS_UIDragCanvasEnsure(const PSUIState &ui)
  {
   string name=PS_UIName(ui,"ui.drag.canvas");
   if(g_ps_drag_canvas_created && g_ps_drag_canvas_name!=name) PS_UIDragCanvasDestroy();
   if(!g_ps_drag_canvas_created)
     {
      if(!g_ps_drag_canvas.CreateBitmapLabel(ChartID(),0,name,ui.panel_x,ui.panel_y,
                                             ui.panel_w,ui.panel_h,COLOR_FORMAT_XRGB_NOALPHA))
        {
         PS_LogError(StringFormat("Cannot create drag canvas %s (error %d).",name,GetLastError()));
         return(false);
        }
      g_ps_drag_canvas_created=true;
      g_ps_drag_canvas_name=name;
      ObjectSetInteger(ChartID(),name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(ChartID(),name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(ChartID(),name,OBJPROP_SELECTED,false);
      ObjectSetInteger(ChartID(),name,OBJPROP_HIDDEN,true);
      ObjectSetInteger(ChartID(),name,OBJPROP_BACK,false);
      ObjectSetInteger(ChartID(),name,OBJPROP_ZORDER,60000);
      ObjectSetInteger(ChartID(),name,OBJPROP_TIMEFRAMES,OBJ_NO_PERIODS);
      ObjectSetString(ChartID(),name,OBJPROP_TOOLTIP,"\n");
     }
   else if(g_ps_drag_canvas.Width()!=ui.panel_w || g_ps_drag_canvas.Height()!=ui.panel_h)
     {
      if(!g_ps_drag_canvas.Resize(ui.panel_w,ui.panel_h))
        {
         PS_LogError("Cannot resize the drag canvas.");
         return(false);
        }
     }
   ObjectSetInteger(ChartID(),name,OBJPROP_XDISTANCE,ui.panel_x);
   ObjectSetInteger(ChartID(),name,OBJPROP_YDISTANCE,ui.panel_y);
   return(true);
  }

void PS_UIDragCanvasDrawBox(const PSUIState &ui,const string suffix)
  {
   string name=PS_UIName(ui,suffix);
   if(!PS_UIObjectShown(name)) return;
   int x=(int)ObjectGetInteger(ChartID(),name,OBJPROP_XDISTANCE)-ui.panel_x;
   int y=(int)ObjectGetInteger(ChartID(),name,OBJPROP_YDISTANCE)-ui.panel_y;
   int w=(int)ObjectGetInteger(ChartID(),name,OBJPROP_XSIZE);
   int h=(int)ObjectGetInteger(ChartID(),name,OBJPROP_YSIZE);
   if(w<=0 || h<=0 || x>=ui.panel_w || y>=ui.panel_h || x+w<=0 || y+h<=0) return;
   color background=(color)ObjectGetInteger(ChartID(),name,OBJPROP_BGCOLOR);
   color border=(color)ObjectGetInteger(ChartID(),name,OBJPROP_BORDER_COLOR);
   g_ps_drag_canvas.FillRectangle(x,y,x+w-1,y+h-1,PS_UICanvasColor(background));
   g_ps_drag_canvas.Rectangle(x,y,x+w-1,y+h-1,PS_UICanvasColor(border));
  }

void PS_UIDragCanvasDrawLabel(const PSUIState &ui,const string suffix)
  {
   string name=PS_UIName(ui,suffix);
   if(!PS_UIObjectShown(name)) return;
   string text=ObjectGetString(ChartID(),name,OBJPROP_TEXT);
   if(text=="") return;
   int x=(int)ObjectGetInteger(ChartID(),name,OBJPROP_XDISTANCE)-ui.panel_x;
   int y=(int)ObjectGetInteger(ChartID(),name,OBJPROP_YDISTANCE)-ui.panel_y;
   if(x>=ui.panel_w || y>=ui.panel_h) return;
   int size=(int)ObjectGetInteger(ChartID(),name,OBJPROP_FONTSIZE);
   string font=ObjectGetString(ChartID(),name,OBJPROP_FONT);
   color text_color=(color)ObjectGetInteger(ChartID(),name,OBJPROP_COLOR);
   g_ps_drag_canvas.FontSet(font,-10*MathMax(1,size));
   g_ps_drag_canvas.TextOut(x,y,text,PS_UICanvasColor(text_color));
  }

bool PS_UIDragCanvasRender(const PSUIState &ui)
  {
   if(!PS_UIDragCanvasEnsure(ui)) return(false);
   g_ps_drag_canvas.Erase(PS_UICanvasColor(PS_CLR_PANEL));
   g_ps_drag_canvas.Rectangle(0,0,ui.panel_w-1,ui.panel_h-1,PS_UICanvasColor(PS_CLR_BORDER));

   for(int i=0;i<PS_CTRL_COUNT;i++)
      PS_UIDragCanvasDrawBox(ui,PS_UIControlSuffix((PSControlId)i,"box"));
   PS_UIDragCanvasDrawBox(ui,"ui.edit.selection");

   string labels[] = {"title","version","direction","order","entry","stop","take","lines",
                      "commission","account","riskp","riskm","actualp","actualm","size","status","mini_size"};
   for(int i=0;i<ArraySize(labels);i++) PS_UIDragCanvasDrawLabel(ui,"ui.lbl."+labels[i]);
   for(int i=0;i<PS_CTRL_COUNT;i++)
      PS_UIDragCanvasDrawLabel(ui,PS_UIControlSuffix((PSControlId)i,"text"));
   PS_UIDragCanvasDrawBox(ui,"ui.edit.caret");

   g_ps_drag_canvas.Update(false);
   return(true);
  }

bool PS_UIBeginPanelDrag(PSUIState &ui,const PSViewMode view_mode)
  {
   PS_UILayout(ui,view_mode);
   return(PS_UIPanelCanvasEnsure(ui));
  }

void PS_UISetPanelPosition(PSUIState &ui,const int x,const int y,const PSViewMode view_mode)
  {
   int old_x=ui.panel_x;
   int old_y=ui.panel_y;
   ui.panel_x=x;
   ui.panel_y=y;
   PS_UILayout(ui,view_mode);
   if(ui.panel_x==old_x && ui.panel_y==old_y) return;
   if(g_ps_panel_canvas_created)
     {
      ObjectSetInteger(ChartID(),g_ps_panel_canvas_name,OBJPROP_XDISTANCE,ui.panel_x);
      ObjectSetInteger(ChartID(),g_ps_panel_canvas_name,OBJPROP_YDISTANCE,ui.panel_y);
      ChartRedraw(ChartID());
     }
  }

void PS_UIPreparePanelDrop(PSUIState &ui)
  {
   ui.dirty=true;
   ui.line_dirty=true;
  }

void PS_UIEndPanelDrag(PSUIState &ui)
  {
   if(g_ps_panel_canvas_created)
     {
      ObjectSetInteger(ChartID(),g_ps_panel_canvas_name,OBJPROP_XDISTANCE,ui.panel_x);
      ObjectSetInteger(ChartID(),g_ps_panel_canvas_name,OBJPROP_YDISTANCE,ui.panel_y);
     }
   ChartRedraw(ChartID());
  }

void PS_UIRenderLinesOnly(PSUIState &ui,const PSModel &model,const PSMarketSnapshot &market)
  {
   if(!ui.line_dirty) return;
   ulong started=GetMicrosecondCount();
   PS_UIReadChartSize(ui);
   PS_UIUpdateLines(ui,model,market);
   ChartRedraw(ChartID());
   PS_PerfCheck("render-lines",started,PS_RENDER_BUDGET_US);
  }


bool PS_UISetChartFlag(const ENUM_CHART_PROPERTY_INTEGER property,const bool value,const string label)
  {
   ResetLastError();
   if(ChartSetInteger(ChartID(),property,value)) return(true);
   PS_LogErrorRateLimited("chart-property."+label,
                          StringFormat("Cannot set chart property %s to %s (error %d).",label,(value ? "true" : "false"),GetLastError()),
                          5000);
   return(false);
  }

void PS_UIInitializeEvents(PSUIState &ui)
  {
   ui.event_mouse_move_original=(bool)ChartGetInteger(ChartID(),CHART_EVENT_MOUSE_MOVE,0);
   ui.event_mouse_wheel_original=(bool)ChartGetInteger(ChartID(),CHART_EVENT_MOUSE_WHEEL,0);
   ui.events_initialized=true;
   PS_UISetChartFlag(CHART_EVENT_MOUSE_MOVE,true,"CHART_EVENT_MOUSE_MOVE");
   PS_UISetChartFlag(CHART_EVENT_MOUSE_WHEEL,true,"CHART_EVENT_MOUSE_WHEEL");
  }

void PS_UIGuardEnter(PSUIState &ui)
  {
   if(!ui.guard_saved)
     {
      ui.saved_mouse_scroll=(bool)ChartGetInteger(ChartID(),CHART_MOUSE_SCROLL,0);
      ui.saved_context_menu=(bool)ChartGetInteger(ChartID(),CHART_CONTEXT_MENU,0);
      ui.saved_crosshair=(bool)ChartGetInteger(ChartID(),CHART_CROSSHAIR_TOOL,0);
      ui.saved_drag_trade_levels=(bool)ChartGetInteger(ChartID(),CHART_DRAG_TRADE_LEVELS,0);
      ui.saved_keyboard_control=(bool)ChartGetInteger(ChartID(),CHART_KEYBOARD_CONTROL,0);
      ui.saved_quick_navigation=(bool)ChartGetInteger(ChartID(),CHART_QUICK_NAVIGATION,0);
      ui.guard_saved=true;
     }

   // These chart capabilities are temporarily disabled while LotCraft owns
   // pointer or keyboard input. Broker levels remain visible; only their native
   // drag path is suspended.
   PS_UISetChartFlag(CHART_MOUSE_SCROLL,false,"CHART_MOUSE_SCROLL");
   PS_UISetChartFlag(CHART_CONTEXT_MENU,false,"CHART_CONTEXT_MENU");
   PS_UISetChartFlag(CHART_CROSSHAIR_TOOL,false,"CHART_CROSSHAIR_TOOL");
   PS_UISetChartFlag(CHART_DRAG_TRADE_LEVELS,false,"CHART_DRAG_TRADE_LEVELS");
   PS_UISetChartFlag(CHART_KEYBOARD_CONTROL,false,"CHART_KEYBOARD_CONTROL");
   PS_UISetChartFlag(CHART_QUICK_NAVIGATION,false,"CHART_QUICK_NAVIGATION");
  }

void PS_UIGuardExit(PSUIState &ui)
  {
   if(!ui.guard_saved) return;
   PS_UISetChartFlag(CHART_MOUSE_SCROLL,ui.saved_mouse_scroll,"CHART_MOUSE_SCROLL restore");
   PS_UISetChartFlag(CHART_CONTEXT_MENU,ui.saved_context_menu,"CHART_CONTEXT_MENU restore");
   PS_UISetChartFlag(CHART_CROSSHAIR_TOOL,ui.saved_crosshair,"CHART_CROSSHAIR_TOOL restore");
   PS_UISetChartFlag(CHART_DRAG_TRADE_LEVELS,ui.saved_drag_trade_levels,"CHART_DRAG_TRADE_LEVELS restore");
   PS_UISetChartFlag(CHART_KEYBOARD_CONTROL,ui.saved_keyboard_control,"CHART_KEYBOARD_CONTROL restore");
   PS_UISetChartFlag(CHART_QUICK_NAVIGATION,ui.saved_quick_navigation,"CHART_QUICK_NAVIGATION restore");
   ui.guard_saved=false;
  }

void PS_UIRestoreEvents(PSUIState &ui)
  {
   if(!ui.events_initialized) return;
   PS_UIGuardExit(ui);
   PS_UISetChartFlag(CHART_EVENT_MOUSE_MOVE,ui.event_mouse_move_original,"CHART_EVENT_MOUSE_MOVE restore");
   PS_UISetChartFlag(CHART_EVENT_MOUSE_WHEEL,ui.event_mouse_wheel_original,"CHART_EVENT_MOUSE_WHEEL restore");
   ui.events_initialized=false;
  }

void PS_UIDeleteOwned(PSUIState &ui)
  {
   PS_UIRestoreEvents(ui);
   PS_UIHandleCanvasesDestroy();
   PS_UIDragCanvasDestroy();
   PS_UIPanelCanvasDestroy();
   if(PS_UIHasOwnedPrefix(ui))
      ObjectsDeleteAll(ChartID(),ui.prefix);
   else if(ui.prefix!="")
      PS_LogError("Refusing to delete chart objects with an invalid ownership prefix.");
   ChartRedraw(ChartID());
   ui.created=false;
  }

#endif
