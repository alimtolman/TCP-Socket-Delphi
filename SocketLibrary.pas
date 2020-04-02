unit SocketLibrary;

interface

uses
  SysUtils, Winapi.Winsock2;

type
  TSocketHandle = Winapi.WinSock2.TSocket;

  TAddressList = record
  public
    Host: string;
    Addresses: TArray<Cardinal>;
    IpAddresses: TArray<string>;
    Count: Integer;
  end;

  TSocket = class
  private
    FConnected: Boolean;
    FIsErrorCaused: Boolean;
    FLastErrorCode: Integer;
    FLastErrorDescription: string;
    FSocketHandle: TSocketHandle;
    (* functions *)
    function GetAvailableCount(): Cardinal;
    function GetSocketAddress(const Address: Cardinal; const Port: Integer): TSockAddr;
    procedure Initialize();
    function IsError(const ErrorCode: Integer): Boolean;
  public
    constructor Create();
    destructor Destroy(); override;
    procedure Connect(const Host: string; const Port: Integer; const TryAllIP: Boolean = True);
    procedure ClearError();
    procedure Close();
    function GetAddressList(const Host: string): TAddressList;
    function Receive(const Length: Integer): TArray<Byte>;
    procedure Send(const Data: TArray<Byte>; const Length: Integer);
    (* properties *)
    property Available: Cardinal read GetAvailableCount;
    property Connected: Boolean read FConnected;
    property Handle: TSocketHandle read FSocketHandle;
    property IsErrorCaused: Boolean read FIsErrorCaused;
    property LastErrorDescription: string read FLastErrorDescription;
  end;

implementation

{ TSocket }

constructor TSocket.Create();
var
  wd: WSAData;
begin
  Winapi.Winsock2.WSAStartup(Winapi.Winsock2.WINSOCK_VERSION, wd);

  FConnected := False;
  FSocketHandle := Winapi.Winsock2.INVALID_SOCKET;

  ClearError();
end;

destructor TSocket.Destroy();
begin
  Close();
  Winapi.Winsock2.WSACleanup();
end;

(* private *)

function TSocket.GetAvailableCount(): Cardinal;
var
  NullPtr: Pointer;
  AvailableCount: Cardinal;
  ResultCode: Integer;
begin
  Result := 0;
  NullPtr := nil;
  AvailableCount := 0;
  ResultCode := Winapi.Winsock2.recv(FSocketHandle, NullPtr, 0, 0);

  if IsError(ResultCode) then
    Exit;

  ResultCode := Winapi.Winsock2.ioctlsocket(FSocketHandle, Winapi.Winsock2.FIONREAD, AvailableCount);

  if IsError(ResultCode) then
    Exit;

  Result := AvailableCount;
end;

function TSocket.GetSocketAddress(const Address: Cardinal; const Port: Integer): TSockAddr;
var
  SocketAddress: TSockAddr;
begin
  SocketAddress.sa_family := Winapi.Winsock2.AF_INET;
  SocketAddress.sa_data[0] := AnsiChar(Port shr 8);
  SocketAddress.sa_data[1] := AnsiChar(Port);
  SocketAddress.sa_data[2] := AnsiChar(Address);
  SocketAddress.sa_data[3] := AnsiChar(Address shr 8);
  SocketAddress.sa_data[4] := AnsiChar(Address shr 16);
  SocketAddress.sa_data[5] := AnsiChar(Address shr 24);
  SocketAddress.sa_data[6] := AnsiChar(0);
  SocketAddress.sa_data[7] := AnsiChar(0);
  SocketAddress.sa_data[8] := AnsiChar(0);
  SocketAddress.sa_data[9] := AnsiChar(0);
  SocketAddress.sa_data[10] := AnsiChar(0);
  SocketAddress.sa_data[11] := AnsiChar(0);
  SocketAddress.sa_data[12] := AnsiChar(0);
  SocketAddress.sa_data[13] := AnsiChar(0);

  Result := SocketAddress;
end;

procedure TSocket.Initialize();
begin
  FSocketHandle := Winapi.Winsock2.WSASocket(Winapi.Winsock2.AF_INET, Winapi.Winsock2.SOCK_STREAM, Winapi.Winsock2.IPPROTO_TCP, nil, 0, Winapi.Winsock2.WSA_FLAG_OVERLAPPED);

  if FSocketHandle = Winapi.Winsock2.INVALID_SOCKET then
    IsError(Winapi.Winsock2.SOCKET_ERROR);
end;

