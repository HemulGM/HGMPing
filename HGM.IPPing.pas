unit HGM.IPPing;

interface

function PingHost(const HostName: string; var ResponseTime: Cardinal; TimeoutMS: Cardinal = 500): Boolean;

function HostNameToIP(Name: string; var Ip: string): Boolean;

implementation

uses
  Windows, SysUtils, WinSock;

function IcmpCreateFile: THandle; stdcall; external 'iphlpapi.dll';

function IcmpCloseHandle(icmpHandle: THandle): Boolean; stdcall; external 'iphlpapi.dll';

function IcmpSendEcho(icmpHandle: THandle; DestinationAddress: In_Addr; RequestData: Pointer; RequestSize: Smallint; RequestOptions: Pointer; ReplyBuffer: Pointer; ReplySize: DWORD; Timeout: DWORD): DWORD; stdcall; external 'iphlpapi.dll';

type
  PEchoReply = ^TEchoReply;

  TEchoReply = packed record
    Addr: In_Addr;
    Status: DWORD;
    RoundTripTime: DWORD;
  end;

var
  WSAData: TWSAData;

procedure Startup;
begin
  if WSAStartup($0101, WSAData) <> 0 then
    raise Exception.Create('WSAStartup');
end;

procedure Cleanup;
begin
  if WSACleanup <> 0 then
    raise Exception.Create('WSACleanup');
end;

function HostNameToIP(Name: string; var Ip: string): Boolean;
var
  HostEnt: PHostEnt;
  Addr: PAnsiChar;
begin
  Result := False;
  HostEnt := gethostbyname(PAnsiChar(AnsiString(Name)));
  if Assigned(HostEnt) and Assigned(HostEnt^.h_addr_list) then
  begin
    Addr := HostEnt^.h_addr_list^;
    if Assigned(Addr) then
    begin
      Ip := Format('%d.%d.%d.%d', [Byte(Addr[0]), Byte(Addr[1]), Byte(Addr[2]), Byte(Addr[3])]);
      Result := True;
    end;
  end;
end;

function PingHost(const HostName: string; var ResponseTime: Cardinal; TimeoutMS: Cardinal = 500): Boolean;
const
  rSize = $400;
var
  HostEnt: PHostEnt;
  InAddr: PInAddr;
  Handle: THandle;
  DateStr: string;
  Buffer: array[0..rSize - 1] of Byte;
begin
  Result := False;
  try
    HostEnt := gethostbyname(PAnsiChar(AnsiString(HostName)));
    if HostEnt = nil then
      RaiseLastOSError;
    if HostEnt.h_addrtype = AF_INET then
      Pointer(InAddr) := HostEnt.h_addr^
    else
      Exit;

    DateStr := FormatDateTime('yyyymmddhhnnsszzz', Now);

    Handle := IcmpCreateFile;
    if Handle = INVALID_HANDLE_VALUE then
      RaiseLastOSError;
    try
      ResponseTime := GetTickCount;
      Result := (IcmpSendEcho(Handle, InAddr^, PChar(DateStr), Length(DateStr), nil, @Buffer[0], rSize, TimeoutMS) <> 0) and
        (PEchoReply(@Buffer[0]).Status = 0);
      ResponseTime := GetTickCount - ResponseTime;
    finally
      IcmpCloseHandle(Handle);
    end;
  except
    Result := False;
  end;
end;

initialization
  Startup;

finalization
  Cleanup;

end.

