#ifndef __LOTCRAFT_PS_PLATFORM_MQH__
#define __LOTCRAFT_PS_PLATFORM_MQH__

#include "PS_Logging.mqh"

#import "user32.dll"
int   PostMessageW(uint hWnd,uint Msg,uint wParam,int lParam);
int   PostMessageW(ulong hWnd,uint Msg,ulong wParam,long lParam);
int   SetForegroundWindow(uint hWnd);
int   SetForegroundWindow(ulong hWnd);
int   OpenClipboard(uint hWndNewOwner);
int   OpenClipboard(ulong hWndNewOwner);
int   GetCursorPos(int &point[]);
int   ScreenToClient(uint hWnd,int &point[]);
int   ScreenToClient(ulong hWnd,int &point[]);
int   EmptyClipboard();
uint  SetClipboardData(uint uFormat,uint hMem);
ulong SetClipboardData(uint uFormat,ulong hMem);
int   CloseClipboard();
short GetAsyncKeyState(int vKey);
uint  GetDoubleClickTime();
int   GetSystemMetrics(int nIndex);
#import

#import "kernel32.dll"
uint  GlobalAlloc(uint uFlags,uint dwBytes);
ulong GlobalAlloc(uint uFlags,ulong dwBytes);
uint  GlobalLock(uint hMem);
ulong GlobalLock(ulong hMem);
int   GlobalUnlock(uint hMem);
int   GlobalUnlock(ulong hMem);
uint  GlobalFree(uint hMem);
ulong GlobalFree(ulong hMem);
uint  lstrcpyW(uint destination,string source);
ulong lstrcpyW(ulong destination,string source);
#import

#define PS_CF_UNICODETEXT 13
#define PS_GMEM_MOVEABLE  0x0002
#define PS_WM_KEYDOWN     0x0100
#define PS_WM_KEYUP       0x0101
#define PS_VK_F9          0x78
#define PS_VK_LBUTTON     0x01
#define PS_SM_CXDOUBLECLK 36
#define PS_SM_CYDOUBLECLK 37

uint PS_PlatformDoubleClickTime()
  {
   uint interval=GetDoubleClickTime();
   return(interval>0 ? interval : 500);
  }

int PS_PlatformDoubleClickWidth()
  {
   int width=GetSystemMetrics(PS_SM_CXDOUBLECLK);
   return(width>0 ? width : 4);
  }

int PS_PlatformDoubleClickHeight()
  {
   int height=GetSystemMetrics(PS_SM_CYDOUBLECLK);
   return(height>0 ? height : 4);
  }

bool PS_PlatformClipboardSet(const string text,string &error)
  {
   error="";
   if(!MQLInfoInteger(MQL_DLLS_ALLOWED))
     {
      error="Clipboard requires MT5 'Allow DLL imports' for this EA.";
      return(false);
     }

   long raw_handle=0;
   if(!ChartGetInteger(ChartID(),CHART_WINDOW_HANDLE,0,raw_handle))
     {
      error=StringFormat("Cannot obtain chart window handle (error %d).",GetLastError());
      return(false);
     }

   int chars=StringLen(text)+1;
   if(chars<=0)
     {
      error="Clipboard text is empty.";
      return(false);
     }

   if(_IsX64)
     {
      ulong bytes=(ulong)chars*2;
      ulong memory=GlobalAlloc(PS_GMEM_MOVEABLE,bytes);
      if(memory==0)
        {
         error="Windows could not allocate clipboard memory.";
         return(false);
        }
      ulong pointer=GlobalLock(memory);
      if(pointer==0)
        {
         GlobalFree(memory);
         error="Windows could not lock clipboard memory.";
         return(false);
        }
      if(lstrcpyW(pointer,text)==0)
        {
         GlobalUnlock(memory);
         GlobalFree(memory);
         error="Windows could not copy text into clipboard memory.";
         return(false);
        }
      GlobalUnlock(memory);

      if(OpenClipboard((ulong)raw_handle)==0)
        {
         GlobalFree(memory);
         error="Windows clipboard is currently unavailable.";
         return(false);
        }
      if(EmptyClipboard()==0)
        {
         CloseClipboard();
         GlobalFree(memory);
         error="Windows could not clear the clipboard.";
         return(false);
        }
      ulong transferred=SetClipboardData(PS_CF_UNICODETEXT,memory);
      CloseClipboard();
      if(transferred==0)
        {
         GlobalFree(memory);
         error="Windows rejected the clipboard data.";
         return(false);
        }
      return(true);
     }

   uint bytes32=(uint)chars*2;
   uint memory32=GlobalAlloc(PS_GMEM_MOVEABLE,bytes32);
   if(memory32==0)
     {
      error="Windows could not allocate clipboard memory.";
      return(false);
     }
   uint pointer32=GlobalLock(memory32);
   if(pointer32==0)
     {
      GlobalFree(memory32);
      error="Windows could not lock clipboard memory.";
      return(false);
     }
   if(lstrcpyW(pointer32,text)==0)
     {
      GlobalUnlock(memory32);
      GlobalFree(memory32);
      error="Windows could not copy text into clipboard memory.";
      return(false);
     }
   GlobalUnlock(memory32);

   if(OpenClipboard((uint)raw_handle)==0)
     {
      GlobalFree(memory32);
      error="Windows clipboard is currently unavailable.";
      return(false);
     }
   if(EmptyClipboard()==0)
     {
      CloseClipboard();
      GlobalFree(memory32);
      error="Windows could not clear the clipboard.";
      return(false);
     }
   uint transferred32=SetClipboardData(PS_CF_UNICODETEXT,memory32);
   CloseClipboard();
   if(transferred32==0)
     {
      GlobalFree(memory32);
      error="Windows rejected the clipboard data.";
      return(false);
     }
   return(true);
  }

