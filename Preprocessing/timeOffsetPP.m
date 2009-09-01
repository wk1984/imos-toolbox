function sample_data = timeOffsetPP( sample_data )
%TIMEOFFSETPP Prompts the user to apply time correction to the given data 
% sets.
%
% All IMOS datasets should be provided in UTC time. Raw data may not
% necessarily have been captured in UTC time, so a correction must be made
% before the data can be considered to be in an IMOS compatible format.
% This function prompts the user to provide a time offset value (in hours)
% to apply to each of the data sets.
%
% Inputs:
%   sample_data - cell array of structs, the data sets to which time
%                 correction should be applied.
%
% Outputs:
%   sample_data - same as input, with time correction applied.
%

%
% Author: Paul McCarthy <paul.mccarthy@csiro.au>
%

%
% Copyright (c) 2009, eMarine Information Infrastructure (eMII) and Integrated 
% Marine Observing System (IMOS).
% All rights reserved.
% 
% Redistribution and use in source and binary forms, with or without 
% modification, are permitted provided that the following conditions are met:
% 
%     * Redistributions of source code must retain the above copyright notice, 
%       this list of conditions and the following disclaimer.
%     * Redistributions in binary form must reproduce the above copyright 
%       notice, this list of conditions and the following disclaimer in the 
%       documentation and/or other materials provided with the distribution.
%     * Neither the name of the eMII/IMOS nor the names of its contributors 
%       may be used to endorse or promote products derived from this software 
%       without specific prior written permission.
% 
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
% POSSIBILITY OF SUCH DAMAGE.
%

  error(nargchk(1,1,nargin));
  
  if ~iscell(sample_data), error('sample_data must be a cell array'); end
  if isempty(sample_data), return;                                    end
  
  dateFmt = 'dd mm yyyy';
  try dateFmt = readToolboxProperty('toolbox.dateFormat');
  catch e
  end

  descs     = {};
  timezones = {};
  offsets   = [];
  sets      = ones(length(sample_data), 1);
  
  % create descriptions, and get timezones/offsets for each data set
  for k = 1:length(sample_data)
    
    descs{k} = [...
      sample_data{k}.meta.Sites.SiteName                            ' '   ...
      num2str(sample_data{k}.meta.DeploymentData.InstrumentDepth)   'm: ' ...
      sample_data{k}.meta.instrument_make                           ' '   ...
      sample_data{k}.meta.instrument_model                          ' ('  ...
      datestr(sample_data{k}.time_coverage_start, dateFmt)          ' - ' ...
      datestr(sample_data{k}.time_coverage_end, dateFmt)            ')'];
    
    timezones{k} = sample_data{k}.meta.DeploymentData.TimeZone;
    offsets  (k) = readTimeOffset(timezones{k}); 
    
    if isnan(offsets(k)), offsets(k) = 0; end
  end
  
  f = figure(...
    'Name',        'Time Offset',...
    'Visible',     'off',...
    'MenuBar'  ,   'none',...
    'Resize',      'off',...
    'WindowStyle', 'Modal',...
    'NumberTitle', 'off');
    
  cancelButton  = uicontrol('Style',  'pushbutton', 'String', 'Cancel');
  confirmButton = uicontrol('Style',  'pushbutton', 'String', 'Ok');
  
  setCheckboxes  = [];
  timezoneLabels = [];
  offsetFields   = [];
  
  for k = 1:length(sample_data)
    
    setCheckboxes(k) = uicontrol(...
      'Style',    'checkbox',...
      'String',   descs{k},...
      'Value',    1, ...
      'UserData', k);
    
    timezoneLabels(k) = uicontrol(...
      'Style', 'text',...
      'String', timezones{k});
    
    offsetFields(k) = uicontrol(...
      'Style',    'edit',...
      'UserData', k, ...
      'String',   num2str(offsets(k)));
  end
  
  % set all widgets to normalized for positioning
  set(f,              'Units', 'normalized');
  set(cancelButton,   'Units', 'normalized');
  set(confirmButton,  'Units', 'normalized');
  set(setCheckboxes,  'Units', 'normalized');
  set(timezoneLabels, 'Units', 'normalized');
  set(offsetFields,   'Units', 'normalized');
  
  set(f,             'Position', [0.2 0.35 0.6 0.3]);
  set(cancelButton,  'Position', [0.0 0.0  0.5 0.1]);
  set(confirmButton, 'Position', [0.5 0.0  0.5 0.1]);
  
  rowHeight = 0.9 / length(sample_data);
  for k = 1:length(sample_data)
    
    rowStart = 1.0 - k * rowHeight;
    
    set(setCheckboxes (k), 'Position', [0.0 rowStart 0.6 rowHeight]);
    set(timezoneLabels(k), 'Position', [0.6 rowStart 0.2 rowHeight]);
    set(offsetFields  (k), 'Position', [0.8 rowStart 0.2 rowHeight]);
  end
  
  % set back to pixels
  set(f,              'Units', 'normalized');
  set(cancelButton,   'Units', 'normalized');
  set(confirmButton,  'Units', 'normalized');
  set(setCheckboxes,  'Units', 'normalized');
  set(timezoneLabels, 'Units', 'normalized');
  set(offsetFields,   'Units', 'normalized');
  
  % set widget callbacks
  set(f,             'CloseRequestFcn',   @cancelCallback);
  set(f,             'WindowKeyPressFcn', @keyPressCallback);
  set(setCheckboxes, 'Callback',          @checkboxCallback);
  set(offsetFields,  'Callback',          @offsetFieldCallback);
  set(cancelButton,  'Callback',          @cancelCallback);
  set(confirmButton, 'Callback',          @confirmCallback);
  
  set(f, 'Visible', 'on');
  
  uiwait(f);
  
  % apply the time offset to the 
  for k = 1:length(sample_data)
    
    if ~sets(k), continue; end
    
    disp(descs{k});
    
    
  end
  
  function keyPressCallback(source,ev)
  %KEYPRESSCALLBACK If the user pushes escape/return while the dialog has 
  % focus, the dialog is cancelled/confirmed. This is done by delegating 
  % to the cancelCallback/confirmCallback functions.
  %
    if     strcmp(ev.Key, 'escape'), cancelCallback( source,ev); 
    elseif strcmp(ev.Key, 'return'), confirmCallback(source,ev); 
    end
  end

  function cancelCallback(source,ev)
  %CANCELCALLBACK Cancel button callback. Discards user input and closes the 
  % dialog .
  %
    sets(:)    = 0;
    offsets(:) = 0;
    delete(f);
  end

  function confirmCallback(source,ev)
  %CONFIRMCALLBACK. Confirm button callback. Closes the dialog.
  %
    delete(f);
  end
  
  function checkboxCallback(source, ev)
  %CHECKBOXCALLBACK Called when a checkbox selection is changed.
  % Enables/disables the offset text field.
  %
    idx = get(source, 'UserData');
    val = get(source, 'Value');
    
    sets(idx) = val;
    
    if val, val = 'on';
    else    val = 'off';
    end
    
    set(offsetFields(idx), 'Enable', val);
    
  end

  function offsetFieldCallback(source, ev)
  %OFFSETFIELDCALLBACK Called when the user edits one of the offset fields.
  % Verifies that the text entered is a number.
  %
  
    val = get(source, 'String');
    idx = get(source, 'UserData');
    
    val = str2double(val);
    
    % reset the offset value on non-numerical 
    % input, otherwise save the new value
    if isnan(val), set(source, 'String', num2str(offsets(idx)));
    else           offsets(idx) = val;
    
    end
  
  end
