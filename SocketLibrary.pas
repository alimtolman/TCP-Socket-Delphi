unit SocketLibrary;

interface

uses
  SysUtils, Winapi.Winsock2;

type
  TSocketHandle = Winapi.WinSock2.TSocket;

  TAddressList = record
  public
    Host: string;
    Port: Integer;
    Addresses: TArray<Cardinal>;
    IpAddresses: TArray<string>;
    Count: Integer;
  end;

  TSocketClient = class
  private
    FConnected: Boolean;
    FIsErrorCaused: Boolean;
    FLastError: string;
    FLastErrorCode: Integer;
    FSocketHandle: TSocketHandle;
    FTimeout: Integer;
    (* functions *)
    function GetAvailableCount(): Cardinal;
    function GetCanRead(): Boolean;
    function GetCanWrite(): Boolean;
    function GetSocketAddress(const Address: Cardinal; const Port: Integer): TSockAddr;
    function Initialize(): Boolean;
    function IsError(const ErrorCode: Integer): Boolean;
    procedure SetTimeout(const Value: Integer);
  public
    constructor Create();
    destructor Destroy(); override;
    procedure Connect(const Host: string; const Port: Integer; const TryAllIP: Boolean = True);
    procedure ClearError();
    procedure Close();
    function GetAddressList(const Host: string; const Port: Integer): TAddressList;
    function Receive(const Length: Integer): TArray<Byte>;
    procedure Send(const Data: TArray<Byte>; const Length: Integer);
    (* properties *)
    property Available: Cardinal read GetAvailableCount;
    property CanRead: Boolean read GetCanRead;
    property CanWrite: Boolean read GetCanWrite;
    property Connected: Boolean read FConnected;
    property Handle: TSocketHandle read FSocketHandle;
    property IsErrorCaused: Boolean read FIsErrorCaused;
    property LastError: string read FLastError;
    property Timeout: Integer read FTimeout write SetTimeout;
  end;

implementation

{ TSocketClient }

constructor TSocketClient.Create();
var
  wd: WSAData;
begin
  Winapi.Winsock2.WSAStartup(Winapi.Winsock2.WINSOCK_VERSION, wd);

  FConnected := False;
  FSocketHandle := Winapi.Winsock2.INVALID_SOCKET;
  FTimeout := 15000;

  ClearError();
  Initialize();
  SetTimeout(FTimeout);
end;

destructor TSocketClient.Destroy();
begin
  Close();
  Winapi.Winsock2.WSACleanup();
end;

(* private *)

function TSocketClient.GetAvailableCount(): Cardinal;
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

function TSocketClient.GetCanRead(): Boolean;
var
  TimeVal: TTimeVal;
  FdSet: TFdSet;
  ResultCode: Integer;
begin
  Result := False;
  TimeVal.tv_sec := FTimeout div 1000;
  TimeVal.tv_usec := (FTimeout mod 1000) * 1000;

  FdSet.fd_count := 1;
  FdSet.fd_array[0] := FSocketHandle;

  ResultCode := Winapi.Winsock2.select(0, @FdSet, nil, nil, @TimeVal);

  if IsError(ResultCode) then
    Exit;

  Result := ResultCode > 0;
end;

function TSocketClient.GetCanWrite(): Boolean;
var
  TimeVal: TTimeVal;
  FdSet: TFdSet;
  ResultCode: Integer;
begin
  Result := False;
  TimeVal.tv_sec := FTimeout div 1000;
  TimeVal.tv_usec := (FTimeout mod 1000) * 1000;

  FdSet.fd_count := 1;
  FdSet.fd_array[0] := FSocketHandle;

  ResultCode := Winapi.Winsock2.select(0, nil, @FdSet, nil, @TimeVal);

  if IsError(ResultCode) then
    Exit;

  Result := ResultCode > 0;
end;

function TSocketClient.GetSocketAddress(const Address: Cardinal; const Port: Integer): TSockAddr;
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

