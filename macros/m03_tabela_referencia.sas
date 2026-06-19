/* ============================================================
   m03_tabela_referencia.sas  -  E3: Tabela de referencia (Fase 1)
   ------------------------------------------------------------
   OBJETIVO
     Re-embrulhar a Fase 1 de "1 - Inferiencia.sas" (l. 517-1409)
     como macro agnostica a base. A LOGICA ESTATISTICA E IDENTICA
     ao legado (wiki pag. 6 - "manter a logica identica"); a unica
     diferenca e a parametrizacao (nomes vindos do master) e o
     consumo das 3 colunas de contagem do motor unificado
     (n_aprovados / n_convertidos / n_maus), o que torna o codigo
     identico em ANALITICA e SUMARIZADA (wiki pag. 5).

     Passos (iguais ao legado):
       BLOCO 2  monta_niveis        - enumera os niveis hierarquicos
                                      (score sempre fica; colapsa da
                                      direita p/ a esquerda)
       BLOCO 3  agrega_nivel/loop   - agrega cada nivel + IC Wilson
                empilha_niveis      - consolida os niveis
       BLOCO 4  empilha_validos     - empilha celulas validas
                seleciona_melhor_   - melhor nivel por celula via
                  nivel               cascata de COALESCE (fallback)
       BLOCO 5  deriva_k            - k exponencial dos dados (se 0)
       BLOCO 6  extrapola_caudas    - FPD = FPD_ancora * exp(k*dist)
                                      nas faixas sem dado; ICs
                                      propagados proporcionalmente
                                      a ancora
       BLOCO 7  tabela final + confiabilidade (ALTA/MEDIA/BAIXA/
                                      EXTRAPOLADO)
       BLOCO 8  relatorio HTML de confiabilidade

     Macros auxiliares reaproveitadas (DoD E3): monta_niveis,
     agrega_nivel, loop_niveis, empilha_niveis, empilha_validos,
     prefix_vars, join_cond, seleciona_melhor_nivel, deriva_k,
     extrapola_caudas. Sao definidas em escopo de arquivo; a driver
     %tabela_referencia monta o contexto e as chama na ordem.

   ------------------------------------------------------------
   ARMADILHAS RESPEITADAS (wiki pag. 6):
     - %DO dentro de PROC SQL: toda geracao dinamica de SQL fica
       DENTRO de %macro (seleciona_melhor_nivel etc.).
     - Join hierarquico usa TODAS as vars do nivel (nivel 1 =
       score+grupo+canal; nivel 2 = score+grupo; nivel 3 = score).
     - ICs saem SEM sufixo _ref (ic_sup_conv, ...) p/ a Fase 2.
     - O score (1a var de VAR_SEG) NUNCA e colapsado.
     - Fechar todos os blocos (quit;/run;).

   ------------------------------------------------------------
   PARAMETROS (todos vem do 00_MASTER.sas - nada cravado aqui)

     ds_base          base do m01 com as 3 contagens (a MESMA da Fase 0)
     var_seg          vars de segmentacao (default &VAR_SEG); ordem importa
                      (1a = score = ancora da extrapolacao)
     var_score_faixa  var de score/faixa (default &VAR_SCORE_FAIXA;
                      deve ser a 1a de var_seg)
     k_exponencial    fator de aceleracao das caudas
                      (default &K_EXPONENCIAL; 0 = derivar dos dados)
     ds_tabela_ref    dataset de saida - tabela de referencia
                      (default &DS_TABELA_REF, ex.: INF.TABELA_REF_MV)
     col_aprovados    coluna de contagem de aprovados   (default n_aprovados)
     col_convertidos  coluna de contagem de convertidos (default n_convertidos)
     col_maus         coluna de contagem de maus        (default n_maus)
     relatorio        1 = emite o relatorio HTML de confiabilidade

   PRE-REQUISITO: Fase 0 (m02_diagnostico) executada na MESMA sessao.
     Macro vars necessarias: MIN_N, MIN_EVENTOS, Z_ALFA.

   ENTRADAS  : &ds_base + macro vars da Fase 0.
   SAIDAS    : &ds_tabela_ref com taxa_conversao_ref, taxa_fpd_ref,
               ic_sup_conv/ic_inf_conv/ic_sup_fpd/ic_inf_fpd (SEM _ref),
               nivel_usado, vars_nivel_usado, fl_extrapolado, confiabilidade.
   DEPENDE DE: E0 (m00_setup), E1 (m01_montar_base), E2 (m02_diagnostico).

   ------------------------------------------------------------
   EXEMPLO DE USO (no 00_MASTER.sas):

     %include "macros/m03_tabela_referencia.sas";
     %tabela_referencia(
        ds_base         = INF.BASE_MODELAGEM_AM,
        var_seg         = SCORE_HVI3 IDENTIFICA_GRUPO_MODELO CANAL_PCO_AJUSTADO,
        var_score_faixa = SCORE_HVI3,
        k_exponencial   = 0,
        ds_tabela_ref   = INF.TABELA_REF_MV
     );
   ============================================================ */


