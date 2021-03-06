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
library and download hash matching funcs
}

unit helper_share_misc;

interface

uses
  classes, ares_types, ares_objects, comettrees, sysutils,
  classes2, windows;

function is_in_lib_sha1(hash_sha1: string): boolean;
function is_in_progress_sha1(hash_sha1: string): boolean;
function isSharableExt(ext: string): boolean;
function isUnsharableName(lown: string): boolean;
function isTooSmallToShare(tipo: byte; fsize: int64): boolean;
function hash_IS_inlist(list: tmylist; hash_sha1: string; crcsha1: word): boolean;
procedure addfile_tofresh_downloads(pfilez: precord_file_library);


implementation

uses
  vars_global, helper_strings, ufrmmain, helper_unicode, const_ares,
  helper_mimetypes, helper_download_misc;

procedure addfile_tofresh_downloads(pfilez: precord_file_library);
var
  pf: precord_file_library;
begin
  try
    if vars_global.fresh_downloaded_files = nil then vars_global.fresh_downloaded_files := tmylist.create;

    pf := AllocMem(sizeof(record_file_library));
    with pf^ do begin
      hash_of_phash := pfilez^.hash_of_phash;
      hash_sha1 := pfilez^.hash_sha1;
      crcsha1 := pfilez^.crcsha1;
      path := pfilez^.path;
      ext := pfilez^.ext;
      amime := pfilez^.amime;
      corrupt := false;
      title := pfilez^.title;
      artist := pfilez^.artist;
      album := pfilez^.album;
      category := pfilez^.category;
      year := pfilez^.year;
      language := pfilez^.language;
      comment := pfilez^.comment;
      url := pfilez^.url;
      keywords_genre := pfilez^.keywords_genre;
      fsize := pfilez^.fsize;
      param1 := pfilez^.param1;
      param2 := pfilez^.param2;
      param3 := pfilez^.param3;
      filedate := pfilez^.filedate;
      vidinfo := pfilez^.vidinfo;
      mediatype := pfilez^.mediatype;
    end;

    vars_global.fresh_downloaded_files.add(pf); // to be soon parsed and sent by thread_client
  except
  end;
end;

function hash_IS_inlist(list: tmylist; hash_sha1: string; crcsha1: word): boolean;
var
  i: integer;
  pfile: precord_file_library;
begin
  result := false;
  try

    for i := 0 to list.count - 1 do begin
      pfile := list[i];
      if pfile^.crcsha1 <> crcsha1 then continue;
      if pfile^.hash_sha1 <> hash_sha1 then continue;
      result := true;
      exit;
    end;

  except
  end;
end;

function isUnsharableName(lown: string): boolean;
begin
  result := true;

  if pos('incomplete', lown) = 0 then
    if pos('___arestra___', lown) = 0 then
      if pos('credit', lown) = 0 then
        if pos('account', lown) = 0 then
          if pos('payment', lown) = 0 then
            if pos('password', lown) = 0 then
              if pos('bank', lown) = 0 then result := false;
end;

function isTooSmallToShare(tipo: byte; fsize: int64): boolean;
begin
  result := true;

  case tipo of
    5: begin
        if fsize < MIN_VIDEO_SIZE then exit;
      end;
    1: begin
        if fsize < MIN_MP3_SIZE then exit;
      end else begin
      if fsize < 1 then exit;
    end;
  end;

  result := False;
end;

function isSharableExt(ext: string): boolean;
begin
  result := False;
  if length(ext) < 3 then exit; //punto +2

  if pos(ext, SHARED_AUDIO_EXT) = 0 then
    if pos(ext, SHARED_VIDEO_EXT) = 0 then
      if pos(ext, SHARED_IMAGE_EXT) = 0 then
        if pos(ext, SHARED_DOCUMENT_EXT) = 0 then
          if pos(ext, SHARED_SOFTWARE_EXT) = 0 then
            if pos(ext, SHARED_OTHER_EXT) = 0 then exit;

  result := true;
end;

function is_in_progress_sha1(hash_sha1: string): boolean;
var
  node: pCmtVnode;
  dataNode: precord_data_node;
  DnData: precord_displayed_download;
  crcsha1: word;
begin


  result := false;

  if length(hash_sha1) <> 20 then exit;

  crcsha1 := crcstring(hash_sha1);

  node := ares_frmmain.treeview_download.getfirst;
  while (node <> nil) do begin
    dataNode := ares_frmmain.treeview_download.getdata(node);
    if dataNode^.m_type <> dnt_download then begin
      node := ares_frmmain.treeview_download.getnextsibling(node);
      continue;
    end;

    DnData := dataNode^.data;
    if DnData^.handle_obj <> INVALID_HANDLE_VALUE then
      if DnData^.crcsha1 = crcsha1 then
        if DnData^.hash_sha1 = hash_sha1 then begin
          result := helper_download_misc.isDownloadActive(DnData);
          exit;
        end;
    node := ares_frmmain.treeview_download.getnextsibling(node);
  end;

end;


function is_in_lib_sha1(hash_sha1: string): boolean;
var
  i: integer;
  pfile: precord_file_library;
  crcsha1: word;
begin
  result := false;

  if length(hash_sha1) <> 20 then exit;

  crcsha1 := crcstring(hash_sha1);

  for i := 0 to vars_global.lista_shared.count - 1 do begin
    pfile := vars_global.listA_shared[i];
    if pfile^.crcsha1 <> crcsha1 then continue;
    if pfile^.hash_sha1 = hash_sha1 then begin
      result := true;
      break;
    end;
  end;
end;

end.