function TSocketClient.Initialize(): Boolean;
begin
  Result := True;
  FSocketHandle := Winapi.Winsock2.WSASocket(Winapi.Winsock2.AF_INET, Winapi.Winsock2.SOCK_STREAM, Winapi.Winsock2.IPPROTO_TCP, nil, 0, Winapi.Winsock2.WSA_FLAG_OVERLAPPED);

  if FSocketHandle = Winapi.Winsock2.INVALID_SOCKET then
    Result := not IsError(Winapi.Winsock2.SOCKET_ERROR);
end;

function TSocketClient.IsError(const ErrorCode: Integer): Boolean;
begin
  Result := False;

  if ErrorCode <> Winapi.Winsock2.SOCKET_ERROR then
    Exit;

  FLastErrorCode := Winapi.Winsock2.WSAGetLastError();

  case FLastErrorCode of
    0: Exit;
    WSA_INVALID_HANDLE: FLastError := 'WSA_INVALID_HANDLE';
    WSA_NOT_ENOUGH_MEMORY: FLastError := 'WSA_NOT_ENOUGH_MEMORY';
    WSA_INVALID_PARAMETER: FLastError := 'WSA_INVALID_PARAMETER';
    WSA_OPERATION_ABORTED: FLastError := 'WSA_OPERATION_ABORTED';
    WSA_IO_INCOMPLETE: FLastError := 'WSA_IO_INCOMPLETE';
    WSA_IO_PENDING: FLastError := 'WSA_IO_PENDING';
    WSAEINTR: FLastError := 'WSAEINTR';
    WSAEBADF: FLastError := 'WSAEBADF';
    WSAEACCES: FLastError := 'WSAEACCES';
    WSAEFAULT: FLastError := 'WSAEFAULT';
    WSAEINVAL: FLastError := 'WSAEINVAL';
    WSAEMFILE: FLastError := 'WSAEMFILE';
    WSAEWOULDBLOCK: FLastError := 'WSAEWOULDBLOCK';
    WSAEINPROGRESS: FLastError := 'WSAEINPROGRESS';
    WSAEALREADY: FLastError := 'WSAEALREADY';
    WSAENOTSOCK: FLastError := 'WSAENOTSOCK';
    WSAEDESTADDRREQ: FLastError := 'WSAEDESTADDRREQ';
    WSAEMSGSIZE: FLastError := 'WSAEMSGSIZE';
    WSAEPROTOTYPE: FLastError := 'WSAEPROTOTYPE';
    WSAENOPROTOOPT: FLastError := 'WSAENOPROTOOPT';
    WSAEPROTONOSUPPORT: FLastError := 'WSAEPROTONOSUPPORT';
    WSAESOCKTNOSUPPORT: FLastError := 'WSAESOCKTNOSUPPORT';
    WSAEOPNOTSUPP: FLastError := 'WSAEOPNOTSUPP';
    WSAEPFNOSUPPORT: FLastError := 'WSAEPFNOSUPPORT';
    WSAEAFNOSUPPORT: FLastError := 'WSAEAFNOSUPPORT';
    WSAEADDRINUSE: FLastError := 'WSAEADDRINUSE';
    WSAEADDRNOTAVAIL: FLastError := 'WSAEADDRNOTAVAIL';
    WSAENETDOWN: FLastError := 'WSAENETDOWN';
    WSAENETUNREACH: FLastError := 'WSAENETUNREACH';
    WSAENETRESET: FLastError := 'WSAENETRESET';
    WSAECONNABORTED: FLastError := 'WSAECONNABORTED';
    WSAECONNRESET: FLastError := 'WSAECONNRESET';
    WSAENOBUFS: FLastError := 'WSAENOBUFS';
    WSAEISCONN: FLastError := 'WSAEISCONN';
    WSAENOTCONN: FLastError := 'WSAENOTCONN';
    WSAESHUTDOWN: FLastError := 'WSAESHUTDOWN';
    WSAETOOMANYREFS: FLastError := 'WSAETOOMANYREFS';
    WSAETIMEDOUT: FLastError := 'WSAETIMEDOUT';
    WSAECONNREFUSED: FLastError := 'WSAECONNREFUSED';
    WSAELOOP: FLastError := 'WSAELOOP';
    WSAENAMETOOLONG: FLastError := 'WSAENAMETOOLONG';
    WSAEHOSTDOWN: FLastError := 'WSAEHOSTDOWN';
    WSAEHOSTUNREACH: FLastError := 'WSAEHOSTUNREACH';
    WSAENOTEMPTY: FLastError := 'WSAENOTEMPTY';
    WSAEPROCLIM: FLastError := 'WSAEPROCLIM';
    WSAEUSERS: FLastError := 'WSAEUSERS';
    WSAEDQUOT: FLastError := 'WSAEDQUOT';
    WSAESTALE: FLastError := 'WSAESTALE';
    WSAEREMOTE: FLastError := 'WSAEREMOTE';
    WSASYSNOTREADY: FLastError := 'WSASYSNOTREADY';
    WSAVERNOTSUPPORTED: FLastError := 'WSAVERNOTSUPPORTED';
    WSANOTINITIALISED: FLastError := 'WSANOTINITIALISED';
    WSAEDISCON: FLastError := 'WSAEDISCON';
    WSAENOMORE: FLastError := 'WSAENOMORE';
    WSAECANCELLED: FLastError := 'WSAECANCELLED';
    WSAEINVALIDPROCTABLE: FLastError := 'WSAEINVALIDPROCTABLE';
    WSAEINVALIDPROVIDER: FLastError := 'WSAEINVALIDPROVIDER';
    WSAEPROVIDERFAILEDINIT: FLastError := 'WSAEPROVIDERFAILEDINIT';
    WSASYSCALLFAILURE: FLastError := 'WSASYSCALLFAILURE';
    WSASERVICE_NOT_FOUND: FLastError := 'WSASERVICE_NOT_FOUND';
    WSATYPE_NOT_FOUND: FLastError := 'WSATYPE_NOT_FOUND';
    WSA_E_NO_MORE: FLastError := 'WSA_E_NO_MORE';
    WSA_E_CANCELLED: FLastError := 'WSA_E_CANCELLED';
    WSAEREFUSED: FLastError := 'WSAEREFUSED';
    WSAHOST_NOT_FOUND: FLastError := 'WSAHOST_NOT_FOUND';
    WSATRY_AGAIN: FLastError := 'WSATRY_AGAIN';
    WSANO_RECOVERY: FLastError := 'WSANO_RECOVERY';
    WSANO_DATA: FLastError := 'WSANO_DATA';
    WSA_QOS_RECEIVERS: FLastError := 'WSA_QOS_RECEIVERS';
    WSA_QOS_SENDERS: FLastError := 'WSA_QOS_SENDERS';
    WSA_QOS_NO_SENDERS: FLastError := 'WSA_QOS_NO_SENDERS';
    WSA_QOS_NO_RECEIVERS: FLastError := 'WSA_QOS_NO_RECEIVERS';
    WSA_QOS_REQUEST_CONFIRMED: FLastError := 'WSA_QOS_REQUEST_CONFIRMED';
    WSA_QOS_ADMISSION_FAILURE: FLastError := 'WSA_QOS_ADMISSION_FAILURE';
    WSA_QOS_POLICY_FAILURE: FLastError := 'WSA_QOS_POLICY_FAILURE';
    WSA_QOS_BAD_STYLE: FLastError := 'WSA_QOS_BAD_STYLE';
    WSA_QOS_BAD_OBJECT: FLastError := 'WSA_QOS_BAD_OBJECT';
    WSA_QOS_TRAFFIC_CTRL_ERROR: FLastError := 'WSA_QOS_TRAFFIC_CTRL_ERROR';
    WSA_QOS_GENERIC_ERROR: FLastError := 'WSA_QOS_GENERIC_ERROR';
    WSA_QOS_ESERVICETYPE: FLastError := 'WSA_QOS_ESERVICETYPE';
    WSA_QOS_EFLOWSPEC: FLastError := 'WSA_QOS_EFLOWSPEC';
    WSA_QOS_EPROVSPECBUF: FLastError := 'WSA_QOS_EPROVSPECBUF';
    WSA_QOS_EFILTERSTYLE: FLastError := 'WSA_QOS_EFILTERSTYLE';
    WSA_QOS_EFILTERTYPE: FLastError := 'WSA_QOS_EFILTERTYPE';
    WSA_QOS_EFILTERCOUNT: FLastError := 'WSA_QOS_EFILTERCOUNT';
    WSA_QOS_EOBJLENGTH: FLastError := 'WSA_QOS_EOBJLENGTH';
    WSA_QOS_EFLOWCOUNT: FLastError := 'WSA_QOS_EFLOWCOUNT';
    WSA_QOS_EUNKOWNPSOBJ: FLastError := 'WSA_QOS_EUNKOWNPSOBJ';
    WSA_QOS_EPOLICYOBJ: FLastError := 'WSA_QOS_EPOLICYOBJ';
    WSA_QOS_EFLOWDESC: FLastError := 'WSA_QOS_EFLOWDESC';
    WSA_QOS_EPSFLOWSPEC: FLastError := 'WSA_QOS_EPSFLOWSPEC';
    WSA_QOS_EPSFILTERSPEC: FLastError := 'WSA_QOS_EPSFILTERSPEC';
    WSA_QOS_ESDMODEOBJ: FLastError := 'WSA_QOS_ESDMODEOBJ';
    WSA_QOS_ESHAPERATEOBJ: FLastError := 'WSA_QOS_ESHAPERATEOBJ';
    WSA_QOS_RESERVED_PETYPE: FLastError := 'WSA_QOS_RESERVED_PETYPE';
    else
      FLastError := 'Socket error (' + IntToStr(FSocketHandle) + ')'
  end;

  FIsErrorCaused := True;
  Result := True;