/* ============================================================
   BLOCO 1 - VALIDACAO DE PRE-REQUISITOS (macro vars da Fase 0)
   ============================================================ */
%macro valida_fase0;
    %if %symexist(MIN_N) = 0 or %symexist(MIN_EVENTOS) = 0 or %symexist(Z_ALFA) = 0 %then %do;
        %put ERROR: Macro variaveis da Fase 0 nao encontradas (MIN_N/MIN_EVENTOS/Z_ALFA).;
        %put ERROR- Execute o m02_diagnostico antes do m03_tabela_referencia (mesma sessao SAS).;
        %abort cancel;
    %end;
    %else %do;
        %put NOTE: === Fase 0 detectada: MIN_N=&MIN_N | MIN_EVENTOS=&MIN_EVENTOS | Z_ALFA=&Z_ALFA ===;
    %end;
%mend valida_fase0;


/* ============================================================
   BLOCO 2 - ENUMERACAO DOS NIVEIS HIERARQUICOS
   Mantem sempre a 1a var (score); colapsa as demais da direita
   para a esquerda. Ex. VAR_SEG = score grupo canal:
     Nivel 1: score grupo canal
     Nivel 2: score grupo
     Nivel 3: score
   ============================================================ */
%macro monta_niveis;
    %local i j vars_nivel;
    %global N_NIVEIS;

    %let N_NIVEIS = 1;
    %global VAR_NIVEL1;
    %let VAR_NIVEL1 = &VAR_SEG.;
    %put NOTE: Nivel 1: &VAR_NIVEL1.;

    %if &N_VARS. > 1 %then %do;
        %do i = 2 %to &N_VARS.;
            %let vars_nivel = ;
            %do j = 1 %to %eval(&N_VARS. - &i. + 1);
                %let vars_nivel = &vars_nivel. %scan(&VAR_SEG., &j., %str( ));
            %end;
            %let vars_nivel = %sysfunc(strip(&vars_nivel.));
            %let N_NIVEIS = %eval(&N_NIVEIS. + 1);
            %global VAR_NIVEL&N_NIVEIS.;
            %let VAR_NIVEL&N_NIVEIS. = &vars_nivel.;
            %put NOTE: Nivel &N_NIVEIS.: &&VAR_NIVEL&N_NIVEIS..;
        %end;
    %end;

    %put NOTE: === Total de niveis hierarquicos: &N_NIVEIS. ===;
%mend monta_niveis;


/* ============================================================
   BLOCO 3 - AGREGACAO POR NIVEL + IC DE WILSON
   Consome as 3 contagens do motor (sum(n_*)) em vez de
   count(*)/sum(case). Formulas de IC IDENTICAS ao legado.
   "having sum(&COL_APR) > 0" reproduz o "where FL_APROVADOS=1".
   ============================================================ */
