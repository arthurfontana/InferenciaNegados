/* ============================================================================
   inferencia_simplificada.sas

   Versao enxuta da inferencia de negados, em DUAS macros:

     %gerar_inferencia  -> gera a TABELA DE REFERENCIA (taxa de conversao e
                           taxa de FPD observadas por celula, com fallback
                           hierarquico).
     %aplicar_inferencia-> APLICA a tabela de referencia em qualquer base
                           (analitica ou sumarizada), atribuindo
                           prob_conversao / prob_fpd / prob_mau e os fisicos.

   POR QUE EXISTE (vs. o fluxo de 6 arquivos / ~6300 linhas):
     O conceito e simples - taxa observada por agrupamento, replicada para
     quem nao temos observacao. Esta versao mantem so o nucleo:
       1) agrega por celula em niveis hierarquicos (colapsa da direita p/ a
          esquerda; o SCORE - 1a var - nunca e colapsado);
       2) usa o nivel mais granular que tenha amostra suficiente
          (MIN_N aprovados e MIN_EVENTOS maus); senao colapsa; em ultimo
          caso usa a media GLOBAL;
       3) aplica via join em cascata.

   O QUE FOI CORTADO de proposito (estava no fluxo antigo):
     - Derivacao automatica de MIN_N / MIN_EVENTOS (Wilson + power analysis):
       agora sao PARAMETROS chumbados no default (230 / 62), validados nos
       exercicios anteriores. Para recalibrar, passe outros valores.
     - Extrapolacao exponencial das caudas de score: substituida pela linha
       GLOBAL de fallback (mais simples e mais honesta).
     - Intervalos de confianca de Wilson e relatorios PROC REPORT.

   DECISOES PARAMETRIZAVEIS:
     - var_seg : lista de variaveis de segmentacao; a ORDEM importa, a 1a e a
                 ancora (score) e nunca e colapsada. Hoje sao 3, mas pode ser
                 qualquer lista.
     - As 3 colunas de contagem/flag (aprovados, convertidos, maus) servem
       tanto p/ base ANALITICA (flags 0/1; sum() vira contagem) quanto p/ base
       SUMARIZADA (ja sao contagens). O codigo e o mesmo.

   ENCODING: arquivo em ASCII puro (sem acentos) de proposito, p/ evitar
     problemas de Latin-1/UTF-8 ao abrir no SAS.
   ============================================================================ */

options validvarname=v7;


/* ============================================================================
   PARAMETROS DE ENTRADA  (edite aqui - NAO precisa mexer nas macros)
   ----------------------------------------------------------------------------
   Tudo que antes ficava "chumbado" dentro das macros esta exposto abaixo como
   macro variavel, ja com o valor PADRAO validado setado. Voce NAO precisa
   alterar nada: rode como esta. Os comentarios dizem o que cada parametro faz,
   o efeito de mexer e uma FAIXA sugerida, caso queira testar a sensibilidade
   (use a macro %validar_confianca, no fim do arquivo, p/ medir o efeito).

   As macros mantem esses mesmos defaults internamente (rede de seguranca). O
   bloco de EXEMPLO no fim do arquivo le os valores definidos aqui.
   ============================================================================ */

/* --- 1) Mapeamento das colunas da base (nomes reais; NAO e "tuning") ------- */
%let VAR_SEG         = SCORE_HVI3 IDENTIFICA_GRUPO_MODELO CANAL_PCO_AJUSTADO;
   /* Variaveis de segmentacao e a ORDEM (a ordem importa). A 1a (SCORE) e a
      ANCORA: nunca e colapsada. A ULTIMA (CANAL) e a 1a a ser descartada no
      fallback hierarquico.
      EFEITO: mais variaveis  -> celulas mais especificas, porem menores (mais
              propostas caem no fallback / GLOBAL, menos granularidade efetiva).
              menos variaveis -> celulas maiores e mais estaveis, menos detalhe.
              a ORDEM define o que se perde primeiro ao colapsar.
      FAIXA : 2 a 4 variaveis. A 1a TEM de ser o score. */

%let COL_APROVADOS   = FL_APROVADOS;          /* flag 0/1 ou contagem de aprovados */
%let COL_CONVERTIDOS = FL_ALTAS;              /* flag 0/1 ou contagem de altas      */
%let COL_MAUS        = fl_atrs_parc_over_30;  /* flag 0/1 ou contagem de maus (FPD) */