end;

procedure TSocketClient.SetTimeout(const Value: Integer);
var
  TimeVal: TTimeVal;
  ResultCode: Integer;
begin
  if Value < 0 then
    Exit;

  TimeVal.tv_sec := Value;
  TimeVal.tv_usec := (Value mod 1000) * 1000;

  ResultCode := Winapi.Winsock2.setsockopt(FSocketHandle, Winapi.Winsock2.SOL_SOCKET, Winapi.Winsock2.SO_RCVTIMEO, PAnsiChar(@TimeVal), SizeOf(TimeVal));

  IsError(ResultCode);

  ResultCode := Winapi.Winsock2.setsockopt(FSocketHandle, Winapi.Winsock2.SOL_SOCKET, Winapi.Winsock2.SO_SNDTIMEO, PAnsiChar(@TimeVal), SizeOf(TimeVal));

  IsError(ResultCode);
end;

(* public *)

procedure TSocketClient.Connect(const Host: string; const Port: Integer; const TryAllIP: Boolean = True);
var
  AddressList: TAddressList;
  SocketAddress: TSockAddr;
  ResultCode: Integer;
  i: Integer;
begin
  if (FConnected) or (Host.IsEmpty) or (Port < 0) then
    Exit;

  if (FSocketHandle = Winapi.Winsock2.INVALID_SOCKET) and (not Initialize()) then
    Exit;

  ResultCode := -1;
  AddressList := GetAddressList(Host, Port);

  if AddressList.Count = 0 then
  begin
    FLastError := 'Could not find host ' + Host + ':' + IntToStr(Port);
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

procedure TSocketClient.ClearError();
begin
  FIsErrorCaused := False;
  FLastErrorCode := 0;
  FLastError := '';

  Winapi.Winsock2.WSASetLastError(FLastErrorCode);
end;

procedure TSocketClient.Close();
begin
  Winapi.Winsock2.shutdown(FSocketHandle, Winapi.Winsock2.SD_BOTH);
  Winapi.Winsock2.closesocket(FSocketHandle);

  FSocketHandle := Winapi.Winsock2.INVALID_SOCKET;
end;

function TSocketClient.GetAddressList(const Host: string; const Port: Integer): TAddressList;
var
  HostEnt: PHostEnt;
  Address: PInAddr;
  AddressList: TAddressList;
begin
  HostEnt := Winapi.Winsock2.gethostbyname(PAnsiChar(AnsiString(Host)));
  AddressList.Host := Host;
  AddressList.Port := Port;
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

function TSocketClient.Receive(const Length: Integer): TArray<Byte>;
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

procedure TSocketClient.Send(const Data: TArray<Byte>; const Length: Integer);
var
  ResultCode: Integer;
begin
  ResultCode := Winapi.Winsock2.send(FSocketHandle, Data[0], Length, 0);

  IsError(ResultCode);
end;

end.