%macro agrega_nivel(nivel, vars);

    %local vars_comma;
    %let vars_comma = %sysfunc(tranwrd(%superq(vars), %str( ), %str(,)));

    proc sql;
        create table WORK._AGG_NIVEL&nivel. as
        select
            &nivel. as nivel_hierarquico,
            "%sysfunc(strip(%superq(vars)))" as vars_usadas length=200,
            &vars_comma.,
            sum(&COL_APR)  as n_aprovados,
            sum(&COL_CONV) as n_convertidos,
            sum(&COL_MAU)  as n_maus,

            calculated n_convertidos / calculated n_aprovados as taxa_conversao,

            case
                when calculated n_convertidos > 0
                    then calculated n_maus / calculated n_convertidos
                else .
            end as taxa_fpd,

            /* IC Wilson - conversao superior */
            (
                calculated taxa_conversao
                + ((&Z_ALFA.**2) / (2 * calculated n_aprovados))
                + &Z_ALFA. * sqrt(
                    (calculated taxa_conversao * (1 - calculated taxa_conversao)
                     / calculated n_aprovados)
                    + ((&Z_ALFA.**2) / (4 * (calculated n_aprovados**2)))
                )
            )
            /
            (1 + ((&Z_ALFA.**2) / calculated n_aprovados)) as ic_sup_conv,

            /* IC Wilson - conversao inferior */
            (
                calculated taxa_conversao
                + ((&Z_ALFA.**2) / (2 * calculated n_aprovados))
                - &Z_ALFA. * sqrt(
                    (calculated taxa_conversao * (1 - calculated taxa_conversao)
                     / calculated n_aprovados)
                    + ((&Z_ALFA.**2) / (4 * (calculated n_aprovados**2)))
                )
            )
            /
            (1 + ((&Z_ALFA.**2) / calculated n_aprovados)) as ic_inf_conv,

            /* IC Wilson - FPD superior */
            case
                when calculated n_convertidos > 0 then
                    (
                        calculated taxa_fpd
                        + ((&Z_ALFA.**2) / (2 * calculated n_convertidos))
                        + &Z_ALFA. * sqrt(
                            (calculated taxa_fpd * (1 - calculated taxa_fpd)
                             / calculated n_convertidos)
                            + ((&Z_ALFA.**2) / (4 * (calculated n_convertidos**2)))
                        )
                    )
                    /
                    (1 + ((&Z_ALFA.**2) / calculated n_convertidos))
                else .
            end as ic_sup_fpd,

            /* IC Wilson - FPD inferior */
            case
                when calculated n_convertidos > 0 then
                    (
                        calculated taxa_fpd
                        + ((&Z_ALFA.**2) / (2 * calculated n_convertidos))
                        - &Z_ALFA. * sqrt(
                            (calculated taxa_fpd * (1 - calculated taxa_fpd)
                             / calculated n_convertidos)
                            + ((&Z_ALFA.**2) / (4 * (calculated n_convertidos**2)))
                        )
                    )
                    /
                    (1 + ((&Z_ALFA.**2) / calculated n_convertidos))
                else .
            end as ic_inf_fpd

        from &DS_INPUT.
        group by &vars_comma.
        having sum(&COL_APR) > 0
        ;
    quit;

    /* classifica celulas neste nivel */
    data WORK._AGG_NIVEL&nivel.;
        set WORK._AGG_NIVEL&nivel.;
        length status_celula $8;

        if n_convertidos = 0 then
            status_celula = "VAZIA";
        else if n_aprovados < &MIN_N. then
            status_celula = "INVALIDA";
        else if n_maus < &MIN_EVENTOS. then
            status_celula = "INSTAVEL";
        else
            status_celula = "VALIDA";

        fl_valida = (status_celula = "VALIDA");
    run;

%mend agrega_nivel;


/* Executa a agregacao para cada nivel */
%macro loop_niveis;
    %local i;
    %do i = 1 %to &N_NIVEIS.;
        %agrega_nivel(&i., &&VAR_NIVEL&i.);
        %put NOTE: === Nivel &i. agregado: &&VAR_NIVEL&i. ===;
    %end;
%mend loop_niveis;


/* Consolida todos os niveis em uma unica tabela */
%macro empilha_niveis;
    data WORK._AGG_TODOS_NIVEIS;
        set
        %do i = 1 %to &N_NIVEIS.;
            WORK._AGG_NIVEL&i.
        %end;
        ;
    run;
    %put NOTE: === Consolidado criado: WORK._AGG_TODOS_NIVEIS ===;
%mend empilha_niveis;


/* Empilha apenas as celulas validas de cada nivel */
%macro empilha_validos;
    data WORK._TODOS_VALIDOS;
        set
        %do i = 1 %to &N_NIVEIS.;
            WORK._AGG_NIVEL&i. (where=(fl_valida=1))
        %end;
        ;
    run;
%mend empilha_validos;


/* Prefixa uma lista de vars com um alias (a.var1, a.var2, ...) */
%macro prefix_vars(vars, alias=a);
    %local k n var;
    %let n = %sysfunc(countw(%superq(vars), %str( )));
    %do k = 1 %to &n.;
        %let var = %scan(%superq(vars), &k., %str( ));
        &alias..&var.
        %if &k. < &n. %then , ;
    %end;
