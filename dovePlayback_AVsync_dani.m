function dovePlayback_AVsync_dani(ringNumber,debug)
% dovePlayback_AVsync(ringNumber,debug)
%
% This function manages playback for Dani's experiment.
% Required inputs: ring number of the bird being tested. This determines which 
% stimulus set she is shown.
%
% cquigley 2020, based on dovePlayback_AVsync

% to-do: check ifi delay of audio/video is correct
% fix number of stim
% fix number of repetitions

% % TRY WITH PRIORITY 1 BUT IT MIGHT BREAK STUFF
% Priority(1);

% MAKE A MAPPING OF RING NUMBER TO STIMBIRD (2/8) and COND (A/V/AV)
RINGNUM_MAPPING = {6,	2,	'A';
18,	8,	'A';
25,	2,	'A';
111,	8,	'A';
510,	2,	'A';
195,	8,	'A';
509,	2,	'A';
7,	8,	'V';
19,	2,	'V';
35,	8,	'V';
52,	2,	'V';
502,	8,	'V';
134,	2,	'V';
700,	8,	'V';
1,	2,	'AV';
16,	8,	'AV';
24,	2,	'AV';
612,	8,	'AV';
559,	2,	'AV';
575,	8,	'AV';
613,	2,	'AV'};
									 
try
	brow = find([RINGNUM_MAPPING{:,1}]==ringNumber);
	stimbird = RINGNUM_MAPPING{brow,2};
	expcond = RINGNUM_MAPPING{brow,3};
catch
	disp('Problem with this ringnum, please check it is correct / RINGNUM_MAPPING is complete');
	return
end

MOVIEDIR = [pwd '/VIDEO/'];
AUDIODIR = 'AUDIO/';

pbrate=1;    % Playbackrate is 1
nFiles = 10; % ten stimulus files avialable per bird 
nReps = 5; % 5 repetitions of each to yield >8 minutes of courtship 
aFs  = 48000; % audio sampling rate 
vFR = 120; % video rate
shortPauseParams_s = [0.5 1.5]-0.2; % range for uniform random sampling for short pause [minus the 0.2 s wait for prebuffering]
longPause_s = 40-0.2; % was 57 seconds for cle (minus prebuffering)
waitframes = 1; % for audio visual sync

% gather some params for later saving:
datapath = 'DATA/';
params.rngState = rand("state");
params.ringnum = ringNumber;
params.stimbird = stimbird;
params.expcondition = expcond;
params.expname = 'dovePlayback_AVsync_dani'; 
tmp = regexp(datestr(now),' ','split');
params.expdatetime = [tmp{1} '_' tmp{2}];

% make and save randomisation according to constraints:
% Each of the videos is repeated 5 times, shuffled with no repeated pairs allowed.
nonshuffled = repmat(1:nFiles,1,nReps); 
ok = 0;
while ~ok
	shuf = randperm(length(nonshuffled));
	if all(abs(diff(nonshuffled(shuf)))>0)
		stimOrder = nonshuffled(shuf);
		ok = 1;
	end
end		
params.stimOrder = stimOrder;


% initialise visual part
AssertOpenGL;
% prepare for graphics
% black background:
background=[0, 0, 0];
Screen('Preference', 'VisualDebugLevel', 1);
screens = Screen('Screens');
screen = max(screens);
[win, srect] = Screen('OpenWindow', screen, background);

% Measure the vertical refresh rate of the monitor
ifi = Screen('GetFlipInterval', win);
framerate = 1/ifi;
if abs(diff(framerate,vFR))>1
	disp('frame rate of monitor is not correct!');
	disp('try opening a terminal and typing xrandr --screen 1 -r 120');
	return
end

% initialise audio
% Initialize driver, request low-latency preinit:
InitializePsychSound(1);
% Number of channels and Frequency of the sound
nrchannels = 2;
aFs = 48000;

audioDelay = ifi;

