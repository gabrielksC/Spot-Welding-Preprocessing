%% Vê o tipo das colunas e modifica para leitura
opts = detectImportOptions("Features 1.xlsx");
opts = setvartype(opts, {'Current_kA_','ElectrodeForce_mm_', 'FileName'}, 'double');


%% Leitura da tablea
dados = readtable('Features 1.xlsx', opts);
curvas = readtable('Curvas.xlsx');

%% 
summary(dados);


%% Separando em duas matrizes uma de tensão e uma de corrente
tensao = curvas(:, 1:2:end);
corrente = curvas(:, 2:2:end);

%% Removendo o volts e amper
tensao(2,:) = [];
corrente(2,:) = [];

%% Convertendo de table para matriz

tensao = cellfun(@str2double, table2cell(tensao));
corrente = cellfun(@str2double, table2cell(corrente)) * 1e3;

%% Delta T -> 1/Sampling frequency:

Dt = 1/25.6e3; % 1/25.6khz

%% Calculo da potencia [W]

potencia = tensao;
potencia(2:end, :) = tensao(2:end, :) .* corrente(2:end, :);

%% Calculo da Resistencia [ohms]

resistencia = tensao;
resistencia(2:end, :) = tensao(2:end, :) ./ corrente(2:end,:);

%% Calculo da energia
indice = potencia(1,:);
indice = indice';

energia = indice;

for i = 1:182
    energia(i,2) = sum(potencia(2:end,i)) * Dt;
end

%% Colocando energia na tabela dados
% Verifica a posição dos indices
[tf, loc] = ismember(dados{:,2}, energia(:,1));
% Cria a coluna energia e preenche 
dados.Energia_J_(tf) = energia(loc(tf), 2);

%% Valor maximo e tempo para o valor maximo

maximos = indice; 
tmaximos = indice;

for i = 1:182
    [maximos(i,2),tmaximos(i,2)] = max(tensao(2:end,i));
    [maximos(i,3),tmaximos(i,3)] = max(corrente(2:end,i));
    [maximos(i,4),tmaximos(i,4)] = max(resistencia(2:end,i));
end

tmaximos(:,2:end) = tmaximos(:,2:end) * Dt; % de indice para segundos

%% Colocando maximos e tempo para o valor maximo na tabela
[tf, loc] = ismember(dados{:,2}, maximos(:,1));

dados.Vmax(tf)  = maximos(loc(tf), 2);
dados.Imax(tf) = maximos(loc(tf), 3);
dados.Rmax(tf) = maximos(loc(tf), 4);

[tf, loc] = ismember(dados{:,2}, tmaximos(:,1));

% tempo de maximo total
dados.TVmax(tf)  = tmaximos(loc(tf), 2);
dados.TImax(tf) = tmaximos(loc(tf), 3);
dados.TRmax(tf) = tmaximos(loc(tf), 4);

%% tempo do ciclo 

TCiclo = indice;

for i = 1:182
    limiar = 0.1 * max(potencia(2:end,i)); % 10% do valor maximo
    
    inicio = find(potencia(2:end,i) > limiar, 1, 'first');
    fim    = find(potencia(2:end,i) > limiar, 1, 'last');
    
    TCiclo(i,2) = inicio * Dt;
    TCiclo(i,3) = fim * Dt;
    TCiclo(i,4) = (fim - inicio) * Dt;
end

[tf, loc] = ismember(dados{:,2}, TCiclo(:,1));

dados.inicioCiclo(tf) = TCiclo(loc(tf), 2);
dados.fimCiclo(tf) = TCiclo(loc(tf), 3);
dados.TCiclo(tf) = TCiclo(loc(tf), 4);

% Calculo dos tempos relativos
[tf, loc] = ismember(TCiclo(:,1), tmaximos(:,1));

Trelativo = indice;

Trelativo(tf,2) = tmaximos(loc(tf),2) - TCiclo(tf,2);
Trelativo(tf,3) = tmaximos(loc(tf),3) - TCiclo(tf,2);
Trelativo(tf,4) = tmaximos(loc(tf),4) - TCiclo(tf,2);

[tf, loc] = ismember(dados{:,2}, TCiclo(:,1));

dados.TRelativoVmax(tf) = Trelativo(loc(tf), 2);
dados.TRelativoImax(tf) = Trelativo(loc(tf), 3);
dados.TRelativoRmax(tf) = Trelativo(loc(tf), 4);

%% derivadas maximas e minimas
% indice, dV/dt, dI/dt, dP/dt, dR/dt 
dx = indice;

% Derivadas Maxima
for i = 1:182
    dx(i,2) = max(diff(tensao(2:end,i)));
    dx(i,3) = max(diff(corrente(2:end,i)));
    dx(i,4) = max(diff(potencia(2:end,i)));
    dx(i,5) = max(diff(resistencia(2:end,i)));
end

[tf, loc] = ismember(dados{:,2}, dx(:,1));

dados.dVMax(tf) = dx(loc(tf), 2);
dados.dIMax(tf) = dx(loc(tf), 3);
dados.dPMax(tf) = dx(loc(tf), 4);
dados.dRMax(tf) = dx(loc(tf), 5);


%% salvar a tabela

%writetable(dados, 'features.xlsx');