%mend prefix_vars;


/* Monta a condicao de join por nivel (v.var = a.var and ...) */
%macro join_cond(vars, alias_base=a, alias_join=v);
    %local k n var;
    %let n = %sysfunc(countw(%superq(vars), %str( )));
    %do k = 1 %to &n.;
        %let var = %scan(%superq(vars), &k., %str( ));
        &alias_join..&var. = &alias_base..&var.
        %if &k. < &n. %then and;
    %end;
%mend join_cond;


/* ============================================================
   BLOCO 4 - SELECAO DO MELHOR NIVEL POR CELULA
   Parte da base unica do nivel mais granular e faz LEFT JOIN
   com cada nivel (so celulas validas), usando COALESCE para
   pegar o primeiro nivel onde houve match. O score nunca e
   colapsado; as demais vars sao colapsadas da direita p/ a
   esquerda (ordem dos niveis). Toda a geracao com %do fica
   DENTRO desta macro (armadilha do %DO em open code).
   ============================================================ */
%macro seleciona_melhor_nivel;
    %local i;

    proc sql;
        create table WORK._MELHOR_NIVEL as
        select
            %prefix_vars(&VAR_SEG., alias=a),

            /* primeira taxa de conversao valida encontrada */
            coalesce(
                %do i = 1 %to &N_NIVEIS.;
                    v&i..taxa_conversao
                    %if &i. < &N_NIVEIS. %then ,;
                %end;
            ) as taxa_conversao_ref,

            /* primeiro FPD valido encontrado */
            coalesce(
                %do i = 1 %to &N_NIVEIS.;
                    v&i..taxa_fpd
                    %if &i. < &N_NIVEIS. %then ,;
                %end;
            ) as taxa_fpd_ref,

            /* IC superior de conversao do nivel usado */
            coalesce(
                %do i = 1 %to &N_NIVEIS.;
                    v&i..ic_sup_conv
                    %if &i. < &N_NIVEIS. %then ,;
                %end;
            ) as ic_sup_conv,

            /* IC inferior de conversao do nivel usado */
            coalesce(
                %do i = 1 %to &N_NIVEIS.;
                    v&i..ic_inf_conv
                    %if &i. < &N_NIVEIS. %then ,;
                %end;
            ) as ic_inf_conv,

            /* IC superior de FPD do nivel usado */
            coalesce(
                %do i = 1 %to &N_NIVEIS.;
                    v&i..ic_sup_fpd
                    %if &i. < &N_NIVEIS. %then ,;
                %end;
            ) as ic_sup_fpd,

            /* IC inferior de FPD do nivel usado */
            coalesce(
                %do i = 1 %to &N_NIVEIS.;
                    v&i..ic_inf_fpd
                    %if &i. < &N_NIVEIS. %then ,;
                %end;
            ) as ic_inf_fpd,

            /* primeiro nivel hierarquico valido */
            case
                %do i = 1 %to &N_NIVEIS.;
                    when not missing(v&i..taxa_conversao) then v&i..nivel_hierarquico
                %end;
                else .
            end as nivel_usado,

            /* lista de vars do nivel efetivamente usado */
            coalescec(
                %do i = 1 %to &N_NIVEIS.;
                    v&i..vars_usadas
                    %if &i. < &N_NIVEIS. %then ,;
                %end;
            ) as vars_nivel_usado length=200,

            /* quantidades do nivel efetivamente usado */
            coalesce(
                %do i = 1 %to &N_NIVEIS.;
                    v&i..n_convertidos
                    %if &i. < &N_NIVEIS. %then ,;
                %end;
            ) as n_convertidos_ref,

            coalesce(
                %do i = 1 %to &N_NIVEIS.;
                    v&i..n_maus
                    %if &i. < &N_NIVEIS. %then ,;
                %end;
            ) as n_maus_ref,

            coalesce(
                %do i = 1 %to &N_NIVEIS.;
                    v&i..n_aprovados
                    %if &i. < &N_NIVEIS. %then ,;
                %end;
            ) as n_aprovados_ref

        from WORK._BASE_NIVEL1_UNICA a

        %do i = 1 %to &N_NIVEIS.;
            left join
            (
                select *
                from WORK._AGG_NIVEL&i.
                where fl_valida = 1
            ) as v&i.
            on %join_cond(&&VAR_NIVEL&i., alias_base=a, alias_join=v&i.)
        %end;
        ;
    quit;

    %put NOTE: === Bloco 4 concluido: WORK._MELHOR_NIVEL criado ===;
