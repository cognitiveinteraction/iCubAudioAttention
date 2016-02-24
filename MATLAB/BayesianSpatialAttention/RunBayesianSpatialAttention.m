%build a probabalistic map of space in radial beams and update it in a
%Bayesian way over time.
%Important insight: there can be more than one "map" of space.  There can
%be a "map" of probabilities for each sound object


display(['Running audioMapRadial using code at: ' mfilename('fullpath')]);
addpath('./Functions_and_Scripts');

%perform initialization and setup;  get back a struct with all the settings
%we'll need
P=ConfigureParameters;

currentMicHeading_degrees=0.0;  %the current heading of the robot

frame=P.audioIn.Data(1,1).audioD(:,end-P.sizeFramePlusOverlap+1:end); %initialize the first frame
lastFrameStamp = frame(3,end);%ask what is the stamp of the most recent sample written (it's in the last column in the buffer)

%prime the filterbank
P_inL=zeros(8,P.nBands);
P_inR=zeros(8,P.nBands);

%matrices for holding previous frames of rms amplitudes

pastAmp=ones(P.nPastFrames,P.nBands).*.0001; %we have to seed this with some arbitrarily small numbers
pastDeltaAmp=zeros(P.nPastFrames,P.nBands);


selectedBeam=1;
selectedAngle=1;

maxBeamsIndices=zeros(P.nBands,1);
frameCounter=1;

%set up an auditory object to keep track of sound sources
O.onsetTime=tic;
O.angle=0.0;
O.salience=0.0;
O.radialPriors=ones(1,P.numSpaceAngles);

%tune the filterbank by listening to a target talker
%[fWeights]=TuneFilterBank(P);

%for testing
% fWeightsL=ones(4096,64);
% fWeightsR=ones(4096,64);

%for testing
%load('mattWeights.mat');
numFramesToAcquire=100;
acquireProbData=zeros(numFramesToAcquire,P.numSpaceAngles);


%to not use top-down attention use uniform weights
O.fWeights=ones(P.nBands,P.frameDuration_samples); %note that this is bandsxsamples.  to apply these weights in the spectral stage we'll need samples by bands because of the filterbank output

done=0;
while(~done)
    
    t=tic;
    
    
    %this reads output of the filterbank streamed by AudioCaptureFilterBank_YARP or
    %AudioCaptureFilterBank_PreRecorded
    frame=P.audioIn.Data(1,1).audioD(:,end-(P.frameDuration_samples+2*P.frameOverlap)+1:end); %note the overlap.  This is so that we can run beamformer and extract exactly frameDuration_samples from each frame by leaving off the tails.  Unnecessary unless you want to concatenate frames for output
    
    
    frameL=frame(1,:);
    frameR=frame(2,:);
    
    %%%%%%%    Pre-Attentive Stage    **********
    
    
    
    
    %%%%%%Spectral Pre-processing*****
    
    %decompose each channle using a gammatone filterbank
    %and stream out the filtered frames into two seperate files
    [fFrameL,P_outL,~,~,~]=gammatonePhase(frame(1,:),P_inL,P.sampleRate, P.cfs);
    P_inL=P_outL; %save last value to initialize next call of the filter
    [fFrameR,P_outR,~,~,~]=gammatonePhase(frame(2,:),P_inR,P.sampleRate, P.cfs);
    P_inR=P_outR;
    
    %to use top-down attention apply the filterbank weights for the
    %selected target talker here (i.e. very early selection)
    %apply learned weights to the filterbank to select the target talker in
    %a top-down sense
    %     fFrameL=fFrameL.*O.fWeights';
    %     fFrameR=fFrameR.*O.fWeights';
    
    
    %compute the amplitude of each band
    amp_frameL=rms(fFrameL,1);
    amp_frameR=rms(fFrameR,1);
    
    amp=(amp_frameL+amp_frameR)./2;  %collapse left and right channels - assume they have (nearly) identical spectra
    
    %look at onsets and offsets independently
    deltaAmpOnsets=(amp-mean(pastAmp,1))./mean(pastAmp,1);  %subtract the mean of the past spectral amplitude and divide by the mean of the past spectral amplitude
    deltaAmpOffsets=(mean(pastAmp,1)-amp)./mean(pastAmp,1);
    pastAmp=circshift(pastAmp,[1 0]); %push the stack down and wrap
    pastAmp(1,:)=amp;  %overwrite the top of the stack
    
    
    deltaAmpOnsets(deltaAmpOnsets<0)=0; %only deal with increments
    deltaAmpOffsets(deltaAmpOffsets<0)=0;
    
    
    
    %     %inspection
    %     subplot(2,1,1);
    %     bar(P.cfs,deltaAmpOnsets);
    %     ylim([-10 10]);
    %
    %     subplot(2,1,2);
    %     bar(P.cfs,deltaAmpOffsets);
    %     ylim([-10 10]);
    %
    %     drawnow;
    %
    
    %     bar(deltaAmpOffsets);
    %     ylim([-1 .5]);
    %     drawnow;
    
    [onsetSpectralPeakValues,onsetSpectralPeakIndices]=findpeaks(deltaAmpOnsets); %find the peak values and their indices in the spectrum
    [offsetSpectralPeakValues,offsetSpectralPeakIndices]=findpeaks(deltaAmpOffsets); %find the peak values and their indices in the spectrum
    [frameSpectralPeakValues,frameSpectralPeakIndices]=findpeaks(amp); %find the absolute raw "peakiness" of the current frame
    
    %deal with the not-so-unlikely case of a single peak by just using the
    %height of the peak
    if(isempty(onsetSpectralPeakValues))
        [onsetSpectralPeakValues,onsetSpectralPeakIndices]=max(deltaAmpOnsets); %just use the single largest value
    end
    if(isempty(offsetSpectralPeakValues))
        [offsetSpectralPeakValues,offsetSpectralPeakIndices]=max(deltaAmpOffsets); %just use the single largest value
    end
    if(isempty(frameSpectralPeakValues))
        [frameSpectralPeakValues,frameSpectralPeakIndices]=max(amp); %just use the single largest value
    end
    
    onsetAudioSalience= sum(onsetSpectralPeakValues) * length(onsetSpectralPeakValues); %this is the magical secret sauce that tells us how likely there is a new "voice-like" object in the scene
    offsetAudioSalience= sum(offsetSpectralPeakValues) / length(offsetSpectralPeakValues); %this is the magical secret sauce that tells us how likely there is a new "voice-like" object in the scene
    
    frameSalience=sum(frameSpectralPeakValues) * length(frameSpectralPeakValues);
    %%inspection
    
    %     subplot(2,1,1);
%       plot(frameCounter,onsetAudioSalience,'ro');
%        hold on;
    %
    %     subplot(2,1,2);
    %     plot(frameCounter,frameSalience,'go');
    %     hold on;
    %
%        drawnow;
    
    
    %     scatter(onsetAudioSalience,offsetAudioSalience,'o');
    %     drawnow;
    %     hold on;
    %
    
    %%%end spectral salience
   
    fFrameL=fFrameL';
    fFrameR=fFrameR';
    
    
    %%%%%%  Selective Attention Stage *********
    
    
    %compute the time-decaying salience
    %tdSalience =  P.salienceGain * 1./(1+exp(0.20*toc(O.onsetTime))) * O.salience ;
    O.tdSalience = (2 * toc(O.onsetTime) * exp(-toc(O.onsetTime) * 1.8) + exp(-toc(O.onsetTime) * 0.08)) * O.salience;
%     
%     plot(frameCounter,O.tdSalience,'o');
%     hold on;
%     drawnow;
    
    
    %we have to know where we're pointing: circshift the vector of priors so that we can look up a prior
    %in mic array coordinates
   if(P.useDesktopRobot==1)
        currentMicHeading_degrees=P.motorControl.currentHeading;  %ask for the current heading from the motor controller
   else
       currentMicHeading_degrees=0;
   end
   
   currentMicHeading_index=find(currentMicHeading_degrees>=P.spaceAngles,1,'first'); %find the index in space angles that corresponds to the mic heading
    
    %check if a new object appeared
    if(onsetAudioSalience>O.tdSalience && onsetAudioSalience > P.attentionCaptureThreshold)
        %a new object captured attention so update all the object features
        O.salience=onsetAudioSalience;  %the current objects salience
        O.onsetTime=tic;%take the last time stamp of the frame to be the onset time ... note that's arbitrarily inaccurate to within frameDuration
        
        %set new filterbank weights
        O.fWeights=repmat(deltaAmpOnsets',[1 P.frameDuration_samples]);
                
        %get some variables ready for the output of the beamformer stage
        thisFrameImage=zeros(P.nBands,P.nBeams,P.frameDuration_samples+2*P.frameOverlap); %it's only nBeamsPerHemi *2 long because we loose half the samples off either end (theoretically they're the last samples of the previous frame and the first samples of the frame that hasn't happend yet)
        
        %sweep a beam to find a first guess at this new object's location
        %   %this is exactly a bank of delay-and-sum beamformers
        for bandCounter=1:P.nBands
            
            thisBandL=fFrameL(bandCounter,:);
            thisBandR=fFrameR(bandCounter,:);
            
            beamCounter=1;
            for b=-P.nBeamsPerHemifield:P.nBeamsPerHemifield
                tempR=circshift(thisBandR,[0 b]); %shift through each lag
                thisFrameImage(bandCounter,beamCounter,:)=thisBandL+tempR; %add the shifted right channnel to the unshifted left channel
                beamCounter=beamCounter+1;
                
            end
            
        end
        
        %localize by find the beam with the most energy
        %note that the filterbank weights multiply through this computation
        
        thisFrameRMS=rms(thisFrameImage,3); %find the bandsxbeams matrix of rms values
        
        %this computes a first-guess angle to steer towards
        weightedRMS=sum(thisFrameRMS,1);
        [maxRMS,maxBeam]=max(weightedRMS,[],2);
        
        %to initialize the prior probabilities of each angle in the object's
        %probabalistic map, we need to normalize the initial beams
        %initialize the map of prior probabilities for this object
        
        
        %%this will use a single vector of priors for every frequency.  If we
        %%arrive at that vector by pooling across frequencies, then this makes
        %%sense
        initialPriors=weightedRMS;
        reflectedPriors=fliplr(initialPriors);
        surroundPriors=[initialPriors reflectedPriors(:,2:end-1)]; %reflect the front onto the back (because we've got only two mics in the array
        surroundPriors=circshift(surroundPriors,[0 P.nBeamsPerHemifield]); %we need this lined up with P.micAngles which has -180 as its first element
        
        
        interpolatedSurroundPriors=interp1(P.micAngles,surroundPriors,P.spaceAngles,'spline'); %the beam distribution isn't linearly arranged around the circle and doesn't sample the space with the same resolution as the angles that point into external space.  Interpolate.
        O.radialPriors=circshift(interpolatedSurroundPriors,[0 -currentMicHeading_index]); %circshift it into real-world space so the mic angle is decoupled from the world around it
        
        if(P.sendAngleToYarp==1)
            audioAttentionControl('/mosaic/angle:i',O.angle * 180/pi,tdSalience);
        end
        
        [~,initialBeam]=max(O.radialPriors(1:180));
        initialAngle=P.spaceAngles(initialBeam);
        display(['found salient talker at beam ' num2str(initialBeam) ' angle ' num2str(O.angle*180/pi) ' degrees']);
        
    else
        
        
        %previous filterbank weights for the selected talker to the beamforming
        %stage, use the weights stored in the object
        fFrameL=O.fWeights.*fFrameL;
        fFrameR=O.fWeights.*fFrameR;
        
        
        %get some variables ready for the output of the beamformer stage
        thisFrameImage=zeros(P.nBands,P.nBeams,P.frameDuration_samples+2*P.frameOverlap); %it's only nBeamsPerHemi *2 long because we loose half the samples off either end (theoretically they're the last samples of the previous frame and the first samples of the frame that hasn't happend yet)

        %sweep a beam to find the most recent evidence angle
        for bandCounter=1:P.nBands
            
            thisBandL=fFrameL(bandCounter,:);
            thisBandR=fFrameR(bandCounter,:);
            
            beamCounter=1;
            for b=-P.nBeamsPerHemifield:P.nBeamsPerHemifield
                tempR=circshift(thisBandR,[0 b]); %shift through each lag
                thisFrameImage(bandCounter,beamCounter,:)=thisBandL+tempR; %add the shifted right channnel to the unshifted left channel
                beamCounter=beamCounter+1;
                
            end
            
        end
        
        %localize by find the beam with the most energy
        %note that the filterbank weights multiply through this computation
        
        thisFrameRMS=rms(thisFrameImage,3); %find the bandsxbeams matrix of rms values
        
        %this computes a first-guess angle to steer towards
        weightedRMS=sum(thisFrameRMS,1);
        [maxRMS,maxBeam]=max(weightedRMS,[],2);
        
        
        %pass the object with its vector of priors in external space and the current angle
        %updatePriors will rotate the priors to align with mic space and use these to update the priors using Bayes and return
        %the object with updated priors (i.e. posteriors which can be used
        %as priors in the subsequent iteration)       
        O.radialPriors=UpdatePriors(O,maxBeam,currentMicHeading_index,P);
        
    end
    
    O.radialPriors=O.radialPriors./sum(O.radialPriors);
   
    %decide where we think the current object is
    [~,O.selectedBeam]=max(O.radialPriors);
  
    
    O.angle_space=P.spaceAngles(O.selectedBeam)*180/pi;
    O.angle_mic=round(O.angle_space-currentMicHeading_degrees);
    %plot the radial priors
    
    plot(P.spaceAngles*180/pi,O.radialPriors);
    drawnow;
    
    display(currentMicHeading_index);
    
   % display(['Current object is probably at ' num2str(O.angle_space) ' degrees']);
%     
%     plot(frameCounter,O.angle_space,'ro');
%     hold on;
%     plot(frameCounter,O.angle_mic,'bo');
%     drawnow;
    
    if(P.useDesktopRobot==1)
        P.motorControl=TurnDegrees(P.motorControl,O.angle_mic);
        display(['current heading is at ' num2str(currentMicHeading_degrees)]);
        display(['turning robot ' num2str(O.angle_mic) ' degrees']);
        %pause(.5);
    end
    
    
%     bar(O.radialPriors.*O.salience);
%     ylim([0 100]);
%     drawnow;
    
    
    
    %imagesc(squeeze(P.beamMatrix(:,O.selectedBeam,:)));
    %zlim([0.0 0.05]);
    %drawnow;
    
    %     %for data acquisition in an experiment
    %     %acquire data showing the time progression of O.radialPriors
    %     if(frameCounter<=numFramesToAcquire)
    %         acquireProbData(frameCounter,:)=O.radialPriors;
    %     else
    %         display('done acquiring data');
    %     end
    
    %increment for next frame
    nextFrameStamp=lastFrameStamp+P.frameDuration_samples; %increment
    lastFrameStamp=nextFrameStamp;
    frameCounter=frameCounter+1;
    
    while(P.audioIn.Data(1,1).audioD(end-1,end)<nextFrameStamp)
        %spin until the next frame has been written into the buffer
    end
    
    
    
  % toc(t); 
end