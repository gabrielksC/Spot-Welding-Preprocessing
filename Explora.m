% =========================================================================
% SCRIPT EXPLORA.M - FEATURE ENGINEERING
% =========================================================================
% Objective:
% This script takes raw data (voltage and current waveforms over time 
% for each spot weld) and calculates new electrical parameters (features) 
% that describe the thermal behavior of each weld cycle.
% These new features will be used later by Machine Learning models 
% to predict the weld's strength (Shear Force).
% =========================================================================

clc; 
clear; 
close all;

%% 1. READ BASE DATA
% Set the import options for the base features file, specifying the data
% type for some columns as 'double' (numeric) to prevent reading errors.
opts = detectImportOptions("Features 1.xlsx");
opts = setvartype(opts, {'Current_kA_','ElectrodeForce_mm_', 'FileName'}, 'double');

% 'data' contains the initial feature table.
% 'curves' contains the voltage and current time series for each weld.
data = readtable('Features 1.xlsx', opts);
curves = readtable('Curvas.xlsx');

%% Initial statistical summary of the data
summary(data);

%% 2. SEPARATE VOLTAGE AND CURRENT CURVES
% In the Curvas.xlsx file, columns are interleaved (Voltage, Current, Voltage...).
% Here we separate the odd columns (Voltage) and the even ones (Current).
voltage = curves(:, 1:2:end);
current = curves(:, 2:2:end);

% Remove the second row which contains the unit labels ("V" and "kA")
voltage(2,:) = [];
current(2,:) = [];

%% 3. FORMAT CONVERSION
% Convert the extracted tables (cell arrays of strings) into numeric matrices,
% and convert current from kA to A (multiplying by 1000).
voltage = cellfun(@str2double, table2cell(voltage));
current = cellfun(@str2double, table2cell(current)) * 1e3;

%% 4. SAMPLING FREQUENCY DEFINITION
% Dt is the time interval between each measured point. 
% A sampling frequency of 25.6 kHz was used (25600 samples per second).
Dt = 1/25.6e3; % Delta T = ~39 microseconds

%% 5. CALCULATION OF INSTANTANEOUS QUANTITIES
% Power [W]: P(t) = V(t) * I(t)
power = voltage;
power(2:end, :) = voltage(2:end, :) .* current(2:end, :);

% Dynamic Resistance [Ohms]: R(t) = V(t) / I(t)
resistance = voltage;
resistance(2:end, :) = voltage(2:end, :) ./ current(2:end,:);

%% 6. CALCULATION OF TOTAL CYCLE ENERGY
% The total energy dissipated in the weld (in Joules) is the integral of power
% over time. Here, we calculate the sum of power multiplied by Dt.
index = power(1,:); % Store the first row (sample indices/names)
index = index';

energy = index;
for i = 1:size(power, 2)
    energy(i,2) = sum(power(2:end,i)) * Dt;
end

% Map the calculated energy values to the correct row in the 'data' table
[tf, loc] = ismember(data{:,2}, energy(:,1));
data.Energy_J_(tf) = energy(loc(tf), 2);

%% 7. MAXIMUM POINTS AND THEIR INSTANTS (PEAKS)
% Find the maximum values reached by the curves during the weld
maximums = index; 
t_maximums = index;

for i = 1:size(voltage, 2)
    [maximums(i,2), t_maximums(i,2)] = max(voltage(2:end,i));       % Vmax
    [maximums(i,3), t_maximums(i,3)] = max(current(2:end,i));       % Imax
    [maximums(i,4), t_maximums(i,4)] = max(resistance(2:end,i));    % Rmax
end

% Convert the instances from 'row number' (index) to physical time 
% in seconds by multiplying by the time step Dt.
t_maximums(:,2:end) = t_maximums(:,2:end) * Dt; 

% Insert the maximum values into the main table
[tf, loc] = ismember(data{:,2}, maximums(:,1));
data.Vmax(tf)  = maximums(loc(tf), 2);
data.Imax(tf)  = maximums(loc(tf), 3);
data.Rmax(tf)  = maximums(loc(tf), 4);

