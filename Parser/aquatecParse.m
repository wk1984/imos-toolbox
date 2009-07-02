function sample_data = aquatecParse( file )
%AQUATECPARSE Parses a raw data file retrieved from an Aquatec AQUAlogger.
%
% Parses a raw data file retrieved from an Aquatec AQUAlogger 520. The
% AQUAlogger 520 range of sensors provide logging capability for temperature
% and pressure.
% (http://www.aquatecgroup.com)
%
% The following variants on the AQUAlogger 520 exist:
%   - 520T:  temperature
%   - 520P:  pressure
%   - 520PT: pressure and temperature
%
% The raw data file format for all loggers is identical; every line in a
% file, including sample data, is a key-value pair, separated by a comma. 
% The following lines are examples:
%
% VERSION,3.0
% LOGGER TYPE,520PT Pressure & Temperature   
% LOGGER,23-502,SYD100 T2 
% DATA,23:00:01 24/06/2008,29412,16.310779,26345,1.025358,
% DATA,23:00:02 24/06/2008,29411,16.312112,26346,1.025938,
%
% If the logger was configured to use burst mode, the bursts are averaged.
%
% Inputs:
%   file - cell array of file names (Only supports one currently).
%
% Outputs:
%   sample_data - struct containing sample data.
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

  if ~iscellstr(file), error('file must be a cell array of strings'); end

  sample_data = struct;
  sample_data.dimensions = {};
  sample_data.variables  = {};
  
  %
  % read in the file
  %

  % read in the header information into 'keys' and 
  % 'meta', and the rest of the file into 'data'
  fid = -1;
  keys = {};
  meta = {};
  data = '';
  try
    fid = fopen(file{1}, 'rb');
    
    % note the use of fgets - the newline is kept, so we can reconstruct
    % the first data line read after all the metadata has been read in
    line = fgets(fid);
    while ischar(line) ...
       && ~strncmp(line, 'DATA', 4) ...
       && ~strncmp(line, 'BURSTSTART', 10)
     
      line = textscan(line, '%s%[^\n]', 'Delimiter', ',');
      keys{end+1} = deblank(line{1});
      meta{end+1} = deblank(line{2});
      
      line = fgets(fid);
    end
    
    % we reached end of file before any 
    % DATA or BURSTSTART lines were read
    if ~ischar(line), error('no data in file'); end
    
    % read the rest of the file into 'data' 
    % - we've already got the first line
    data = char(fread(fid, inf, 'char')');
    data = [line data];
    
    fclose(fid);
  catch e 
    if fid ~= -1, fclose(fid); end
    rethrow(e);
  end
  
  %
  % get basic metadata
  % 
  
  model    = getValues({'LOGGER TYPE'},keys, meta);
  firmware = getValues({'VERSION'},    keys, meta);
  serial   = getValues({'LOGGER'},     keys, meta);
  
  sample_data.instrument_make      = 'Aquatec';
  sample_data.instrument_model     = ['Aqualogger ' model{1}];
  sample_data.instrument_firmware  = firmware{1};
  sample_data.instrument_serial_no = serial{1};
  
  %
  % get regime data (mode, sample rate, etc)
  %
  
  regime = getValues({'REGIME'}, keys, meta);
  regime = textscan(regime{1}, '%s', 'Delimiter', ',');
  regime = deblank( regime{1});
  
  % if continuous mode was used, we need to save the start and stop 
  % times so we can interpolate sample times and sample interval
  startTime = getValues({'START TIME'}, keys, meta);
  startTime = datenum(startTime{1}, 'HH:MM:SS dd/mm/yyyy');
  
  stopTime = getValues({'STOP TIME'}, keys, meta);
  stopTime = datenum(stopTime{1}, 'HH:MM:SS dd/mm/yyyy');
  
  % turn sample interval into serial date units
  sampleInterval  = textscan(regime{2}, '%f%s');
  if strncmp(sampleInterval{2}, 'minute', 6)
    sampleInterval = sampleInterval{1}/3600;
  else 
    sampleInterval = sampleInterval{1}/86400;
  end
  
  % figure out if burst or continuous mode is used - if burst 
  % mode is used, we need to average the samples in each burst
  isBurst         = regime{1};
  samplesPerBurst = 1;
  
  % if the logger was using burst mode, we need to save the number 
  % of samples per burst so we know how many to average over
  if strcmp(isBurst, 'Burst Mode')
    
    isBurst         = true;
    samplesPerBurst = str2double(regime{3});
    
  else isBurst = false;
  end
  
  %
  % figure out what data (temperature, pressure) is in the file
  %
  heading = getValues({'HEADING'}, keys, meta);
  heading = textscan(heading{1}, '%s', 'Delimiter', ',');
  heading = deblank (heading{1});
  
  numFields = length(heading);
  timeIdx   = find(ismember(heading, 'Timecode'));
  tempIdx   = find(ismember(heading, 'Ext temperature'));
  presIdx   = find(ismember(heading, 'Pressure'));
  
  % figure out the textscan format to use for reading 
  % in the data at most 8 fields are read in (6 fields 
  % for time y,m,d,H,M,S, and fields for temp/pressure)
  format = '%*s';
  delims = ',';
  for k = 1:numFields
    
    % I'm assuming that the index order is: time < temp < pres
    if ~isempty(timeIdx) &&  k == timeIdx
      format = [format '%f%f%f%f%f%f'];
      delims = [delims ': /'];
    elseif ~isempty(tempIdx) && (k == tempIdx+1), format = [format '%f'];
    elseif ~isempty(presIdx) && (k == presIdx+1), format = [format '%f'];
    else                                          format = [format '%*s'];
    end
  end
  
  time = [];
  temp = [];
  pres = [];
  
  data = textscan(data, format, 'Delimiter', delims);
  
  % if the file contains timestamps, use them
  if ~isempty(timeIdx) 
    time = datenum(data{6},data{5},data{4},data{1},data{2},data{3});
  
  % otherwise generate timestamps from 
  % the start time and sample interval
  else time = startTime:sampleInterval:stopTime; 
  end
  
  % get temperature if present
  if ~isempty(tempIdx)
    
    if ~isempty(timeIdx), tempIdx = timeIdx + 6;
    else                  tempIdx = 1;
    end
    
    temp = data{tempIdx};
  end
  
  % get pressure if present
  if ~isempty(presIdx)
    
    if     ~isempty(tempIdx), presIdx = tempIdx + 1;
    elseif ~isempty(timeIdx), presIdx = timeIdx + 6;
    else                      presIdx = 1;
    end
    
    pres = data{presIdx};
  end
  
  %
  % if burst mode, we need to average the bursts
  %
  if isBurst
    newTime = [];
    newTemp = [];
    newPres = [];
    
    numBursts = length(time) / samplesPerBurst;
    
    for k = 1:numBursts
      
      % get indices for the current burst
      burstIdx = 1 + (k-1)*samplesPerBurst;
      burstIdx = burstIdx:(burstIdx+samplesPerBurst-1);
      
      % time is the mean of the burst timestamps
      burstTime = mean(time(burstIdx));
      
      newTime(k) = burstTime;
      
      % temp/pres are means of the burst samples
      if ~isempty(temp), newTemp(k) = mean(temp(burstIdx)); end
      if ~isempty(pres), newPres(k) = mean(pres(burstIdx)); end
    end
    
    time = newTime;
    temp = newTemp;
    pres = newPres;
  end
  
  %
  % set up the sample_data structure
  %
  sample_data.dimensions{1}.name = 'TIME';
  sample_data.dimensions{1}.data = time;
  
  if isempty(timeIdx), error('time column is missing'); end
  
  % add a temperature variable if present
  if ~isempty(tempIdx)
    sample_data.variables{end+1}.name       = 'TEMP';
    sample_data.variables{end}  .dimensions = [1];
    sample_data.variables{end}  .data       = temp;
  end
  
  % add a pressure variable if present
  if ~isempty(presIdx)
    sample_data.variables{end+1}.name       = 'PRES';
    sample_data.variables{end}  .dimensions = [1];
    sample_data.variables{end}  .data       = pres;
  end
end

function [match nomatch] = getValues(key, keys, values)
%GETVALUES Returns a cell aray of values for the given key(s), as contained in
% the given data.
%
% Inputs:
%   key     - Cell array of strings containing the key(s) to look up
%   keys    - Cell array of keys, corresponding to the values array.
%   values  - Cell array of values, corresponding to the keys array
%
% Outputs:
%   match   - values of entries with the given key.
%   nomatch - values of entries without the given key
%
  match   = {};
  nomatch = {};

  for k = 1:length(keys)
    
    % search for a match
    found = false;
    for m = 1:length(key)
      if strcmp(key{m}, keys{k}), found = true; break; end
    end
    
    % save the match (or non-match)
    if found, match  {end+1} = values{k}{1};
    else      nomatch{end+1} = values{k}{1};
    end
  end
end