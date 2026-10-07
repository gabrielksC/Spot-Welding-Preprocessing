clc; 
clear; 
close all;

%% 1. READ BASE DATA
% Set the import options for the base features file, specifying the data
% type for some columns as 'double' (numeric) to prevent reading errors.
opts = detectImportOptions("Features 1.xlsx");
opts = setvartype(opts, {'Current_kA_','ElectrodeForce_mm_', 'FileName'}, 'double');

% 'curves' contains the voltage and current time series for each weld.
curves = readtable('Curvas.xlsx');

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

current(1,:) = current(1,:)/1e3;

%% Tirar espera

Pre_SoldaA = NaN(size(current));
Pre_SoldaV = NaN(size(voltage));

Pre_SoldaA(1,:) = current(1,:);
Pre_SoldaV(1,:) = voltage(1,:);


for i = 1:size(current, 2)

    threshold = 0.1 * max(current(2:end,i));

    start_idx = find(current(2:end,i) > threshold, 1, 'first');
    end_idx   = find(current(2:end,i) > threshold, 1, 'last');

    Pre_SoldaA(2:(end_idx-start_idx+2), i) = current(start_idx+1:end_idx+1, i);
    Pre_SoldaV(2:(end_idx-start_idx+2), i) = voltage(start_idx+1:end_idx+1, i);


end
%% Plot teste

plot(Pre_SoldaA(2:1:end,1))
hold on 
plot(current(2:1:end,1))
yline(threshold,'--', '10%')
hold off

%% Deixar so solda

SoldaA = NaN(size(current));
SoldaV = NaN(size(voltage));

SoldaA(1,:) = current(1,:);
SoldaV(1,:) = voltage(1,:);

for i = 1:size(current, 2)

    threshold = 0.42 * max(current(2:end,i));

    start_idx = find(current(2:end,i) > threshold, 1, 'first');
    end_idx   = find(current(2:end,i) > threshold, 1, 'last');

    SoldaA(2:(end_idx-start_idx+2), i) = current(start_idx+1:end_idx+1, i);
    SoldaV(2:(end_idx-start_idx+2), i) = voltage(start_idx+1:end_idx+1, i);
end

%% Plot Teste 2

plot(SoldaA(2:1:end,182))
hold on 
plot(current(2:1:end,182))
yline(threshold,'--', '42%')
hold off

%% Salvar no mesmo padrão anterior

CurvasPreSolda = NaN(size(current,1), size(current,2)*2);

CurvasPreSolda(:,1:2:end) = Pre_SoldaV;
CurvasPreSolda(:,2:2:end) = Pre_SoldaA;

CurvasPreSolda = [CurvasPreSolda(1,:); zeros(1,size(CurvasPreSolda,2)); CurvasPreSolda(2:end,:)];

%
CurvasSolda = NaN(size(current,1), size(current,2)*2);

CurvasSolda(:,1:2:end) = SoldaV;
CurvasSolda(:,2:2:end) = SoldaA;

CurvasSolda = [CurvasSolda(1,:);zeros(1,size(CurvasSolda,2)); CurvasSolda(2:end,:)];

writematrix(CurvasPreSolda, 'CurvaPreESolda.xlsx');
writematrix(CurvasSolda, 'CurvaSolda.xlsx');