end

function offset = readTimeOffset(timezone)
% readTimeOffset Reads the given time zone offset value from the
% timeOffsets.txt configuration file. If the time zone is not listed in the
% file, nan is returned.
%
  offset = nan;
  
  % read in the (timezone, offset) pairs
  filepath = [pwd filesep 'Preprocessing' filesep 'timeOffsets.txt'];
  fid = fopen(filepath, 'rt');
  if fid == -1, error('could not open timeOffsets.txt'); end

  lines = textscan(fid, '%s%s', 'Delimiter', ',', 'CommentStyle', '%');
  fclose(fid);
  timezones = lines{1};
  offsets   = lines{2};
  
  % search for a match
  for k = 1:length(timezones)
    
    if strcmp(timezone, timezones{k})
      
      offset = str2double(offsets{k});
      break;
    end
  end
end

function writeTimeOffset(newTimezone, newOffset)
%WRITETIMEOFFSET Writes the given time zone/offset pair to the
% timeOffsets.txt configuration file. If the time zone is already listed in
% the file, its offset value is updated.

  % open handles to old file and replacement file
  oldfile = [pwd filesep 'Preprocessing' filesep  'timeOffsets.txt'];
  newfile = [pwd filesep 'Preprocessing' filesep '.timeOffsets.txt'];
  
  fid = fopen(oldfile, 'rt');
  if  fid == -1, error('could not open timeOffsets.txt');  end
  
  nfid = fopen(newfile, 'wt');
  if nfid == -1
    fclose(fid);
    error('could not open .timeOffsets.txt'); 
  end
  
  % iterate through every line of the old file, copying to the new file
  % if the timezone is found, update its offset value
  line = fgetl(fid);
  updated = 0;
  while ischar(line)
    
    line = deblank(line);
    if isempty(line)
      fprintf(nfid, '\n');
      line = fgetl(fid);
      continue;
    end
    
    scan = textscan(line, '%s%s', 'Delimiter', ',', 'CommentStyle', '%');
    
    timezone  = scan{1};
    oldOffset = scan{2};
    
    if ~isempty(timezone)
      
      timezone = timezone{1};
      
      % update offset value for the specified timezone
      if strcmp(newTimezone, timezone)
      
        line = sprintf('%s, %.1f', newTimezone, newOffset);
        updated = 1;
      end
    end
    
    fprintf(nfid, '%s\n', line);
    line = fgetl(fid);
  end
  
  % if the timezone is not already in the file, add it to the end
  if ~updated
    
    fprintf(nfid, '%s, %.1f\n', newTimezone, newOffset);
  end
  
  fclose(fid);
  fclose(nfid);
  
  % overwrite the old file with the new file
  if ~movefile(newfile, oldfile, 'f')
    error(['could not replace ' oldFile ' with ' newFile]);
  end
  
end