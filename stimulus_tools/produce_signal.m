% Need to fix the signal is not being played over the eintire duration, and
% is instead playing the frequcencis repeadtly until the duration is over
% in repeat.

% Create DataAcquisition Object
d = daq("ni");

% Use a rate well above Nyquist for 40 kHz content (>= 2x). 200 kHz is safe.
d.Rate = 250000;  % Hz

% Add Channels
addoutput(d,"Dev1","ao0","Voltage");

% Sweep settings
A_vpp      = .25;           % Peak-to-peak amplitude (adjust to device limits)
A          = A_vpp/2;     % Amplitude
f0         = 8000;        % Start frequency (Hz)
f1         = 40000;       % End frequency (Hz)
duration   = 1;         % Sweep length in seconds
sweepType  = "linear";       % "log" (exponential) or "linear"

% Build sweep
outputSignal = [];
outputSignal(:,1) = createSweep(A, f0, f1, d.Rate, duration, sweepType, "bipolar");

% --- Ensure at least 500 scans are queued ---
minScans = 125000;
nScans = size(outputSignal,1);
if nScans < minScans
    reps = ceil(minScans / nScans);
    outputSignal = repmat(outputSignal, reps, 1);
end
% -------------------------------------------

% Generate Signal Data (background, repeating)
preload(d, outputSignal);
start(d, "repeatoutput");      % Loops the buffer in the background
pause(5);                      % Let it run (adjust as needed)
stop(d);

% Clean Up
clear d outputSignal

% ---------------------- Helpers ----------------------
function y = createSweep(A, f0, f1, fs, duration, sweepType, type)
    % Time vector
    N  = max(1, round(duration*fs));
    t  = (0:N-1)'/fs;

    % Generate chirp
    switch lower(sweepType)
        case "log"     % Exponential sweep
            y = chirp_safe(t, f0, duration, f1, "logarithmic");
        case "linear"
            y = chirp_safe(t, f0, duration, f1, "linear");
        otherwise
            error('sweepType must be "log" or "linear"');
    end

    % Amplitude & polarity
    if type == "bipolar"
        y = A * y;
    elseif type == "unipolar"
        y = A * y + A;  % shift up to 0..2A
    else
        error('type must be "bipolar" or "unipolar"');
    end

    % Apply short cosine ramp to avoid clicks (e.g., 5 ms)
    rampDur = 0.005;                 % seconds
    rampN   = max(1, round(rampDur*fs));
    w       = ones(N,1);
    r       = (0:rampN-1)'/(rampN-1);
    w(1:rampN)       = 0.5*(1 - cos(pi*r));        % fade-in
    w(end-rampN+1:end) = flipud(w(1:rampN));       % fade-out
    y = y .* w;
end

function y = chirp_safe(t, f0, t1, f1, mode)
    % Wrapper to produce a chirp without relying strictly on Signal Toolbox.
    % Uses analytical phase for linear/log sweeps.
    switch lower(mode)
        case "linear"
            % f(t) = f0 + (f1-f0)*t/t1
            k = (f1 - f0)/t1;                 % Hz/s
            phi = 2*pi*(f0*t + 0.5*k*t.^2);   % phase
        case {"log","logarithmic"}
            % Exponential: f(t) = f0*(f1/f0)^(t/t1)
            R = f1/f0;
            % Instantaneous phase integral: ∫ 2π f0 R^(τ/t1) dτ
            % = 2π f0 t1 / ln(R) * (R^(t/t1) - 1)
            phi = 2*pi*f0*t1/log(R) * (R.^(t/t1) - 1);
        otherwise
            error('Unsupported chirp mode.');
    end
    y = sin(phi);
end
