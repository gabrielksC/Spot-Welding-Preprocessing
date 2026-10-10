clc; 
clear; 
close all;

%% 1. READ BASE DATA

curves = readtable('CurvaSolda.xlsx');

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
voltage = table2array(voltage);
current = table2array(current);

%% Filtro Butterworth

Dt = 1/25.6e3;

Fs = 1/Dt;
Fc = 800;
ordem = 4;

[b,a] = butter(ordem, Fc/(Fs/2), 'low');

SoldaA_filtrada = NaN(size(current));
SoldaV_filtrada = NaN(size(voltage));

% Mantém o ID da primeira linha
SoldaA_filtrada(1,:) = current(1,:);
SoldaV_filtrada(1,:) = voltage(1,:);

for i = 1:size(current,2)

    sinalA = current(2:end,i);
    idxA = ~isnan(sinalA);

    if sum(idxA) > 10
        sinalA_valido = sinalA(idxA);
        sinalA_filtrado = filtfilt(b,a,sinalA_valido);

        temp = NaN(size(sinalA));
        temp(idxA) = sinalA_filtrado;

        SoldaA_filtrada(2:end,i) = temp;
    end


    sinalV = voltage(2:end,i);
    idxV = ~isnan(sinalV);

    if sum(idxV) > 10
        sinalV_valido = sinalV(idxV);
        sinalV_filtrado = filtfilt(b,a,sinalV_valido);

        temp = NaN(size(sinalV));
        temp(idxV) = sinalV_filtrado;

        SoldaV_filtrada(2:end,i) = temp;
    end

end

%%
plot(SoldaA_filtrada(2:1:end,1))
hold on 
plot(current(2:1:end,1))
hold off

%% Salvar no mesmo padrão

CurvasFiltradasPreESolda = NaN(size(current,1), size(current,2)*2);

CurvasFiltradasPreESolda(:,1:2:end) = SoldaV_filtrada;
CurvasFiltradasPreESolda(:,2:2:end) = SoldaA_filtrada;

CurvasFiltradasPreESolda = [CurvasFiltradasPreESolda(1,:); zeros(1,size(CurvasFiltradasPreESolda,2)); CurvasFiltradasPreESolda(2:end,:)];


writematrix(CurvasFiltradasPreESolda, 'CurvaFiltradaSolda.xlsx');

%% DWT
% Frequência de amostragem
Fs = 25.6e3;

DWT = current(1,:)';
%%

for i = 1:size(current,2)
    sinal = current(2:end,i);
    % Remover NaN
    sinal = sinal(~isnan(sinal));

    % DWT

    nivel = 5;
    wavelet = 'db4';

    [C,L] = wavedec(sinal, nivel, wavelet);

    % Separar os coeficientes

    D1 = detcoef(C,L,1);
    D2 = detcoef(C,L,2);
    D3 = detcoef(C,L,3);
    D4 = detcoef(C,L,4);
    D5 = detcoef(C,L,5);

    A5 = appcoef(C,L,wavelet,5);

    % Reconstrução dos componentes da DWT

    A5_rec = wrcoef('a', C, L, wavelet, 5);

    D1_rec = wrcoef('d', C, L, wavelet, 1);
    D2_rec = wrcoef('d', C, L, wavelet, 2);
    D3_rec = wrcoef('d', C, L, wavelet, 3);
    D4_rec = wrcoef('d', C, L, wavelet, 4);
    D5_rec = wrcoef('d', C, L, wavelet, 5);

    E_A5 = sum(A5_rec.^2);

    E_D1 = sum(D1_rec.^2);
    E_D2 = sum(D2_rec.^2);
    E_D3 = sum(D3_rec.^2);
    E_D4 = sum(D4_rec.^2);
    E_D5 = sum(D5_rec.^2);

    E_total = E_A5 + E_D1 + E_D2 + E_D3 + E_D4 + E_D5;

    DWT(i,2) = 100*E_A5/E_total;
    DWT(i,3) = 100*E_D5/E_total;
    DWT(i,4) = 100*E_D4/E_total;
    DWT(i,5) = 100*E_D3/E_total;
    DWT(i,6) = 100*E_D2/E_total;
    DWT(i,7) = 100*E_D1/E_total;

end
%% Salvar DWT junto com as features da solda 
features = readtable('featuresSoldaFiltrada.xlsx');

%%

[tf, loc] = ismember(features{:,2}, DWT(:,1));
features.E_A5(tf) = DWT(loc(tf), 2);
features.E_D5(tf) = DWT(loc(tf), 3);
features.E_D4(tf) = DWT(loc(tf), 4);
features.E_D3(tf) = DWT(loc(tf), 5);
features.E_D2(tf) = DWT(loc(tf), 6);
features.E_D1(tf) = DWT(loc(tf), 7);

writetable(features, 'featuresSoldaFiltradaDWT.xlsx');


%%
figure

subplot(7,1,1)
plot(sinal)
title('Sinal original')

subplot(7,1,2)
plot(A5_rec)
title('A5 - Baixa frequência')

subplot(7,1,3)
plot(D5_rec)
title('D5')

subplot(7,1,4)
plot(D4_rec)
title('D4')

subplot(7,1,5)
plot(D3_rec)
title('D3')

subplot(7,1,6)
plot(D2_rec)
title('D2')

subplot(7,1,7)
plot(D1_rec)
title('D1 - Alta frequência')

xlabel('Amostras')

%% FFT

N = length(sinal);

Y = fft(sinal - mean(sinal));

P2 = abs(Y/N);
P1 = P2(1:floor(N/2)+1);

f = Fs*(0:floor(N/2))/N;

figure
plot(f,P1)
xlim([0 5000])
grid on
xlabel('Frequência [Hz]')
ylabel('Amplitude')
title('Espectro da corrente')