/* --- 2) Thresholds estatisticos (o "tuning" de verdade) -------------------- */
%let MIN_N           = 230;
   /* Minimo de APROVADOS para a celula ser usada no seu nivel; abaixo disso ela
      colapsa para o nivel acima (menos granular) ou, em ultimo caso, p/ o GLOBAL.
      EFEITO: aumentar  -> premissas mais robustas/estaveis, porem MAIS colapso
              (perde granularidade; mais propostas herdam taxa de niveis amplos).
              diminuir  -> mais granularidade, porem risco de premissa apoiada em
              pouca amostra (ruido).
      FAIXA sugerida: 100 a 500.  Validado: 230. */

%let MIN_EVENTOS     = 62;
   /* Minimo de MAUS (eventos de FPD) para a celula ter FPD confiavel. Protege a
      taxa de inadimplencia de ser estimada sobre pouquissimos maus.
      EFEITO: aumentar  -> FPD por celula mais confiavel, porem mais colapso.
              diminuir  -> FPD mais granular, porem ruidoso em celulas pequenas.
      Regra de bolso: ~ MIN_N x FPD_global  (FPD global ~27% => ~62).
      FAIXA sugerida: 30 a 120.  Validado: 62. */

/* --- 3) Operacao das macros ------------------------------------------------ */
%let MODO            = ANALITICA;  /* ANALITICA (1 linha/proposta) ou SUMARIZADA */
%let BACKTEST        = AUTO;       /* AUTO | SIM | NAO (so roda se houver reais)  */


/* ============================================================================
   MACRO 1 - %gerar_inferencia
   ----------------------------------------------------------------------------
   ds_base         base com as variaveis de segmentacao e as 3 colunas abaixo.
   var_seg         vars de segmentacao (1a = score = ancora). Ex.:
                   SCORE_HVI3 IDENTIFICA_GRUPO_MODELO CANAL_PCO_AJUSTADO
   col_aprovados   flag (0/1) ou contagem de aprovados.
   col_convertidos flag (0/1) ou contagem de convertidos (altas).
   col_maus        flag (0/1) ou contagem de maus (FPD; missing p/ nao-altas).
   ds_ref          dataset de saida (tabela de referencia).
   min_n           minimo de aprovados p/ a celula ser usavel  (default 230).
   min_eventos     minimo de maus p/ a celula ser usavel       (default 62).

   SAIDA (&ds_ref): uma linha por celula valida em cada nivel + 1 linha GLOBAL.
     nivel, vars_usadas, <vars do nivel>, n_aprovados, n_convertidos, n_maus,
     taxa_conversao_ref, taxa_fpd_ref, confiabilidade (ALTA/MEDIA/BAIXA/GLOBAL).
   ============================================================================ */