% Open Psych-Audio port, with the follow arguements
% (1) [] = default sound device
% (2) 1 = sound playback only
% (3) 4 = low latency, aggressive, fail if not possible
% (4) Requested frequency in samples per second
% (5) 2 = stereo putput
pahandle = PsychPortAudio('Open', [], 1, 4, aFs, nrchannels);
% read wavs and put (mono) audio into buffers for later passing to audio device
Abuffers = []; % empty vector
for s = 1:nFiles
	tmp_wava = sprintf('%s%02i_%02i%s.wav',AUDIODIR,stimbird,s,expcond); 
		
	[audiodata, infreq] = psychwavread(tmp_wava);
		
	if infreq ~= aFs
		fprintf('Wrong sampling rate for audio file');
		sca
		keyboard
	end
		
	[samplecount, ninchannels] = size(audiodata);
	audiodata = repmat(transpose(audiodata), nrchannels / ninchannels, 1);

	Abuffers(s) = PsychPortAudio('CreateBuffer', [], audiodata); 
end


% Force GetSecs and WaitSecs into memory to avoid latency later on:
GetSecs;
WaitSecs(0.1);


Screen('Flip',win);

% % EMPTY CAGE
	
% start with background movie to grab frame. switch to stimulus protocol when any key is pressed
% Load background movie. This is a synchronous (blocking) load:
moviename=[MOVIEDIR '00.mp4'];
[movie0, ~, FPS, W, H]  = Screen('OpenMovie', win, moviename, 4,[],2);  % async=4 means no audio; 4+2 means no audio + async	
% preloadSecs = 1 (default), specialflags = 2 for no audio also

if FPS ~= vFR
	fprintf('Wrong sampling rate for video file');
	sca
	keyboard
end
Screen('PlayMovie', movie0, pbrate, 0);
% GRAB EMPTY CAGE TEXTURE:
texPtr_EMPTYCAGE = Screen('GetMovieImage', win, movie0, 1, 0.25); % wait, and request a particular time

xhelper = CenterRectOnPoint([0 0 W H],srect(3)/2,srect(4)/2); % find x centre for movie on screen
x1 = xhelper(1); x2 = xhelper(3);
y2 = srect(4); y1 = y2-H; % y is as low as it can go
DRAW_TO_RECT = [x1 y1 x2 y2];

movienameP=[MOVIEDIR 'bush_daniSizeShifted.mp4'];
[movieP]  = Screen('OpenMovie', win, movienameP, 4,[],2);  % async=4 means no audio; specflag 2 means no audio
% preloadSecs = 1 (default), specialflags = 2 for no audio also
Screen('PlayMovie', movieP, pbrate, 0);
% GRAB EMPTY CAGE TEXTURE:
texPtr_GBUSH = Screen('GetMovieImage', win, movieP, 1); % wait, and request a particular time

% close movie 0 after experiment! it's half a second
% Screen('PlayMovie', movie0, 0);
% Screen('CloseMovie',movie0);

% show empty cage in the meantime
Screen('DrawTexture',win,texPtr_EMPTYCAGE,[],DRAW_TO_RECT);
% Update display:
Screen('Flip', win);

% wait for any key press before continuing into the experiment loop
KbWait([],2); % polls every 5 ms, this is sufficient as timing is unimportant right now

% % EXPERIMENT LOOP