function TSocket.IsError(const ErrorCode: Integer): Boolean;
begin
  Result := False;

  if ErrorCode <> Winapi.Winsock2.SOCKET_ERROR then
    Exit;

  FLastErrorCode := Winapi.Winsock2.WSAGetLastError();

  case FLastErrorCode of
    0:
      Exit;
    WSA_INVALID_HANDLE:
      FLastErrorDescription := 'WSA_INVALID_HANDLE';
    WSA_NOT_ENOUGH_MEMORY:
      FLastErrorDescription := 'WSA_NOT_ENOUGH_MEMORY';
    WSA_INVALID_PARAMETER:
      FLastErrorDescription := 'WSA_INVALID_PARAMETER';
    WSA_OPERATION_ABORTED:
      FLastErrorDescription := 'WSA_OPERATION_ABORTED';
    WSA_IO_INCOMPLETE:
      FLastErrorDescription := 'WSA_IO_INCOMPLETE';
    WSA_IO_PENDING:
      FLastErrorDescription := 'WSA_IO_PENDING';
    WSAEINTR:
      FLastErrorDescription := 'WSAEINTR';
    WSAEBADF:
      FLastErrorDescription := 'WSAEBADF';
    WSAEACCES:
      FLastErrorDescription := 'WSAEACCES';
    WSAEFAULT:
      FLastErrorDescription := 'WSAEFAULT';
    WSAEINVAL:
      FLastErrorDescription := 'WSAEINVAL';
    WSAEMFILE:
      FLastErrorDescription := 'WSAEMFILE';
    WSAEWOULDBLOCK:
      FLastErrorDescription := 'WSAEWOULDBLOCK';
    WSAEINPROGRESS:
      FLastErrorDescription := 'WSAEINPROGRESS';
    WSAEALREADY:
      FLastErrorDescription := 'WSAEALREADY';
    WSAENOTSOCK:
      FLastErrorDescription := 'WSAENOTSOCK';
    WSAEDESTADDRREQ:
      FLastErrorDescription := 'WSAEDESTADDRREQ';
    WSAEMSGSIZE:
      FLastErrorDescription := 'WSAEMSGSIZE';
    WSAEPROTOTYPE:
      FLastErrorDescription := 'WSAEPROTOTYPE';
    WSAENOPROTOOPT:
      FLastErrorDescription := 'WSAENOPROTOOPT';
    WSAEPROTONOSUPPORT:
      FLastErrorDescription := 'WSAEPROTONOSUPPORT';
    WSAESOCKTNOSUPPORT:
      FLastErrorDescription := 'WSAESOCKTNOSUPPORT';
    WSAEOPNOTSUPP:
      FLastErrorDescription := 'WSAEOPNOTSUPP';
    WSAEPFNOSUPPORT:
      FLastErrorDescription := 'WSAEPFNOSUPPORT';
    WSAEAFNOSUPPORT:
      FLastErrorDescription := 'WSAEAFNOSUPPORT';
    WSAEADDRINUSE:
      FLastErrorDescription := 'WSAEADDRINUSE';
    WSAEADDRNOTAVAIL:
      FLastErrorDescription := 'WSAEADDRNOTAVAIL';
    WSAENETDOWN:
      FLastErrorDescription := 'WSAENETDOWN';
    WSAENETUNREACH:
      FLastErrorDescription := 'WSAENETUNREACH';
    WSAENETRESET:
      FLastErrorDescription := 'WSAENETRESET';
    WSAECONNABORTED:
      FLastErrorDescription := 'WSAECONNABORTED';
    WSAECONNRESET:
      FLastErrorDescription := 'WSAECONNRESET';
    WSAENOBUFS:
      FLastErrorDescription := 'WSAENOBUFS';
    WSAEISCONN:
      FLastErrorDescription := 'WSAEISCONN';
    WSAENOTCONN:
      FLastErrorDescription := 'WSAENOTCONN';
    WSAESHUTDOWN:
      FLastErrorDescription := 'WSAESHUTDOWN';
    WSAETOOMANYREFS:
      FLastErrorDescription := 'WSAETOOMANYREFS';
    WSAETIMEDOUT:
      FLastErrorDescription := 'WSAETIMEDOUT';
    WSAECONNREFUSED:
      FLastErrorDescription := 'WSAECONNREFUSED';
    WSAELOOP:
      FLastErrorDescription := 'WSAELOOP';
    WSAENAMETOOLONG:
      FLastErrorDescription := 'WSAENAMETOOLONG';
    WSAEHOSTDOWN:
      FLastErrorDescription := 'WSAEHOSTDOWN';
    WSAEHOSTUNREACH:
      FLastErrorDescription := 'WSAEHOSTUNREACH';
    WSAENOTEMPTY:
      FLastErrorDescription := 'WSAENOTEMPTY';
    WSAEPROCLIM:
      FLastErrorDescription := 'WSAEPROCLIM';
    WSAEUSERS:
      FLastErrorDescription := 'WSAEUSERS';
    WSAEDQUOT:
      FLastErrorDescription := 'WSAEDQUOT';
    WSAESTALE:
      FLastErrorDescription := 'WSAESTALE';
    WSAEREMOTE:
      FLastErrorDescription := 'WSAEREMOTE';
    WSASYSNOTREADY:
      FLastErrorDescription := 'WSASYSNOTREADY';
    WSAVERNOTSUPPORTED:
      FLastErrorDescription := 'WSAVERNOTSUPPORTED';
    WSANOTINITIALISED:
      FLastErrorDescription := 'WSANOTINITIALISED';
    WSAEDISCON:
      FLastErrorDescription := 'WSAEDISCON';
    WSAENOMORE:
      FLastErrorDescription := 'WSAENOMORE';
    WSAECANCELLED:
      FLastErrorDescription := 'WSAECANCELLED';
    WSAEINVALIDPROCTABLE:
      FLastErrorDescription := 'WSAEINVALIDPROCTABLE';
    WSAEINVALIDPROVIDER:
      FLastErrorDescription := 'WSAEINVALIDPROVIDER';
    WSAEPROVIDERFAILEDINIT:
      FLastErrorDescription := 'WSAEPROVIDERFAILEDINIT';
    WSASYSCALLFAILURE:
      FLastErrorDescription := 'WSASYSCALLFAILURE';
    WSASERVICE_NOT_FOUND:
      FLastErrorDescription := 'WSASERVICE_NOT_FOUND';
    WSATYPE_NOT_FOUND:
      FLastErrorDescription := 'WSATYPE_NOT_FOUND';
    WSA_E_NO_MORE:
      FLastErrorDescription := 'WSA_E_NO_MORE';
    WSA_E_CANCELLED:
      FLastErrorDescription := 'WSA_E_CANCELLED';
    WSAEREFUSED:
      FLastErrorDescription := 'WSAEREFUSED';
    WSAHOST_NOT_FOUND:
      FLastErrorDescription := 'WSAHOST_NOT_FOUND';
    WSATRY_AGAIN:
      FLastErrorDescription := 'WSATRY_AGAIN';
    WSANO_RECOVERY:
      FLastErrorDescription := 'WSANO_RECOVERY';
    WSANO_DATA:
      FLastErrorDescription := 'WSANO_DATA';
    WSA_QOS_RECEIVERS:
      FLastErrorDescription := 'WSA_QOS_RECEIVERS';
    WSA_QOS_SENDERS:
      FLastErrorDescription := 'WSA_QOS_SENDERS';
    WSA_QOS_NO_SENDERS:
      FLastErrorDescription := 'WSA_QOS_NO_SENDERS';
    WSA_QOS_NO_RECEIVERS:
      FLastErrorDescription := 'WSA_QOS_NO_RECEIVERS';
    WSA_QOS_REQUEST_CONFIRMED:
      FLastErrorDescription := 'WSA_QOS_REQUEST_CONFIRMED';
    WSA_QOS_ADMISSION_FAILURE:
      FLastErrorDescription := 'WSA_QOS_ADMISSION_FAILURE';
    WSA_QOS_POLICY_FAILURE:
      FLastErrorDescription := 'WSA_QOS_POLICY_FAILURE';
    WSA_QOS_BAD_STYLE:
      FLastErrorDescription := 'WSA_QOS_BAD_STYLE';
    WSA_QOS_BAD_OBJECT:
      FLastErrorDescription := 'WSA_QOS_BAD_OBJECT';
    WSA_QOS_TRAFFIC_CTRL_ERROR:
      FLastErrorDescription := 'WSA_QOS_TRAFFIC_CTRL_ERROR';
    WSA_QOS_GENERIC_ERROR:
      FLastErrorDescription := 'WSA_QOS_GENERIC_ERROR';
    WSA_QOS_ESERVICETYPE:
      FLastErrorDescription := 'WSA_QOS_ESERVICETYPE';
    WSA_QOS_EFLOWSPEC:
      FLastErrorDescription := 'WSA_QOS_EFLOWSPEC';
    WSA_QOS_EPROVSPECBUF:
      FLastErrorDescription := 'WSA_QOS_EPROVSPECBUF';
    WSA_QOS_EFILTERSTYLE:
      FLastErrorDescription := 'WSA_QOS_EFILTERSTYLE';
    WSA_QOS_EFILTERTYPE:
      FLastErrorDescription := 'WSA_QOS_EFILTERTYPE';
    WSA_QOS_EFILTERCOUNT:
      FLastErrorDescription := 'WSA_QOS_EFILTERCOUNT';
    WSA_QOS_EOBJLENGTH:
      FLastErrorDescription := 'WSA_QOS_EOBJLENGTH';
    WSA_QOS_EFLOWCOUNT:
      FLastErrorDescription := 'WSA_QOS_EFLOWCOUNT';
    WSA_QOS_EUNKOWNPSOBJ:
      FLastErrorDescription := 'WSA_QOS_EUNKOWNPSOBJ';
    WSA_QOS_EPOLICYOBJ:
      FLastErrorDescription := 'WSA_QOS_EPOLICYOBJ';
    WSA_QOS_EFLOWDESC:
      FLastErrorDescription := 'WSA_QOS_EFLOWDESC';
    WSA_QOS_EPSFLOWSPEC:
      FLastErrorDescription := 'WSA_QOS_EPSFLOWSPEC';
    WSA_QOS_EPSFILTERSPEC:
      FLastErrorDescription := 'WSA_QOS_EPSFILTERSPEC';
    WSA_QOS_ESDMODEOBJ:
      FLastErrorDescription := 'WSA_QOS_ESDMODEOBJ';
    WSA_QOS_ESHAPERATEOBJ:
      FLastErrorDescription := 'WSA_QOS_ESHAPERATEOBJ';
    WSA_QOS_RESERVED_PETYPE:
      FLastErrorDescription := 'WSA_QOS_RESERVED_PETYPE';
    else
      FLastErrorDescription := 'Socket error (' + IntToStr(FSocketHandle) + ')'
  end;

  FIsErrorCaused := True;
  Result := True;