%macro gerar_inferencia(
    ds_base=,
    var_seg=,
    col_aprovados=,
    col_convertidos=,
    col_maus=,
    ds_ref=,
    min_n=230,
    min_eventos=62
);

    %local n_vars globalnivel i j vars_k k_comma;
    %let n_vars      = %sysfunc(countw(&var_seg, %str( )));
    %let globalnivel = %eval(&n_vars + 1);

    %if %length(&ds_base)=0 or %length(&var_seg)=0 or %length(&ds_ref)=0 %then %do;
        %put ERROR: gerar_inferencia - ds_base, var_seg e ds_ref sao obrigatorios.;
        %return;
    %end;

    proc datasets library=work nolist; delete _ref_lvl: _ref_glob; quit;

    /* --- um agregado por nivel: colapsa da direita p/ a esquerda --- */
    %do i = 1 %to &n_vars;

        %let vars_k = ;
        %do j = 1 %to %eval(&n_vars - &i + 1);
            %let vars_k = &vars_k %scan(&var_seg, &j, %str( ));
        %end;
        %let vars_k   = %sysfunc(strip(&vars_k));
        %let k_comma  = %sysfunc(tranwrd(&vars_k, %str( ), %str(,)));

        proc sql;
            create table work._ref_lvl&i as
            select
                &i               as nivel,
                "&vars_k"        as vars_usadas length=200,
                &k_comma,
                sum(&col_aprovados)   as n_aprovados,
                sum(&col_convertidos) as n_convertidos,
                sum(&col_maus)        as n_maus,
                calculated n_convertidos / calculated n_aprovados
                                       as taxa_conversao_ref,
                case when calculated n_convertidos > 0
                     then calculated n_maus / calculated n_convertidos
                     else . end        as taxa_fpd_ref
            from &ds_base
            group by &k_comma
            having sum(&col_aprovados)   >= &min_n
               and sum(&col_maus)        >= &min_eventos
               and sum(&col_convertidos) >  0;
        quit;
    %end;

    /* --- linha GLOBAL de fallback (sem segmentacao) --- */
    proc sql;
        create table work._ref_glob as
        select
            &globalnivel     as nivel,
            "GLOBAL"         as vars_usadas length=200,
            sum(&col_aprovados)   as n_aprovados,
            sum(&col_convertidos) as n_convertidos,
            sum(&col_maus)        as n_maus,
            calculated n_convertidos / calculated n_aprovados
                                   as taxa_conversao_ref,
            case when calculated n_convertidos > 0
                 then calculated n_maus / calculated n_convertidos
                 else . end        as taxa_fpd_ref
        from &ds_base;
    quit;

    /* --- empilha tudo e classifica a confiabilidade --- */
    data &ds_ref;
        set %do i = 1 %to &n_vars; work._ref_lvl&i %end; work._ref_glob;
        length confiabilidade $11;
        if      nivel = 1            then confiabilidade = "ALTA";
        else if nivel = &globalnivel then confiabilidade = "GLOBAL";
        else if nivel = &n_vars      then confiabilidade = "BAIXA";
        else                              confiabilidade = "MEDIA";
        label
            nivel              = "Nivel hierarquico (1=mais granular; GLOBAL=ultimo)"
            vars_usadas        = "Variaveis usadas neste nivel"
            taxa_conversao_ref = "Taxa de conversao observada"
            taxa_fpd_ref       = "Taxa de FPD observada"
            confiabilidade     = "ALTA / MEDIA / BAIXA / GLOBAL";
    run;

    proc datasets library=work nolist; delete _ref_lvl: _ref_glob; quit;

    %put NOTE: ===== gerar_inferencia: tabela de referencia -> &ds_ref =====;
    title "TABELA DE REFERENCIA - celulas por confiabilidade";
    proc sql;
        select confiabilidade,
               count(*)            as celulas,
               sum(n_aprovados)    as aprovados,
               mean(taxa_fpd_ref)  as fpd_medio format=percent8.2
        from &ds_ref group by confiabilidade;
    quit;
    title;

%mend gerar_inferencia;


/* ============================================================================
   MACRO 2 - %aplicar_inferencia
   ----------------------------------------------------------------------------
   ds_novo         base a enriquecer (analitica OU sumarizada). Precisa das
                   mesmas var_seg da tabela de referencia.
   ds_ref          tabela de referencia gerada por %gerar_inferencia.
   var_seg         mesmas vars (mesma ordem) usadas na geracao.
   ds_out          dataset de saida enriquecido.
   col_aprovados   flag/contagem de aprovados em ds_novo (usado como peso).
   peso            coluna que pondera os fisicos (default = col_aprovados).
   modo            ANALITICA (cria prob_mau) ou SUMARIZADA (default ANALITICA).
   col_convertidos / col_maus
                   reais observados em ds_novo, SE existirem (p/ backtest).
   backtest        AUTO (roda se a base tiver os reais) | SIM | NAO.

   SAIDA (&ds_out): ds_novo + prob_conversao, prob_fpd, [prob_mau],
     fisico_altas, fisico_maus, nivel_premissa, confiabilidade_premissa.

   FISICOS / REGRAS DE OURO:
     fisico_altas = peso * prob_conversao
     fisico_maus  = peso * prob_conversao * prob_fpd
     Taxa de FPD inferida = SUM(fisico_maus)/SUM(fisico_altas)
     prob_mau = prob_conversao*prob_fpd SO faz sentido na base ANALITICA.
   ============================================================================ */