bool PS_PlatformOpenNativeOrderDialog(string &error)
  {
   error="";
   if(!MQLInfoInteger(MQL_DLLS_ALLOWED))
     {
      error="Manual order dialog requires MT5 'Allow DLL imports' for this EA.";
      return(false);
     }

   long raw_handle=0;
   if(!ChartGetInteger(ChartID(),CHART_WINDOW_HANDLE,0,raw_handle))
     {
      error=StringFormat("Cannot obtain chart window handle (error %d).",GetLastError());
      return(false);
     }

   ResetLastError();
   if(!ChartSetInteger(ChartID(),CHART_BRING_TO_TOP,true))
      PS_LogWarningRateLimited("manual.bring-to-top",StringFormat("Cannot request chart foreground state (error %d).",GetLastError()),5000);
   if(_IsX64)
     {
      ulong handle=(ulong)raw_handle;
      SetForegroundWindow(handle);
      int down=PostMessageW(handle,PS_WM_KEYDOWN,(ulong)PS_VK_F9,1);
      int up=PostMessageW(handle,PS_WM_KEYUP,(ulong)PS_VK_F9,-1073741823);
      if(down==0 || up==0)
        {
         error="Windows did not accept the F9 New Order command.";
         return(false);
        }
      return(true);
     }

   uint handle32=(uint)raw_handle;
   SetForegroundWindow(handle32);
   int down32=PostMessageW(handle32,PS_WM_KEYDOWN,(uint)PS_VK_F9,1);
   int up32=PostMessageW(handle32,PS_WM_KEYUP,(uint)PS_VK_F9,-1073741823);
   if(down32==0 || up32==0)
     {
      error="Windows did not accept the F9 New Order command.";
      return(false);
     }
   return(true);
  }

bool PS_PlatformPointerPosition(int &x,int &y)
  {
   x=0;
   y=0;
   if(!MQLInfoInteger(MQL_DLLS_ALLOWED)) return(false);

   long raw_handle=0;
   if(!ChartGetInteger(ChartID(),CHART_WINDOW_HANDLE,0,raw_handle)) return(false);

   int point[2];
   point[0]=0;
   point[1]=0;
   if(GetCursorPos(point)==0) return(false);
   int converted=(_IsX64 ? ScreenToClient((ulong)raw_handle,point)
                         : ScreenToClient((uint)raw_handle,point));
   if(converted==0) return(false);
   x=point[0];
   y=point[1];
   return(true);
  }

bool PS_PlatformLeftButtonDown()
  {
   if(!MQLInfoInteger(MQL_DLLS_ALLOWED)) return(true);
   short state=GetAsyncKeyState(PS_VK_LBUTTON);
   return((state & 0x8000)!=0);
  }

#endif
