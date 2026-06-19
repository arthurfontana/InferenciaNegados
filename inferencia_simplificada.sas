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
   EXEMPLO DE USO (descomente e ajuste os nomes):

   LIBNAME INF "/sasdata/Credito_Estudos/POL/ARTHUR_FONTANA/INFERENCIA";

   * 1) Gerar a tabela de referencia a partir da base historica observada;
   %gerar_inferencia(
       ds_base         = INF.BASE_MODELAGEM_AM,
       var_seg         = SCORE_HVI3 IDENTIFICA_GRUPO_MODELO CANAL_PCO_AJUSTADO,
       col_aprovados   = FL_APROVADOS,
       col_convertidos = FL_ALTAS,
       col_maus        = fl_atrs_parc_over_30,
       ds_ref          = INF.TABELA_REF_MV
   );

   * 2a) Backtest: aplicar na propria base historica (tem os reais);
   %aplicar_inferencia(
       ds_novo         = INF.BASE_MODELAGEM_AM,
       ds_ref          = INF.TABELA_REF_MV,
       var_seg         = SCORE_HVI3 IDENTIFICA_GRUPO_MODELO CANAL_PCO_AJUSTADO,
       ds_out          = INF.BASE_MODELAGEM_AM_INF,
       col_aprovados   = FL_APROVADOS,
       modo            = ANALITICA,
       col_convertidos = FL_ALTAS,
       col_maus        = fl_atrs_parc_over_30
   );

   * 2b) Simulacao: aplicar na base nova (sem reais, so prob/fisico);
   %aplicar_inferencia(
       ds_novo       = INF.LOG_05_06_MV,
       ds_ref        = INF.TABELA_REF_MV,
       var_seg       = SCORE_HVI3 IDENTIFICA_GRUPO_MODELO CANAL_PCO_AJUSTADO,
       ds_out        = INF.LOG_05_06_MV_INF,
       col_aprovados = FL_APROVADOS,
       modo          = ANALITICA
   );
   ============================================================================ */