%macro aplicar_inferencia(
    ds_novo=,
    ds_ref=,
    var_seg=,
    ds_out=,
    col_aprovados=,
    peso=,
    modo=ANALITICA,
    col_convertidos=,
    col_maus=,
    backtest=AUTO
);

    %local n_vars globalnivel i j v vars_k cond _dsid _has _rc _roda_bt;
    %let n_vars      = %sysfunc(countw(&var_seg, %str( )));
    %let globalnivel = %eval(&n_vars + 1);
    %let modo        = %upcase(&modo);
    %if %length(&peso)=0 %then %let peso = &col_aprovados;

    %if %length(&ds_novo)=0 or %length(&ds_ref)=0 or %length(&var_seg)=0
        or %length(&ds_out)=0 %then %do;
        %put ERROR: aplicar_inferencia - ds_novo, ds_ref, var_seg e ds_out sao obrigatorios.;
        %return;
    %end;

    /* ------------------------------------------------------------------
       JOIN EM CASCATA: liga cada nivel (so as vars daquele nivel) + a
       linha GLOBAL; coalesce pega o 1o (mais granular) com match.
       O %do fica DENTRO da macro (armadilha do %DO em open code).
       ------------------------------------------------------------------ */
    proc sql;
        create table work._ap as
        select a.*
            %do i = 1 %to &n_vars;
                , l&i..taxa_conversao_ref as _c&i
                , l&i..taxa_fpd_ref       as _f&i
                , l&i..nivel              as _n&i
            %end;
                , g.taxa_conversao_ref as _c&globalnivel
                , g.taxa_fpd_ref       as _f&globalnivel
                , g.nivel              as _n&globalnivel
        from &ds_novo a
            %do i = 1 %to &n_vars;
                %let vars_k = ;
                %do j = 1 %to %eval(&n_vars - &i + 1);
                    %let vars_k = &vars_k %scan(&var_seg, &j, %str( ));
                %end;
                %let vars_k = %sysfunc(strip(&vars_k));
                %let cond = ;
                %do j = 1 %to %sysfunc(countw(&vars_k, %str( )));
                    %let v = %scan(&vars_k, &j, %str( ));
                    %if &j=1 %then %let cond = l&i..&v = a.&v;
                    %else            %let cond = &cond and l&i..&v = a.&v;
                %end;
                left join (select * from &ds_ref where nivel=&i) l&i
                    on &cond
            %end;
        left join (select * from &ds_ref where nivel=&globalnivel) g
            on 1=1
        ;
    quit;

    /* ------------------------------------------------------------------
       CONSOLIDA: coalesce -> premissa final; fisicos; prob_mau (analitica)
       ------------------------------------------------------------------ */
    data &ds_out;
        set work._ap;

        prob_conversao = coalesce(of _c1-_c&globalnivel);
        prob_fpd       = coalesce(of _f1-_f&globalnivel);
        nivel_premissa = coalesce(of _n1-_n&globalnivel);

        length confiabilidade_premissa $11;
        if      nivel_premissa = 1            then confiabilidade_premissa = "ALTA";
        else if nivel_premissa = &globalnivel then confiabilidade_premissa = "GLOBAL";
        else if nivel_premissa = &n_vars      then confiabilidade_premissa = "BAIXA";
        else                                       confiabilidade_premissa = "MEDIA";

        fisico_altas = &peso * prob_conversao;
        fisico_maus  = &peso * prob_conversao * prob_fpd;
        %if &modo = ANALITICA %then %do;
            prob_mau = prob_conversao * prob_fpd;
        %end;

        drop _c1-_c&globalnivel _f1-_f&globalnivel _n1-_n&globalnivel;

        label
            prob_conversao          = "Probabilidade de conversao (premissa)"
            prob_fpd                = "Probabilidade de FPD (premissa)"
            nivel_premissa          = "Nivel hierarquico da premissa usada"
            confiabilidade_premissa = "ALTA / MEDIA / BAIXA / GLOBAL"
            fisico_altas            = "Altas inferidas (peso*conv)"
            fisico_maus             = "Maus inferidos (peso*conv*fpd)"
            %if &modo = ANALITICA %then %do;
            prob_mau                = "Prob. conjunta conv*fpd (so analitica)"
            %end;
        ;
    run;

    proc datasets library=work nolist; delete _ap; quit;
    %put NOTE: ===== aplicar_inferencia: base enriquecida -> &ds_out =====;

    /* ------------------------------------------------------------------
       BACKTEST (real x inferido) - so se a base tiver os reais.
       ------------------------------------------------------------------ */
    %let _roda_bt = 0;
    %if %upcase(&backtest) ne NAO and %length(&col_convertidos) and %length(&col_maus) %then %do;
        %let _dsid = %sysfunc(open(&ds_novo));
        %if &_dsid %then %do;
            %let _has = %sysfunc(varnum(&_dsid, &col_convertidos));
            %let _rc  = %sysfunc(close(&_dsid));
            %if &_has %then %let _roda_bt = 1;
        %end;
    %end;

    %if &_roda_bt = 1 %then %do;
        title "BACKTEST - real x inferido (sobre aprovados com premissa)";
        proc sql;
            select
                sum(&peso)                              as aprovados   format=comma20.,
                sum(&col_convertidos)                   as altas_real  format=comma20.,
                sum(fisico_altas)                       as altas_inf   format=comma20.1,
                sum(&col_maus)                          as maus_real   format=comma20.,
                sum(fisico_maus)                        as maus_inf    format=comma20.1,
                sum(&col_maus)/sum(&col_convertidos)    as fpd_real    format=percent8.2,
                sum(fisico_maus)/sum(fisico_altas)      as fpd_inf     format=percent8.2
            from &ds_out
            where prob_conversao is not null;
        quit;
        title;
    %end;

