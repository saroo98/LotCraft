"""Bounded production clipboard reads with fault-injected platform calls.

This never reads the interactive clipboard and does not reproduce MQL marshalling.
The vector substitution is only the existing harness's MQL-array syntax adapter.
"""
import pytest

from native_mql_harness import compile_and_run, extract_function


def read_source():
    body = extract_function("MQL5/Experts/LotCraft/PS_Platform.mqh", "PS_PlatformClipboardGet")
    body = body.replace("ushort units[];", "std::vector<ushort> units;")
    return r'''
#include <cassert>
#include <cstdint>
#include <string>
#include <vector>
using string=std::string;using ulong=unsigned long long;using uint=unsigned int;using ushort=unsigned short;using MqlLong=std::int64_t;
const uint PS_CF_UNICODETEXT=13;const int MQL_DLLS_ALLOWED=1,CHART_WINDOW_HANDLE=2;
bool _IsX64=true,dll_allowed=true,chart_ok=true,format_ok=true,opened=false;
int stage=0,opens=0,closes=0,locks=0,unlocks=0,reads=0;
MqlLong chart_handle=0x100000001LL;
ulong memory=0x2345678900000001ULL,pointer=0x3456789000000002ULL;
std::vector<ushort> clipboard_units={'1','.','2','5',0};
bool MQLInfoInteger(int){return dll_allowed;}int ChartID(){return 1;}
bool ChartGetInteger(int,int,int,MqlLong &owner){owner=chart_handle;return chart_ok;}
int IsClipboardFormatAvailable(uint format){assert(format==13);return format_ok;}
template<class T> int OpenClipboard(T owner){++opens;assert(ulong(owner)==ulong(chart_handle));if(stage==1)return 0;opened=true;return 1;}
int CloseClipboard(){assert(opened);++closes;opened=false;return 1;}
ulong GetClipboardData(int format){assert(opened && format==13 && _IsX64);return stage==2?0:memory;}
uint GetClipboardData(uint format){assert(opened && format==13 && !_IsX64);return stage==2?0:uint(memory);}
template<class T> T GlobalSize(T handle){assert(ulong(handle)==memory);return T(stage==3?1:stage==4?65538:stage==5?3:clipboard_units.size()*2);}
template<class T> T GlobalLock(T handle){assert(ulong(handle)==memory);if(stage==7)return 0;++locks;return T(pointer);}
template<class T> int GlobalUnlock(T handle){assert(ulong(handle)==memory);++unlocks;return 1;}
int ArrayResize(std::vector<ushort> &units,int count){if(stage==6)return -1;units.resize(count);return count;}
template<class T> void RtlMoveMemory(std::vector<ushort> &units,T source,T bytes){
  assert(ulong(source)==pointer && ulong(bytes)==clipboard_units.size()*2);
  ++reads;units=clipboard_units;
}
string ShortArrayToString(const std::vector<ushort> &units,int start,int length){string text;for(int i=0;i<length;i++)text+=char(units[start+i]);return text;}
#define long MqlLong
''' + body + "\n#undef long\n"


@pytest.mark.parametrize("bits", [32, 64])
@pytest.mark.parametrize("stage", range(9))
def test_read_size_pointer_width_termination_and_failure_cleanup(tmp_path, bits, stage):
    compile_and_run(tmp_path, read_source() + f'''
int main(){{
  _IsX64={str(bits == 64).lower()};
  if(!_IsX64){{chart_handle=0x10001;memory=0x23456789;pointer=0x34567890;}}
  stage={stage};if(stage==8)clipboard_units.pop_back();
  string text="previous",error="previous";
  bool success=PS_PlatformClipboardGet(text,error);
  assert(success=={str(stage == 0).lower()} && !opened && locks==unlocks);
  assert(closes==(stage==1?0:1));
  if(success){{assert(text=="1.25" && error.empty() && reads==1);}}
  else{{assert(text.empty() && !error.empty());}}
}}
''')


@pytest.mark.parametrize("condition", ["dll_allowed=false;", "chart_ok=false;", "chart_handle=0;", "format_ok=false;"])
def test_read_preconditions_do_not_open_clipboard(tmp_path, condition):
    compile_and_run(tmp_path, read_source() + f'''
int main(){{
  {condition}string text,error;
  assert(!PS_PlatformClipboardGet(text,error));
  assert(opens==0 && locks==0 && !error.empty() && text.empty());
}}
''')