end;

(* public *)

procedure TSocket.Connect(const Host: string; const Port: Integer; const TryAllIP: Boolean = True);
var
  AddressList: TAddressList;
  SocketAddress: TSockAddr;
  ResultCode: Integer;
  i: Integer;
begin
  if FSocketHandle = Winapi.Winsock2.INVALID_SOCKET then
    Initialize();

  ResultCode := -1;
  AddressList := GetAddressList(Host);

  if AddressList.Count = 0 then
  begin
    FLastErrorDescription := 'Could not find host ' + Host + ':' + IntToStr(Port);

    Exit;
  end;

  for i := 0 to AddressList.Count - 1 do
  begin
    SocketAddress := GetSocketAddress(AddressList.Addresses[i], Port);
    ResultCode := Winapi.Winsock2.WSAConnect(FSocketHandle, SocketAddress, SizeOf(SocketAddress), nil, nil, nil, nil);

    if (ResultCode = 0) or (not TryAllIP) then
      Break;
  end;

  if not IsError(ResultCode) then
    FConnected := True;
end;

procedure TSocket.ClearError();
begin
  FIsErrorCaused := False;
  FLastErrorCode := 0;
  FLastErrorDescription := '';

  Winapi.Winsock2.WSASetLastError(FLastErrorCode);