%mend aplicar_inferencia;


/* ============================================================================
   MACRO 3 - %exportar_simulador
   ----------------------------------------------------------------------------
   Exporta a TABELA DE REFERENCIA (saida do %gerar_inferencia) para um CSV que
   o App Simulador de Credito consome. NAO aplica nada: so serializa as taxas
   por celula, em TODOS os niveis hierarquicos, p/ o app fazer a cascata em
   runtime contra a base que o usuario subir.

   POR QUE SO A TABELA DE REFERENCIA (e nao uma base ja inferida):
     A geracao das taxas (este repo, SAS) e independente da base de estudo. A
     aplicacao (cascata + fisicos) depende de QUAL base o usuario sobe no app,
     entao acontece la, em runtime. O contrato completo (colunas, algoritmo de
     cascata, fisicos e regras de ouro) esta em CONTRATO_INFERENCIA.md.

   ESTRUTURA DO CSV (delimitador ';', decimal '.', cabecalho = nomes das vars):
       nivel               1=mais granular ... (n_vars+1)=GLOBAL
       confiabilidade      ALTA / MEDIA / BAIXA / GLOBAL
       <vars de var_seg>   chaves; nos niveis colapsados as vars descartadas
                           ficam EM BRANCO (curinga); GLOBAL = todas em branco
       taxa_conversao_ref  P(converte | aprovado)
       taxa_fpd_ref        P(inadimple | converteu)
       n_aprovados / n_convertidos / n_maus   amostra que embasa a celula
                           (so se incluir_amostra=SIM)
       vars_usadas         lista textual das vars do nivel (apoio/auditoria)

   PARAMETROS:
     ds_ref           tabela de referencia gerada pelo %gerar_inferencia.
     caminho_csv      arquivo CSV de saida (ex.: .../inferencia_ref.csv).
     var_seg          mesmas vars (mesma ordem) da geracao (default &VAR_SEG).
     incluir_amostra  SIM (default) inclui n_aprovados/n_convertidos/n_maus;
                      NAO exporta so as taxas + confiabilidade.
   ============================================================================ */
%macro exportar_simulador(
    ds_ref=,
    caminho_csv=,
    var_seg=&VAR_SEG,
    incluir_amostra=SIM
);

    %local amostra_cols n_lin;

    %if %length(&ds_ref)=0 or %length(&caminho_csv)=0 %then %do;
        %put ERROR: exportar_simulador - ds_ref e caminho_csv sao obrigatorios.;
        %return;
    %end;
    %if %sysfunc(exist(&ds_ref))=0 %then %do;
        %put ERROR: exportar_simulador - tabela de referencia &ds_ref nao existe. Rode gerar_inferencia antes.;
        %return;
    %end;

    %if %upcase(&incluir_amostra)=SIM %then
        %let amostra_cols = n_aprovados n_convertidos n_maus;
    %else
        %let amostra_cols = ;

    /* reordena as colunas de forma deterministica p/ o app (retain define a
       ordem). As vars colapsadas ficam EM BRANCO - o app as le como curinga. */
    data work._exp_ref;
        retain nivel confiabilidade &var_seg
               taxa_conversao_ref taxa_fpd_ref &amostra_cols vars_usadas;
        set &ds_ref;
        keep nivel confiabilidade &var_seg
             taxa_conversao_ref taxa_fpd_ref &amostra_cols vars_usadas;
    run;

    proc export data=work._exp_ref
        outfile="&caminho_csv" dbms=csv replace;
        delimiter=';';
    run;

    proc sql noprint;
        select count(*) into :n_lin trimmed from work._exp_ref;
    quit;

    proc datasets library=work nolist; delete _exp_ref; quit;

    %put NOTE: ===== exportar_simulador: &n_lin linhas exportadas -> &caminho_csv =====;
    %put NOTE:       Leve este CSV + CONTRATO_INFERENCIA.md para o App Simulador.;

