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
 }

{
Description:
global consts
}

unit const_ares;

interface

uses
windows,graphics;

const
 DEFAULT_BUILD_NO      = 3027;
 ARES_VERS             = '2.0.6.3027';
 NUM_SESSIONS_TO_SUPERNODES = 5;
 APPNAME               = 'Ares';
 BITTORRENT_APPNAME    = 'AG';

 STR_HTTP_LOWER='http://';
 STR_DEFAULT_WEBSITE=STR_HTTP_LOWER+'aresgalaxy.sourceforge.net';
 STR_DEFAULT_HOMEPAGE=STR_DEFAULT_WEBSITE+'/areshome.html';

 IDTAB_LIBRARY  = 0;
 IDTAB_SCREEN   = 1;
 IDTAB_SEARCH   = 2;
 IDTAB_TRANSFER = 3;
 IDTAB_CHAT     = 4;
 IDTAB_OPTION   = 5;

  
 DHT_SINCE_BUILD       =2996;
 BITTORRENTPARTIAL_BUILDSINCE = 3020; //DEBUG
 CHRSPACE=chr(32);
 
 ARES_MIME_OTHER       = 0;
 ARES_MIME_MP3         = 1;
 ARES_MIME_AUDIOOTHER1 = 2;
 ARES_MIME_AUDIOOTHER2 = 4;
 ARES_MIME_SOFTWARE    = 3;
 ARES_MIME_VIDEO       = 5;
 ARES_MIME_DOCUMENT    = 6;
 ARES_MIME_IMAGE       = 7;
 ARES_MIMESRC_OTHER    = 8;
 ARES_MIMESRC_ALL255   = 255;
 ARES_MIMECLTSRC_ALL   = 0;
 ARES_MIME_GUI_ALL     = 10;
 MAX_LENGTH_TITLE      = 64;
 MAX_LENGTH_FIELDS     = 64;
 MAX_LENGTH_URL        = 100;
 MAX_LENGTH_COMMENT    = 255;
 MAX_CHAT_TOPIC_LEN    = 180;
 MAX_CHAT_LINE_LEN     = 200;
 MAX_DCCHAT_LINE_LEN   = 400;
 MAX_NICK_LEN          = 20;
 LIMIT_INTEGER         = 2147483647;
 MIN_CHAT_NAME_LEN     = 4;
 MAX_CHAT_NAME_LEN     = 30;
 MAX_HSERVERS_IN_REG   = 15;
 NUM_MAX_TRANSFERS_PRIVCHAT = 2;
 MAX_CLIENTOUTCONN     = 8;
 MAX_FILE_SHARED       = 10000;
 MIN_MP3_SIZE          = 30000;
 MIN_VIDEO_SIZE        = 100000;
 MAXNUM_ACTIVE_DOWNLOADS = 100;
 MIN_SIZE_VIDEO        = 100000;
 MIN_SIZE_MP3          = 30000;
 MIN_SIZE_SHARED       = 4096;
 MAX_RESULT_PER_SEARCH = 200;
 MAX_HASHHIT_SUPERNODEUDP = 5;
 HASH_SUPERNODE_ALLOWED_USERS = 400;
 ACCEPT_HARD_LIMIT     = 550;
 MAX_CONNECTIONS_PER_IP = 5;
 MAX_ACCEPT_SOCKETS_NO_OR_FLOOD = 40;
 MAX_ACCEPT_SOCKETS_FROM_IP_NO_OR_FLOOD = 10;
 MAX_ACCEPT_PER_CALL   = 5;
 MAX_TRY_PARTIAL       = 2;
 NUMERO_MAX_ALTERNATES_A_PARTIAL = 10;
 NUM_MAX_QUEUED        = 100;
 MAX_NUM_SOURCES       = 70;
 MAX_NUM_PARTIAL_SOURCES = 200;
 CHRNULL               = chr(0);
 CRLF                  = chr(13)+chr(10);
 MAX_SERVER_COMMANDS   = 15;
 MAX_USER_COMMANDS     = 5;
 MAX_HISTORY_TYPEDCHATLINES = 100;
 GWL_EXSTYLE           = (-20);
 LEECH_MIN_BANDWIDTH   = 8;
 GIGABYTE              = 1073741824;
 MEGABYTE              = 1048576;
 KBYTE                 = 1024;
 MAX_CHUNK_SIZE        = 20971520; // 20*MEGABYTE;
 STR_ANON              = 'anon_';
 STR_BITTORRENT        = 'BitTorrent';
 STR_MYSHAREDFOLDER    = 'My Shared Folder';
 STR_MYTORRENTS        = 'My Torrents';
 STR_ALBUMART          = 'albumart';
 STR_DRM_EXT           = '.wma .asf .m4p .m4a';
 STR_LENGTH_HEADER     = 'length=';
 STR_LIMIT             = 'limit=';
 STR_POLLMAX           = 'pollMax=';
 STR_POLLMIN           = 'pollMin=';
 STR_XQUEUED_HEADER    = 'X-Queued: position=';
 NULL_SHA1             = '00000000000000000000';
 STR_FOURQSTNMRK       = '????';
 STR_UNKNOWNCLIENT     = '@'+STR_FOURQSTNMRK;
 STR_UNKNOWNS          = 'Unknown';
 STR_KB                = 'KB';
 STR_MB                = 'MB';
 STR_BYTES             = 'bytes';
 STR_NA                = 'N/A';
 
 STR_CHAR_A            = 'a';
 STR_CHAR_B            = 'b';
 STR_CHAR_C            = 'c';
 STR_CHAR_D            = 'd';
 STR_CHAR_E            = 'e';
 STR_CHAR_F            = 'f';
 STR_CHAR_G            = 'g';
 STR_CHAR_H            = 'h';
 STR_CHAR_I            = 'i';
 STR_CHAR_K            = 'k';
 STR_CHAR_L            = 'l';
 STR_CHAR_M            = 'm';
 STR_CHAR_N            = 'n';
 STR_CHAR_O            = 'o';
 STR_CHAR_P            = 'p';
 STR_CHAR_Q            = 'q';
 STR_CHAR_R            = 'r';
 STR_CHAR_S            = 's';
 STR_CHAR_T            = 't';
 STR_CHAR_U            = 'u';
 STR_CHAR_V            = 'v';
 STR_CHAR_Z            = 'z';
 STR_CHAR_X            = 'x';
 STR_CHAR_Y            = 'y';
 STR_CHAR_W            = 'w';

 STR_TRANSFER_ENCODING_CHUNKED1='transfer-encoding: chunked';
 STR_TRANSFER_ENCODING_CHUNKED2='transfer-encoding:chunked';
 
 STR_DEFAULT_AWAYMSG   = 'This is an automatic away message generated by '+APPNAME+
                         ' program, user isn''t here now.';
 REG_SHARE_ROOT        = 'lib';
 REG_BOUNDS_ROOT       = 'bounds';
 REG_STR_STATSUPHIST   = 'Stats.TMBUpHist';
 REG_STR_STATSDNHIST   = 'Stats.TMBDownHist';
 REG_STR_STATS_UPSPEED = 'Stats.CUpSpeed';
 REG_STR_STATS_DNSPEED = 'Stats.CDnSpeed';
 REG_STR_STATS_TOTUPTIME = 'Stats.CTtUptime';
 REG_STR_STATS_AVGUPTIME = 'Stats.CAvgTime';
 REG_STR_STATS_FIRSTDAY  = 'Stats.CFRTime';
 ARESKEY               = 'Software\Ares\';
 GETARESNET1           = 'AresNet1';
 GETARESNET2           = 'AresNet2';
 GETARESNET4           = 'AresNet4';
 GETDATASTR            = 'data';
 STR_CHATROOM_LAST_TOPIC = 'ChatRoom.LastTopic';


implementation


end.
