#ifndef __LOTCRAFT_PS_UI_METRICS_MQH__
#define __LOTCRAFT_PS_UI_METRICS_MQH__

#include "PS_Types.mqh"

struct PSUIMetrics
  {
   double dpi_scale;
   double fit_scale;
   double scale;
   int outer_padding;
   int section_gap;
   int control_gap;
   int row_gap;
   int radius_panel;
   int radius_section;
   int radius_control;
   int full_w;
   int full_h;
   int compact_w;
   int compact_h;
   int mini_w;
   int mini_h;
  };

PSUIMetrics g_ps_metrics;

int PS_U(const int base_px)
  {
   return((int)MathRound(base_px*g_ps_metrics.scale));
  }

int PS_Font(const int base_px)
  {
   return(MathMax(7,PS_U(base_px)));
  }

void PS_UIMetricsRefresh(const int chart_w,const int chart_h,const PSViewMode mode)
  {
   int dpi=(int)TerminalInfoInteger(TERMINAL_SCREEN_DPI);
   if(dpi<=0) dpi=96;
   g_ps_metrics.dpi_scale=MathMax(1.0,MathMin(2.0,(double)dpi/96.0));
   int base_w=(mode==PS_VIEW_FULL ? 438 : (mode==PS_VIEW_COMPACT ? 372 : 360));
   int base_h=(mode==PS_VIEW_FULL ? 529 : (mode==PS_VIEW_COMPACT ? 470 : 92));
   double fit_w=(double)MathMax(1,chart_w-8)/(double)base_w;
   double fit_h=(double)MathMax(1,chart_h-8)/(double)base_h;
   g_ps_metrics.fit_scale=MathMin(fit_w,fit_h);
   g_ps_metrics.scale=MathMax(0.82,MathMin(g_ps_metrics.dpi_scale,g_ps_metrics.fit_scale));
   g_ps_metrics.outer_padding=PS_U(10);
   g_ps_metrics.section_gap=PS_U(8);
   g_ps_metrics.control_gap=PS_U(6);
   g_ps_metrics.row_gap=PS_U(6);
   g_ps_metrics.radius_panel=PS_U(9);
   g_ps_metrics.radius_section=PS_U(5);
   g_ps_metrics.radius_control=PS_U(4);
   g_ps_metrics.full_w=PS_U(438);
   g_ps_metrics.full_h=PS_U(529);
   g_ps_metrics.compact_w=PS_U(372);
   g_ps_metrics.compact_h=PS_U(470);
   g_ps_metrics.mini_w=PS_U(360);
   g_ps_metrics.mini_h=PS_U(92);
  }

#endif