%mend seleciona_melhor_nivel;


/* ============================================================
   BLOCO 5 - DERIVACAO DO K EXPONENCIAL
   Se K_EXPONENCIAL=0, deriva da curva observada:
     k = media( ln(FPD_n / FPD_n-1) ) entre faixas validas.
   Piso de seguranca 0.15 se a derivacao falhar.
   ============================================================ */
%macro deriva_k;

    %if &K_EXPONENCIAL. = 0 %then %do;

        proc sort data=WORK._MELHOR_NIVEL out=WORK._SCORE_ORDENADO;
            by &VAR_SCORE_FAIXA.;
        run;

        data WORK._CALC_K;
            set WORK._SCORE_ORDENADO;
            where taxa_fpd_ref > 0 and nivel_usado ne .;
            lag_fpd = lag(taxa_fpd_ref);
            if _n_ > 1 and lag_fpd > 0 then
                log_ratio = log(taxa_fpd_ref / lag_fpd);
        run;

        proc sql noprint;
            select mean(log_ratio)
            into :K_EXP_DERIVADO trimmed
            from WORK._CALC_K
            where log_ratio > 0;   /* so aceleracoes positivas */
        quit;

        /* piso de seguranca */
        %if &K_EXP_DERIVADO. = . or &K_EXP_DERIVADO. = %then
            %let K_EXP_DERIVADO = 0.15;

        %let K_EXPONENCIAL = &K_EXP_DERIVADO.;
        %put NOTE: === K exponencial derivado dos dados: &K_EXPONENCIAL. ===;

    %end;
    %else %do;
        %put NOTE: === K exponencial informado pelo usuario: &K_EXPONENCIAL. ===;
    %end;

%mend deriva_k;


/* ============================================================
   BLOCO 6 - EXTRAPOLACAO EXPONENCIAL NAS CAUDAS
   Para faixas de score sem celula valida em nenhum nivel,
   extrapola a partir da ultima faixa confiavel (ancora):
     FPD_extrap(n)  = FPD_ancora  * exp(k * distancia)
     conv_extrap(n) = conv_ancora * exp((k*0.5) * distancia)
   ICs das faixas extrapoladas: propagados proporcionalmente a
   ancora (razao IC/taxa da ancora aplicada a taxa extrapolada).
   ============================================================ */
