function dovePlayback_habituation_GBushVacuum(debug)
% dovePlayback_habituation_GBushVacuum(debug)
%
% This function manages playback for habituation phases 3 and 4 of Dani's experiment.
%
% cquigley 2020

% this script will check for following key presses only:
enablekeys = [55, 56, 34, 25]; % v, c, p, q
RestrictKeysForKbCheck(enablekeys);

MOVIEDIR = [pwd '/VIDEO/'];
AUDIODIR = 'AUDIO/';

pbrate=1;    % Playbackrate is 1
nFiles = 9; % nine stimulus files avialable per bird, each 10 seconds 
nReps = 5; % 4 repetitions of each to yield ~7.5 minutes of courtship 
aFs  = 48000; % audio sampling rate 
vFR = 120; % video rate

waitframes = 1; % for audio visual sync


% make and save randomisation according to constraints:
% Each of the 9 stimuli is repeated 5 times, shuffled with no repeated pairs allowed.
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
	tmp_wava = sprintf('%svacuum_%02i.wav',AUDIODIR,s); 
		
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
	
% start with background movie to grab frame. switch to stimulus protocol depending on key pressed
% Load background movie
moviename=[MOVIEDIR 'fourFrames_emptybox_1086x826.mp4'];
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

% close movie 0 after experiment! it's only 4 frames tho
% Screen('PlayMovie', movie0, 0);
% Screen('Movie',movie0);

% and grab the plant frame for later
movienameP=[MOVIEDIR 'fourFrames_georgeBush_1086x826.mp4'];
[movieP, ~, FPS, W, H]  = Screen('OpenMovie', win, movienameP, 4,[],2);  % async=4 means no audio; specflag 2 means no audio
% preloadSecs = 1 (default), specialflags = 2 for no audio also
Screen('PlayMovie', movieP, pbrate, 0);
% GRAB EMPTY CAGE TEXTURE:
texPtr_GBUSH = Screen('GetMovieImage', win, movieP, 1, 0.25); % wait, and request a particular time

% show empty cage in the meantime
Screen('DrawTexture',win,texPtr_EMPTYCAGE,[],DRAW_TO_RECT);
% Update display, don't worry about timing:
Screen('Flip', win);


go = 1;
a_counter = 1; % increment after each vacuum started; mod to length of stim to circle around if needed

while(go)
  % waiting zone:
  % wait for any key press before continuing into the experiment loop
  [~,kbcode] = KbWait([],2); % polls every 5 ms, this is sufficient as timing is unimportant right now
  stimCode = KbName(kbcode); % code 
   
  % % EXPERIMENT LOOP
  switch(stimCode)
    case 'c' % movie0 is already loaded
      % stop audio playback if needed
	    PsychPortAudio('Stop', pahandle);
      
      % empty screen
      Screen('DrawTexture',win,texPtr_EMPTYCAGE,[],DRAW_TO_RECT);
      % Update display, don't worry about timing:
      Screen('Flip', win);
      
    case 'v' % play current randomisation stimulus, reset counter when limit reached
      % empty screen (in case plant is on)
      Screen('DrawTexture',win,texPtr_EMPTYCAGE,[],DRAW_TO_RECT);
      % Update display, don't worry about timing:
      Screen('Flip', win);
      
      % prepare audio
	    % Fill the audio playback buffer with the audio data for whatever video this trial is
	    PsychPortAudio('FillBuffer', pahandle, stimOrder(a_counter)); 
      % update the counter, reset if limit reached
      a_counter = a_counter+1;
      if a_counter>length(stimOrder)
        a_counter = 1;
      end
      
      % Schedule start of audio immediately
		  tnow = GetSecs();
			tWhen = tnow + (waitframes - 0.5) * ifi;
			PsychPortAudio('Start', pahandle, 1, tWhen, 0);
	    
    case 'p' % flip to plant texture
      % stop audio playback if needed
	    PsychPortAudio('Stop', pahandle);
      
      Screen('DrawTexture',win,texPtr_GBUSH,[],DRAW_TO_RECT);
      % Update display, don't worry about timing:
      Screen('Flip', win);

    case 'q' % quit
      go = 0; % exit the while loop and clean up  
    otherwise
      go = 0; % also exit and clean up. should be an impossible point to reach tho
  endswitch
  
end % while loop
    

% Release textures:
Screen('Close', texPtr_EMPTYCAGE);
Screen('Close',texPtr_GBUSH);
Screen('CloseMovie',movie0); % close both movies
Screen('CloseMovie',movieP);


% Close screen etc.:
% Priority(0);
% Delete all dynamic audio buffers:
PsychPortAudio('DeleteBuffer');
% Close the audio device
PsychPortAudio('Close', pahandle);
ShowCursor(screen);
RestrictKeysForKbCheck([]);
sca;