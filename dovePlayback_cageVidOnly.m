function dovePlayback_cageVidOnly(debug)
% dovePlayback_AVsync(debug)
%
% This function manages playback for habituation of Dani's experiment.
%
% cquigley 2020
									 
expcond = 1; % cage video only

MOVIEDIR = [pwd '/VIDEO/']; % full path needed!

pbrate=1;    % Playbackrate is 1
aFs  = 48000; % audio sampling rate 
vFR = 120; % video rate

waitframes = 1; % for audio visual sync

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

% Force GetSecs and WaitSecs into memory to avoid latency later on:
GetSecs;
WaitSecs(0.1);

% can't remember why this is here but it doesn't do any harm
Screen('Flip',win);

% % EMPTY CAGE
% start with background movie to grab frame. switch to stimulus protocol when any key is pressed
% Load background movie
%moviename=[MOVIEDIR 'fourFrames_emptybox_1086x826.mp4'];


moviename=[MOVIEDIR 'bush_daniSizeShifted.mp4'];

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

% wait for any key press before shutting everything down
KbWait([],2); % polls every 5 ms, this is sufficient as timing is unimportant right now

% Release texture:
Screen('Close', texPtr_EMPTYCAGE);
Screen('CloseMovie',movie0); % close other movie

% Close screen etc.:
% Priority(0);
ShowCursor(screen);
sca;