%macro extrapola_caudas;

    data WORK._MELHOR_NIVEL_AUX;
        set WORK._MELHOR_NIVEL;
        length score_char $100;
        score_char = strip(vvalue(&VAR_SCORE_FAIXA.));
        /* extrai a parte numerica da faixa (ex.: R20 -> 20) */
        score_num = input(compress(score_char, , 'kd'), best32.);
    run;

    /* ancora = ultima faixa valida (maior score_num com FPD obs.) */
    proc sql noprint;
        select max(score_num)
        into :ANCORA_SCORE_NUM trimmed
        from WORK._MELHOR_NIVEL_AUX
        where taxa_fpd_ref > 0
          and nivel_usado ne .;
    quit;

    %if %superq(ANCORA_SCORE_NUM)= %then %do;
        %put ERROR: Nenhuma ancora valida encontrada em WORK._MELHOR_NIVEL.;
        %put ERROR- Verifique se ha ao menos uma faixa com taxa_fpd_ref>0 e nivel_usado preenchido.;
    %end;
    %else %do;

        proc sql noprint;
            select score_char,
                   taxa_fpd_ref,
                   taxa_conversao_ref,
                   ic_sup_fpd,
                   ic_inf_fpd,
                   ic_sup_conv,
                   ic_inf_conv
            into :ANCORA_SCORE       trimmed,
                 :ANCORA_FPD         trimmed,
                 :ANCORA_CONV        trimmed,
                 :ANCORA_IC_SUP_FPD  trimmed,
                 :ANCORA_IC_INF_FPD  trimmed,
                 :ANCORA_IC_SUP_CONV trimmed,
                 :ANCORA_IC_INF_CONV trimmed
            from WORK._MELHOR_NIVEL_AUX
            where score_num = &ANCORA_SCORE_NUM.
              and taxa_fpd_ref > 0
              and nivel_usado ne .;
        quit;

        %put NOTE: === Ancora: faixa &ANCORA_SCORE. | FPD=&ANCORA_FPD. | Conv=&ANCORA_CONV. ===;

        data WORK._MELHOR_NIVEL_EXTRAP;
            set WORK._MELHOR_NIVEL_AUX;

            ancora_score_num = &ANCORA_SCORE_NUM.;
            ancora_fpd       = &ANCORA_FPD.;
            ancora_conv      = &ANCORA_CONV.;
            k                = &K_EXPONENCIAL.;

            if missing(taxa_fpd_ref) or missing(nivel_usado) then do;

                distancia = score_num - ancora_score_num;

                taxa_fpd_ref       = ancora_fpd * exp(k * distancia);
                /* conversao: aceleracao mais suave (50% do k do FPD) */
                taxa_conversao_ref = ancora_conv * exp((k * 0.5) * distancia);

                taxa_fpd_ref       = min(taxa_fpd_ref,       0.9999);
                taxa_conversao_ref = min(taxa_conversao_ref, 0.9999);

                nivel_usado      = 99;   /* codigo de extrapolacao */
                vars_nivel_usado = "EXTRAPOLADO";
                fl_extrapolado   = 1;

                /* ICs: razao IC/taxa da ancora aplicada a taxa extrapolada */
                _ratio_sup_fpd  = &ANCORA_IC_SUP_FPD.  / &ANCORA_FPD.;
                _ratio_inf_fpd  = &ANCORA_IC_INF_FPD.  / &ANCORA_FPD.;
                _ratio_sup_conv = &ANCORA_IC_SUP_CONV. / &ANCORA_CONV.;
                _ratio_inf_conv = &ANCORA_IC_INF_CONV. / &ANCORA_CONV.;

                ic_sup_fpd  = min(taxa_fpd_ref       * _ratio_sup_fpd,  0.9999);
                ic_inf_fpd  = max(taxa_fpd_ref       * _ratio_inf_fpd,  0.0001);
                ic_sup_conv = min(taxa_conversao_ref * _ratio_sup_conv, 0.9999);
                ic_inf_conv = max(taxa_conversao_ref * _ratio_inf_conv, 0.0001);

                drop _ratio_sup_fpd _ratio_inf_fpd _ratio_sup_conv _ratio_inf_conv;
            end;
            else do;
                fl_extrapolado = 0;
                distancia      = .;
            end;

            drop score_char score_num ancora_score_num ancora_fpd ancora_conv k;
        run;

    %end;

%mend extrapola_caudas;


/* ============================================================
   DRIVER - %tabela_referencia
   Monta o contexto (nomes do legado, GLOBAIS p/ visibilidade
   das macros auxiliares) e executa Fase 1 ponta a ponta.
   ============================================================ */