end;

procedure TSocket.Close();
begin
  Winapi.Winsock2.shutdown(FSocketHandle, Winapi.Winsock2.SD_BOTH);
  Winapi.Winsock2.closesocket(FSocketHandle);

  FSocketHandle := Winapi.Winsock2.INVALID_SOCKET;
end;

function TSocket.GetAddressList(const Host: string): TAddressList;
var
  HostEnt: PHostEnt;
  Address: PInAddr;
  AddressList: TAddressList;
begin
  HostEnt := Winapi.Winsock2.gethostbyname(PAnsiChar(AnsiString(Host)));
  AddressList.Host := Host;
  AddressList.Addresses := [];
  AddressList.IpAddresses := [];
  AddressList.Count := 0;

  if HostEnt <> nil then
  begin
    while True do
    begin
      Address := PInAddr(HostEnt.h_addr_list[AddressList.Count]);

      if Address = nil then
        Break;

      AddressList.Addresses := AddressList.Addresses + [Address.S_addr];
      AddressList.IpAddresses := AddressList.IpAddresses + [IntToStr(Address.S_un_b.s_b1) + '.' + IntToStr(Address.S_un_b.s_b2) + '.' + IntToStr(Address.S_un_b.s_b3) + '.' + IntToStr(Address.S_un_b.s_b4)];

      Inc(AddressList.Count);
    end;
  end;

  Result := AddressList;
end;

function TSocket.Receive(const Length: Integer): TArray<Byte>;
var
  Data: TArray<Byte>;
  ResultCode: Integer;
begin
  SetLength(Data, Length);

  Result := [];
  ResultCode := Winapi.Winsock2.recv(FSocketHandle, Data[0], Length, 0);

  if IsError(ResultCode) then
    Exit;

  Result := Data;
end;

procedure TSocket.Send(const Data: TArray<Byte>; const Length: Integer);
var
  ResultCode: Integer;
begin
  ResultCode := Winapi.Winsock2.send(FSocketHandle, Data[0], Length, 0);

  IsError(ResultCode);
end;

end.
