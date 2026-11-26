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
int   IsClipboardFormatAvailable(uint uFormat);
long  GetClipboardData(int uFormat);
uint  GetClipboardData(uint uFormat);
uint  SetClipboardData(uint uFormat,uint hMem);
ulong SetClipboardData(uint uFormat,ulong hMem);
int   CloseClipboard();
short GetAsyncKeyState(int vKey);
uint  MapVirtualKeyW(uint uCode,uint uMapType);
uint  GetDoubleClickTime();
int   GetSystemMetrics(int nIndex);
ulong FindWindowExW(ulong hWndParent,ulong hWndChildAfter,string class_name,long window_name);
ulong GetDlgItem(ulong hDlg,int nIDDlgItem);
int   IsWindowVisible(ulong hWnd);
uint  GetWindowThreadProcessId(ulong hWnd,uint &process_id);
int   GetWindowTextW(ulong hWnd,ushort &text[],int max_count);
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
uint  GlobalSize(uint hMem);
ulong GlobalSize(ulong hMem);
uint  GetCurrentProcessId();
void  RtlMoveMemory(ushort &destination[],uint source,uint bytes);
void  RtlMoveMemory(ushort &destination[],ulong source,ulong bytes);
uint  lstrcpyW(uint destination,string source);
ulong lstrcpyW(ulong destination,string source);
#import

#import "shell32.dll"
uint  ShellExecuteW(uint hWnd,string operation,string file,string parameters,string directory,int show_command);
ulong ShellExecuteW(ulong hWnd,string operation,string file,string parameters,string directory,int show_command);
#import