%mend exportar_simulador;


/* ============================================================================
   MACRO 4 (OPCIONAL) - %validar_confianca
   ----------------------------------------------------------------------------
   Roda a inferencia COMPLETA (gerar + aplicar como backtest) sobre a base
   historica observada e mede se o resultado e confiavel:
     - cobertura por confiabilidade (% de aprovados com premissa ALTA / GLOBAL);
     - desvio inferido x real, de ALTAS e de FPD.
   Imprime um VEREDITO (CONFIAVEL / ATENCAO / REVISAR) e RECOMENDACOES ligadas
   aos parametros - inclusive se vale a pena mexer em MIN_N / MIN_EVENTOS.

   E OPCIONAL: serve p/ dar seguranca ANTES de simular. Nao altera o fluxo - usa
   datasets temporarios em WORK e nao toca nas suas bases.

   ds_base         base historica observada (com aprovados, altas e maus reais).
   var_seg/col_*/min_n/min_eventos : default = bloco de PARAMETROS do topo.
   sensibilidade   NAO (default) | SIM. Se SIM, re-roda variando MIN_N e
                   MIN_EVENTOS (fatores 0.5 / 1.5 / 2.0 do valor atual) e mostra
                   uma tabela comparativa - responde na pratica a pergunta
                   "e se eu aumentar/diminuir esse parametro, melhora?".

   SAIDA: prints no log + dataset work._vc_res (1 linha por cenario testado).
   ============================================================================ */
