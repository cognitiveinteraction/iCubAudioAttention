%ITD Salience Localizer

%fundamentally different from ITD Localizer!
%ITD Salience Localizer monitors the GCC-PHAT for spatial transients (i.e. new
%objects)

%it doesn't send data to YARP!  It creates a new object file when it sees a
%change in lag space

ITDSalienceConfigureAudioParameters;  %call the script that sets up the P parameter structure

doneLooping=0;
exceedsThreshold=0;

previousAngle=0.0;  %scope this outside of the loop
newAngle = 0.0;
tempNewAngle=0.0;
newAngle_deg=newAngle/pi  * (180);


%memory map the input-level file...this is the raw audio signal
%coming from the audio hardware...also initialize an index to keep track of
%which frame is the most recent available frame to read
global audioD;
global sampleD;
[audioD,sampleD]=OpenAudioInputData;
tempMostRecentSample=sampleD.Data(1,1).f;
%tempMostRecentSample=48000;  %uncomment if you want to work "offline" by reading data from the 2nd seconde of the audio dump file
currentFrameIndex = tempMostRecentSample - (P.frameDuration_samples - 1) - P.fixedLag_samples;  %set the read index to the first sample in the next frame to be read...here we need to be careful to lag the audio data dump by some small by non-trivial time
currentFrameTime = tic;  %grab the current time


%initialize a lag space vector
currentLagSpace=zeros(1,2*P.frameDuration_samples);
newLagSpace=zeros(1,2*P.frameDuration_samples);

figure(1);
hold off;
drawnow;

while (~doneLooping)  %loop continuously handling audio in a spatialy sort of way
    t=tic;
    %update our local copy of the audio data frame and its coordinates
    [frame,currentFrameIndex, currentFrameTime]=GetNextFrame(currentFrameIndex,currentFrameTime);
    
    [tempNewAngle,newLagSpace,lag_dif]=ComputeAngleUsingITDSalience(frame,currentLagSpace,P.sampleRate);  %compute the angle using a GCC-PHAT approach
    
    if(max(lag_dif))>=0.2 %update the angle if there's a positive transient (positive could be movement or onset...should do something with offsets eventually...but hmmm, not the same as onsets according to our EEG data)
        newAngle=tempNewAngle;
        newAngle_deg=newAngle/pi  * (180);
        currentLagSpace=newLagSpace; %update the lag space only if you updated the angle
    end
    
    display(['current angle is: ' num2str(newAngle_deg)]);
    
    %to plot angle in a radial plot
    %make some pretty pictures
    [x,y] = pol2cart(newAngle,1); %convert angle and unit radius to cartesian
    figure(1);
    hold off;
    compass(x,y);
    drawnow;
    
%     %to plot the lag space
%     plot(lag_dif(end/2-50:end/2+50));
%     ylim([-0.5 0.5]);
%     drawnow;

end