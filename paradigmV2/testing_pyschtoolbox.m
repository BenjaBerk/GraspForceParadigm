 æ% Clear the workspace and the screen
sca;
close all;
clear;

disp('Loading lsl library...')
lib = lsl_loadlib();

Screen('Preference', 'SkipSyncTests', 1);

% Here we call some default settings for setting up Psychtoolbox
PsychDefaultSetup(2);


% Get the screen numbers
screens = Screen('Screens');

% Draw to the external screen if avaliable
screenNumber = max(screens);

% Define black and white
white = WhiteIndex(screenNumber);
black = BlackIndex(screenNumber);

% Open an on screen window
[window, windowRect] = PsychImaging('OpenWindow', screenNumber, black);

% Get the size of the on screen window
[screenXpixels, screenYpixels] = Screen('WindowSize', window);

% Query the frame duration
ifi = Screen('GetFlipInterval', window);

% Set up alpha-blending for smooth (anti-aliased) lines
Screen('BlendFunction', window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');

% Setup the text type for the window
Screen('TextFont', window, 'Ariel');
Screen('TextSize', window, 36);

% Get the centre coordinate of the window
[xCenter, yCenter] = RectCenter(windowRect);

% Here we set the size of the arms of our fixation cross
fixCrossDimPix = 40;

% Now we set the coordinates (these are all relative to zero we will let
% the drawing routine center the cross in the center of our monitor for us)
xCoords = [-fixCrossDimPix fixCrossDimPix 0 0];
yCoords = [0 0 -fixCrossDimPix fixCrossDimPix];
allCoords = [xCoords; yCoords];

% Set the line width for our fixation cross
lineWidthPix = 4;

%--------- Experiment variables -------
ObjectList = 1; %%%%%% IMPORTANT TO CHANGE FOR EVERY PARTICIPANT!!! %%%%%

nTrialsPerObject = 2;
nBlocks = 2;
nPracticeTrials = 2;
nObjects = 2;

fixInterval = 3;
executionTime = 5;
interTrialBreak = 2;

spaceKey = KbName('space');
%--------------------------------------

%-------- Randomized objects ----------
cylLight = 'cyl_light';
cylHeavy = 'cyl_heavy';
sphereLight = 'sphere_light';
sphereHeavy = 'sphere_heavy';

inst_1 = 'Welcome, in this experiment you will be tasked with picking up one of four objects \n which will be presented in front of you. \n';
inst_2 = 'Prior to the start you will be doing a small practice block to get used to the movement and the speed.\n';
inst_3 = 'Please see the images below for instructions on how to grasp and execute the movement. \n';
inst_4 = '\n When ready to start the practice, hit any key on the keyboard.\n';

% inst_img = 'affordance_model.png'; % Test image, pls remember to change !!!!!!!!!!!!!!!!
% [objLoad,map,alpha] = imread(inst_img);
object = Screen('MakeTexture',window,objLoad); 

disp(['Reading object order from file ' num2str(ObjectList) '...'])
fileID = fopen(['ObjectList_' num2str(ObjectList) '.txt'], 'r');

% Initialize an empty cell array to store the nested cells
objectOrder = cell(1,nBlocks);

% Read each line and store it as a 1x4 cell in the 1x8 cell array
i = 1;
line = fgetl(fileID);
while ischar(line)
    % Split the line by commas and store as a 1x4 cell
    objectOrder{i} = strsplit(line, ',');
    i = i + 1;
    line = fgetl(fileID);
end

% Close the file
fclose(fileID);

disp('Read object data from file');

%--------------------------------------

%-------- LSL marker stream -----------

% Setting up marker stream
info = lsl_streaminfo(lib, 'MyMarkerStream', 'Markers',1,0,'cf_string');
outlet = lsl_outlet(info);

blockId = 'block_start';
trialID = '';
fixStart = 'fixation_start';
fixEnd = 'fixation_end';
movementStart = 'movement_start';

movementEnd = 'movement_end';
breakStart = 'break_start';
breakEnd = 'break_end';
%-------------------------------------


% Here we use to a waitframes number greater then 1 to flip at a rate not
% equal to the monitors refreash rate. For this example, once per second,
% to the nearest frame
function wf = waitframe(n,ifi)
    wf = round(n/ifi);
    disp(wf)
end

%--- Practice block with instructions --- %

outlet.push_sample({'practice_start'})
DrawFormattedText(window, [inst_1 inst_2 inst_3 inst_4],...
                'center', screenYpixels * 0.25, white);
Screen('DrawTexture', object, 'center', screenYpixels * 0.75); % draw the object 
vbl = Screen('Flip', window);
KbStrokeWait;
% Send block marker
for i = 1:nTrialsPerObject
    if i == 1
        DrawFormattedText(window, 'Press Any Key To Begin practice',...
            'center', 'center', white);
        vbl = Screen('Flip', window);

        KbStrokeWait;
    end

    % Screen 1: Create fixation cross for 3 seconds
    Screen('DrawLines', window, allCoords,...
    lineWidthPix, white, [xCenter yCenter], 2);

    % Wait until break is finished to flip to next screen
    vbl = Screen('Flip', window, vbl + (waitframe(interTrialBreak,ifi) - 0.5) * ifi);

       % Screen 2: Create execute movement screen for 5 sec
    DrawFormattedText(window, 'X',...
            'center', 'center', black);
    disp('screen 2')
    % Wait until fixation is finished to flip to next screen
    vbl = Screen('Flip', window, vbl + (waitframe(fixInterval,ifi) - 0.5) * ifi);

    % Send marker when participant initiates and finishes movement
    waitTime = waitframe(executionTime, ifi);
    spacePressedSent = false;
    
    startTime = GetSecs;
    goalTime = startTime + 4.50;
    while startTime < goalTime
        [keyIsDown,secs, keyCode] = KbCheck;
        if ~keyCode(spaceKey) & spacePressedSent == false
            spacePressedSent = true;
            disp('execution started');
        end
        if keyCode(spaceKey) & spacePressedSent == true
            disp('execution finished')
            break
        end
        startTime = GetSecs;
    end
    
    % Screen 3: Create get ready screen 
    if i < nTrialsPerObject
        DrawFormattedText(window, 'get ready for next trial...',...
                'center', 'center', white);
    end
    % Wait until executiontime is finished to flip to next screen
    vbl = Screen('Flip', window, vbl + (waitframe(executionTime,ifi) - 0.5) * ifi);
    outlet.push_sample({breakStart})

end
% Flip outside of the loop to get a time stamp
DrawFormattedText(window, 'End of practice, please notify the experimenter when ready to continue',...
                'center', 'center', white);
vbl = Screen('Flip', window);
KbStrokeWait;
outlet.push_sample({'practice_finished'})
% ----------------------------------------- %

% --- Begin Experiment --- %
for block = 1:nBlocks
    DrawFormattedText(window, 'Press Any Key To Begin New Block',...
                'center', 'center', white);
    vbl = Screen('Flip', window);
    KbStrokeWait;
    % Send block marker
    outlet.push_sample({['block_' num2str(block)]})

    for obj = 1:nObjects
        % Send object marker
        object = objectOrder{block}{obj};
        disp(object)
    
        % Start the trial loop for object
        for i = 1:nTrialsPerObject
            if i == 1
                DrawFormattedText(window, 'Press Any Key To Begin',...
                    'center', 'center', white);

                vbl = Screen('Flip', window);

                KbStrokeWait;
                outlet.push_sample({[object 'start']})
            end

            % Screen 1: Create fixation cross for 3 seconds
            Screen('DrawLines', window, allCoords,...
            lineWidthPix, white, [xCenter yCenter], 2);

            % Wait until break is finished to flip to next screen
            vbl = Screen('Flip', window, vbl + (waitframe(interTrialBreak,ifi) - 0.5) * ifi);
            outlet.push_sample({fixStart})
      
               % Screen 2: Create execute movement screen for 5 sec
            DrawFormattedText(window, 'X',...
                    'center', 'center', black);
            disp('screen 2')
            % Wait until fixation is finished to flip to next screen
            vbl = Screen('Flip', window, vbl + (waitframe(fixInterval,ifi) - 0.5) * ifi);
            outlet.push_sample({movementStart})

            % Send marker when participant initiates and finishes movement
            waitTime = waitframe(executionTime, ifi);
            spacePressedSent = false;
                         
            startTime = GetSecs;
            goalTime = startTime + 4.7;
            while startTime < goalTime
                [keyIsDown,secs, keyCode] = KbCheck;
                if ~keyCode(spaceKey) & spacePressedSent == false
                    spacePressedSent = true;
                    outlet.push_sample({'execution_started'})
                    disp('execution started');
                end
                if keyCode(spaceKey) & spacePressedSent == true
                    outlet.push_sample({'execution_finished'})
                    disp('execution finished')
                    break
                end
                startTime = GetSecs;
            end
            
            % Screen 3: Create get ready screen 
            if i < nTrialsPerObject
                DrawFormattedText(window, 'get ready for next trial...',...
                        'center', 'center', white);
            end
            % Wait until executiontime is finished to flip to next screen
            vbl = Screen('Flip', window, vbl + (waitframe(executionTime,ifi) - 0.5) * ifi);
            outlet.push_sample({breakStart})

        end
        %------ Have a break -------
        if obj < nObjects
            DrawFormattedText(window, 'Have a break while objects are switched...\n Press any key when ready to continue',...
                    'center', 'center', white);
            vbl = Screen('Flip', window);
            KbStrokeWait;
        end
    end
    %--------- Have a break -------
    if block < nBlocks
        DrawFormattedText(window, 'End of block...\n Press any key when ready to continue',...
                'center', 'center', white);
        vbl = Screen('Flip', window);
        KbStrokeWait
    end
    
end

DrawFormattedText(window, 'end of experiment, press any key to exit',...
            'center', 'center', white);
Screen('Flip', window);
% Flip to the screen

% Wait for a key press
KbStrokeWait;

% Clear the screen
sca;