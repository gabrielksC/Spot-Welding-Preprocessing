%% =========================================================
% FEATURE IMPORTANCE ANALYSIS
% Salva features importantes de modelos com R² > 0.90
%
% Objetivo:
% Descobrir quais features aparecem repetidamente
% como importantes nos melhores modelos
%% =========================================================

clc;
clear;
close all;

%% =========================================================
% LEITURA DOS DADOS
%% =========================================================

dados = readtable('features.xlsx');

%% Remover colunas desnecessárias

dados = removevars(dados, ...
    ["Notes", "WeldingParameter", "FileName", "TestNumber"]);

%% Remover NaN

dados = rmmissing(dados);

%% =========================================================
% FEATURES E TARGET
%% =========================================================

X = removevars(dados, "ShearForce_N_");

Y = dados.ShearForce_N_;

%% =========================================================
% Apenas colunas numéricas
%% =========================================================

idx = varfun(@isnumeric, ...
    X, ...
    'OutputFormat', 'uniform');

X = X(:, idx);

%% =========================================================
% Normalização
%% =========================================================

X = normalize(X);

%% =========================================================
% MODELOS
%% =========================================================

modelos = {
    'BaggedTrees'
    'LSBoost'
};

%% =========================================================
% CONFIGURAÇÕES
%% =========================================================

threshold = 0.90;

numTentativas = 50;

%% =========================================================
% TABELA FINAL
%% =========================================================

resultadoFinal = table();

%% =========================================================
% LOOP PRINCIPAL
%% =========================================================

for tentativa = 1:numTentativas

    fprintf('\n====================================\n');
    fprintf('Tentativa %d\n', tentativa);
    fprintf('====================================\n');

    %% =====================================
    % Split treino/teste
    %% =====================================

    cv = cvpartition(height(X), ...
        'HoldOut', 0.2);

    XTrain = X(training(cv), :);
    YTrain = Y(training(cv));

    XTest = X(test(cv), :);
    YTest = Y(test(cv));

    %% =====================================
    % Testar modelos
    %% =====================================

    for i = 1:length(modelos)

        nomeModelo = modelos{i};

        %% =================================
        % MODELOS
        %% =================================

        switch nomeModelo

            case 'BaggedTrees'

                modelo = fitrensemble( ...
                    XTrain, ...
                    YTrain, ...
                    'Method', ...
                    'Bag');

            case 'LSBoost'

                modelo = fitrensemble( ...
                    XTrain, ...
                    YTrain, ...
                    'Method', ...
                    'LSBoost');

        end

        %% =================================
        % Predição
        %% =================================

        Y_pred = predict(modelo, XTest);

        %% =================================
        % Métricas
        %% =================================

        rmse = sqrt(mean((YTest - Y_pred).^2));

        mae = mean(abs(YTest - Y_pred));

        R2 = 1 - sum((YTest - Y_pred).^2) / ...
                   sum((YTest - mean(YTest)).^2);

        fprintf('\nModelo: %s\n', nomeModelo);
        fprintf('R2 = %.4f\n', R2);

        %% =================================
        % Apenas modelos bons
        %% =================================

        if R2 >= threshold

            fprintf('>>> MODELO APROVADO\n');

            %% =============================
            % Feature Importance
            %% =============================

            imp = predictorImportance(modelo);

            %% Ordenar importância

            [impOrdenada, idxOrdenado] = ...
                sort(imp, 'descend');

            nomesOrdenados = ...
                X.Properties.VariableNames(idxOrdenado);

            %% =============================
            % Top Features
            %% =============================

            topN = min(10, length(impOrdenada));

            topFeatures = nomesOrdenados(1:topN);

            topImportance = impOrdenada(1:topN);

            %% =============================
            % Salvar tabela
            %% =============================

            tabelaTemp = table( ...
                repmat(string(nomeModelo), topN,1), ...
                repmat(tentativa, topN,1), ...
                repmat(R2, topN,1), ...
                string(topFeatures(:)), ...
                topImportance(:), ...
                'VariableNames', ...
                {'Modelo', ...
                 'Tentativa', ...
                 'R2', ...
                 'Feature', ...
                 'Importancia'});

            resultadoFinal = ...
                [resultadoFinal; tabelaTemp];

        end

    end

end

%% =========================================================
% SALVAR RESULTADOS
%% =========================================================

writetable( ...
    resultadoFinal, ...
    'FeatureImportance_Results.xlsx');

fprintf('\n====================================\n');
fprintf('ARQUIVO SALVO!\n');
fprintf('FeatureImportance_Results.xlsx\n');
fprintf('====================================\n');

%% =========================================================
% CONTAGEM DAS FEATURES MAIS IMPORTANTES
%% =========================================================

featuresUnicas = unique(resultadoFinal.Feature);

contagem = zeros(length(featuresUnicas),1);

mediaImportancia = zeros(length(featuresUnicas),1);

for i = 1:length(featuresUnicas)

    idx = resultadoFinal.Feature == featuresUnicas(i);

    contagem(i) = sum(idx);

    mediaImportancia(i) = ...
        mean(resultadoFinal.Importancia(idx));

end

%% =========================================================
% TABELA RESUMO
%% =========================================================

tabelaResumo = table( ...
    featuresUnicas, ...
    contagem, ...
    mediaImportancia, ...
    'VariableNames', ...
    {'Feature', ...
     'QuantidadeAparicoes', ...
     'MediaImportancia'});

%% Ordenar

tabelaResumo = sortrows( ...
    tabelaResumo, ...
    'MediaImportancia', ...
    'descend');

%% Mostrar

fprintf('\n====================================\n');
fprintf('FEATURES MAIS IMPORTANTES\n');
fprintf('====================================\n');

disp(tabelaResumo)

%% =========================================================
% SALVAR RESUMO
%% =========================================================

writetable( ...
    tabelaResumo, ...
    'Resumo_Features.xlsx');

%% =========================================================
% GRÁFICO FINAL
%% =========================================================

figure('Position',[100 100 1200 500]);

bar(tabelaResumo.MediaImportancia);

xticklabels(tabelaResumo.Feature);

xtickangle(45);

ylabel('Média da Importância');

title('Features Mais Relevantes');

grid on;