%macro validar_confianca(
    ds_base=,
    var_seg=&VAR_SEG,
    col_aprovados=&COL_APROVADOS,
    col_convertidos=&COL_CONVERTIDOS,
    col_maus=&COL_MAUS,
    min_n=&MIN_N,
    min_eventos=&MIN_EVENTOS,
    sensibilidade=NAO
);

    %local peso _apr _alr _ali _mar _mai _cobA _cobG
           cob_alta cob_glob fpd_real fpd_inf dev_fpd dev_alt adev_fpd
           veredito f fator min_n_try min_eve_try;
    %let peso = &col_aprovados;

    %if %length(&ds_base)=0 %then %do;
        %put ERROR: validar_confianca - ds_base e obrigatorio.;
        %return;
    %end;

    /* helper interno: roda 1 cenario e empilha as metricas em work._vc_res.
       Le ds_base/var_seg/col_*/peso do escopo da macro mae; escreve as somas
       nas macro vars _apr.._cobG (locais da macro mae). */
    %macro _vc_eval(p_min_n, p_min_eve, p_cenario);
        %gerar_inferencia(
            ds_base=&ds_base, var_seg=&var_seg, col_aprovados=&col_aprovados,
            col_convertidos=&col_convertidos, col_maus=&col_maus,
            ds_ref=work._vc_ref, min_n=&p_min_n, min_eventos=&p_min_eve);

        %aplicar_inferencia(
            ds_novo=&ds_base, ds_ref=work._vc_ref, var_seg=&var_seg,
            ds_out=work._vc_out, col_aprovados=&col_aprovados, modo=ANALITICA,
            col_convertidos=&col_convertidos, col_maus=&col_maus, backtest=NAO);

        proc sql noprint;
            select
                sum(&peso),
                sum(&col_convertidos),
                sum(fisico_altas),
                sum(&col_maus),
                sum(fisico_maus),
                sum(case when confiabilidade_premissa='ALTA'   then &peso else 0 end),
                sum(case when confiabilidade_premissa='GLOBAL' then &peso else 0 end)
            into :_apr trimmed, :_alr trimmed, :_ali trimmed,
                 :_mar trimmed, :_mai trimmed, :_cobA trimmed, :_cobG trimmed
            from work._vc_out where prob_conversao is not null;
        quit;

        data _vc_row;
            length cenario $20;
            cenario          = "&p_cenario";
            min_n            = &p_min_n;
            min_eventos      = &p_min_eve;
            aprovados        = &_apr;
            cobertura_alta   = &_cobA / &_apr;
            cobertura_global = &_cobG / &_apr;
            fpd_real         = &_mar / &_alr;
            fpd_inf          = &_mai / &_ali;
            desvio_fpd       = (&_mai/&_ali - &_mar/&_alr) / (&_mar/&_alr);
            desvio_altas     = (&_ali - &_alr) / &_alr;
            format cobertura_alta cobertura_global fpd_real fpd_inf
                   desvio_fpd desvio_altas percent8.2  aprovados comma20.;
            label cenario          = "Cenario"
                  min_n            = "MIN_N"
                  min_eventos      = "MIN_EVENTOS"
                  aprovados        = "Aprovados c/ premissa"
                  cobertura_alta   = "% aprov. premissa ALTA"
                  cobertura_global = "% aprov. premissa GLOBAL"
                  fpd_real         = "FPD real"
                  fpd_inf          = "FPD inferido"
                  desvio_fpd       = "Desvio rel. FPD (inf-real)"
                  desvio_altas     = "Desvio rel. altas (inf-real)";
        run;

        proc append base=work._vc_res data=_vc_row force; run;
    %mend _vc_eval;

    proc datasets library=work nolist; delete _vc_res; quit;

    /* ---- cenario ATUAL (parametros vigentes) ---- */
    %_vc_eval(&min_n, &min_eventos, ATUAL);

    %if %length(&_apr)=0 %then %let _apr = 0;
    %if &_apr = 0 %then %do;
        %put ERROR: validar_confianca - base sem aprovados com premissa. Verifique ds_base e as colunas.;
        %return;
    %end;

    %let cob_alta = %sysevalf(&_cobA/&_apr);
    %let cob_glob = %sysevalf(&_cobG/&_apr);
    %let fpd_real = %sysevalf(&_mar/&_alr);
    %let fpd_inf  = %sysevalf(&_mai/&_ali);
    %let dev_fpd  = %sysevalf((&fpd_inf-&fpd_real)/&fpd_real);
    %let dev_alt  = %sysevalf((&_ali-&_alr)/&_alr);
    %let adev_fpd = %sysfunc(abs(&dev_fpd));

    %if %sysevalf(&adev_fpd <= 0.05) and %sysevalf(&cob_alta >= 0.90) %then
        %let veredito = CONFIAVEL;
    %else %if %sysevalf(&adev_fpd <= 0.10) and %sysevalf(&cob_alta >= 0.80) %then
        %let veredito = ATENCAO;
    %else
        %let veredito = REVISAR;

    %put;
    %put NOTE: ============================================================;
    %put NOTE: VALIDACAO DE CONFIANCA - cenario ATUAL;
    %put NOTE:   MIN_N=&min_n  MIN_EVENTOS=&min_eventos;
    %put NOTE:   VAR_SEG=&var_seg;
    %put NOTE: ------------------------------------------------------------;
    %put NOTE:   Cobertura premissa ALTA  : %sysfunc(putn(&cob_alta,percent8.2));
    %put NOTE:   Cobertura premissa GLOBAL: %sysfunc(putn(&cob_glob,percent8.2));
    %put NOTE:   FPD real : %sysfunc(putn(&fpd_real,percent8.2))   FPD inferido: %sysfunc(putn(&fpd_inf,percent8.2));
    %put NOTE:   Desvio relativo FPD  : %sysfunc(putn(&dev_fpd,percent8.2));
    %put NOTE:   Desvio relativo altas: %sysfunc(putn(&dev_alt,percent8.2));
    %put NOTE: ------------------------------------------------------------;
    %put NOTE:   VEREDITO: &veredito;
    %put NOTE: ============================================================;

    /* ---- recomendacoes (ligadas aos parametros) ---- */
    %put NOTE: RECOMENDACOES:;
    %if &veredito = CONFIAVEL %then %do;
        %put NOTE:  - Resultado dentro do esperado. Parametros validados (230/62) ok.;
        %put NOTE:  - Quer MAIS granularidade? Teste MIN_N/MIN_EVENTOS menores (ex.: 150/40);
        %put NOTE:    rodando com sensibilidade=SIM p/ comparar antes de adotar.;
    %end;
    %else %do;
        %if %sysevalf(&cob_alta < 0.90) %then %do;
            %put WARNING:  - Cobertura ALTA baixa (%sysfunc(putn(&cob_alta,percent8.2))): muita proposta;
            %put WARNING:    herdando premissa de niveis amplos. Tente DIMINUIR MIN_N/MIN_EVENTOS;
            %put WARNING:    (ex.: 150/40) ou reduzir o numero de variaveis em VAR_SEG.;
        %end;
        %if %sysevalf(&adev_fpd > 0.05) %then %do;
            %put WARNING:  - Desvio de FPD alto (%sysfunc(putn(&dev_fpd,percent8.2))): premissa de;
            %put WARNING:    inadimplencia instavel. Tente AUMENTAR MIN_EVENTOS (ex.: 90) p/ estabilizar,;
            %put WARNING:    ou revisar a segmentacao (o canal PAP e um caso conhecido - ver CONTEXTO.md).;
        %end;
        %put NOTE:  - Rode com sensibilidade=SIM p/ ver o efeito real de cada ajuste.;
    %end;

    /* ---- sensibilidade (opcional): varia os thresholds e compara ---- */
    %if %upcase(&sensibilidade)=SIM %then %do;
        %put NOTE: ----- sensibilidade: variando MIN_N / MIN_EVENTOS -----;
        %do f=1 %to 3;
            %let fator       = %scan(0.5 1.5 2.0, &f, %str( ));
            %let min_n_try   = %sysfunc(round(%sysevalf(&min_n*&fator)));
            %let min_eve_try = %sysfunc(round(%sysevalf(&min_eventos*&fator)));
            %_vc_eval(&min_n_try, &min_eve_try, FATOR_&fator);
        %end;
    %end;

    title "VALIDACAO DE CONFIANCA - cenarios (ATUAL = parametros vigentes)";
    proc print data=work._vc_res noobs label; run;
    title;

    proc datasets library=work nolist; delete _vc_ref _vc_out _vc_row; quit;
    %put NOTE: ===== validar_confianca: tabela comparativa -> work._vc_res =====;

