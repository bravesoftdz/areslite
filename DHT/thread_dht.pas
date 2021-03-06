{
 this file is part of Ares
 Aresgalaxy ( http://aresgalaxy.sourceforge.net )

  This program is free software; you can redistribute it and/or
  modify it under the terms of the GNU General Public License
  as published by the Free Software Foundation; either
  version 2 of the License, or (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

*****************************************************************
 The following delphi code is based on Emule (0.46.2.26) Kad's implementation http://emule.sourceforge.net
 and KadC library http://kadc.sourceforge.net/
*****************************************************************
 }

{
Description:
DHT worker thread
}


unit thread_dht;

interface

uses
  classes, classes2, sysutils, dhtconsts, dhttypes, windows, dhtutils,
  dhtzones, winsock, blcksock, synsock, zlib, int128, math, dhthashlist,
  dhtcontact, dhtsearchManager, activex {coinitialize}, hashlist, keywfunc,
  types_supernode, class_cmdlist, ares_types, ares_objects;

type
  tthread_dht = class(tthread)
  protected
    GlobHashValue: string;
    GlobcrcSha1: word;
    GlobPfile: precord_file_library;

    buffer_parse_keywords: array[0..399] of byte;
    keyword_buffer: array[0..KEYWORD_LEN_MAX - 1] of byte;
    glb_lst_keywords: tmylist;
    firewallChecks: tmylist;
    downloadHashes: tmylist;
    rfield_title: ^record_field;
    rfield_artist: ^record_field;
    rfield_album: ^record_field;
    rfield_category: ^record_field;
    rfield_date: ^record_field;
    rfield_language: ^record_field;
    wanted_search: Twanted_search;
    m_searchresults: TMylist;

    m_nextExpireLists,
    m_nextExpirePartialSources,
    m_lastContact,
    m_bigTimer,
    m_nextSelfLookup,
    m_lastSecond,
    m_startTime,
    lastBootstrap,
    m_nextBackUpNodes,
    m_nextCacheCheck,
    nowt: cardinal;

    m_global_ip: cardinal;
    m_global_LANIP: cardinal;
    m_global_port: word;

    m_numFirewallResults, m_notFirewalledMessages: byte;
    m_lastFirewallCheck: cardinal;

    procedure get_library_file; //sync
    function handler_publish_keyFile(buff: pbytearray; lenPayload: integer; FromIp: cardinal; TCPPort: word): boolean;
    procedure DHT_ParseFileInfo(nresult: precord_search_result; buff: PbyteArray; len: integer);
    procedure DHT_AddSrcResults;
    procedure FreeResultSearch(nresult: precord_search_result);
    procedure checkOutHashSearches;
    procedure checkOutKeySearches;
    function FindDownloadSha1Treeview(const HashSha1: string): Boolean;
    function FindDlHash(crcsha1: word; HashSha1: string): precord_download_hash;

    function DHT_ParseKeywords(pfile: precord_dht_storedfile; len_keywords: integer): boolean;
    procedure DHT_parseSearch(offset: integer; var complex: string);
    function DHT_HasEnoughKeys: boolean;
    procedure DHT_ParseComplexField(complex: string);
    procedure DHT_localSearch(var OffsetWrite: integer; var resultCount: integer);
    function DHT_FindRarestKeyword: PDHTKeyword;
    function DHT_matchFile(pfile: precord_dht_storedfile; ShouldMatch: boolean): boolean;
    procedure DHT_SerializeResult(pfile: precord_dht_storedfile; var offsetWrite: integer);
    procedure DHT_SendKeywordResult(var offsetWrite: integer);
    procedure check_shareHashFile;
    procedure check_shareKeyFile;
    procedure check_GUI; //sync

    procedure fill_random_id;
    procedure AddContacts(data: pbytearray; len_data: integer; numContacts: integer);

    procedure check_events;
    procedure check_second;
    procedure check_bootstrap; // sync

    procedure execute; override;
    procedure shutdown;
    procedure init_vars;
    procedure create_listener;
    procedure udp_Receive;

    procedure processBootstrapRequest;
    procedure processBootstrapResponse;

    procedure processHelloRequest;
    procedure processHelloResponse;

    procedure processSearchIDRequest(simple: boolean = true);
    procedure processSearchIDResponse;

    procedure processSearchKeyRequest;
    procedure processSearchKeyResponse;
    procedure processPublishKeyRequest;
    procedure processPublishKeyResponse;

    procedure processPublishHashRequest;
    procedure processPublishHashResponse;
    procedure processSearchHashRequest;
    procedure processSearchPartialSourceHashRequest;
    procedure processSearchPartialSourceHashResponse;

    procedure processSearchHashResponse;

    procedure DHT_SendPartialSources(phash: precord_dht_hash; tcpport: word);

    procedure processIpRequest;
    procedure processCachesRequest;
    procedure processCachesResponse;

    procedure processFirewallCheckRequest;
    procedure FirewallChecksDeal;
    procedure processFirewallCheckStart; //sync
    procedure SendCheckFirewall;
    procedure processFirewallCheckResult;
    procedure SyncNotFirewalled;

    procedure AddContact(data: pbytearray; len_data: integer; ip: cardinal; port: word; tcpport: word; fromHelloReq: boolean);
  end;

var
  DHT_hash_sha1_global: array[0..19] of byte;
  DHT_crcsha1_global: word;
  DHT_CacheCheckIp: cardinal;

implementation

uses
  vars_global, helper_ipfunc, helper_registry, helper_datetime,
  dhtsocket, utility_ares, DHTsearch, helper_mimetypes, const_ares,
  helper_strings, securehash, helper_stringfinal, dhtkeywords,
  helper_share_misc, helper_search_gui, helper_visual_headers, mysupernodes,
  ufrmmain, comettrees, helper_ares_cacheservers, helper_download_misc,DebugLog;


procedure tthread_dht.fill_random_id; //synch
var
  i: integer;
  guid: Tguid;
  buffer: array[0..15] of byte;
begin
  coinitialize(nil);
  cocreateguid(guid);
  couninitialize;

  move(guid, buffer[0], 16);

 //shuffle a bit
  for i := 0 to 15 do buffer[i] := buffer[i] + random(256);
  for i := 15 downto 0 do buffer[i] := buffer[i] + random(256);
  for i := 0 to 15 do buffer[i] := buffer[i] + random(256);
  for i := 15 downto 0 do buffer[i] := buffer[i] + random(256);

  move(buffer[0], DHTme[0], 4);
  move(buffer[4], DHTme[1], 4);
  move(buffer[8], DHTme[2], 4);
  move(buffer[12], DHTme[3], 4);

end;

procedure tthread_dht.init_vars;
var
  zero: CU_INT128;
begin
 //DHT_buffer:=AllocMem(sizeof(TDHTBuffer));

  FillChar(DHT_RemoteSin, Sizeof(DHT_RemoteSin), 0);
  DHT_events := tmylist.create;

  db_DHT_hashFile           := ThashList.create(DB_DHTHASH_ITEMS);
  db_DHT_hashPartialSources := ThashList.create(DB_DHTHASHPARTIALSOURCES_ITEMS);
  db_DHT_keywordFile        := THashList.create(DB_DHTKEYFILES_ITEMS);
  db_DHT_keywords           := THashList.create(DB_DHT_KEYWORD_ITEMS);

  glb_lst_keywords := TMylist.create;

  new(rfield_title);
  new(rfield_artist);
  new(rfield_album);
  new(rfield_category);
  new(rfield_date);
  new(rfield_language);

  wanted_search     := TWanted_search.create;

  m_searchresults   := TMyList.create;
  firewallChecks    := Tmylist.create;
  downloadHashes    := tmylist.create;

  m_bigtimer                  := time_now;
  m_startTime                 := m_bigtimer;
  m_lastSecond                := m_bigtimer;
  m_nextExpireLists           := m_bigTimer + MIN2S(60);
  m_nextExpirePartialSources  := m_bigTimer + MIN2S(10);
  m_nextSelfLookup            := m_bigtimer + MIN2S(3);
  m_nextBackUpNodes           := m_bigTimer + MIN2S(10);
  m_nextCacheCheck            := m_bigTimer + MIN2S(4);
  lastBootstrap               := 0;
  m_lastContact               := 0;

  m_numFirewallResults    := 0;
  m_notFirewalledMessages := 0;
  m_lastFirewallCheck     := 0;

  DHT_Searches            := Tmylist.create;

  DHT_availableContacts := 0;
  DHT_SharedFilesCount  := 0;
  DHT_SharedHashCount   := 0;
  DHT_SharedPartialSourcesCount := 0;

  CU_Int128_setValue(@zero, 0);

  // random ID
  synchronize(fill_random_id);
  reg_getDHT_ID;

  DHT_routingZone := TRoutingZone.create;
  DHT_routingZone.init(nil, 0, @zero, false);

  dhtzones.DHT_readnodeFile(vars_global.data_path + '\Data\DHTnodes.dat', DHT_routingZone);
  DHT_routingZone.startTimer;
  
  reg_setDHT_ID; // set it right here   
end;




procedure tthread_dht.create_listener;
var
  sin: TVarSin;
//x:integer;
begin
//while (vars_global.BindIPs='') then
  FillChar(Sin, Sizeof(Sin), 0);
  Sin.sin_family := AF_INET;
  Sin.sin_port := synsock.htons(vars_global.myport);
  Sin.sin_addr.s_addr := 0;

  DHT_socket := synsock.socket(PF_INET, 0, IPPROTO_UDP);

{
 x:=1; other processes are already using our UDP local endpoint?
 synsock.SetSockOpt(DHT_socket, SOL_SOCKET, SO_REUSEADDR, @x, SizeOf(x));
 }

  synsock.Bind(DHT_socket, @Sin, SizeOfVarSin(Sin));
end;

procedure tthread_dht.udp_Receive;
var
  er, len: integer;
  buff: pointer;
  outsize: integer;
begin

  if not TCPSocket_canRead(DHT_socket, 0, er) then exit;
  Len := SizeOf(DHT_RemoteSin);

  DHT_len_recvd := synsock.RecvFrom(DHT_socket,
    DHT_Buffer,
    sizeof(DHT_buffer),
    0,
    @DHT_RemoteSin,
    Len);

  if DHT_len_recvd < 2 then exit;

  if isAntiP2PIP(DHT_remoteSin.sin_addr.S_addr) then exit;
  if ip_firewalled(DHT_remoteSin.sin_addr.S_addr) then exit;
  if probable_fw(DHT_remoteSin.sin_addr.S_addr) then exit;

  if DHT_buffer[0] <> OP_DHT_HEADER then begin

    if DHT_buffer[0] = OP_DHT_PACKEDPROT then begin
      try
        if ZDecompress(@DHT_buffer[2], DHT_len_recvd - 2, buff, outsize) then begin

          DHT_len_recvd := outsize + 2;
          if DHT_len_recvd > sizeof(DHT_buffer) then begin
            FreeMem(buff, outsize);
            exit;
          end else move(buff^, DHT_buffer[2], DHT_len_recvd);

          FreeMem(buff, outsize);
        end;
      except
        outputdebugstring(pchar('dht zlib error'));
        exit;
      end;
    end else exit;

  end;


  m_lastContact := time_now; // prevents > 15 minutes inactivity (see check events)

  try
    case DHT_buffer[1] of

      CMD_DHT_BOOTSTRAP_REQ: processBootstrapRequest;
      CMD_DHT_BOOTSTRAP_RES: processBootstrapResponse;

      CMD_DHT_HELLO_REQ: processHelloRequest;
      CMD_DHT_HELLO_RES: processHelloResponse;

      CMD_DHT_REQID: processSearchIDRequest;
      CMD_DHT_REQID2: processSearchIDRequest(false);
      CMD_DHT_RESID: processSearchIDResponse;

      CMD_DHT_SEARCHKEY_REQ: processSearchKeyRequest;
      CMD_DHT_SEARCHKEY_RES: processSearchKeyResponse;
      CMD_DHT_PUBLISHKEY_REQ: processPublishKeyRequest;
      CMD_DHT_PUBLISHKEY_RES: processPublishKeyResponse;

      CMD_DHT_SEARCHHASH_REQ: processSearchHashRequest; // search and publish
      CMD_DHT_SEARCHHASH_RES: processSearchHashResponse;
      CMD_DHT_SEARCHPARTIALHASH_RES: processSearchPartialSourceHashResponse;
      CMD_DHT_PUBLISHHASH_REQ: processPublishHashRequest;
      CMD_DHT_PUBLISHHASH_RES: processPublishHashResponse;

      CMD_DHT_IPREQ: processIpRequest;
      CMD_DHT_CACHESREQ: processCachesRequest;
      CMD_DHT_CACHESREP: processCachesResponse;

      CMD_DHT_FIREWALLCHECK: processFirewallCheckRequest;
      CMD_DHT_FIREWALLCHECKINPROG: synchronize(processFirewallCheckStart);
      CMD_DHT_FIREWALLCHECKRESULT: processFirewallCheckResult;
    end;
  except
    outputdebugstring(pchar('dht protocol error'));
  end;
  sleep(2);

end;




// remote peer performed a connection test on us and reports us result

procedure tthread_dht.processFirewallCheckResult;
begin
  TRACE('processFirewallCheckResult');
  if DHT_len_recvd < 3 then exit;

  inc(m_numFirewallResults);

  if DHT_Buffer[2] = DHTFIREWALLRESULT_CONNECTED then
    if m_notFirewalledMessages < 250 then inc(m_notFirewalledMessages);

  if m_numFirewallResults >= 3 then
    if m_notFirewalledMessages >= 3 then synchronize(SyncNotFirewalled);
end;

procedure tthread_dht.SyncNotFirewalled;
begin
  vars_global.im_firewalled := false;
end;

//remote client acknowledge our request to perform a test on us and sends back our ip

procedure tthread_dht.processFirewallCheckStart;
begin
  TRACE('processFirewallCheckStart');
  if DHT_len_recvd < 6 then exit;

  move(DHT_Buffer[2], vars_global.localipC, 4);
  vars_global.localip := ipint_to_dotstring(vars_global.localipC);
end;

// send connection test request to remote peer (every time we need it and have a fresh hello response)

procedure tthread_dht.SendCheckFirewall;
begin
  if gettickcount - m_lastFirewallCheck < 1000 then exit;
  m_lastFirewallCheck := gettickcount;

  DHT_len_tosend := 4;
  DHT_Buffer[1] := CMD_DHT_FIREWALLCHECK;
  move(vars_global.myport, DHT_Buffer[2], 2);
  DHT_send(DHT_remoteSin.sin_addr.S_addr, synsock.ntohs(DHT_remoteSin.sin_port), false);
end;


// remote peer asks us to check his connection by attempting to connect (TCP) back to him

procedure tthread_dht.processFirewallCheckRequest;
var
  firewallCheck: precord_DHT_firewallcheck;
  er: integer;
begin
  TRACE('processFirewallCheckRequest');
  if DHT_len_recvd < 4 then exit;


  firewallCheck := AllocMem(sizeof(record_DHT_Firewallcheck));
  with firewallCheck^ do begin
    Remoteip := DHT_remoteSin.sin_addr.S_addr;
    RemoteUDPPort := synsock.ntohs(DHT_remoteSin.sin_port);
    move(DHT_Buffer[2], RemoteTCPPort, 2);
    started := gettickcount;
    sockt := TCPSocket_Create;
    TCPSocket_Block(sockt, false);
    TCPSocket_Connect(sockt, ipint_to_dotstring(RemoteIp), inttostr(RemoteTCPPort), er);
  end;
  firewallChecks.add(FirewallCheck);

  move(firewallCheck^.Remoteip, DHT_Buffer[2], 4);
  move(firewallCheck^.RemoteUDPport, DHT_Buffer[6], 2);

  DHT_len_tosend := 8;
  DHT_buffer[1] := CMD_DHT_FIREWALLCHECKINPROG;
  DHT_send(DHT_remoteSin.sin_addr.S_addr, firewallCheck^.RemoteUDPport, false);

end;

// test connections and reports results to remote requestors here

procedure tthread_dht.FirewallChecksDeal;
  procedure sendResult(ip: cardinal; port: word; resultCode: byte);
  begin
    DHT_len_tosend := 7;
    DHT_buffer[1] := CMD_DHT_FIREWALLCHECKRESULT;
    DHT_buffer[2] := resultCode;
    move(ip, DHT_Buffer[3], 4);
    DHT_send(IP, port, false);
  end;
var
  firewallCheck: precord_DHT_firewallcheck;
  i, er: integer;
  tim: cardinal;
begin

  tim := gettickcount;
  i := 0;
  while (i < firewallChecks.count) do begin
    firewallCheck := firewallChecks[i];

    if tim - firewallCheck.started > 15000 then begin
      TCPSocket_Free(firewallCheck^.sockt);
      firewallChecks.delete(i);
      sendResult(firewallCheck^.RemoteIP,
        firewallCheck^.RemoteUDPport,
        DHTFIREWALLRESULT_FAILEDCONNECTION);
      FreeMem(firewallCheck, sizeof(record_DHT_Firewallcheck));
      continue;
    end;

    if not TCPSocket_CanWrite(firewallCheck.sockt, 0, er) then begin
      if ((er <> 0) and (er <> WSAEWOULDBLOCK)) then begin
        TCPSocket_Free(firewallCheck^.sockt);
        firewallChecks.delete(i);
        sendResult(firewallCheck^.RemoteIP,
          firewallCheck^.RemoteUDPport,
          DHTFIREWALLRESULT_FAILEDCONNECTION);
        FreeMem(firewallCheck, sizeof(record_DHT_Firewallcheck));
      end else inc(i);
      continue;
    end;


    TCPSocket_Free(firewallCheck^.sockt);
    firewallChecks.delete(i);
    sendResult(firewallCheck^.RemoteIP,
      firewallCheck^.RemoteUDPport,
      DHTFIREWALLRESULT_CONNECTED);
    FreeMem(firewallCheck, sizeof(record_DHT_Firewallcheck));
  end;

end;

// clients wants some fresh cacheservers' addresses

procedure tthread_dht.processCachesRequest;
var
  port: word;
  len: integer;
begin
  TRACE('processCachesRequest');
  helper_ares_cacheservers.cache_get_20hosts(@DHT_buffer[2], len);

  if len >= 4 then begin
    port := synsock.ntohs(DHT_remoteSin.sin_port);
    DHT_len_tosend := 2 + len;
    DHT_buffer[1] := CMD_DHT_CACHESREP;
    DHT_send(DHT_remoteSin.sin_addr.S_addr, port, false);
  end;

end;

// fresh cache servers arrived from remote host

procedure tthread_dht.processCachesResponse;
var
  datum: string;
begin
  TRACE('processCachesResponse');
  if DHT_len_recvd < 6 then exit;
  if DHT_len_recvd > 182 then exit;
  if cardinal(DHT_remoteSin.sin_addr.S_addr) <> DHT_CacheCheckIp then exit;

  m_nextCacheCheck := nowt + HR2S(24);

  setLength(datum, DHT_Len_recvd - 2);
  move(DHT_Buffer[2], datum[1], length(datum));
  helper_ares_cacheservers.cache_add_cache_host_patch(datum, 4);
end;

// client wants to know his IP

procedure tthread_dht.processIpRequest;
var
  port: word;
  ip: cardinal;
begin
  TRACE('processIpRequest');
  port := synsock.ntohs(DHT_remoteSin.sin_port);
  ip := DHT_remoteSin.sin_addr.S_addr;

  move(ip, DHT_Buffer[2], 4);
  move(port, DHT_Buffer[6], 2);

  DHT_len_tosend := 8;
  DHT_buffer[1] := CMD_DHT_IPREP;
  DHT_send(DHT_remoteSin.sin_addr.S_addr, port, false);
end;

// client need fresh DHT hosts

procedure tthread_dht.processBootstrapRequest;
var
  port: word;
  contacts: Tmylist;
  numContacts: word;
  c: TContact;
  offset: integer;
begin
  TRACE('processBootstrapRequest');
  if DHT_len_recvd <> 27 then exit;
  try

    port := synsock.ntohs(DHT_remoteSin.sin_port);

 // Add the sender to the list of contacts
    addContact(@DHT_buffer[2], DHT_len_recvd - 2, DHT_remoteSin.sin_addr.S_addr, port, 0, true);

 // Get some contacts to return
    contacts := tmylist.create;
    DHT_getBootstrapContacts(DHT_RoutingZone, contacts, 20);
    numContacts := 1 + contacts.count;

 // Create response packet
 //We only collect a max of 20 contacts here.. Max size is 527.
 //2 + 25(20) + 15(1)
  // Write packet info
    offset := 2;
    move(numContacts, DHT_Buffer[offset], 2);

    inc(offset, 2);
    while (contacts.count > 0) do begin
      c := contacts[contacts.count - 1];
      contacts.delete(contacts.count - 1);

      CU_INT128_CopyToBuffer(@c.m_clientID, @DHT_Buffer[offset]);
      move(c.m_ip, DHT_Buffer[offset + 16], 4);
      move(c.m_udpport, DHT_Buffer[offset + 20], 2);
      move(c.m_tcpport, DHT_Buffer[offset + 22], 2);
      DHT_Buffer[offset + 24] := c.m_type;
      inc(offset, 25);
    end;

    contacts.free;

  // send my details now
    CU_INT128_CopyToBuffer(@DHTMe, @DHT_Buffer[offset]);
    move(vars_global.localipC, DHT_Buffer[offset + 16], 4);
    move(vars_global.myport, DHT_Buffer[offset + 20], 2);
    move(vars_global.myport, DHT_Buffer[offset + 22], 2);
    DHT_Buffer[offset + 24] := 0;
    inc(offset, 25);

    DHT_len_tosend := offset;
    DHT_buffer[1] := CMD_DHT_BOOTSTRAP_RES;
    DHT_send(DHT_remoteSin.sin_addr.S_addr, port, false);

  except
  end;
end;


procedure tthread_dht.processBootstrapResponse;
var
  numContacts, port: word;
  offset: integer;
begin
  TRACE('processBootstrapResponse');
  if DHT_len_recvd < 29 then exit;

  try

    offset := 2;
    move(DHT_Buffer[offset], numContacts, 2);

    port := synsock.ntohs(DHT_remoteSin.sin_port);


// Verify packet is expected size
    if DHT_len_recvd <> (4 + (25 * numContacts)) then exit;

    inc(offset, 2);

 // Add these contacts to the list.
    addContacts(@DHT_Buffer[offset], DHT_len_recvd - 4, numContacts);

  // Set contact to alive.
    DHT_RoutingZone.setAlive(DHT_remoteSin.sin_addr.S_addr, port);
  except
  end;
end;


procedure tthread_dht.processHelloRequest;
var
  port: word;
begin
  TRACE('processHelloRequest');
  if DHT_len_recvd <> 27 then exit;
  try
    port := synsock.ntohs(DHT_remoteSin.sin_port);

 // Add the sender to the list of contacts
    addContact(@DHT_buffer[2], DHT_len_recvd - 2, DHT_remoteSin.sin_addr.S_addr, port, 0, true);

    DHT_sendMyDetails(CMD_DHT_HELLO_RES, DHT_remoteSin.sin_addr.S_addr, port);
  except
  end;
end;


procedure tthread_dht.processHelloResponse;
var
  port: word;
begin
  TRACE('processHelloResponse');
  if DHT_len_recvd <> 27 then exit;
  try
    port := synsock.ntohs(DHT_remoteSin.sin_port);
 // Add or Update contact.
    addContact(@DHT_buffer[2], DHT_len_recvd - 2, DHT_remoteSin.sin_addr.S_addr, port, 0, false);

 // Set contact to alive.
    DHT_RoutingZone.setAlive(DHT_remoteSin.sin_addr.S_addr, port);

    if m_numFirewallResults < 3 then SendCheckFirewall;

    if m_nextCacheCheck <= nowt then DHT_SendCacheCheck(DHT_remoteSin.sin_addr.S_addr, port);

  except
  end;
end;


procedure tthread_dht.processSearchIDRequest(simple: boolean = true);
var
  ttype: byte;
  target, distance, check: CU_INT128;
  results: tmylist;
  count, port: word;
  c: TContact;
  i, offset: integer;
begin
  TRACE('processSearchIDRequest');
  if simple then begin
    if DHT_len_recvd <> 34 then exit;
  end else begin
    if DHT_len_recvd <> 34 then exit;
  end;
  try

    port := synsock.ntohs(DHT_remoteSin.sin_port);

    if not simple then begin
      ttype := DHT_Buffer[2];
      ttype := ttype and $1F; //max results
      if ttype = 0 then exit;
      offset := 3;
    end else begin
      ttype := $B;
      offset := 2;
    end;

 //This is the target node trying to be found.
    CU_INT128_copyFromBuffer(@DHT_buffer[offset], @target);
    CU_INT128_FillNXor(@distance, @DHTme, @target); // distance relative to my tree


 //This makes sure we are not mistaken identify. Some client may have fresh installed and have a new hash.
    CU_INT128_copyFromBuffer(@DHT_buffer[offset + 16], @check);
    if check[0] <> DHTme[0] then exit;
    if check[1] <> DHTme[1] then exit;
    if check[2] <> DHTme[2] then exit;
    if check[3] <> DHTme[3] then exit;


 // Get required number close to wanted target
    results := tmylist.create;
    DHT_RoutingZone.getClosestTo(2, @target, @distance, ttype, results);
    count := min(results.count, ttype);

 // Write response
 // Max count is 32. size 817..
 // 16 + 2 + 25(32)
    if not simple then CU_INT128_CopyTobuffer(@target, @DHT_Buffer[2]);
    DHT_buffer[18] := count;

    offset := 19;
    for i := 0 to results.count - 1 do begin
      c := results[i];

      CU_INT128_copytoBuffer(@c.m_clientID, @DHT_buffer[offset]);
     //ReversedIP:=synsock.ntohl(c.m_ip); watch it Kad uses reversed order, we don't
      move(c.m_ip, DHT_buffer[offset + 16], 4);
      move(c.m_udpport, DHT_buffer[offset + 20], 2);
      move(c.m_tcpport, DHT_buffer[offset + 22], 2);
      DHT_buffer[offset + 24] := c.m_type;

      inc(offset, 25);

      if i >= 31 then break;
    end;

    results.free;

    DHT_len_tosend := offset;
    DHT_buffer[1] := CMD_DHT_RESID;
    DHT_send(DHT_remoteSin.sin_addr.S_addr, port, false);

  except
  end;
end;


procedure tthread_dht.processSearchIDResponse;
var
  numContacts: byte;
  i, offset: integer;
  port: word;
  id, targetID, distance: CU_INT128;
  his_ip: cardinal;
  his_tcpport, his_udpport: word;
  ttype: byte;
  c: Tcontact;
  results: tmylist;
  tempContacts: tmylist;
begin
  TRACE('processSearchIDResponse');
  if DHT_len_recvd < 19 then exit;
  try

    numContacts := DHT_buffer[18];
    if DHT_len_recvd <> 19 + (25 * numContacts) then begin
      if ((numContacts <> 32) or (DHT_len_recvd <> 844)) then exit;
    end;

    port := synsock.ntohs(DHT_remoteSin.sin_port);

 // Set contact to alive.
    DHT_RoutingZone.setAlive(DHT_remoteSin.sin_addr.S_addr, port);
    CU_INT128_CopyFromBuffer(@DHT_buffer[2], @targetID); //target ID to be found

    results := tmylist.create;
    tempContacts := tmylist.create;

    offset := 19;
    for i := 1 to numContacts do begin
      CU_INT128_CopyFromBuffer(@DHT_buffer[offset], @id);

      move(DHT_buffer[offset + 16], his_ip, 4);
   //his_ip:=synsock.ntohl(his_ip); //watch it Kad use reversed order, we don't

      if isAntiP2PIP(his_ip) then begin
        inc(offset, 25);
        continue;
      end;
      if ip_Firewalled(his_ip) then begin
        inc(offset, 25);
        continue;
      end;
      if probable_fw(his_ip) then begin
        inc(offset, 25);
        continue;
      end;

      move(DHT_buffer[offset + 20], his_udpport, 2);
      move(DHT_buffer[offset + 22], his_tcpport, 2);
      ttype := DHT_buffer[offset + 24];
      inc(offset, 25);


// *********************  check for duplicates *****************************
      c := DHT_routingZone.FindHost(his_ip);
      if c <> nil then begin
        if ((c.m_clientID[0] <> id[0]) or
          (c.m_clientID[1] <> id[1]) or
          (c.m_clientID[2] <> id[2]) or
          (c.m_clientID[3] <> id[3])) then continue; // already seen this ip but with different ID
      end else begin
        CU_INT128_FillNXor(@distance, @DHTMe, @id);
        c := DHT_routingZone.getContact(@id, @distance);
        if c <> nil then
          if his_ip <> c.m_ip then continue; //already seen ID but with different IP
      end;
// ***************************************************************************


      DHT_routingZone.add(@id, his_ip, his_udpport, his_tcpport, ttype);

      c := Tcontact.create;
      c.init(@id, his_ip, his_udpport, his_tcpport, @DHTme);
      results.add(c);
      tempContacts.add(c);
    end;

    if results.count > 0 then dhtsearchManager.processResponse(@targetID, DHT_remoteSin.sin_addr.S_addr, port, results, tempContacts);
    tempContacts.free;
    results.free;

  except
  end;
end;




procedure tthread_dht.processSearchKeyRequest;
var
  complex: string;
  offSetWrite, numResults: integer;
begin
  TRACE('processSearchKeyRequest');
  if DHT_len_recvd < 11 then exit;
                     {
                       header(5) +
                       typekey(1) +
                       lenkey(1) +
                       crckey(2) +
                       key(>=2)
                     }

  if DHT_len_recvd > 255 then exit; // man get a life ;)

  wanted_search.clear;
  wanted_search.strict := true;

  wanted_search.amime := DHT_Buffer[2];
  if wanted_search.amime > 5 then wanted_search.amime := ARES_MIMESRC_ALL255;


  move(DHT_Buffer[3], wanted_search.search_id[0], 2);

  complex := '';

  DHT_parseSearch(5, complex);

  if not DHT_HasEnoughKeys then exit;
  if wanted_search.strict then DHT_ParseComplexField(complex);



  move(wanted_search.search_id[0], DHT_Buffer[2], 2);
  numResults := 0;
  offsetWrite := 4;

  DHT_localSearch(offSetWrite, numResults);

  if offsetWrite > 4 then DHT_SendKeywordResult(offsetWrite);
end;

procedure tthread_dht.DHT_SerializeResult(pfile: precord_dht_storedfile; var offsetWrite: integer);
var
  lenInfo: word;
begin


  move(pfile^.hashValue[0], DHT_Buffer[offsetWrite], 20);
  inc(offsetWrite, 20);

  DHT_Buffer[offsetWrite] := pfile^.amime;
  inc(offsetWrite);

  move(pfile^.fsize, DHT_Buffer[offsetWrite], 8);
  inc(offsetWrite, 8);

  move(pfile^.param1, DHT_Buffer[offsetWrite], 4);
  inc(offsetWrite, 4);
  move(pfile^.param3, DHT_Buffer[offsetWrite], 4);
  inc(offsetWrite, 4);

  move(pfile^.ip, DHT_Buffer[offsetWrite], 4);
  inc(offsetWrite, 4);
  move(pfile^.port, DHT_Buffer[offsetWrite], 2);
  inc(offsetWrite, 2);

  lenInfo := length(pfile^.info) + 3;
  move(lenInfo, DHT_Buffer[offsetWrite], 2);
  inc(offsetWrite, 2);

  move(pfile^.info[1], DHT_Buffer[offsetWrite], lenInfo - 3);
  inc(offsetWrite, lenInfo - 3);

 // write stats
  DHT_Buffer[offsetWrite] := 1;
  DHT_Buffer[offsetWrite + 1] := TAG_ID_DHT_STATS;
  DHT_Buffer[offsetWrite + 2] := pfile^.count;
  inc(offSetWrite, 3);

  if offsetWrite > 9000 then DHT_SendKeywordResult(offsetWrite);
end;

procedure tthread_dht.DHT_SendKeywordResult(var offsetWrite: integer);
begin
  DHT_len_tosend := offsetWrite;
  DHT_Buffer[1] := CMD_DHT_SEARCHKEY_RES;
  DHT_send(DHT_remoteSin.sin_addr.S_addr, synsock.ntohs(DHT_remoteSin.sin_port), (offSetWrite > 200));


  offsetWrite := 4;
  move(wanted_search.search_id[0], DHT_Buffer[2], 2);
end;

procedure tthread_dht.DHT_localSearch(var OffsetWrite: integer; var resultCount: integer);
var
  KW: PDHTKeyword;
  pItem: PDHTKeywordItem;
  pFile: precord_dht_storedfile;

  ShouldMatch: boolean;
  loops: integer;
begin

  try

    KW := DHT_FindRarestKeyword;
    if KW = nil then exit;

    pItem := KW^.firstitem;
    if pItem = nil then exit;

    ShouldMatch := ((wanted_search.sizecomp <> 0) or
      (wanted_search.param1comp <> 0) or
      (wanted_search.param3comp <> 0));

    loops := 0;

    if ((wanted_search.lista_helper_result.count > 1) or
      (wanted_search.strict) or
      (wanted_search.amime <= 5)) then begin

      while pItem <> nil do begin
        pfile := pItem^.share;
        if not DHT_matchFile(pfile, ShouldMatch) then begin
          inc(loops);
          if (loops mod 100) = 30 then sleep(1);
          pItem := pItem^.next;
          continue;
        end;

        DHT_SerializeResult(pfile, offSetWrite);

        inc(resultCount);
        if resultCount >= DHT_MAX_RETURNEDKEYWORDFILES then exit;

        inc(loops);
        if (loops mod 100) = 30 then sleep(1);
        pItem := pItem^.next;
      end;

    end else begin

      while pItem <> nil do begin
        pfile := pItem^.share;

        DHT_SerializeResult(pfile, offSetWrite);

        inc(resultCount);
        if resultCount >= DHT_MAX_RETURNEDKEYWORDFILES then exit;

        inc(loops);
        if (loops mod 100) = 30 then sleep(1);
        pItem := pItem^.next;
      end;

    end;



  except
  end;
end;



function tthread_dht.DHT_FindRarestKeyword: PDHTKeyword;
var
  kwcrc: word;
  kw: pDHTkeyword;
  keyword: string;
  i, smallest: integer;
begin
  result := nil;

  try
    smallest := 0;


////// SEARCH GENERAL AND EXIT
    if not wanted_search.strict then begin
      for i := 0 to wanted_search.keywords_generali.count - 1 do begin
        keyword := PNapCmd(wanted_search.keywords_generali.Items[i])^.cmd;
        kwcrc := PNapCmd(wanted_search.keywords_generali.Items[i])^.id;
        kw := DHT_KWList_Findkey(pchar(keyword), length(keyword), kwcrc);

        if kw = nil then begin
          result := nil;
          exit;
        end;

        wanted_search.lista_helper_result.add(kw);
        if ((kw.count < smallest) or (smallest = 0)) then begin
          result := kw;
          smallest := kw.count;
        end;
      end;
      exit;
    end;

  except
    exit;
  end;



  try


////// SEARCH TITLE
    if wanted_search.keywords_title.count > 0 then begin

      for i := 0 to wanted_search.keywords_title.count - 1 do begin
        keyword := PNapCmd(wanted_search.keywords_title.Items[i])^.cmd;
        kwcrc := wanted_search.keywords_title.Id(i);
        kw := DHT_KWList_Findkey(pchar(keyword), length(keyword), kwcrc);

        if kw = nil then begin
          result := nil;
          exit;
        end;

        wanted_search.lista_helper_result_title.add(kw);
        if ((kw.count < smallest) or (smallest = 0)) then begin
          result := kw;
          smallest := kw.count;
        end;
      end;
    end;

////// SEARCH ARTISTS
    if wanted_search.keywords_artist.count > 0 then begin

      for i := 0 to wanted_search.keywords_artist.count - 1 do begin
        keyword := PNapCmd(wanted_search.keywords_artist.Items[i])^.cmd;
        kwcrc := PNapCmd(wanted_search.keywords_artist.Items[i])^.id;
        kw := DHT_KWList_Findkey(pchar(keyword), length(keyword), kwcrc);

        if kw = nil then begin
          result := nil;
          exit;
        end;

        wanted_search.lista_helper_result_artist.add(kw);
        if ((kw.count < smallest) or (smallest = 0)) then begin
          result := kw;
          smallest := kw.count;
        end;
      end;
    end;

////// SEARCH ALBUMS
    if wanted_search.keywords_album.count > 0 then begin

      for i := 0 to wanted_search.keywords_album.count - 1 do begin
        keyword := PNapCmd(wanted_search.keywords_album.Items[i])^.cmd;
        kwcrc := PNapCmd(wanted_search.keywords_album.Items[i])^.id;
        kw := DHT_KWList_Findkey(pchar(keyword), length(keyword), kwcrc);

        if kw = nil then begin
          result := nil;
          exit;
        end;

        wanted_search.lista_helper_result_album.add(kw);
        if ((kw.count < smallest) or (smallest = 0)) then begin
          result := kw;
          smallest := kw.count;
        end;
      end;
    end;

////// SEARCH CATEGORY
    if wanted_search.keywords_category.count > 0 then begin

      for i := 0 to wanted_search.keywords_category.count - 1 do begin
        keyword := PNapCmd(wanted_search.keywords_category.Items[i])^.cmd;
        kwcrc := PNapCmd(wanted_search.keywords_category.Items[i])^.id;
        kw := DHT_KWList_Findkey(pchar(keyword), length(keyword), kwcrc);

        if kw = nil then begin
          result := nil;
          exit;
        end;

        wanted_search.lista_helper_result_category.add(kw);
        if ((kw.count < smallest) or (smallest = 0)) then begin
          result := kw;
          smallest := kw.count;
        end;
      end;
    end;

////// SEARCH DATE
    if length(wanted_search.keyword_date) >= 2 then begin

      kwcrc := wanted_search.crcdate;
      kw := DHT_KWList_Findkey(pchar(wanted_search.keyword_date), length(wanted_search.keyword_date), kwcrc);

      if kw = nil then begin
        result := nil;
        exit;
      end;

      wanted_search.lista_helper_result_date.add(kw);
      if ((kw.count < smallest) or (smallest = 0)) then begin
        result := kw;
        smallest := kw.count;
      end;
    end;

////// SEARCH LANGUAGE
    if length(wanted_search.keyword_language) >= 2 then begin

      kwcrc := wanted_search.crclanguage; //stringcrc(wanted_search^.keyword_language,true);
      kw := DHT_KWList_Findkey(pchar(wanted_search.keyword_language), length(wanted_search.keyword_language), kwcrc);

      if kw = nil then begin
        result := nil;
        exit;
      end;

      wanted_search.lista_helper_result_language.add(kw);
      if ((kw.count < smallest) or (smallest = 0)) then begin
        result := kw;
        smallest := kw.count;
      end;
    end;


  except
    exit;
  end;

end;

function tthread_dht.DHT_matchFile(pfile: precord_dht_storedfile; ShouldMatch: boolean): boolean;
var
  i, j: integer;
  found: boolean;
begin
  result := false;

  if wanted_search.amime <= 5 then
    if wanted_search.amime <> pfile^.amime then exit; //matches mime type


  if not wanted_search.strict then begin
    for i := 0 to wanted_search.lista_helper_result.Count - 1 do begin
      found := false;
      for j := 0 to pfile^.numkeywords - 1 do begin
        if pfile^.keywords^[j * 3] <> wanted_search.lista_helper_result[i] then continue; // must include all keywords
        found := true;
        break;
      end;
      if not found then exit;
    end;
    result := true;
    exit;
  end;



  if ShouldMatch then begin
    if wanted_search.sizecomp > 0 then begin
      case wanted_search.sizecomp of
        1: if pfile^.fsize > wanted_search.wantedsize then exit;
        2: if ((pfile^.fsize < wanted_search.wanted_size_avarage_min) or
            (pfile^.fsize > wanted_search.wanted_size_avarage_max)) then exit;
        3: if pfile^.fsize < wanted_search.wantedsize then exit;
      end;
    end;
    if wanted_search.param1comp > 0 then begin
      if pfile^.param1 = 0 then exit;
      case wanted_search.param1comp of
        1: if pfile^.param1 > wanted_search.wantedparam1 then exit;
        2: if pfile^.param1 <> wanted_search.wantedparam1 then exit;
        3: if pfile^.param1 < wanted_search.wantedparam1 then exit;
      end;
    end;
    if wanted_search.param3comp > 0 then begin
      if pfile^.param3 = 0 then exit;
      case wanted_search.param3comp of
        1: if pfile^.param3 > wanted_search.wantedparam3 then exit;
        2: if ((pfile^.param3 < wanted_search.wanted_param3_avarage_min) or (pfile^.param3 > wanted_search.wanted_param3_avarage_max)) then exit;
        3: if pfile^.param3 < wanted_search.wantedparam3 then exit;
      end;
    end;
  end;

  for i := 0 to wanted_search.lista_helper_result_title.count - 1 do begin //match title?
    found := false;
    for j := 0 to pfile^.numkeywords - 1 do begin
      if pfile^.keywords^[(j * 3) + 2] <> precord_field(rFIELD_TITLE) then continue;
      if pfile^.keywords^[j * 3] <> wanted_search.lista_helper_result_title[i] then continue;
      found := true;
      break;
    end;
    if not found then exit;
  end;


  for i := 0 to wanted_search.lista_helper_result_artist.count - 1 do begin //match artist?
    found := false;
    for j := 0 to pfile^.numkeywords - 1 do begin
      if pfile^.keywords^[(j * 3) + 2] <> precord_field(rFIELD_ARTIST) then continue;
      if pfile^.keywords^[j * 3] <> wanted_search.lista_helper_result_artist[i] then continue;
      found := true;
      break;
    end;
    if not found then exit;
  end;


  for i := 0 to wanted_search.lista_helper_result_album.count - 1 do begin //match album?
    found := false;
    for j := 0 to pfile^.numkeywords - 1 do begin
      if pfile^.keywords^[(j * 3) + 2] <> precord_field(rFIELD_ALBUM) then continue;
      if pfile^.keywords^[j * 3] <> wanted_search.lista_helper_result_album[i] then continue;
      found := true;
      break;
    end;
    if not found then exit;
  end;


  for i := 0 to wanted_search.lista_helper_result_category.count - 1 do begin //match album?
    found := false;
    for j := 0 to pfile^.numkeywords - 1 do begin
      if pfile^.keywords^[(j * 3) + 2] <> precord_field(rFIELD_CATEGORY) then continue;
      if pfile^.keywords^[j * 3] <> wanted_search.lista_helper_result_category[i] then continue;
      found := true;
      break;
    end;
    if not found then exit;
  end;


  if wanted_search.lista_helper_result_date.count > 0 then begin //match album?
    found := false;
    for j := 0 to pfile^.numkeywords - 1 do begin
      if pfile^.keywords^[(j * 3) + 2] <> precord_field(rFIELD_DATE) then continue;
      if pfile^.keywords^[j * 3] <> wanted_search.lista_helper_result_date[0] then continue;
      found := true;
      break;
    end;
    if not found then exit;
  end;


  if wanted_search.lista_helper_result_language.count > 0 then begin //match album?
    found := false;
    for j := 0 to pfile^.numkeywords - 1 do begin
      if pfile^.keywords^[(j * 3) + 2] <> precord_field(rFIELD_LANGUAGE) then continue;
      if pfile^.keywords^[j * 3] <> wanted_search.lista_helper_result_language[0] then continue;
      found := true;
      break;
    end;
    if not found then exit;
  end;


  result := true;

end;

procedure tthread_dht.DHT_ParseComplexField(complex: string);
var
  num: byte;
begin
  try
    while (length(complex) > 2) do begin
      num := ord(complex[1]);
      delete(complex, 1, 1);
      if length(complex) < 2 then exit;

      case num of

 //DHT uses int64  (8 bytes)
        1: begin //size minor of
            if length(complex) < 8 then exit;
            wanted_search.sizecomp := 1;
            wanted_search.wantedsize := chars_2_Qword(complex);
            delete(complex, 1, 8);
          end;
        2: begin //size approximately
            if length(complex) < 8 then exit;
            wanted_search.sizecomp := 2;
            wanted_search.wantedsize := chars_2_Qword(complex);
            wanted_search.wanted_size_avarage_min := wanted_search.wantedsize - (wanted_search.wantedsize div 10);
            wanted_search.wanted_size_avarage_max := wanted_search.wantedsize + (wanted_search.wantedsize div 10);
            delete(complex, 1, 8);
          end;
        3: begin //size major of
            if length(complex) < 8 then exit;
            wanted_search.sizecomp := 3;
            wanted_search.wantedsize := chars_2_Qword(complex);
            delete(complex, 1, 8);
          end;


        4: begin //param1 minor of
            wanted_search.param1comp := 1;
            wanted_search.wantedparam1 := chars_2_word(complex);
            delete(complex, 1, 2);
          end;
        5: begin //param1 uqual to
            wanted_search.param1comp := 2;
            wanted_search.wantedparam1 := chars_2_word(complex);
            delete(complex, 1, 2);
          end;
        6: begin //param1 major of
            wanted_search.param1comp := 3;
            wanted_search.wantedparam1 := chars_2_word(complex);
            delete(complex, 1, 2);
          end;


        10: begin //param3 minor of
            wanted_search.param3comp := 1;
            wanted_search.wantedparam3 := chars_2_dword(complex);
            delete(complex, 1, 4);
          end;
        11: begin //param3 circa
            wanted_search.param3comp := 2;
            wanted_search.wantedparam3 := chars_2_dword(complex);
            wanted_search.wanted_param3_avarage_max := wanted_search.wantedparam3 + (wanted_search.wantedparam3 div 10);
            wanted_search.wanted_param3_avarage_min := wanted_search.wantedparam3 - (wanted_search.wantedparam3 div 10);
            delete(complex, 1, 4);
          end; //param3 major of
        12: begin
            wanted_search.param3comp := 3;
            wanted_search.wantedparam3 := chars_2_dword(complex);
            delete(complex, 1, 4);
          end;

      end;
    end;

  except
  end;
end;


function tthread_dht.DHT_HasEnoughKeys: boolean;
begin
  result := false;

  if wanted_search.strict then begin
    if wanted_search.keywords_title.count = 0 then
      if wanted_search.keywords_artist.count = 0 then
        if wanted_search.keywords_album.count = 0 then
          if wanted_search.keywords_category.count = 0 then
            if length(wanted_search.keyword_date) < 2 then
              if length(wanted_search.keyword_language) < 2 then exit;
  end else begin
    if wanted_search.keywords_generali.count = 0 then exit;
  end;

  result := true;
end;

procedure tthread_dht.DHT_parseSearch(offset: integer; var complex: string);
var
  i: integer;
  lenkey: byte;
  crckey: word;
  keyword: string;
begin
  try
    i := offset;
    while (i + 2 < DHT_len_recvd) do begin


      case DHT_Buffer[i] of

        20: begin //general
            lenkey := DHT_Buffer[i + 1];
            if lenkey < KEYWORD_LEN_MIN then break;
            if lenkey > KEYWORD_LEN_MAX then break;
            if DHT_len_recvd < i + 4 + lenkey then break;
            move(DHT_Buffer[i + 2], crckey, 2);
            setlength(keyword, lenkey);
            move(DHT_Buffer[i + 4], keyword[1], lenkey);
            inc(i, 4 + lenkey);
            wanted_search.keywords_generali.AddCmd(crckey, keyword);
            wanted_search.strict := false;
          end;

        1: begin //title
            lenkey := DHT_Buffer[i + 1];
            if lenkey < KEYWORD_LEN_MIN then break;
            if lenkey > KEYWORD_LEN_MAX then break;
            if DHT_len_recvd < i + 4 + lenkey then break;
            move(DHT_Buffer[i + 2], crckey, 2);
            setlength(keyword, lenkey);
            move(DHT_Buffer[i + 4], keyword[1], lenkey);
            inc(i, 4 + lenkey);
            wanted_search.keywords_title.AddCmd(crckey, keyword);
          end;

        2: begin //artist
            lenkey := DHT_Buffer[i + 1];
            if lenkey < KEYWORD_LEN_MIN then break;
            if lenkey > KEYWORD_LEN_MAX then break;
            if DHT_len_recvd < i + 4 + lenkey then break;
            move(DHT_Buffer[i + 2], crckey, 2);
            setlength(keyword, lenkey);
            move(DHT_Buffer[i + 4], keyword[1], lenkey);
            inc(i, 4 + lenkey);
            wanted_search.keywords_artist.AddCmd(crckey, keyword);
          end;

        3: begin //album
            lenkey := DHT_Buffer[i + 1];
            if lenkey < KEYWORD_LEN_MIN then break;
            if lenkey > KEYWORD_LEN_MAX then break;
            if DHT_len_recvd < i + 4 + lenkey then break;
            move(DHT_Buffer[i + 2], crckey, 2);
            setlength(keyword, lenkey);
            move(DHT_Buffer[i + 4], keyword[1], lenkey);
            inc(i, 4 + lenkey);
            wanted_search.keywords_album.AddCmd(crckey, keyword);
          end;

        4: begin //category
            lenkey := DHT_Buffer[i + 1];
            if lenkey < KEYWORD_LEN_MIN then break;
            if lenkey > KEYWORD_LEN_MAX then break;
            if DHT_len_recvd < i + 4 + lenkey then break;
            move(DHT_Buffer[i + 2], crckey, 2);
            setlength(keyword, lenkey);
            move(DHT_Buffer[i + 4], keyword[1], lenkey);
            inc(i, 4 + lenkey);
            wanted_search.keywords_category.AddCmd(crckey, keyword);
          end;

        5: begin //date single
            lenkey := DHT_Buffer[i + 1];
            if lenkey < KEYWORD_LEN_MIN then break;
            if lenkey > KEYWORD_LEN_MAX then break;
            if DHT_len_recvd < i + 4 + lenkey then break;
            move(DHT_Buffer[i + 2], wanted_search.crcdate, 2);
            setlength(wanted_search.keyword_date, lenkey);
            move(DHT_Buffer[i + 4], wanted_search.keyword_date[1], lenkey);
            inc(i, 4 + lenkey); //possibile bug, per 3 giorni dall'uscita versione qui non avevo crcdate e crclanguage
          end;

        6: begin //language single
            lenkey := DHT_Buffer[i + 1];
            if lenkey < KEYWORD_LEN_MIN then break;
            if lenkey > KEYWORD_LEN_MAX then break;
            if DHT_len_recvd < i + 4 + lenkey then break;
            move(DHT_Buffer[i + 2], wanted_search.crclanguage, 2);
            setlength(wanted_search.keyword_language, lenkey);
            move(DHT_Buffer[i + 4], wanted_search.keyword_language[1], lenkey);
            inc(i, 4 + lenkey);
          end;

        7: begin //complex
            lenkey := DHT_Buffer[i + 1];
            if lenkey < 3 then break;
            if DHT_len_recvd < i + 2 + lenkey then break;
            setlength(complex, lenkey);
            move(DHT_Buffer[i + 2], complex[1], lenkey);
            break;
          end else break;

      end;


    end;

  except
  end;
end;

procedure tthread_dht.processSearchKeyResponse;
var
  port: word;
  searchID: word;
  i: integer;
  s: TDHTSearch;
  found: boolean;
  offset: integer;
  lenInfo: word;
  nresult: precord_search_result;

  list: tlist;
  source: Trisorsa_download;
  dl_hash: precord_download_hash;
begin
  TRACE('processSearchKeyResponse');
  if DHT_len_recvd < 39 then exit;

  port := synsock.ntohs(DHT_remoteSin.sin_port);
 // Set contact to alive.
  DHT_RoutingZone.setAlive(DHT_remoteSin.sin_addr.S_addr, port);

  move(DHT_Buffer[2], SearchID, 2);

  found := false;
  for i := 0 to DHT_Searches.count - 1 do begin
    s := DHT_Searches[i];
    if s.m_type <> dhttypes.KEYWORD then continue;
    if s.m_searchID <> searchID then continue;
    inc(s.m_answers);
    found := true;
    break;
  end;

  if not found then exit;

  offset := 4;
  while (offset + 40 < DHT_len_recvd) do begin
    nresult := AllocMem(sizeof(record_search_result));
    nresult^.search_id := SearchID;
    nresult^.hash_of_phash := '';
    nresult^.downloaded := false;

    SetLength(nresult^.hash_sha1, 20);
    move(DHT_buffer[Offset], nresult^.hash_sha1[1], 20);
    nresult^.crcsha1 := crcstring(nresult^.hash_sha1);

    inc(offset, 20);
    nresult^.amime := serversharetype_to_clienttype(DHT_Buffer[offset]);
    inc(offset);
    move(DHT_Buffer[offset], nresult^.fsize, 8);
    inc(offset, 8);
    move(DHT_Buffer[offset], nresult^.param1, 4);
    inc(offset, 4);
    move(DHT_Buffer[offset], nresult^.param3, 4);
    inc(offset, 4);
    nresult^.ip_alt := 0;
    nresult^.ip_server := 0;
    nresult^.port_server := 0;
    move(DHT_Buffer[offset], nresult^.ip_user, 4);

    inc(offset, 4);
    move(DHT_Buffer[offset], nresult^.port_user, 2);
    inc(offset, 2);
    move(DHT_Buffer[offset], lenInfo, 2);
    inc(offset, 2);
    DHT_ParseFileInfo(nresult, @DHT_Buffer[offset], lenInfo);
    inc(offset, lenInfo);

    nresult^.ImageIndex := amime_to_imgindexsmall(nresult^.amime);
    nresult^.nickname := 'dht' + lowercase(inttohex(random($FF), 2) + inttohex(random($FF), 2)) + STR_UNKNOWNCLIENT;

    if isAntiP2PIP(nresult^.ip_user) then begin
      FreeResultSearch(nresult);
      continue;
    end;

    m_searchresults.add(nresult);


    dl_hash := FindDlHash(nresult^.crcsha1, nresult^.hash_sha1);
    if dl_hash <> nil then begin
      source := trisorsa_download.create;
      with source do begin
        ip := nresult^.ip_user;
        porta := nresult^.port_user;
        handle_download := dl_hash^.handle_download;
        ip_interno := 0;
        nickname := 'dht' + lowercase(inttohex(random(255), 2) + inttohex(random(255), 2)) + STR_UNKNOWNCLIENT;
        tick_attivazione := 0;
        socket := nil;
      end;
      list := vars_global.lista_risorse_temp.locklist;
      list.add(source);
      vars_global.lista_risorse_temp.Unlocklist;
      nresult^.being_downloaded := true;
    end else nresult^.being_downloaded := false;

  end; // endof parse cycle

  if m_searchresults.count > 0 then synchronize(DHT_AddSrcResults);


end;


procedure tthread_dht.DHT_ParseFileInfo(nresult: precord_search_result; buff: PbyteArray; len: integer);
  procedure mycopybuffer(offset: integer; var destination: string; len: integer);
  begin
    SetLength(destination, len);
    move(buff[offset + 2], destination[1], len);
  end;
var
  offset: integer;
  lenTag: byte;
begin
  nresult^.title := '';
  nresult^.artist := '';
  nresult^.album := '';
  nresult^.category := '';
  nresult^.language := '';
  nresult^.year := '';
  nresult^.comments := '';
  nresult^.url := '';
  nresult^.filenameS := '';
  nresult^.keyword_genre := '';
  nresult^.param2 := 0;
  nresult^.DHTload := 1;

  offset := 0;
  while (offset + 2 < len) do begin

    lenTag := buff[offset];
    case buff[offset + 1] of
      TAG_ID_DHT_TITLE: mycopybuffer(offset, nresult^.title, lenTag);
      TAG_ID_DHT_FILENAME: mycopybuffer(offset, nresult^.filenameS, lenTag);
      TAG_ID_DHT_ARTIST: mycopybuffer(offset, nresult^.artist, lenTag);
      TAG_ID_DHT_ALBUM: mycopybuffer(offset, nresult^.album, lenTag);
      TAG_ID_DHT_CATEGORY: mycopybuffer(offset, nresult^.category, lenTag);
      TAG_ID_DHT_LANGUAGE: mycopybuffer(offset, nresult^.language, lenTag);
      TAG_ID_DHT_DATE: mycopybuffer(offset, nresult^.year, lenTag);
      TAG_ID_DHT_COMMENTS: mycopybuffer(offset, nresult^.comments, lenTag);
      TAG_ID_DHT_URL: mycopybuffer(offset, nresult^.url, lenTag);
      TAG_ID_DHT_KEYWGENRE: mycopybuffer(offset, nresult^.keyword_genre, lenTag);
      TAG_ID_DHT_PARAM2: move(Buff[offset + 2], nresult^.param2, 4);
      TAG_ID_DHT_STATS: nresult^.DHTload := buff[offset + 2];
    end;
    inc(offset, lenTag + 2);

  end;

end;

procedure tthread_dht.FreeResultSearch(nresult: precord_search_result);
begin
  with nresult^ do begin
    title := '';
    artist := '';
    album := '';
    filenameS := '';
    category := '';
    comments := '';
    language := '';
    url := '';
    year := '';
    hash_sha1 := '';
    keyword_genre := '';
    nickname := '';
  end;
  FreeMem(nresult, sizeof(record_search_result));
end;


procedure tthread_dht.DHT_AddSrcResults; //sync
var
  nresult: precord_search_result;
  src: precord_panel_search;
  i: integer;
  found: boolean;
  ExistentNode, NewNode: pcmtvnode;
  shouldNotAdd: boolean;
begin

// find search panel
  src := nil;
  nresult := m_searchresults[0];
  found := false;
  for i := 0 to src_panel_list.count - 1 do begin
    src := src_panel_list[i];
    if src^.started = 0 then continue;
    if src^.searchID <> nresult^.search_id then continue;
    found := true;
    break;
  end;

  if not found then begin // free them all since we don't have a search anymore
    while m_searchresults.count > 0 do begin
      nresult := m_searchresults[m_searchresults.count - 1];
      m_searchresults.delete(m_searchresults.count - 1);
      FreeResultSearch(nresult);
    end;
    exit;
  end;




  src^.listview.beginupdate;

  while (m_searchresults.count > 0) do begin
    nresult := m_searchresults[m_searchresults.count - 1];
    m_searchresults.delete(m_searchresults.count - 1);


    if src^.is_advanced then begin
      if not helper_search_gui.check_complex_search(src, nresult) then begin
        FreeResultSearch(nresult);
        continue;
      end;
    end;

    if not helper_search_gui.check_matching_srcmime(src, nresult) then begin //mime type mismatch, is this from a spammer?
      FreeResultSearch(nresult);
      continue;
    end;

   // should we search for matching hashes already in list?
    if src^.numresults > 0 then begin
      ExistentNode := FindMatchingSearchResult(src^.listview, nresult, shouldnotadd);
      if shouldNotAdd then begin
        FreeResultSearch(nresult);
        continue;
      end;
    end else ExistentNode := nil;


   // assign final flags (need to do this in synchronize)
    nresult^.already_in_lib := (helper_share_misc.is_in_lib_sha1(nresult^.hash_sha1));
    nresult^.being_downloaded := (is_in_progress_sha1(nresult^.hash_sha1));

   // we have a node to attach to, same hash as this result
    if ExistentNode <> nil then begin
      if ExistentNode^.childcount = 0 then begin // copy already existing node to a child of itself
        NewNode := src^.listview.addchild(ExistentNode);
        helper_search_gui.copy_node_src(src^.listview, ExistentNode, NewNode);
      end;
      NewNode := src^.listview.addchild(ExistentNode);
      helper_search_gui.copy_node_dataNParentAttributes(src^.listview, ExistentNode, nresult, NewNode);

      inc(src^.numhits);
      src^.backup_results.add(nresult);
      continue;
    end;

   // new node to be added, prepare listview
    if src^.numresults = 0 then begin
    // add results to GUI
      src^.listview.canbgcolor := true;
      helper_visual_headers.header_search_show(src);
      if src^.containerPanel.visible then begin
        ares_frmmain.edit_src_filter.Enabled := true;
      end;
    end;

   // add node
    NewNode := src^.listview.addchild(nil);
    helper_search_gui.copy_node_data(src, nresult, NewNode);

    src^.backup_results.add(nresult);
    inc(src^.numresults);
    inc(src^.numhits);
  end;

  if src^.listview.Header.sortcolumn >= 0 then
    src^.listview.Sort(nil, src^.listview.header.sortcolumn, src^.listview.header.sortdirection);

  src^.listview.endupdate;

end;

procedure tthread_dht.processPublishKeyRequest;
var
  tcpport, lenItem: word;
  offset: integer;
  sendAck: boolean;
  publishprefix: cardinal;
begin
  TRACE('processSearchKeyResponse');
  if DHT_len_recvd < 50 then exit;

  move(DHT_Buffer[2], publishprefix, 4);
  if publishprefix xor DHTMe[0] > SEARCHTOLERANCE then exit; // too far from me

  move(DHT_Buffer[18], tcpport, 2); //tcp transfer port of user sharing files to be published
  if tcpport = 0 then tcpport := synsock.ntohs(DHT_remoteSin.sin_port); //should be equal to udpport in Ares

  sendAck := false;
  offset := 20;
  while (offset + 30 < DHT_Len_recvd) do begin
    move(DHT_Buffer[offset], lenItem, 2);
    inc(offset, 2);
    if DHT_Len_recvd < offset + LenItem then break;

    sendAck := handler_publish_keyFile(@DHT_Buffer[offset], lenItem, DHT_remoteSin.sin_addr.S_addr, tcpport);

    inc(offset, lenItem);
  end;

  if not sendAck then exit;

  DHT_Buffer[1] := CMD_DHT_PUBLISHKEY_RES;
  DHT_len_tosend := 18;
  DHT_Send(DHT_remoteSin.sin_addr.S_addr, synsock.ntohs(DHT_remoteSin.sin_port), false);

end;

function tthread_dht.handler_publish_keyFile(buff: pbytearray; lenPayload: integer; FromIp: cardinal; TCPPort: word): boolean;
var
  len_keywords: word;
  pfile, firstFile: precord_dht_storedfile;
  offset: integer;
begin
  result := false;

  move(buff[0], DHT_hash_sha1_global[0], 20);
  move(DHT_hash_sha1_global[18], DHT_crcsha1_global, 2);

  pfile := DHT_FindKeywordFile;
  if pfile <> nil then begin // already available, loop through sources, to update or add this user
    pfile^.lastSeen := time_now;

    if pfile^.ip <> fromIP then begin
      pfile^.ip := FromIP;
      if pfile^.count < 100 then inc(pfile^.count);
    end;
    pfile^.port := tcpport;
    result := true;
    exit;
  end;



  if DHT_SharedFilesCount >= DHT_MAX_SHARED_KEYWORDFILES then begin // too many files
    result := true;
    exit;
  end;

  // new file available ... parse packet

  offset := 20;

  move(buff[offset], len_keywords, 2);
  if len_keywords > 400 then exit; // too long keyword serialization?

  inc(offset, 2);

  if lenPayload < offset + len_keywords + 21 then exit; // enough data so far?

  move(buff[offset], buffer_parse_keywords[0], len_keywords);
  inc(offset, len_keywords);

  pfile := AllocMem(sizeof(record_dht_storedfile));

  pfile^.amime := Buff[offset];
  if pfile^.amime > 5 then begin
    FreeMem(pfile, sizeof(record_dht_storedfile));
    exit;
  end;
  inc(offset);

  move(buff[offset], pfile^.fsize, 8); // int64 8 bytes
  if pfile^.fsize = 0 then begin
    FreeMem(pfile, sizeof(record_dht_storedfile));
    exit;
  end;
  inc(offset, 8);

   // copy searchable parameters
  move(Buff[offset], pfile^.param1, 4);
  inc(offset, 4);
  move(Buff[offset], pfile^.param3, 4);
  inc(offset, 4);

  move(DHT_hash_sha1_global[0], pfile^.hashValue[0], 20);
  pfile^.crc := DHT_crcsha1_global;
  pfile^.count := 1;
  pfile^.lastSeen := time_now;
  pfile^.ip := FromIP;
  pfile^.port := tcpport;
  pfile^.numKeywords := 0;


  if not DHT_ParseKeywords(pfile, len_keywords) then begin // can't parse keyword?
    FreeMem(pfile, sizeof(record_dht_storedfile));
    exit;
  end;
  if pfile^.numKeywords = 0 then begin // no searchable keywords?
    FreeMem(pfile, sizeof(record_dht_storedfile));
    exit;
  end;

   // copy the rest of payload
  setLength(pfile^.info, lenPayload - offset);
  move(Buff[offset], pfile^.info[1], lenPayload - offset);



  // insert file reference into table
  firstFile := db_DHT_keywordFile.bkt[(DHT_crcsha1_global mod DB_DHTKEYFILES_ITEMS)];
  pfile^.next := firstFile;
  if firstFile <> nil then firstFile^.prev := pfile;
  pfile^.prev := nil;
  db_DHT_keywordFile.bkt[(DHT_crcsha1_global mod DB_DHTKEYFILES_ITEMS)] := pfile;

  inc(DHT_SharedFilesCount);

  result := true;

end;

function tthread_dht.DHT_ParseKeywords(pfile: precord_dht_storedfile; len_keywords: integer): boolean;
var
  offset: integer;
  lenkey: byte;
  crckey: word;

  kw: PDHTKeyword;
  kwi: PDHTKeywordItem;
  pfield: pointer;
  j: integer;
  dump: string;
begin
  result := false;

  glb_lst_keywords.clear;

  offset := 0;
  while (offset + 5 < len_keywords) do begin //parsiamo le keywords

    lenkey := buffer_parse_keywords[offset + 3];

    if lenkey > KEYWORD_LEN_MAX then begin
      inc(offset, 4 + lenkey);
      continue;
    end;

    if lenkey < KEYWORD_LEN_MIN then break;
    if offset + 4 + lenkey > len_keywords then break;

    case buffer_parse_keywords[offset] of
      1: pfield := precord_field(rfield_title);
      2: pfield := precord_field(rfield_artist);
      3: pfield := precord_field(rfield_album);
      4: pfield := precord_field(rfield_category);
      5: pfield := precord_field(rfield_language);
      6: pfield := precord_field(rfield_date) else begin
        pfield := precord_field(rfield_title);
        break;
      end;
    end;

    //copy keyword
    move(buffer_parse_keywords[offset + 4], keyword_buffer[0], lenkey);
    //copy crc
    move(buffer_parse_keywords[offset + 1], crckey, 2);


    setLength(dump, lenkey);
    move(keyword_buffer[0], dump[1], lenkey);


    // add keyword to table
    kw := DHT_KWList_Findkey(@keyword_buffer[0], lenkey, crckey);
    if kw = nil then kw := DHT_KWList_Addkey(@keyword_buffer[0], lenkey, crckey);
    kwi := DHT_KWList_AddShare(kw, pfile); // may outputs nil for duplicate keys
    glb_lst_keywords.Add(kw);
    glb_lst_keywords.Add(kwi); //may be nil
    glb_lst_keywords.Add(pfield);


    inc(pfile^.numkeywords);

    if glb_lst_keywords.count >= MAX_KEYWORDS3 then break;

    inc(offset, 4 + lenkey);
  end;



  // keep track of keywords pointers in file structure
  ReallocMem(pfile^.keywords, glb_lst_keywords.count * SizeOf(Pointer));
  for j := 0 to glb_lst_keywords.count - 1 do pfile^.keywords[j] := glb_lst_keywords.Items[j];

  result := true;
end;

procedure tthread_dht.processSearchPartialSourceHashRequest;
var
  hisTCPPort: word;
  source: precord_dht_source;
  phash, firstHash: precord_DHT_hash;
begin
{
client sent us his TCP port because this file isn't so popular
we keep track of such requests to improve partial filesharing
}
  TRACE('processSearchPartialSourceHashRequest');
  move(DHT_Buffer[22], hisTCPPort, 2);
  phash := DHT_FindHashFile(db_DHT_hashPartialSources);
  if phash <> nil then begin
    DHT_SendPartialSources(phash, hisTCPPort);
    exit;
  end;


//otherwise create new partial files hash record and add a new source item

  phash := AllocMem(sizeof(record_dht_hash));
  move(DHT_hash_sha1_global[0], phash^.hashValue[0], 20);
  phash^.crc := DHT_crcsha1_global;
  phash^.lastSeen := time_now;
  phash^.count := 1;

 // insert hash into table
  firstHash := db_DHT_hashPartialSources.bkt[DHT_crcsha1_global mod DB_DHTHASH_ITEMS];
  phash^.next := firstHash;
  if firstHash <> nil then firstHash^.prev := phash;
  phash^.prev := nil;
  db_DHT_hashPartialSources.bkt[DHT_crcsha1_global mod DB_DHTHASH_ITEMS] := phash;

  inc(DHT_SharedPartialSourcesCount);

 // create source record
  source := AllocMem(sizeof(record_dht_source));
  source^.lastSeen := phash^.lastSeen;
  source^.ip := DHT_remoteSin.sin_addr.S_addr;
  setLength(source^.raw, 2);
  move(hisTCPPort, source^.raw[1], 2);
    // no entries in a new hash structure, we're first
  source^.prev := nil;
  source^.next := nil;
  phash^.firstSource := source;

end;

procedure tthread_dht.DHT_SendPartialSources(phash: precord_dht_hash; tcpport: word);
var
  source: precord_dht_source;
  ResultCount, load, offset: integer;
  shouldAddHim, isAdding: boolean;
begin

  phash^.lastSeen := time_now; // extend time to live
  load := (phash^.count * 100) div DHT_MAX_SOURCES_HASH;
  if load = 0 then inc(load);

  offset := 24;

  shouldAddHim := true;
  ResultCount := 0;
  isadding := true;

  source := phash^.firstSource;
  while (source <> nil) do begin

    if source^.ip = cardinal(DHT_remoteSin.sin_addr.S_addr) then begin
      shouldAddHim := false;
      source := source^.next;
      continue;
    end;

    if isAdding then begin // add result to output
      inc(ResultCount);
      move(source^.ip, DHT_Buffer[offset], 4);
      DHT_Buffer[offset + 4] := length(source^.raw);
      move(source^.raw[1], DHT_Buffer[offset + 5], length(source^.raw));
      inc(offset, 5 + length(source^.raw));
      if offset >= 724 then isadding := false; // max 100 results?
    end;

    source := source^.next;
  end;



  if shouldAddHim then begin // add him to list
    if phash.count >= DHT_MAX_PARTIALSOURCES_HASH then DHT_FreeLastSource(phash);
    inc(phash^.count); // we got a new source here
    source := AllocMem(sizeof(record_dht_source));
    source^.lastSeen := phash^.lastSeen;
    source^.ip := DHT_remoteSin.sin_addr.S_addr;
    setLength(source^.raw, 2);
    move(tcpport, source^.raw[1], 2);

    source^.prev := nil;
    if phash^.firstSource <> nil then begin
      phash^.firstSource^.prev := source;
      source^.next := phash^.firstSource;
    end else source^.next := nil;
    phash^.firstSource := source;
  end;

  if offSet = 24 then exit; // no results to send

  // send back results
  DHT_Buffer[22] := load;
  DHT_Buffer[23] := ResultCount;
  DHT_Buffer[1] := CMD_DHT_SEARCHPARTIALHASH_RES;
  DHT_len_tosend := offset;
  DHT_send(DHT_remoteSin.sin_addr.S_addr, synsock.ntohs(DHT_remoteSin.sin_port), false);

end;

procedure tthread_dht.processSearchHashRequest;
var
  fileprefix: cardinal;
  load, offset, addedCount: integer;
  phash: precord_DHT_hash;
  source: precord_dht_source;
begin
  TRACE('processSearchHashRequest');
  if DHT_len_recvd < 22 then exit;

  move(DHT_Buffer[2], fileprefix, 4);
  if fileprefix xor DHTMe[0] > SEARCHTOLERANCE then exit; // too far from me

  move(DHT_buffer[2], DHT_hash_sha1_global[0], 20);
  move(DHT_hash_sha1_global[18], DHT_crcsha1_global, 2);

  if DHT_len_recvd >= 24 then processSearchPartialSourceHashRequest;

  phash := DHT_FindHashFile(db_DHT_hashFile);
  if phash = nil then exit;

  load := (phash^.count * 100) div DHT_MAX_SOURCES_HASH;
  if load = 0 then inc(load);

  DHT_Buffer[22] := load;


  offset := 24;
  addedCount := 0;

  source := phash^.firstSource;
  while (source <> nil) do begin
    inc(addedCount);

    move(source^.ip, DHT_Buffer[offset], 4);
    DHT_Buffer[offset + 4] := length(source^.raw);
    move(source^.raw[1], DHT_Buffer[offset + 5], length(source^.raw));
    inc(offset, 5 + length(source^.raw));

    source := source^.next;

    if source <> nil then
      if offset > 9900 then
        if offset + (length(source^.raw) + 5) >= sizeof(DHT_Buffer) then break;
  end;

  DHT_Buffer[23] := addedCount;
  DHT_Buffer[1] := CMD_DHT_SEARCHHASH_RES;
  DHT_len_tosend := offset;
  DHT_send(DHT_remoteSin.sin_addr.S_addr, synsock.ntohs(DHT_remoteSin.sin_port), false);

end;

procedure tthread_dht.processSearchHashResponse;
var
  port: word;
  found: boolean;
  i, offset: integer;
  s: TDHTSearch;
  lenSource: byte;

  dl_hash: precord_download_hash;
  crcsha1: word;
  hashsha1, supernodes: string;
  list: tlist;
  source: trisorsa_download;
begin
  TRACE('processSearchHashResponse');
  if DHT_len_recvd < 24 then exit;

  port := synsock.ntohs(DHT_remoteSin.sin_port);

 // Set contact to alive.
  DHT_RoutingZone.setAlive(DHT_remoteSin.sin_addr.S_addr, port);

  found := false;
  for i := 0 to DHT_searches.count - 1 do begin
    s := DHT_searches[i];
    if s.m_type <> dhttypes.FINDSOURCE then continue;
    if CompareMem(@s.m_outPayload[1], @DHT_Buffer[2], 20) then begin
      inc(s.m_answers);
      found := true;
      break;
    end;
  end;

  if not found then exit;


  setLength(hashsha1, 20);
  move(DHT_Buffer[2], hashsha1[1], 20);
  crcsha1 := crcstring(hashsha1);


  dl_hash := FindDlHash(crcSha1, hashSha1);
  if dl_hash = nil then exit;

  list := lista_risorse_temp.locklist;



  offset := 24;
  while (offset + 7 <= DHT_len_recvd) do begin
    move(DHT_Buffer[offset], m_global_ip, 4);
    inc(offset, 4);
    lenSource := DHT_Buffer[offset];

    inc(offset);
    if ((offset + lenSource <= DHT_len_recvd) and (lenSource >= 6)) then begin
      move(DHT_Buffer[offset], m_global_LANIP, 4);
      move(DHT_Buffer[offset + 4], m_global_port, 2);
      if lenSource >= 12 then begin
        setLength(supernodes, LenSource - 6);
        move(DHT_Buffer[offset + 6], Supernodes[1], length(Supernodes));
      end else Supernodes := '';

      if not isAntiP2PIP(m_global_ip) then begin

        source := trisorsa_download.create;
        with source do begin
          if length(Supernodes) > 0 then InsertServers(Supernodes);
          ip := m_global_ip;
          porta := m_global_port;
          handle_download := dl_hash^.handle_download;
          ip_interno := m_global_LANIP;
          nickname := 'dht' + lowercase(inttohex(random(255), 2) + inttohex(random(255), 2)) + STR_UNKNOWNCLIENT;
          tick_attivazione := 0;
          socket := nil;
        end;
        list.add(source);

      end;

    end else break;
    inc(offset, lenSource);
  end;



  lista_risorse_temp.unlocklist;
end;

procedure tthread_dht.processSearchPartialSourceHashResponse;
var
  offset: integer;
  lenSource: byte;
  found: boolean;
  s: TDHTSearch;
  i: integer;

  dl_hash: precord_download_hash;
  crcsha1: word;
  hashSha1: string;
  lisT: tlist;
begin
  TRACE('processSearchPartialSourceHashResponse');
  if DHT_len_recvd < 24 then exit;


 // Set contact to alive.
  DHT_RoutingZone.setAlive(DHT_remoteSin.sin_addr.S_addr, synsock.ntohs(DHT_remoteSin.sin_port));

 // must be related to a FINDSource request
  found := false;
  for i := 0 to DHT_searches.count - 1 do begin
    s := DHT_searches[i];
    if s.m_type <> dhttypes.FINDSOURCE then continue;
    if CompareMem(@s.m_outPayload[1], @DHT_Buffer[2], 20) then begin
      inc(s.m_answers);
      found := true;
      break;
    end;
  end;
  if not found then exit;

  setLength(hashSha1, 20);
  move(DHT_Buffer[2], hashSha1[1], 20);
  crcsha1 := crcstring(hashsha1);

  dl_hash := FindDlHash(crcsha1, hashSha1);
  if dl_hash = nil then exit;

  list := vars_global.lista_risorsepartial_temp.locklist;


  offset := 24;
  while (offset + 7 <= DHT_len_recvd) do begin
    move(DHT_Buffer[offset], m_global_ip, 4);
    inc(offset, 4);
    lenSource := DHT_Buffer[offset];

    inc(offset);

    if ((offset + lenSource <= DHT_len_recvd) and
      (lenSource >= 2)) then begin
      move(DHT_Buffer[offset], m_global_port, 2);

    {  source:=trisorsa_encap.create;
      with source do begin
       handle_download:=dl_hash^.handle_download;
       download:=nil;
       ip:=m_global_ip;
       port:=m_global_port;
       port_server:=0;
       ip_server:=0;
       ip_alt:=0;
       user:='dht'+lowercase(inttohex(random(255),2)+inttohex(random(255),2))+STR_UNKNOWNCLIENT;
       is_upload:=false;
       stato:=STATO_WAITING_FOR_CALL;
      end;
       list.add(source);}

    end else break;

    inc(offset, lenSource);
  end;


  vars_global.lista_risorsepartial_temp.Unlocklist;
end;

procedure tthread_dht.processPublishHashRequest;
var
  load: integer;
  phash, firstHash: precord_DHT_hash;
  source: precord_dht_source;
  sourceInfoLen: integer;
  fileprefix: cardinal;
begin
  TRACE('processPublishHashRequest');
  if DHT_len_recvd < 28 then exit;


  move(DHT_Buffer[2], fileprefix, 4);
  if fileprefix xor DHTMe[0] > SEARCHTOLERANCE then exit; // too far from me

  move(DHT_buffer[2], DHT_hash_sha1_global[0], 20);
  move(DHT_hash_sha1_global[18], DHT_crcsha1_global, 2);

  sourceinfoLen := DHT_len_recvd - 22;
  if sourceinfoLen < 6 then exit; // enough to have just one internalIP:TCPport pair?
  if sourceinfoLen > 36 then exit; // max internalIP:TCPport + 5 supernode IP:port pairs

  phash := DHT_FindHashFile(db_DHT_hashFile);
  if phash <> nil then begin // already have this sha1?

    phash^.lastSeen := time_now; // extend time to live
    load := (phash^.count * 100) div DHT_MAX_SOURCES_HASH;
    if load = 0 then load := 1;

    if phash.count >= DHT_MAX_SOURCES_HASH then DHT_FreeLastSource(phash);


    source := DHT_FindHashFileSource(phash, DHT_remoteSin.sin_addr.S_addr);
    if source <> nil then begin // already got this source...just update it
      source^.lastSeen := phash^.lastSeen;
      if length(source^.raw) <> sourceinfoLen then setLength(source^.raw, sourceInfoLen);
      move(DHT_Buffer[22], source^.raw[1], sourceinfoLen);
      DHT_sendBackPublishHashAck(DHT_remoteSin.sin_addr.S_addr,
        synsock.ntohs(DHT_remoteSin.sin_port),
        load);
      exit;
    end;

    inc(phash^.count); // we got a new source here

    source := AllocMem(sizeof(record_dht_source));
    source^.lastSeen := phash^.lastSeen;
    source^.ip := DHT_remoteSin.sin_addr.S_addr;
    setLength(source^.raw, sourceInfoLen);
    move(DHT_Buffer[22], source^.raw[1], sourceinfoLen);

    // attach source to hash record
    source^.prev := nil;
    if phash^.firstSource <> nil then begin
      phash^.firstSource^.prev := source;
      source^.next := phash^.firstSource;
    end else source^.next := nil;
    phash^.firstSource := source;

    DHT_sendBackPublishHashAck(DHT_remoteSin.sin_addr.S_addr,
      synsock.ntohs(DHT_remoteSin.sin_port),
      load);
    exit;
  end;




  if DHT_SharedHashCount >= DHT_MAX_SHARED_HASHFILES then begin // to many files
    DHT_sendBackPublishHashAck(DHT_remoteSin.sin_addr.S_addr,
      synsock.ntohs(DHT_remoteSin.sin_port),
      1);
    exit;
  end;



//otherwise create new hash record and add a new source item

  phash := AllocMem(sizeof(record_dht_hash));
  move(DHT_hash_sha1_global[0], phash^.hashValue[0], 20);
  phash^.crc := DHT_crcsha1_global;
  phash^.lastSeen := time_now;
  phash^.count := 1;

 // insert hash into table
  firstHash := db_DHT_hashFile.bkt[DHT_crcsha1_global mod DB_DHTHASH_ITEMS];
  phash^.next := firstHash;
  if firstHash <> nil then firstHash^.prev := phash;
  phash^.prev := nil;
  db_DHT_hashFile.bkt[DHT_crcsha1_global mod DB_DHTHASH_ITEMS] := phash;

  inc(DHT_SharedHashCount);



 // create source record
  source := AllocMem(sizeof(record_dht_source));
  source^.lastSeen := phash^.lastSeen;
  source^.ip := DHT_remoteSin.sin_addr.S_addr;
  setLength(source^.raw, sourceInfoLen);
  move(DHT_Buffer[22], source^.raw[1], sourceinfoLen);

  source^.prev := nil; // no entries in a new hash structure, we're first
  source^.next := nil;
  phash^.firstSource := source;

  DHT_sendBackPublishHashack(DHT_remoteSin.sin_addr.S_addr,
    synsock.ntohs(DHT_remoteSin.sin_port),
    1); // just added load=1
end;

procedure tthread_dht.processPublishHashResponse;
var
  port: word;
  targetID: CU_INT128;
begin
  TRACE('processPublishHashResponse');
  if DHT_len_recvd < 23 then exit;
//2+hash(20)+byteload

  port := synsock.ntohs(DHT_remoteSin.sin_port);

 // Set contact to alive.
  DHT_RoutingZone.setAlive(DHT_remoteSin.sin_addr.S_addr, port);

  CU_INT128_CopyFrombuffer(@DHT_Buffer[2], @targetID);

  DHTSearchManager.processPublishHashAck(@TargetID, DHT_remoteSin.sin_addr.S_addr, port);
end;



procedure tthread_dht.processPublishKeyResponse;
var
  port: word;
  publishID: CU_INT128;
begin
  TRACE('processPublishKeyResponse');
  if DHT_len_recvd < 18 then exit;
//2+searchID(16)

  port := synsock.ntohs(DHT_remoteSin.sin_port);

 // Set contact to alive.
  DHT_RoutingZone.setAlive(DHT_remoteSin.sin_addr.S_addr, port);

  CU_INT128_copyFromBuffer(@DHT_Buffer[2], @publishID);
  dhtsearchManager.processPublishKeyAck(@publishID, DHT_remoteSin.sin_addr.S_addr, port);
end;


procedure tthread_dht.execute;
begin
  priority        := tpnormal;
  freeonterminate := false;

  sleep(1000);

  init_vars;
  create_listener;

  while (not terminated) do begin

    nowt := time_now;


    udp_receive;

    check_events;
    check_second;

    sleep(10);
  end;

  shutdown;
end;

procedure tthread_dht.check_shareHashFile;
var
  phash: precord_DHT_hashfile;
  hashlst: Tlist;
begin
  if ((dhtsearchmanager.num_searches(dhttypes.STOREFILE) >= MAX_DHT_HASH_OUTPUBLISHREQS) and
    (DHT_Searches.count >= MAX_DHT_OUTSEARCHES)) then exit;

  phash := nil;

  hashlst := DHT_hashFiles.locklist;
  if hashlst.count > 0 then begin
    phash := hashlst[hashlst.count - 1];
    hashlst.delete(hashlst.count - 1);
  end;
  DHT_hashFiles.UnlockList;

  if phash = nil then exit;

  DHTSearchManager.PublishHash(phash);
  FreeMem(phash, sizeof(record_DHT_hashfile));

end;

procedure tthread_dht.check_shareKeyFile;
var
  kwdlst: tlist;
  pkeyw: precord_DHT_keywordFilePublishReq;
  sha1: TSha1;
  valueSha1, PublishPayload: string;
  s: TDHTSearch;
begin
  if ((dhtsearchmanager.num_searches(dhttypes.STOREKEYWORD) >= MAX_DHT_KEY_OUTPUBLISHREQS) and
    (DHT_Searches.count >= MAX_DHT_OUTSEARCHES)) then exit;

  pkeyw := nil;
  kwdlst := DHT_KeywordFiles.locklist;
  if kwdlst.count > 0 then begin
    pkeyw := kwdlst[kwdlst.count - 1];
    kwdlst.delete(kwdlst.count - 1);
  end;
  DHT_KeywordFiles.unlocklist;

  if pkeyw = nil then exit;


 //get sha1 value of this keyword
  sha1 := TSha1.create;
  sha1.Transform(pkeyw^.keyw[1], length(pkeyw^.keyw));
  sha1.complete;
  ValueSha1 := sha1.hashvalue;
  sha1.free;

 //  we take the first 16 bytes of hashed keyword as targetIDs are 128bit long
  s := TDHTSearch.create;
  s.m_type := DHTtypes.STOREKEYWORD;
  CU_INT128_copyFromBuffer(@ValueSha1[1], @s.m_target);
  s.m_publishKeyPayloads := tmyStringlist.create;

 // get all files related to this keyword
  while (pkeyw^.fileHashes.count > 0) do begin
    GlobHashValue := pkeyw^.fileHashes.strings[pkeyw^.fileHashes.count - 1];
    pkeyw^.fileHashes.delete(pkeyw^.fileHashes.Count - 1);

    GlobcrcSha1 := crcstring(GlobHashValue);
    GlobPfile := nil;

    synchronize(get_library_file); // get pfile infos from global list
    if GlobPfile <> nil then begin

      PublishPayload := dhtkeywords.DHT_GetSerialized_PublishPayload(GlobPfile); // this is file's serialized payload to be sent to matching nodes
      s.m_publishKeyPayloads.add(PublishPayload);

      finalize_file_library_item(GlobPfile);
      FreeMem(GlobPFile, sizeof(record_file_library));

    end;

  end;

  pkeyw^.keyW := '';
  pkeyw^.fileHashes.free;
  FreeMem(pkeyw, sizeof(record_DHT_keywordFilePublishReq));

  if s.m_publishKeyPayloads.count = 0 then begin // nothing to share?
    s.free;
    exit;
  end;

  DHT_Searches.add(s);
  s.StartIDSearch;

end;

procedure tthread_dht.get_library_file; //sync
var
  i: integer;
  pfile: precord_file_library;
begin

  for i := 0 to vars_global.lista_shared.count - 1 do begin
    pfile := vars_global.lista_shared[i];
    if not pfile^.shared then continue;
    if pfile^.crcsha1 <> GlobcrcSha1 then continue;
    if pfile^.hash_sha1 <> GlobHashValue then continue;

    GlobPfile := AllocMem(sizeof(record_File_library));
    with GlobPFile^ do begin // get values needed for serialization
      hash_sha1 := pfile^.hash_sha1;
      amime := pfile^.amime;
      fsize := pfile^.fsize;
      param1 := pfile^.param1;
      param2 := pfile^.param2;
      param3 := pfile^.param3;

      title := pfile^.title;
      artist := pfile^.artist;
      album := pfile^.album;
      category := pfile^.category;
      comment := pfile^.comment;
      language := pfile^.language;
      path := pfile^.path;
      url := pfile^.url;
      year := PFile^.year;
      keywords_genre := pfile^.keywords_genre;
    end;

    break;
  end;

end;

procedure tthread_dht.check_GUI; //sync
begin
  checkOutKeySearches;
  if nowt - m_startTime > MIN2S(4) then checkOutHashSearches;
end;

procedure tthread_dht.checkOutKeySearches;
var
  h, i: integer;
  src: precord_panel_search;
  s: TDHTSearch;
  amime: byte;
  str_search, keywordStr, hashValue: string;
  sha1: tsha1;
  found: boolean;
begin
 // remove key searches not available on the GUI
  h := 0;
  while (h < DHT_Searches.count) do begin
    s := DHT_Searches[h];
    if s.m_type <> dhttypes.KEYWORD then begin
      inc(h);
      continue;
    end;

    found := false;
    for i := 0 to src_panel_list.count - 1 do begin
      src := src_panel_list[i];
      if src^.started = 0 then continue;
      if src^.searchID = s.m_searchID then begin
        found := true;
        break;
      end;
    end;

    if not found then begin
      DHT_Searches.delete(h);
      s.free;
    end else inc(h);
  end;


 // add searches from the GUI that we don't have already
  for h := 0 to src_panel_list.count - 1 do begin
    src := src_panel_list[h];
    if src^.started = 0 then continue;
    if gettickcount - src^.started > 15000 then continue; // don't add them more than once, if search finishes quickly because there are no fresh nodes to start from
    if dhtsearchmanager.has_KeywordSearchWithID(src^.searchID) then continue;


    // get longer keyword
    keywordStr := keywfunc.getLongestSearchKeyword(src);
    if keywordStr = '' then continue;

     //calculate sha1 value of it
    sha1 := TSha1.create;
    sha1.transform(keywordStr[1], length(keywordStr));
    sha1.complete;
    hashValue := sha1.HashValue;
    sha1.free;


      // create search object
    s := TDHTSearch.create;
    s.m_type := dhttypes.KEYWORD;
    s.m_searchID := src^.searchID;
      //copy the first 16 bytes of hashvalue onto targetID
    CU_INT128_copyFromBuffer(@HashValue[1], @s.m_target);

      // serialize search packet
    case src^.mime_search of
      ARES_MIME_GUI_ALL: amime := ARES_MIMESRC_ALL255;
      ARES_MIME_MP3: amime := 1;
      ARES_MIME_VIDEO: amime := 3;
      ARES_MIME_IMAGE: amime := 5;
      ARES_MIME_SOFTWARE: amime := 2;
      ARES_MIME_DOCUMENT: amime := 4;
    else amime := ARES_MIME_OTHER;
    end;

    str_search := keywfunc.get_search_packet(src, true);
    delete(str_search, 1, 4);

    s.m_outPayload := chr(amime) +
      int_2_word_string(s.m_searchID) +
      str_search;

    DHT_Searches.add(s);
    s.StartIDSearch;

  end;
end;

function tthread_dht.FindDlHash(crcsha1: word; HashSha1: string): precord_download_hash;
var
  i: integer;
  dl_hash: precord_download_hash;
begin
  result := nil;
  if length(hashSha1) <> 20 then exit;

  for i := 0 to downloadHashes.count - 1 do begin
    dl_hash := downloadHashes[i];
    if dl_hash^.crchash <> crcsha1 then continue;
    if dl_hash^.hash <> hashSha1 then continue;
    result := dl_hash;
    exit;
  end;

end;

function tthread_dht.FindDownloadSha1Treeview(const HashSha1: string): Boolean;
var
  node: pcmtvnode;
  dataNode: precord_data_node;
  DnData: precord_displayed_download;
begin
  result := false;

  node := ares_FrmMain.treeview_download.GetFirst;
  while (node <> nil) do begin
    dataNode := ares_FrmMain.treeview_download.getdata(node);
    if dataNode^.m_type <> dnt_download then begin
      node := ares_FrmMain.treeview_download.getnextsibling(node);
      continue;
    end;

    DnData := dataNode^.data;

    if DnData^.handle_obj = INVALID_HANDLE_VALUE then begin
      node := ares_FrmMain.treeview_download.getnextsibling(node);
      continue;
    end;
    if length(DnData^.hash_sha1) <> 20 then begin
      node := ares_FrmMain.treeview_download.getnextsibling(node);
      continue;
    end;

    if not compareMem(@DnData^.hash_sha1[1], @HashSha1[1], 20) then begin
      node := ares_FrmMain.treeview_download.getnextsibling(node);
      continue;
    end;
    result := true;
    exit;
  end;
end;

procedure tthread_dht.checkOutHashSearches;
var
  h, i: integer;
  s: TDHTSearch;
  found: boolean;
  dataNode: precord_data_node;
  DnData: precord_displayed_download;
  node: pcmtvnode;
  tim: cardinal;
  numOutSearches: integer;

  dl_hash: precord_download_hash;
begin
  h := 0;
  while (h < downloadHashes.count) do begin
    dl_hash := downloadHashes[h];
    if not FindDownloadSha1Treeview(dl_hash^.hash) then begin
      downloadHashes.delete(h);
      dl_hash^.hash := '';
      FreeMem(dl_hash, sizeof(record_download_hash));
    end else inc(h);
  end;


  // remove hash searches not available on the GUI
  h := 0;
  while (h < DHT_Searches.count) do begin
    s := DHT_Searches[h];
    if s.m_type <> dhttypes.FINDSOURCE then begin
      inc(h);
      continue;
    end;

    if not FindDownloadSha1Treeview(s.m_outPayload) then begin
      DHT_Searches.delete(h);
      s.free;
    end else inc(h);
  end;





 // add searches online , only if there are few outgoing, these are automated requeries...
  numOutSearches := dhtsearchmanager.num_searches(dhttypes.FINDSOURCE);
  if numOutSearches >= MAX_DHT_HASH_SEARCHREQS then exit;

  tim := gettickcount;

 // check if we have a search for each download's hash
  node := ares_FrmMain.treeview_download.GetFirst;
  while (node <> nil) do begin

    dataNode := ares_FrmMain.treeview_download.getdata(node);
    if dataNode^.m_type <> dnt_download then begin
      node := ares_FrmMain.treeview_download.getnextsibling(node);
      continue;
    end;

    DnData := dataNode^.data;
    if DnData^.handle_obj = INVALID_HANDLE_VALUE then begin //completed DL?
      node := ares_FrmMain.treeview_download.getnextsibling(node);
      continue;
    end;

    if not helper_download_misc.isDownloadActive(DnData) then begin //paused DL ?
      node := ares_FrmMain.treeview_download.getnextsibling(node);
      continue;
    end;

    if ((DnData^.lastDHTCheckForSources <> 0) and
      (tim - DnData^.lastDHTCheckForSources < 3600000)) then begin // requery every hour
      node := ares_FrmMain.treeview_download.getnextsibling(node);
      continue;
    end;


    found := false;
    for i := 0 to DHT_Searches.count - 1 do begin
      s := DHT_Searches[i];
      if s.m_type <> dhttypes.FINDSOURCE then continue;
      if s.m_outPayload <> DnData^.hash_sha1 then continue;
      found := true;
      break;
    end;

    if ((not found) and (length(DnData^.hash_sha1) = 20)) then begin

      if FindDlHash(DnData^.crcsha1, DnData^.hash_sha1) = nil then begin // add pointer for easier lookup in case of hits
        dl_hash := AllocMem(sizeof(record_download_hash));
        dl_hash^.crchash := Dndata^.crcsha1;
        dl_hash^.hash := DnData^.hash_sha1;
        dl_hash^.handle_download := DnData^.handle_obj;
        downloadHashes.add(dl_hash);
      end;

      DnData^.lastDHTCheckForSources := gettickcount; // track last time we perform a FINDSOURCE search for this file

      s := TDHTSearch.create;
      s.m_type := dhttypes.FINDSOURCE;
      s.m_outPayload := DnData^.hash_sha1; //+
                         //int_2_word_string(vars_global.myport);
      CU_INT128_CopyFromBuffer(@s.m_outPayload[1], @s.m_target);
      DHT_Searches.add(s);
      s.StartIDSearch;
      inc(numOutSearches);
      if numOutSearches >= MAX_DHT_HASH_SEARCHREQS then exit;
    end;

    node := ares_FrmMain.treeview_download.getnextsibling(node);
  end;

end;

procedure tthread_dht.check_second;
begin
  if m_lastSecond > nowt then exit;
  m_lastSecond := nowt + 1;

  synchronize(check_GUI);

  DHTsearchManager.checkSearches(nowt);

  FirewallChecksDeal;

  if ((m_lastContact = 0) or
    (nowt - m_lastContact > DHT_DISCONNECTDELAY)) then
    if nowt - lastBootstrap > 60 then synchronize(check_bootstrap);


  if ((nowt - m_startTime > MIN2S(4)) and
    (m_numFirewallResults >= 3)) then begin
    if ((m_notFirewalledMessages >= 3) or
      ((m_notFirewalledMessages < 3) and (mysupernodes.mySupernodes_count >= 2))) then begin
      if vars_global.DHT_LastPublishKeyFiles = 0 then vars_global.DHT_LastPublishKeyFiles := gettickcount;
      if vars_global.DHT_LastPublishHashFiles = 0 then vars_global.DHT_LastPublishHashFiles := gettickcount;
      check_shareHashFile;
      check_shareKeyFile;
    end;
  end;


  if m_nextSelfLookup <= nowt then begin // self lookup ...search for closest hosts
    DHTSearchManager.findNodeComplete(@DHTme);
    m_nextSelfLookup := nowt + HR2S(1);
  end;

  if m_nextExpireLists <= nowt then begin // stored entries expire in 24 hours
    m_nextExpireLists := nowt + MIN2S(60);
    DHT_CheckExpireHashFileList(db_DHT_hashFile, DHT_EXPIRE_FILETIME);
    DHT_CheckExpireKeywordFileList;
  end;

  if m_nextExpirePartialSources <= nowt then begin
    m_nextExpirePartialSources := nowt + MIN2S(10);
    DHT_CheckExpireHashFileList(db_DHT_hashPartialSources, DHT_EXPIRE_PARTIALSOURCES);
  end;

  if m_nextBackUpNodes <= nowt then begin
    m_nextBackUpNodes := nowt + MIN2S(30);
    DHT_writeNodeFile(vars_global.data_path + '\Data\DHTnodes.dat', DHT_routingZone);
  end;

end;



procedure tthread_dht.check_bootstrap; // sync
begin
  if ((vars_global.DHT_possibleBootstrapClientIP = 0) or
    (vars_global.DHT_possibleBootstrapClientPort = 0)) then exit;


  DHT_sendMyDetails(CMD_DHT_BOOTSTRAP_REQ,
    vars_global.DHT_possibleBootstrapClientIP,
    vars_global.DHT_possibleBootstrapClientPort);

  lastBootstrap := nowt;
  vars_global.DHT_possibleBootstrapClientIP := 0;
  vars_global.DHT_possibleBootstrapClientPort := 0;
end;



procedure tthread_dht.check_events;
var
  i: integer;
  zone: TRoutingZone;
  FeelsAlone: boolean;
begin

  FeelsAlone := ((m_lastContact > 0) and
    (nowt - m_lastContact > DHT_DISCONNECTDELAY - MIN2S(5)));

  for i := 0 to DHT_events.count - 1 do begin
    zone := TRoutingZone(DHT_events[i]);


    if m_bigtimer <= nowt then begin

      if ((zone.m_nextBigTimer <= nowt) or (FeelsAlone)) then begin

        if zone.onBigTimer then begin
          zone.m_nextBigTimer := HR2S(1) + nowt;
          m_bigTimer := SEC(10) + nowt;
        end;

      end;

    end;


    if zone.m_nextSmallTimer <= nowt then begin
      zone.onSmallTimer;
      zone.m_nextSmallTimer := MIN2S(1) + nowt;
    end;

  end;


end;


procedure tthread_dht.shutdown;
var
  s: TDHTSearch;
  i: integer;
  firewallCheck: precord_DHT_firewallcheck;
  dl_hash: precord_download_hash;
begin
  TCPSocket_Free(DHT_socket);

  try
    while (downloadHashes.count > 0) do begin
      dl_hash := downloadHashes[downloadHashes.count - 1];
      downloadHashes.delete(downloadHashes.count - 1);
      dl_hash^.hash := '';
      FreeMem(dl_hash, sizeof(record_download_hash));
    end;
  except
  end;
  downloadHashes.free;


  try
    while (firewallChecks.count > 0) do begin
      firewallCheck := firewallChecks[firewallChecks.count - 1];
      firewallChecks.delete(firewallChecks.count - 1);
      TCPSocket_Free(FirewallCheck.sockt);
      freeMem(firewallCheck, sizeof(record_DHT_firewallcheck));
    end;
  except
  end;
  firewallChecks.free;

  try
    while (DHT_Searches.count > 0) do begin
      s := DHT_Searches[DHT_Searches.count - 1];
      DHT_Searches.delete(DHT_Searches.count - 1);
      s.free;
    end;
  except
  end;
  DHT_Searches.free;

  DHT_writeNodeFile(vars_global.data_path + '\Data\DHTnodes.dat', DHT_routingZone);
  DHT_routingZone.free;


  DHT_events.free;


  for i := 0 to high(db_DHT_hashFile.bkt) do
    DHT_FreeHashFileList(db_DHT_hashFile.bkt[i], db_DHT_hashFile);
  FreeAndNil(db_DHT_hashFile);

  for i := 0 to high(db_DHT_hashPartialSources.bkt) do
    DHT_FreeHashFileList(db_DHT_hashPartialSources.bkt[i], db_DHT_hashPartialSources);
  FreeAndNil(db_DHT_hashPartialSources);

  for i := 0 to high(db_DHT_keywordFile.bkt) do
    DHT_FreeKeywordFileList(db_DHT_keywordFile.bkt[i]);
  FreeAndNil(db_DHT_keywordFile);


  FreeAndNil(db_DHT_keywords);


  glb_lst_keywords.free;
  dispose(rfield_title);
  dispose(rfield_artist);
  dispose(rfield_album);
  dispose(rfield_category);
  dispose(rfield_date);
  dispose(rfield_language);
  wanted_search.free;

  m_searchresults.free;
end;

procedure tthread_dht.AddContacts(data: pbytearray; len_data: integer; numContacts: integer);

{
type
 TContactITem = record
   id : CU_INT128;
   ip : cardinal;
   udpport, tcpport: word;
   ttype: byte;
 end;
 }
var
  offset: integer;
  id, distance: CU_INT128;
  ip: cardinal;
  udpport, tcpport: word;
  ttype: byte;
  c: TContact;

 // CItem : TContactITem;

begin
  try

    offset := 0;
    while ((offset + 24 < len_data) and (numContacts > 0)) do begin

      move(data[offset], id[0], 4);
      move(data[offset + 4], id[1], 4);
      move(data[offset + 8], id[2], 4);
      move(data[offset + 12], id[3], 4);

      move(data[offset + 16], ip, 4);
      move(data[offset + 20], udpport, 2);
      move(data[offset + 22], tcpport, 2);
      ttype := data[offset + 24];

//      CopyMemory(pChar(@data[offset]),pchar( @CItem),24);

      inc(offset, 25);
      dec(numContacts);

      if isAntiP2PIP(ip) then continue;
      if ip_firewalled(ip) then continue;
      if probable_fw(ip) then continue;

      CU_INT128_FillNXor(@distance, @DHTme, @id);
      c := DHT_routingZone.getContact(@id, @distance);
      if c <> nil then begin
        if c.m_ip <> ip then continue; // another host may 'takeover 'any ID?
        //c.m_ip:=ip;
        c.m_udpPort := udpport;
        c.m_tcpPort := tcpport;
      end else begin
      // if he's unknown don't allow him if he's too close to me, should be very far from me anyway...
      // since we use search for rather than ping closer hosts
        if ((distance[0] < 10000) or
          (distance[1] < 10000) or
          (distance[2] < 10000) or
          (distance[3] < 10000)) then continue;

        c := DHT_routingZone.FindHost(ip);
        if c <> nil then continue; //we have seen already this host but with a different ID, probably a LAN network issue

        DHT_routingZone.add(@id, ip, udpport, tcpport, ttype);
      end;

    end;

  except
  end;
end;

procedure tthread_dht.AddContact(data: pbytearray; len_data: integer; ip: cardinal; port: word;
  tcpport: word; fromHelloReq: boolean);

var
  id, distance: CU_INT128;
  ttype: byte;
  c: TContact;
begin

  move(data[0], id[0], 4);
  move(data[4], id[1], 4);
  move(data[8], id[2], 4);
  move(data[12], id[3], 4);

  if tcpport = 0 then begin
    move(data[22], tcpport, 2);
  end;

  ttype := data[24];

  CU_INT128_FillNXor(@distance, @DHTme, @id);
  c := DHT_routingZone.getContact(@id, @distance);
  if c <> nil then begin
    if c.m_ip <> ip then exit; // another host may 'takeover 'any ID?
  //c.m_ip:=ip;
    c.m_udpPort := port;
    c.m_tcpPort := tcpport;
  end else begin
     // if he's unknown don't allow contacts too close to me, should be very far from me anyway...
      // since we use search rather than ping for closer distances
    if ((distance[0] < 10000) or
      (distance[1] < 10000) or
      (distance[2] < 10000) or
      (distance[3] < 10000)) then begin
      exit;
    end;

    c := DHT_routingZone.FindHost(ip);
    if c <> nil then exit; //we have seen already this host but with a different ID, probably a LAN network issue

    DHT_routingZone.add(@id, ip, port, tcpport, ttype);
  end;

end;

end.


