// Run only in an owned noninteractive station. Never switch the input desktop.
#define UNICODE
#define _UNICODE
#include <windows.h>
#include <sddl.h>
#include <cassert>
#include <cstdint>
#include <iostream>
#include <string>
#include <vector>

using string=std::string;
using ulong=unsigned long long;
using uint=unsigned int;
using MqlLong=std::int64_t;
const int MQL_DLLS_ALLOWED=1,CHART_WINDOW_HANDLE=2;
const uint PS_CF_UNICODETEXT=13,PS_GMEM_MOVEABLE=2;
bool _IsX64=true,isolated=false,test_zero_owner=false;
MqlLong chart_handle=0;

std::wstring utf16(const string &text) {
  int length=MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,text.data(),int(text.size()),nullptr,0);
  assert(length>0 || text.empty());
  std::wstring result(length,L'\0');
  if(length)assert(MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,text.data(),int(text.size()),result.data(),length)==length);
  return result;
}
bool MQLInfoInteger(int){return true;}
int ChartID(){return 1;}
bool ChartGetInteger(int,int,int,MqlLong &value){value=chart_handle;return true;}
int StringLen(const string &s){return int(utf16(s).size());}
template<class T> string StringFormat(const string &s,T){return s;}

// The adapter preserves Win64 handle/pointer width. The production algorithm
// below remains unchanged; only MQL strings and DLL calls cross this boundary.
template<class T> T fixture_alloc(uint flags,T bytes){assert(isolated);return T(reinterpret_cast<uintptr_t>(::GlobalAlloc(flags,size_t(bytes))));}
template<class T> T fixture_lock(T h){assert(isolated);return T(reinterpret_cast<uintptr_t>(::GlobalLock(reinterpret_cast<HGLOBAL>(uintptr_t(h)))));}
template<class T> int fixture_unlock(T h){assert(isolated);return ::GlobalUnlock(reinterpret_cast<HGLOBAL>(uintptr_t(h)));}
template<class T> T fixture_free(T h){assert(isolated);return T(reinterpret_cast<uintptr_t>(::GlobalFree(reinterpret_cast<HGLOBAL>(uintptr_t(h)))));}
template<class T> T fixture_copy(T p,const string &s){assert(isolated);return T(reinterpret_cast<uintptr_t>(::lstrcpyW(reinterpret_cast<wchar_t*>(uintptr_t(p)),utf16(s).c_str())));}
template<class T> int fixture_open(T owner){assert(isolated);return ::OpenClipboard(reinterpret_cast<HWND>(uintptr_t(owner)));}
template<class T> T fixture_set(uint format,T h){assert(isolated);return T(reinterpret_cast<uintptr_t>(::SetClipboardData(format,reinterpret_cast<HANDLE>(uintptr_t(h)))));}
int fixture_empty(){assert(isolated);return ::EmptyClipboard();}
int fixture_close(){assert(isolated);return ::CloseClipboard();}

#define GlobalAlloc fixture_alloc
#define GlobalLock fixture_lock
#define GlobalUnlock fixture_unlock
#define GlobalFree fixture_free
#define lstrcpyW fixture_copy
#define OpenClipboard fixture_open
#define SetClipboardData fixture_set
#define EmptyClipboard fixture_empty
#define CloseClipboard fixture_close
#define long MqlLong

// INSERT_PRODUCTION_COPY_FUNCTION

#undef long
#undef GlobalAlloc
#undef GlobalLock
#undef GlobalUnlock
#undef GlobalFree
#undef lstrcpyW
#undef OpenClipboard
#undef SetClipboardData
#undef EmptyClipboard
#undef CloseClipboard

bool unavailable(const char *stage){std::cout<<"ISOLATION_UNAVAILABLE: "<<stage<<" (Windows error "<<GetLastError()<<")\n";return false;}