% Insert the peak times (relative to the equipment's time zero)
[tf, loc] = ismember(data{:,2}, t_maximums(:,1));
data.TVmax(tf) = t_maximums(loc(tf), 2);
data.TImax(tf) = t_maximums(loc(tf), 3);
data.TRmax(tf) = t_maximums(loc(tf), 4);

%% 8. WELD CYCLE DURATION AND MILESTONES
% Determine when the weld actually starts and ends in the curve.
CycleT = index;

for i = 1:size(power, 2)
    % Use 10% of peak power as a threshold to ignore noise
    threshold = 0.1 * max(power(2:end,i)); 
    
    % Find the first (start) and last (end) sample above the threshold
    start_idx = find(power(2:end,i) > threshold, 1, 'first');
    end_idx   = find(power(2:end,i) > threshold, 1, 'last');
    
    % Convert the indices to time in seconds
    CycleT(i,2) = start_idx * Dt;
    CycleT(i,3) = end_idx * Dt;
    CycleT(i,4) = (end_idx - start_idx) * Dt; % Active cycle duration
end

% Update the main table with real start, end, and pulse duration
[tf, loc] = ismember(data{:,2}, CycleT(:,1));
data.CycleStart(tf) = CycleT(loc(tf), 2);
data.CycleEnd(tf)   = CycleT(loc(tf), 3);
data.CycleTime(tf)  = CycleT(loc(tf), 4);

%% 9. RELATIVE TIMES OF MAXIMUMS
% Recalculate when the peaks occurred relative to the actual START 
% of the welding, rather than the equipment's capture start time.
[tf, loc] = ismember(CycleT(:,1), t_maximums(:,1));
T_relative = index;

T_relative(tf,2) = t_maximums(loc(tf),2) - CycleT(tf,2); % Time to reach Vmax
T_relative(tf,3) = t_maximums(loc(tf),3) - CycleT(tf,2); % Time to reach Imax
T_relative(tf,4) = t_maximums(loc(tf),4) - CycleT(tf,2); % Time to reach Rmax

% Insert into the main table
[tf, loc] = ismember(data{:,2}, CycleT(:,1));
data.RelativeTVmax(tf) = T_relative(loc(tf), 2);
data.RelativeTImax(tf) = T_relative(loc(tf), 3);
data.RelativeTRmax(tf) = T_relative(loc(tf), 4);

%% 10. HIGHEST RATE OF CHANGE (MAXIMUM DERIVATIVES)
% Calculates the steepest slope on the curve (how fast the variables changed).
dx = index;

for i = 1:size(voltage, 2)
    % The 'diff' function calculates the difference between a point and the previous one;
    % dividing by Dt gives the derivative over time (rate of change).
    dx(i,2) = max(diff(voltage(2:end,i)) / Dt);       % max dV/dt
    dx(i,3) = max(diff(current(2:end,i)) / Dt);       % max dI/dt
    dx(i,4) = max(diff(power(2:end,i)) / Dt);         % max dP/dt
    dx(i,5) = max(diff(resistance(2:end,i)) / Dt);    % max dR/dt
end

[tf, loc] = ismember(data{:,2}, dx(:,1));
data.dVMax(tf) = dx(loc(tf), 2);
data.dIMax(tf) = dx(loc(tf), 3);
data.dPMax(tf) = dx(loc(tf), 4);
data.dRMax(tf) = dx(loc(tf), 5);

%% 11. CALCULATION OF RMS (Root Mean Square) VALUES
% RMS values are better representations of the true magnitude 
% of an AC (or pulsed) waveform rather than a simple peak or arithmetic mean.
RMS = index;

for i = 1:size(voltage, 2)
    RMS(i,2) = rms(voltage(2:end,i)); 
    RMS(i,3) = rms(current(2:end,i));
    RMS(i,4) = rms(power(2:end,i));
end

[tf, loc] = ismember(data{:,2}, RMS(:,1));
data.Vrms(tf) = RMS(loc(tf), 2);
data.Irms(tf) = RMS(loc(tf), 3);
data.Prms(tf) = RMS(loc(tf), 4);

%% 12. CALCULATION OF TOTAL ELECTRIC CHARGE (Coulombs)
% The transferred electric charge (Q) is the integral of the electric current 
% over time.
charge = index;

for i = 1:size(current, 2)
    charge(i,2) = sum(current(2:end,i)) * Dt;
end

[tf, loc] = ismember(data{:,2}, charge(:,1));
data.Charge_C_(tf) = charge(loc(tf), 2);

%% 13. SAVE THE CONSOLIDATED TABLE
% The final "features.xlsx" file will contain the initial machine attributes
% plus all the waveform attributes (energy, RMS, derivatives, times) 
% that we just calculated. It will be the input for the Machine Learning models scripts.
writetable(data, 'features.xlsx');