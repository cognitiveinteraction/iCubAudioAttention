function [angle,lagSpace,lag_dif] = ComputeAngleUsingITDSalience(S,lagVectorPrevious,rate)
% takes S a stereo sound vector (chans x samples) 
%returns an angle to a peak in GCC_PHAT, the vector of lags, and the
%difference of lags between current frame and previous frame


c=340.29;%define speed of sound in m/s
D=0.1; %define distance between microphones in m


%compute GCC-PHAT

%define the width of the window over which to inspect lags (we're only
%interested in lags of a few 10's- the rest would be reverberation

window=50; %should be divisible by 2...this is how many samples to look on each side of the midline for a peak...this should be related to the distance between the microphones


%xplode the array to make this more clear
s1=S(1,:);
s2=S(2,:);

%compute fft of inputs
f1=fft(s1);
f2=fft(s2);

%compute the weighted generalized correlation coefficient
gcc_phat=(f1.*conj(f2))./abs(f1.*conj(f2));

%compute the inverse transform
gcc_inv = ifft(gcc_phat);

%make it real
gcc_inv_real=real(gcc_inv);

%shift it to zero the 0th lag
gcc_inv_shifted=fftshift(gcc_inv_real);

%compute the difference between the current lag space and the previous
%frame's lag space
lag_dif=gcc_inv_shifted-lagVectorPrevious;

%find the 0th lag
middle=floor(length(gcc_inv_shifted)/2);

%find the index with the biggest peak
[~,tempLag] = max(gcc_inv_shifted(middle-window/2:middle+window/2)); %only the first hundred or so lags are relevant
lag=tempLag-window/2;

%convert the lag in samples to lag in seconds
lag_seconds=lag/rate;

%return the angle
angle=real(asin(c*lag_seconds*(1/D)));


%send this frame's gcc-phat vector back to be passed along to this function during the next frame
lagSpace=gcc_inv_shifted;



return

end
