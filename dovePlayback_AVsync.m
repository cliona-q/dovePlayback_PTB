function dovePlayback_AVsync(ringNumber,debug)
% dovePlayback_AVsync(ringNumber,debug)
%
% This function manages playback for Clementine's second experiment.
% Required inputs: ring number of the bird being tested. This determines which 
% stimulus set she is shown.
%
% cquigley 2019
%
% worked with: PsychtoolboxVersion
% ans = 3.0.15 - Flavor: beta - Corresponds to SVN Revision 9911

% MAKE A MAPPING OF RING NUMBER TO STIMBIRD (9/36) and COND (A/B/C)
RINGNUM_MAPPING = {195,	9,	'A';
575,	36,	'A';
3,	36,	'A';
52,	9,	'A';
700,	9,	'A';
111,	36,	'A';
1,	9,	'A';
18,	36,	'A';
536,	36,	'B';
134,	9,	'B';
7,	9,	'B';
25,	36,	'B';
612,	9,	'B';
510,	9,	'B';
51,	36,	'B';
16,	36,	'B';
509,	36,	'C';
502,	9,	'C';
4,	36,	'C';
19,	9,	'C';
559,	36,	'C';
613,	9,	'C';
6,	36,	'C';
24,	9,	'C'};

									 
									 
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
nFiles = 4; % four stimulus files avialable per bird 
nReps = 4; % 4 repetitions of each to yield ~8  minutes of courtship 
aFs  = 48000; % audio sampling rate 
vFR = 120; % video rate
% subtracted 1 from pauses as there's a new 1 sec wait between opening and playing stim movie
shortPauseParams_s = [2 4]-1; % range for uniform random sampling for short pause
longPause_s = 57-1; % 57 seconds
waitframes = 1; % for audio visual sync
% AUDIO IS 1 FRAME EARLIER THAN VIDEO! DELAY COMPENSATED BELOW WHEN WE KNOW IFI
% audioDelay = ifi;

% gather some params for later saving:
datapath = 'DATA/';
params.rngState = rand("state");
params.ringnum = ringNumber;
params.stimbird = stimbird;
params.expcondition = expcond;
params.expname = 'dovePlayback_AVsync'; % good trigger version
tmp = regexp(datestr(now),' ','split');
params.expdatetime = [tmp{1} '_' tmp{2}];

% make and save randomisation according to constraints:
% Each of the 4 videos is repeated 4 times, shuffled with no repeated pairs allowed.
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
	tmp_wava = sprintf('%s%i_%i%s.wav',AUDIODIR,stimbird,s,expcond); 
		
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

% can't remember why this is here but it doesn't do any harm
Screen('Flip',win);

% % EMPTY CAGE
	
% start with background movie to grab frame. switch to stimulus protocol when any key is pressed
% Load background movie
moviename=[MOVIEDIR '0.mp4'];
[movie0, ~, FPS, W, H]  = Screen('OpenMovie', win, moviename, 4,[],2);  % async=4 means no audio; specflag 2 means no audio
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

% close movie 0 after experiment! it's half a second
% Screen('PlayMovie', movie0, 0);
% Screen('Movie',movie0);

% show empty cage in the meantime
Screen('DrawTexture',win,texPtr_EMPTYCAGE,[],DRAW_TO_RECT);
% Update display, don't worry about timing:
Screen('Flip', win);

% wait for any key press before continuing into the experiment loop
KbWait([],2); % polls every 5 ms, this is sufficient as timing is unimportant right now

% % EXPERIMENT LOOP

% VIDEO loop
for vid = 1:length(stimOrder) % for each video:
	% prepare audio
	% Fill the audio playback buffer with the audio data for whatever video this trial is
	PsychPortAudio('FillBuffer', pahandle, stimOrder(vid)); 
	
	% Get moviename 
	moviename=sprintf('%s%i_%i.mp4',MOVIEDIR,stimbird,stimOrder(vid));
	movie = Screen('OpenMovie', win, moviename,4,2,2);  % async=4 means no audio; 4+2 means no audio + async; preload 2 s video; specialflags is 2 for no audio
	Screen('PlayMovie', movie, pbrate, 0);	
	% wait for a bit of prebuffering 	
	WaitSecs(1);	
	
	% Playback loop: Fetch video frames and display them...
  firstFrame = 1; % so that sound is started at the right time
	while 1
		% Return next frame in movie, in sync with current playback
		% time and sound.
		% tex either the texture handle or zero if no new frame is
		% ready yet. pts = Presentation timestamp in seconds.
		[tex pts] = Screen('GetMovieImage', win, movie, 1);
      
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
				% onset caused by the next flip command, including a delay as timing tests
        % with click stimulus showed that audio starts one frame before video
				tnow = GetSecs();
				tWhen = tnow + (waitframes - 0.5) * ifi;
				tPredictedVisualOnset = PredictVisualOnsetForTime(win, tWhen);
				PsychPortAudio('Start', pahandle, 1, tPredictedVisualOnset+audioDelay, 0);
	      
        % Update display and grab some times to record:
				[vbl visual_onset t1] = Screen('Flip', win, tWhen, 2); % clearmode is 2, i.e. don't clear screen to bg between flips
				t2 = GetSecs;
        
				% Release texture:
        Screen('Close', tex);
				firstFrame = 0;
        vbl = vbl;
			else
				% Yes. Draw the new texture immediately to screen:
				Screen('DrawTexture', win, tex,[],DRAW_TO_RECT);
				
				% Update display 
				vbl = Screen('Flip', win, vbl + 0.5*ifi, 2); % clearmode is 2, i.e. don't clear screen to bg between flips
				  
				% Release texture:
				Screen('Close', tex);
			end
		end
      
	end
  
	% End of playback - stop & close the movie:
	Screen('PlayMovie', movie, 0);
	Screen('CloseMovie', movie);			

	% back to empty screen again  
	Screen('DrawTexture',win,texPtr_EMPTYCAGE,[],DRAW_TO_RECT);  
	% Update display, don't worry about timing:
	Screen('Flip', win);
	
	% stop audio playback if needed
	PsychPortAudio('Stop', pahandle);
		
	if vid<length(stimOrder)
		% % SHORT PAUSE
		if mod(vid,2)==1 % odd numbered video
			WaitSecs(diff(shortPauseParams_s)*rand+shortPauseParams_s(1));
			% % LONG PAUSE
		else
			WaitSecs(longPause_s);
		end
	end
	% save what we need  
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