%macro tabela_referencia(
    ds_base=,
    var_seg=&VAR_SEG,
    var_score_faixa=&VAR_SCORE_FAIXA,
    k_exponencial=&K_EXPONENCIAL,
    ds_tabela_ref=&DS_TABELA_REF,
    col_aprovados=n_aprovados,
    col_convertidos=n_convertidos,
    col_maus=n_maus,
    relatorio=1
);

    options validvarname=v7;

    %if %length(&ds_base) = 0 %then %do;
        %put ERROR: m03_tabela_referencia - parametro ds_base obrigatorio.;
        %abort cancel;
    %end;

    /* pre-requisito: macro vars da Fase 0 */
    %valida_fase0;

    /* contexto p/ as macros auxiliares (nomes do legado) - GLOBAIS
       garantem visibilidade e que o que e setado dentro das macros
       (ANCORA_*, K_EXP_DERIVADO) sobreviva ate os relatorios. */
    %global DS_INPUT VAR_SEG VAR_SCORE_FAIXA K_EXPONENCIAL DS_OUTPUT_FASE1
            VAR_SEG_COMMA N_VARS COL_APR COL_CONV COL_MAU
            ANCORA_SCORE_NUM ANCORA_SCORE ANCORA_FPD ANCORA_CONV
            ANCORA_IC_SUP_FPD ANCORA_IC_INF_FPD ANCORA_IC_SUP_CONV ANCORA_IC_INF_CONV
            K_EXP_DERIVADO;

    %let DS_INPUT        = &ds_base;
    %let VAR_SEG         = &var_seg;
    %let VAR_SCORE_FAIXA = &var_score_faixa;
    %let K_EXPONENCIAL   = &k_exponencial;
    %let DS_OUTPUT_FASE1 = &ds_tabela_ref;
    %let COL_APR         = &col_aprovados;
    %let COL_CONV        = &col_convertidos;
    %let COL_MAU         = &col_maus;
    %let N_VARS          = %sysfunc(countw(&var_seg, %str( )));
    %let VAR_SEG_COMMA   = %sysfunc(tranwrd(%sysfunc(strip(&var_seg)), %str( ), %str(,)));

    %put NOTE: ===== m03_tabela_referencia: base=&DS_INPUT | var_seg=&VAR_SEG =====;

    /* BLOCO 2 - niveis hierarquicos */
    %monta_niveis;

    /* BLOCO 3 - agrega cada nivel + consolida */
    %loop_niveis;
    %empilha_niveis;

    /* PASSO 4.0 - empilha validos (consolidado + por nivel) */
    data WORK._AGG_VALIDAS;
        set WORK._AGG_TODOS_NIVEIS;
        where status_celula = "VALIDA";
    run;
    %empilha_validos;

    /* PASSO 4.1 - base unica do nivel mais granular */
    proc sql;
        create table WORK._BASE_NIVEL1_UNICA as
        select distinct &VAR_SEG_COMMA.
        from WORK._AGG_NIVEL1;
    quit;

    /* BLOCO 4 - melhor nivel por celula (fallback hierarquico) */
    %seleciona_melhor_nivel;

    /* PASSO 4.5 - classifica o tipo de referencia encontrada */
    data WORK._MELHOR_NIVEL;
        set WORK._MELHOR_NIVEL;
        length status_fallback $20;
        if not missing(nivel_usado) then do;
            if nivel_usado = 1 then status_fallback = "DIRETO";
            else status_fallback = "FALLBACK";
        end;
        else status_fallback = "SEM_REFERENCIA";
    run;

    /* BLOCO 5 - k exponencial */
    %deriva_k;

    /* BLOCO 6 - extrapolacao das caudas */
    %extrapola_caudas;

    /* ========================================================
       BLOCO 7 - TABELA DE REFERENCIA FINAL + confiabilidade
       ======================================================== */
    data &DS_OUTPUT_FASE1.;
        set WORK._MELHOR_NIVEL_EXTRAP;

        dt_referencia   = datetime();
        k_exp_usado     = &K_EXPONENCIAL.;
        min_n_usado     = &MIN_N.;
        min_eventos_uso = &MIN_EVENTOS.;

        length confiabilidade $12;
        if fl_extrapolado = 1 then
            confiabilidade = "EXTRAPOLADO";
        else if nivel_usado = 1 then
            confiabilidade = "ALTA";
        else if nivel_usado <= %eval(&N_NIVEIS. - 1) then
            confiabilidade = "MEDIA";
        else
            confiabilidade = "BAIXA";

        format dt_referencia datetime20.;

        label
            taxa_conversao_ref = "Taxa de conversao de referencia"
            taxa_fpd_ref       = "Taxa de FPD de referencia"
            nivel_usado        = "Nivel hierarquico usado (1=granular, 99=extrapolado)"
            vars_nivel_usado   = "Variaveis efetivamente usadas na referencia"
            n_convertidos_ref  = "N convertidos que embasam a referencia"
            n_maus_ref         = "N maus que embasam a referencia"
            fl_extrapolado     = "Flag: premissa extrapolada exponencialmente (1=sim)"
            confiabilidade     = "Nivel de confiabilidade da premissa"
            k_exp_usado        = "Fator k exponencial usado nas caudas"
            min_n_usado        = "MIN_N aplicado (vindo da Fase 0)"
            min_eventos_uso    = "MIN_EVENTOS aplicado (vindo da Fase 0)"
            ic_sup_conv        = "IC Wilson superior - Conversao"
            ic_inf_conv        = "IC Wilson inferior - Conversao"
            ic_sup_fpd         = "IC Wilson superior - FPD"
            ic_inf_fpd         = "IC Wilson inferior - FPD"
            dt_referencia      = "Data/hora de geracao da tabela";
    run;

    /* ========================================================
       BLOCO 8 - RELATORIO HTML DE CONFIABILIDADE
       ======================================================== */
    %if &relatorio = 1 %then %do;

        %local N_REF_TOTAL N_REF_ALTA N_REF_MEDIA N_REF_BAIXA N_REF_EXTRAP MEDIA_FPD_REF;

        proc sql noprint;
            select count(*) into :N_REF_TOTAL  trimmed from &DS_OUTPUT_FASE1.;
            select count(*) into :N_REF_ALTA   trimmed from &DS_OUTPUT_FASE1. where strip(confiabilidade)="ALTA";
            select count(*) into :N_REF_MEDIA  trimmed from &DS_OUTPUT_FASE1. where strip(confiabilidade)="MEDIA";
            select count(*) into :N_REF_BAIXA  trimmed from &DS_OUTPUT_FASE1. where strip(confiabilidade)="BAIXA";
            select count(*) into :N_REF_EXTRAP trimmed from &DS_OUTPUT_FASE1. where strip(confiabilidade)="EXTRAPOLADO";
            select mean(taxa_fpd_ref) into :MEDIA_FPD_REF trimmed from &DS_OUTPUT_FASE1.;
        quit;

        data WORK._REL_FASE1_FINAL;
            length bloco $20 descricao $60 valor $100;

            bloco="Geral";          descricao="Faixas/celulas na tabela de referencia"; valor="&N_REF_TOTAL"; output;

            bloco="Confiabilidade"; descricao="ALTA (nivel 1, granularidade maxima)";   valor=cats(&N_REF_ALTA.,  " celulas"); output;
            bloco="Confiabilidade"; descricao="MEDIA (nivel colapsado)";                 valor=cats(&N_REF_MEDIA., " celulas"); output;
            bloco="Confiabilidade"; descricao="BAIXA (so score, sem demais vars)";       valor=cats(&N_REF_BAIXA., " celulas"); output;
            bloco="Confiabilidade"; descricao="EXTRAPOLADO (sem dados observados)";      valor=cats(&N_REF_EXTRAP.," celulas"); output;

            bloco="Metricas";       descricao="FPD medio da tabela de referencia";       valor=strip(put(&MEDIA_FPD_REF.,percent8.2)); output;
            bloco="Metricas";       descricao="K exponencial usado";                     valor="&K_EXPONENCIAL"; output;
            bloco="Metricas";       descricao="Ancora de extrapolacao";                  valor=cats("Faixa ","&ANCORA_SCORE"); output;

            bloco="Output";         descricao="Dataset de referencia";                   valor="&DS_OUTPUT_FASE1"; output;
            bloco="Atencao";        descricao="Revisar faixas extrapoladas antes do uso";valor="Estimativas sem dados observados"; output;
        run;

        title "FASE 1 - TABELA DE REFERENCIA GERADA";
        proc report data=WORK._REL_FASE1_FINAL nowd;
            column bloco descricao valor;
            define bloco     / group   "Secao";
            define descricao / display "Descricao";
            define valor     / display "Valor";
        run;
        title;

        /* verificacao rapida: celulas com/sem referencia (antes da extrapolacao) */
        title "FASE 1 - CELULAS COM x SEM REFERENCIA (pre-extrapolacao)";
        proc sql;
            select
                count(*)                                          as total_celulas    label="Total de celulas",
                sum(case when nivel_usado ne 99 then 1 else 0 end) as com_referencia   label="Com referencia direta/fallback",
                sum(case when nivel_usado  = 99 then 1 else 0 end) as extrapoladas     label="Extrapoladas"
            from &DS_OUTPUT_FASE1.;
        quit;
        title;

    %end;

    /* ========================================================
       LIMPEZA DE TEMPORARIOS
       ======================================================== */
    proc datasets library=work nolist;
        delete _AGG_NIVEL: _AGG_TODOS_NIVEIS _AGG_VALIDAS _TODOS_VALIDOS
               _BASE_NIVEL1_UNICA _MELHOR_NIVEL _MELHOR_NIVEL_AUX
               _MELHOR_NIVEL_EXTRAP _SCORE_ORDENADO _CALC_K
               %if &relatorio = 1 %then %do; _REL_FASE1_FINAL %end;
        ;
    quit;

    %put NOTE: ===== m03_tabela_referencia concluido -> &DS_OUTPUT_FASE1 =====;
    %put NOTE: K_EXPONENCIAL usado=&K_EXPONENCIAL | Ancora=&ANCORA_SCORE;

%mend tabela_referencia;