bool initialize_isolation(HWINSTA &station,HDESK &desktop,HWND &owner) {
  // Protect the synthetic clipboard and test windows with the current user's SID.
  HANDLE token=nullptr;
  if(!OpenProcessToken(GetCurrentProcess(),TOKEN_QUERY,&token))return unavailable("token");
  DWORD bytes=0;GetTokenInformation(token,TokenUser,nullptr,0,&bytes);
  std::vector<unsigned char> token_bytes(bytes);
  bool got_user=GetTokenInformation(token,TokenUser,token_bytes.data(),bytes,&bytes);
  CloseHandle(token);
  if(!got_user)return unavailable("user SID");
  LPWSTR sid=nullptr;
  if(!ConvertSidToStringSidW(reinterpret_cast<TOKEN_USER*>(token_bytes.data())->User.Sid,&sid))return unavailable("SID text");
  std::wstring dacl=L"D:P(A;;GA;;;"+std::wstring(sid)+L")";LocalFree(sid);
  PSECURITY_DESCRIPTOR descriptor=nullptr;
  if(!ConvertStringSecurityDescriptorToSecurityDescriptorW(dacl.c_str(),SDDL_REVISION_1,&descriptor,nullptr))return unavailable("private DACL");
  SECURITY_ATTRIBUTES security={sizeof(SECURITY_ATTRIBUTES),descriptor,FALSE};
  // Named station creation requires Administrators membership. An unnamed,
  // create-only station also works for ordinary users and cannot reuse one.
  station=CreateWindowStationW(nullptr,CWF_CREATE_ONLY,WINSTA_ALL_ACCESS,&security);
  if(!station){LocalFree(descriptor);return unavailable("private station creation");}
  if(!SetProcessWindowStation(station)){LocalFree(descriptor);return unavailable("station assignment");}
  wchar_t actual_name[256]={};DWORD required=0;
  if(GetProcessWindowStation()!=station ||
     !GetUserObjectInformationW(station,UOI_NAME,actual_name,sizeof(actual_name),&required) ||
     actual_name[0]==L'\0' || _wcsicmp(actual_name,L"WinSta0")==0) {
    LocalFree(descriptor);return unavailable("noninteractive station identity");
  }
  desktop=CreateDesktopW(L"ClipboardFixture",nullptr,nullptr,0,GENERIC_ALL,&security);
  LocalFree(descriptor);
  if(!desktop || !SetThreadDesktop(desktop))return unavailable("private desktop assignment");
  owner=CreateWindowExW(0,L"STATIC",L"LotCraft synthetic owner",0,0,0,1,1,nullptr,nullptr,GetModuleHandleW(nullptr),nullptr);
  if(!owner)return unavailable("hidden clipboard owner");
  isolated=true;chart_handle=MqlLong(reinterpret_cast<intptr_t>(owner));return true;
}

std::wstring read_clipboard(HWND owner) {
  assert(isolated && ::OpenClipboard(owner));
  HANDLE data=GetClipboardData(CF_UNICODETEXT);
  std::wstring text;
  if(data){auto pointer=static_cast<wchar_t*>(::GlobalLock(data));assert(pointer);text=pointer;::GlobalUnlock(data);}
  assert(::CloseClipboard());return text;
}

int main() {
  HWINSTA original_station=GetProcessWindowStation(),station=nullptr;
  HDESK original_desktop=GetThreadDesktop(GetCurrentThreadId()),desktop=nullptr;
  HWND owner=nullptr;
  if(!initialize_isolation(station,desktop,owner))return 0; // Never use WinSta0 as fallback.
  string error;
  const string sentinel="private fixture previous text";
  assert(PS_PlatformClipboardSet(sentinel,error));
  if(test_zero_owner) {
    chart_handle=0;
    assert(!PS_PlatformClipboardSet("1.12345",error));
    assert(read_clipboard(owner)==L"private fixture previous text");
  } else {
    for(const string &text : {string("1.12345"),string("65032.05"),string("0.001"),string("0"),string(u8"£1,234.56 · 金 · 😀")}) {
      assert(PS_PlatformClipboardSet(text,error) && error.empty());
      assert(read_clipboard(owner)==utf16(text));
    }
    // Genuine OpenClipboard contention from another window leaves old data alone.
    HWND holder=CreateWindowExW(0,L"STATIC",L"synthetic holder",0,0,0,1,1,nullptr,nullptr,GetModuleHandleW(nullptr),nullptr);
    assert(holder && ::OpenClipboard(holder));
    assert(!PS_PlatformClipboardSet("replacement",error) && !error.empty());
    assert(::CloseClipboard());
    assert(read_clipboard(owner)==utf16(u8"£1,234.56 · 金 · 😀"));
    DestroyWindow(holder);
  }
  DestroyWindow(owner);
  assert(SetThreadDesktop(original_desktop));
  assert(SetProcessWindowStation(original_station));
  assert(CloseDesktop(desktop));assert(CloseWindowStation(station));
  std::cout<<"PRIVATE_STATION_VERIFIED: exact Unicode round trips and ownership behavior; interactive clipboard untouched\n";
}