%mend validar_confianca;


/* ============================================================================
   EXEMPLO DE USO (descomente e ajuste os nomes).
   Os parametros vem do bloco "PARAMETROS DE ENTRADA" do topo do arquivo, entao
   aqui voce so aponta as BASES. P/ mudar thresholds/segmentacao, edite la em cima.

   LIBNAME INF "/sasdata/Credito_Estudos/POL/ARTHUR_FONTANA/INFERENCIA";

   * 1) Gerar a tabela de referencia a partir da base historica observada;
   %gerar_inferencia(
       ds_base         = INF.BASE_MODELAGEM_AM,
       var_seg         = &VAR_SEG,
       col_aprovados   = &COL_APROVADOS,
       col_convertidos = &COL_CONVERTIDOS,
       col_maus        = &COL_MAUS,
       ds_ref          = INF.TABELA_REF_MV,
       min_n           = &MIN_N,
       min_eventos     = &MIN_EVENTOS
   );

   * 1b) Exportar a tabela de referencia (CSV) para o App Simulador de Credito.
        Leve o CSV + CONTRATO_INFERENCIA.md p/ a sessao do app;
   %exportar_simulador(
       ds_ref      = INF.TABELA_REF_MV,
       caminho_csv = /sasdata/Credito_Estudos/POL/ARTHUR_FONTANA/INFERENCIA/inferencia_ref.csv,
       var_seg     = &VAR_SEG
   );

   * 2a) Backtest: aplicar na propria base historica (tem os reais);
   %aplicar_inferencia(
       ds_novo         = INF.BASE_MODELAGEM_AM,
       ds_ref          = INF.TABELA_REF_MV,
       var_seg         = &VAR_SEG,
       ds_out          = INF.BASE_MODELAGEM_AM_INF,
       col_aprovados   = &COL_APROVADOS,
       modo            = &MODO,
       col_convertidos = &COL_CONVERTIDOS,
       col_maus        = &COL_MAUS,
       backtest        = &BACKTEST
   );

   * 2b) Simulacao: aplicar na base nova (sem reais, so prob/fisico);
   %aplicar_inferencia(
       ds_novo       = INF.LOG_05_06_MV,
       ds_ref        = INF.TABELA_REF_MV,
       var_seg       = &VAR_SEG,
       ds_out        = INF.LOG_05_06_MV_INF,
       col_aprovados = &COL_APROVADOS,
       modo          = &MODO
   );

   * 3) OPCIONAL - validar a confianca antes de simular (gera + aplica + mede).
        sensibilidade=SIM tambem testa MIN_N/MIN_EVENTOS maiores e menores;
   %validar_confianca(
       ds_base       = INF.BASE_MODELAGEM_AM,
       sensibilidade = SIM
   );
   ============================================================================ */