% VIDEO loop
for vid = 1:length(stimOrder) % for each video:
	% prepare audio
	% Fill the audio playback buffer with the audio data for the next stimulus
	PsychPortAudio('FillBuffer', pahandle, stimOrder(vid)); % whatever video this trial is
	
	% Get moviename 
	moviename=sprintf('%s%02i_%02i.mp4',MOVIEDIR,stimbird,stimOrder(vid));
	movie = Screen('OpenMovie', win, moviename,4,2,2);  % async=4 means no audio; 4+2 means no audio + async; preload 2 s video; specialflags is 2 for no audio
	Screen('PlayMovie', movie, pbrate, 0);	
	% wait for a bit of prebuffering 	
	WaitSecs(0.2);	
	
	% Playback loop: Fetch video frames and display them...
  firstFrame = 1; % so that sound is started at the right time
	while 1
	  
    % A:
    % keep pointing to same tex until audio has finished  
    if isequal(expcond,'A')
      tex = texPtr_GBUSH;
      
    else % V & AV:
      % Return next frame in movie, in sync with current playback
		  % time and sound.
		  % tex either the texture handle or zero if no new frame is
		  % ready yet. pts = Presentation timestamp in seconds.
		  [tex pts] = Screen('GetMovieImage', win, movie, 1);
    end 
      
      
		% Valid texture returned?
		if tex < 0
			% The end of this movie is reached.
			break
		end
		
		if tex > 0
		
			if firstFrame % first frame of movie:
				% Yes. Draw the new texture immediately to screen:
				Screen('DrawTexture', win, tex,[],DRAW_TO_RECT);

				% Schedule start of audio at exactly the predicted visual stimulus
				% onset caused by the next flip command.
				tnow = GetSecs();
				tWhen = tnow + (waitframes - 0.5) * ifi;
				tPredictedVisualOnset = PredictVisualOnsetForTime(win, tWhen);
				PsychPortAudio('Start', pahandle, 1, tPredictedVisualOnset+audioDelay, 0);
	      
        % Update display and grab some times to record:
				[vbl visual_onset t1] = Screen('Flip', win, tWhen, 2); % clearmode is 2, i.e. don't clear screen to bg between flips
				t2 = GetSecs;
        
        if ~isequal(expcond,'A')
  				% Release texture:
          Screen('Close', tex);
				end
        
        firstFrame = 0;
        vbl = vbl;
			else % post-first frame
        
   			% Yes. Draw the new texture immediately to screen:
	  		Screen('DrawTexture', win, tex,[],DRAW_TO_RECT);
				 
		  	% Update display 
			  vbl = Screen('Flip', win, vbl + 0.5*ifi, 2); % clearmode is 2, i.e. don't clear screen to bg between flips
			  
        if ~isequal(expcond,'A')  
		  	  % Release texture:
		  	  Screen('Close', tex);
        end
      
        % and if audio stimulus has already stopped in A only cond, break out of this while loop
        
        if isequal(expcond,'A')
          blahblah = PsychPortAudio('GetStatus', pahandle);
          if blahblah.Active == 0
            break
          end
        end	

			end
		end
      
	end
  
	% End of playback - stop & close the movie:
	Screen('PlayMovie', movie, 0);
	Screen('CloseMovie', movie);			

	% back to empty screen again  
	Screen('DrawTexture',win,texPtr_EMPTYCAGE,[],DRAW_TO_RECT);  
	% Update display:
	Screen('Flip', win);
	
	% stop audio playback if needed
	PsychPortAudio('Stop', pahandle);
		
	if vid<length(stimOrder)
		% % SHORT PAUSE
		if mod(vid,5)>0 % not a 5th video 
			WaitSecs(diff(shortPauseParams_s)*rand+shortPauseParams_s(1));
			% % LONG PAUSE
		else % a 5th video
			WaitSecs(longPause_s);
		end
	end
	  
	data.AreqStartTime(vid) = tWhen;
	data.AminStartTime(vid) = t1;  % start
	data.AmaxStartTime(vid) = t2;
	data.VidVisOnsets(vid) = visual_onset;
	data.Vidfliptimes(vid) = t1;
end
    
% wait for any key press before continuing beyond the experiment loop
KbWait([]); % polls every 5 ms, this is sufficient as timing is unimportant right now
% Release texture:
Screen('Close', texPtr_EMPTYCAGE);
Screen('CloseMovie',movie0); % close other movie
Screen('Close',texPtr_GBUSH);
Screen('CloseMovie',movieP);

% Close screen etc.:
% Priority(0);
% Delete all dynamic audio buffers:
PsychPortAudio('DeleteBuffer');
% Close the audio device
PsychPortAudio('Close', pahandle);
ShowCursor(screen);
sca;

% Save the results
save('-mat7-binary',[datapath params.expname '_' num2str(params.ringnum) '_' params.expdatetime '.mat'],'params','data');