#define PS_CF_UNICODETEXT 13
#define PS_GMEM_MOVEABLE  0x0002
#define PS_WM_KEYDOWN     0x0100
#define PS_WM_KEYUP       0x0101
#define PS_VK_F9          0x78
#define PS_VK_LBUTTON     0x01
#define PS_VK_RBUTTON     0x02
#define PS_SM_SWAPBUTTON  23
#define PS_SM_CXDOUBLECLK 36
#define PS_SM_CYDOUBLECLK 37
#define PS_SW_HIDE        0

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
   if(!ChartGetInteger(ChartID(),CHART_WINDOW_HANDLE,0,raw_handle) || raw_handle==0)
     {
      error=StringFormat("Cannot obtain a valid chart window handle (error %d).",GetLastError());
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

bool PS_PlatformClipboardGet(string &text,string &error)
  {
   text="";
   error="";
   if(!MQLInfoInteger(MQL_DLLS_ALLOWED))
     {
      error="Clipboard requires MT5 'Allow DLL imports' for this EA.";
      return(false);
     }
   long owner=0;
   if(!ChartGetInteger(ChartID(),CHART_WINDOW_HANDLE,0,owner) || owner==0)
     {
      error="Cannot obtain a valid chart window handle.";
      return(false);
     }
   if(IsClipboardFormatAvailable(PS_CF_UNICODETEXT)==0)
     {
      error="The clipboard has no Unicode text to paste.";
      return(false);
     }
   int opened=(_IsX64 ? OpenClipboard((ulong)owner) : OpenClipboard((uint)owner));
   if(opened==0)
     {
      error="Windows clipboard is currently unavailable.";
      return(false);
     }
   ulong memory=(_IsX64 ? (ulong)GetClipboardData((int)PS_CF_UNICODETEXT)
                       : (ulong)GetClipboardData((uint)PS_CF_UNICODETEXT));
   ulong bytes=(memory==0 ? 0 : (_IsX64 ? GlobalSize(memory) : (ulong)GlobalSize((uint)memory)));
   // Clipboard data is untrusted. Bound the UTF-16 read and require a terminator.
   if(bytes<2 || bytes>65536 || bytes%2!=0)
     {
      CloseClipboard();
      error="The clipboard text is unavailable or too large.";
      return(false);
     }
   ushort units[];
   int count=(int)(bytes/2);
   if(ArrayResize(units,count)!=count)
     {
      CloseClipboard();
      error="Cannot allocate memory for clipboard text.";
      return(false);
     }
   ulong pointer=(_IsX64 ? GlobalLock(memory) : (ulong)GlobalLock((uint)memory));
   if(pointer==0)
     {
      CloseClipboard();
      error="Windows could not lock clipboard text.";
      return(false);
     }
   if(_IsX64)
     {
      RtlMoveMemory(units,pointer,bytes);
      GlobalUnlock(memory);
     }
   else
     {
      RtlMoveMemory(units,(uint)pointer,(uint)bytes);
      GlobalUnlock((uint)memory);
     }
   CloseClipboard();
   int length=0;
   while(length<count && units[length]!=0) length++;
   if(length==count)
     {
      error="The clipboard text has no valid terminator.";
      return(false);
     }
   text=ShortArrayToString(units,0,length);
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

// Control identifiers of MT5's own New Order window, read from a live
// terminal. Only page tabs and numeric input boxes are listed. The window's
// Buy and Sell buttons are deliberately absent: LotCraft fills numbers in,
// and placing the order always remains the user's own click.
#define PS_ORDER_DIALOG_CLASS     "#32770"
#define PS_ORDER_TAB_MARKET       11116
#define PS_ORDER_TAB_LIMIT        11117
#define PS_ORDER_TAB_STOP         11118
#define PS_ORDER_SYMBOL_COMBO     10331
#define PS_ORDER_EDIT_VOLUME      10333
#define PS_ORDER_EDIT_STOP        10334
#define PS_ORDER_EDIT_TAKE        10336
#define PS_ORDER_EDIT_PRICE       10424
#define PS_WM_CHAR                0x0102
#define PS_EM_SETSEL              0x00B1
#define PS_BM_CLICK               0x00F5

string PS_PlatformWindowText(const ulong window)
  {
   if(window==0) return("");
   ushort buffer[];
   if(ArrayResize(buffer,256)!=256) return("");
   ArrayInitialize(buffer,0);
   int length=GetWindowTextW(window,buffer,255);
   if(length<=0 || length>255) return("");
   return(ShortArrayToString(buffer,0,length));
  }

ulong PS_PlatformFindOrderDialog(const string symbol)
  {
   // The New Order window is a top-level dialog of this terminal process
   // whose symbol box starts with the chart symbol. Its title is localized,
   // so it is recognized by structure, never by caption.
   if(!_IsX64 || !MQLInfoInteger(MQL_DLLS_ALLOWED) || symbol=="") return(0);
   uint own_process=GetCurrentProcessId();
   ulong window=0;
   for(int guard=0;guard<500;guard++)
     {
      window=FindWindowExW(0,window,PS_ORDER_DIALOG_CLASS,0);
      if(window==0) return(0);
      uint process=0;
      GetWindowThreadProcessId(window,process);
      if(process!=own_process || IsWindowVisible(window)==0) continue;
      if(GetDlgItem(window,PS_ORDER_TAB_MARKET)==0) continue;
      string shown=PS_PlatformWindowText(GetDlgItem(window,PS_ORDER_SYMBOL_COMBO));
      if(StringFind(shown,symbol+",")==0) return(window);
     }
   return(0);
  }

ulong PS_PlatformOrderDialogPage(const ulong dialog)
  {
   // Each tab is a child dialog. Only the visible one holds live inputs.
   if(dialog==0) return(0);
   ulong page=0;
   for(int guard=0;guard<32;guard++)
     {
      page=FindWindowExW(dialog,page,PS_ORDER_DIALOG_CLASS,0);
      if(page==0) return(0);
      if(IsWindowVisible(page)!=0 && GetDlgItem(page,PS_ORDER_EDIT_VOLUME)!=0) return(page);
     }
   return(0);
  }

bool PS_PlatformOrderDialogSelectTab(const ulong dialog,const int tab_id)
  {
   if(tab_id!=PS_ORDER_TAB_MARKET && tab_id!=PS_ORDER_TAB_LIMIT && tab_id!=PS_ORDER_TAB_STOP) return(false);
   ulong tab=GetDlgItem(dialog,tab_id);
   if(tab==0) return(false);
   return(PostMessageW(tab,PS_BM_CLICK,(ulong)0,(long)0)!=0);
  }

bool PS_PlatformTypeIntoEdit(const ulong page,const int edit_id,const string text)
  {
   // MT5 ignores text assigned to these boxes and only registers typed
   // characters. Select the old content and type the new value over it.
   if(edit_id!=PS_ORDER_EDIT_VOLUME && edit_id!=PS_ORDER_EDIT_STOP &&
      edit_id!=PS_ORDER_EDIT_TAKE && edit_id!=PS_ORDER_EDIT_PRICE) return(false);
   ulong edit=GetDlgItem(page,edit_id);
   int length=StringLen(text);
   if(edit==0 || IsWindowVisible(edit)==0 || length<=0 || length>24) return(false);
   for(int i=0;i<length;i++)
     {
      ushort ch=StringGetCharacter(text,i);
      if(!((ch>='0' && ch<='9') || ch=='.')) return(false);
     }
   if(PostMessageW(edit,PS_EM_SETSEL,(ulong)0,(long)-1)==0) return(false);
   for(int i=0;i<length;i++)
      if(PostMessageW(edit,PS_WM_CHAR,(ulong)StringGetCharacter(text,i),(long)1)==0) return(false);
   return(true);
  }

bool PS_PlatformOrderPageHasPrice(const ulong page)
  {
   ulong price=GetDlgItem(page,PS_ORDER_EDIT_PRICE);
   return(price!=0 && IsWindowVisible(price)!=0);
  }

string PS_PlatformReadEdit(const ulong page,const int edit_id)
  {
   return(PS_PlatformWindowText(GetDlgItem(page,edit_id)));
  }

bool PS_PlatformPointerPosition(int &x,int &y)
  {
   x=0;
   y=0;
   if(!MQLInfoInteger(MQL_DLLS_ALLOWED)) return(false);

   // Called every pointer frame. The chart window handle does not change
   // while the EA is attached, so it is read once instead of per frame.
   static long cached_chart=0;
   static long cached_handle=0;
   long chart=ChartID();
   if(chart!=cached_chart || cached_handle==0)
     {
      long fresh=0;
      if(!ChartGetInteger(chart,CHART_WINDOW_HANDLE,0,fresh) || fresh==0) return(false);
      cached_chart=chart;
      cached_handle=fresh;
     }
   long raw_handle=cached_handle;

   int point[2];
   point[0]=0;
   point[1]=0;
   if(GetCursorPos(point)==0) return(false);
   int converted=(_IsX64 ? ScreenToClient((ulong)raw_handle,point)
                         : ScreenToClient((uint)raw_handle,point));
   if(converted==0)
     {
      cached_handle=0;
      return(false);
     }
   x=point[0];
   y=point[1];
   return(true);
  }

bool PS_PlatformLeftButtonDown()
  {
   if(!MQLInfoInteger(MQL_DLLS_ALLOWED)) return(true);
   // GetAsyncKeyState reports physical buttons, while chart mouse events
   // report the logical primary button. With swapped buttons the primary
   // button is the physical right one.
   int primary=(GetSystemMetrics(PS_SM_SWAPBUTTON)!=0 ? PS_VK_RBUTTON : PS_VK_LBUTTON);
   short state=GetAsyncKeyState(primary);
   return((state & 0x8000)!=0);
  }

void PS_PlatformKeyboardModifiers(bool &shift_down,bool &ctrl_down)
  {
   // Seed only unknown modifier state. Delivered chart events own known state.
   // The EA runs outside the chart's Windows message thread, so prefer Windows
   // physical state over a terminal observation at that initial boundary.
   // Only the high bit means held; the low "pressed since last call" bit does not.
   if(MQLInfoInteger(MQL_DLLS_ALLOWED))
     {
      shift_down=((GetAsyncKeyState(16) & 0x8000)!=0);
      ctrl_down=((GetAsyncKeyState(17) & 0x8000)!=0);
      return;
     }
   shift_down=((TerminalInfoInteger(TERMINAL_KEYSTATE_SHIFT) & 0x8000)!=0);
   ctrl_down=((TerminalInfoInteger(TERMINAL_KEYSTATE_CONTROL) & 0x8000)!=0);
  }

uint PS_PlatformModifierSide(const int key,const uint flags)
  {
   if(key==160 || key==162) return(1);
   if(key==161 || key==163) return(2);
   // MQL keyboard sparam contains the high WORD of Windows' key lParam:
   // scan code in bits 0..7, extended-key attribute in bit 8.
   if(key==17) return((flags & 0x100)!=0 ? 2 : 1);
   if(key==16)
     {
      uint scan=flags & 0xFF;
      if(scan!=0 && MQLInfoInteger(MQL_DLLS_ALLOWED))
        {
         uint right_scan=MapVirtualKeyW(161,0) & 0xFF;
         if(right_scan!=0 && scan==right_scan) return(2);
        }
      return(1);
     }
   return(0);
  }

bool PS_PlatformLaunchUpdater(string &error)
  {
   error="";
   if(!MQLInfoInteger(MQL_DLLS_ALLOWED))
     {
      error="Update checks require MT5 'Allow DLL imports' for this EA.";
      return(false);
     }

   string product_directory=TerminalInfoString(TERMINAL_DATA_PATH)+"\\MQL5\\Experts\\LotCraft";
   string updater_path=product_directory+"\\LotCraft-Updater.exe";
   long result=0;
   if(_IsX64)
      result=(long)ShellExecuteW((ulong)0,"open",updater_path,"-check-update",product_directory,PS_SW_HIDE);
   else
      result=(long)ShellExecuteW((uint)0,"open",updater_path,"-check-update",product_directory,PS_SW_HIDE);
   if(result<=32)
     {
      error=StringFormat("Windows could not start LotCraft-Updater.exe (ShellExecuteW result %I64d).",result);
      return(false);
     }
   return(true);
  }

#endif
