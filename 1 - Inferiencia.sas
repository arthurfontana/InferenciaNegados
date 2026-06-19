LIBNAME INF "/sasdata/Credito_Estudos/POL/ARTHUR_FONTANA/INFERENCIA";

/* ============================================================
   FASE 0 — DIAGNÓSTICO ESTATÍSTICO DA BASE
   Objetivo: Derivar automaticamente MIN_N e MIN_EVENTOS
             com base em Wilson IC e Power Analysis,
             classificar células e salvar thresholds como
             macro variáveis para as fases seguintes.
   ============================================================

   PARÂMETROS QUE O USUÁRIO DEVE AJUSTAR:
   - DS_INPUT       : nome do dataset de entrada (base histórica)
   - VAR_APROVADO   : coluna flag aprovado     (1=aprovado, 0=não)
   - VAR_CONVERTIDO : coluna flag convertido   (1=convertido, 0=não)
   - VAR_MAU        : coluna flag mau          (1=mau, 0=bom) — base de convertidos
   - VAR_SEG        : variáveis de segmentação (lista separada por espaço)
   - MARGEM_RELATIVA: margem de erro relativa aceitável (ex: 0.30 = ±30% da média)
   - ALPHA          : nível de significância   (ex: 0.05 para IC 95%)
   - PODER          : poder do teste           (ex: 0.80)
   - DS_OUTPUT      : nome do dataset de saída com diagnóstico por célula
   - LIB_OUT        : library de saída
   ============================================================ */

DATA WORK.BASE_SRS_GS_SUM_AMOSTRA;
SET INF.BASE_MODELAGEM_AM /*INF.BASE_SRS_GS_SUM*/ (WHERE=(OPERACAO = "MOVEL" and SISTEMA = "AM" AND SAFRA IN (202509, 202510, 202511, 202512))); /* and ranuni(42) < 0.04));*/
LENGTH CANAL_PCO_AJUSTADO $30;

IF CANAL_PCO_DECISAO IN ("CANAIS INTERNOS",
                         "CANAL NAO MAPEADO",
                         "INBOUND",
                         "LOJA PROPRIA",
                         "LOJAS PROPRIAS",
                         "OUTROS",
                         "RETENCAO",
                         "REVENDA",
                         "SINERGIA B2B2C",
                         "WEB DEALERS",
                         "WEB_DEALERS") THEN CANAL_PCO_AJUSTADO = "OUTROS";

ELSE IF CANAL_PCO_DECISAO IN ("CROSS SELLING",
                              "CROSSELING") THEN CANAL_PCO_AJUSTADO = "CROSSELING";
ELSE IF CANAL_PCO_DECISAO = "DIGITAL" THEN CANAL_PCO_AJUSTADO = "DIGITAL";
ELSE IF CANAL_PCO_DECISAO = "OUTBOUND" THEN CANAL_PCO_AJUSTADO = "OUTBOUND";
ELSE IF CANAL_PCO_DECISAO IN ("PAP",
                              "PAP 2.0",
                              "PAP TORDESILHAS") THEN CANAL_PCO_AJUSTADO = "PAP";
ELSE IF CANAL_PCO_DECISAO IN ("URA ATIVACAO",
                              "URA_ATIVACAO") THEN CANAL_PCO_AJUSTADO = "URA_ATIVACAO";
ELSE CANAL_PCO_AJUSTADO = "OUTROS"; /* FALLBACK */
IF SCORE_HVI3 = "" OR SCORE_HVI3 = "R99" THEN SCORE_HVI3 = "R20";

RUN;

proc freq data=WORK.BASE_SRS_GS_SUM_AMOSTRA; tables SCORE_HVI3 /missing; run;
proc freq data=WORK.BASE_SRS_GS_SUM_AMOSTRA; tables IDENTIFICA_GRUPO_MODELO /missing; run;
proc freq data=WORK.BASE_SRS_GS_SUM_AMOSTRA; tables CANAL_PCO_AJUSTADO /missing; run;



/*Fase 0*/
%let DS_INPUT        = WORK.BASE_SRS_GS_SUM_AMOSTRA;
%let VAR_APROVADO    = FL_APROVADOS;
%let VAR_CONVERTIDO  = FL_ALTAS;
%let VAR_MAU         = fl_atrs_parc_over_30;
%let VAR_SEG         = SCORE_HVI3 IDENTIFICA_GRUPO_MODELO CANAL_PCO_AJUSTADO;   /* ajuste aqui */
%let MARGEM_RELATIVA = 0.40 /*0.30*/;   /* Â±30% da mÃ©dia como margem aceitÃ¡vel */
%let ALPHA           = 0.07 /*0.05*/; 
%let PODER           = 0.75 /*0.80*/;
%let DS_OUTPUT       = WORK.FASE0_DIAGNOSTICO;
%let LIB_OUT         = WORK;

/*Fase 1*/
%let VAR_SCORE_FAIXA = SCORE_HVI3;
%let K_EXPONENCIAL   = 0;    /* 0 = derivar automaticamente dos dados */
%let DS_OUTPUT_FASE1 = INF.TABELA_REF_MV;

/*Fase 2*/
%let DS_NOVO         = WORK.BASE_SRS_GS_SUM_AMOSTRA; /*INDIQUE AQUI A BASE QUE SERÁ ENRIQUECIDA*/;
%let DS_TABELA_REF   = &DS_OUTPUT_FASE1.; /*WORK.FASE1_TABELA_REF;*/ 
%let DS_OUTPUT_FASE2 = INF.BASE_MODELAGEM_AM_MV; 
%let FL_MANTER_ORIG  = 1;   /* 1 = mantÃ©m todas as colunas originais */


/* ============================================================
   BLOCO 1 â€” MÃ‰TRICAS GLOBAIS
   Calcula FPD e conversÃ£o mÃ©dios da base inteira.
   Serve como referÃªncia para derivar thresholds e
   detectar cÃ©lulas que se desviam significativamente.
   ============================================================ */

proc sql /*noprint*/;

    /* Total de aprovados */
    select count(*)
    into :N_TOTAL_APROV trimmed
    from &DS_INPUT.
    where &VAR_APROVADO. = 1;

    /* Total de convertidos (dentro dos aprovados) */
    select count(*)
    into :N_TOTAL_CONV trimmed
    from &DS_INPUT.
    where &VAR_APROVADO. = 1
      and &VAR_CONVERTIDO. = 1;

    /* Total de maus (dentro dos convertidos) */
    select count(*)
     into :N_TOTAL_MAU trimmed
    from &DS_INPUT.
    where &VAR_APROVADO.  = 1
      and &VAR_CONVERTIDO. = 1
      and &VAR_MAU.        = 1;

    /* Totais globais */
    select
        count(*) as N_TOTAL_APROV,
        sum(case when &VAR_CONVERTIDO.=1 then 1 else 0 end) as N_TOTAL_CONV,
        sum(case when &VAR_CONVERTIDO.=1 and &VAR_MAU.=1 then 1 else 0 end) as N_TOTAL_MAU
    into
        :N_TOTAL_APROV trimmed,
        :N_TOTAL_CONV trimmed,
        :N_TOTAL_MAU trimmed
    from &DS_INPUT.
    where &VAR_APROVADO. = 1;


quit;


/* Taxas calculadas fora (mais robusto) */
%let P_CONV_GLOBAL = %sysevalf(&N_TOTAL_CONV. / &N_TOTAL_APROV.);
%let P_FPD_GLOBAL  = %sysevalf(&N_TOTAL_MAU.  / &N_TOTAL_CONV.);

%put === MÃ‰TRICAS GLOBAIS ===;
%put N Aprovados  : &N_TOTAL_APROV.;
%put N Convertidos: &N_TOTAL_CONV.;
%put N Maus       : &N_TOTAL_MAU.;
%put ConversÃ£o    : &P_CONV_GLOBAL.;
%put FPD Global   : &P_FPD_GLOBAL.;


/* ============================================================
   BLOCO 2 â€” CÃLCULO DOS THRESHOLDS ESTATÃSTICOS
   
   Usa a fórmula de Wilson invertida:
     n_min = z² Ã— p Ã— (1-p) / eÂ²
   Onde e = margem_relativa Ã— p (margem em termos absolutos)

   Calcula separadamente para conversÃ£o e FPD.
   O binding (maior dos dois) vira o MIN_N oficial.

   Para MIN_EVENTOS: deriva do FPD global e do n_min,
   com piso de 10 eventos (limite de Poisson).
   ============================================================ */

data _null_;

    alpha  = &ALPHA.;
    poder  = &PODER.;
    z_alfa = probit(1 - alpha/2);   /* z bicaudal: ~1.96 para 95% */
    z_beta = probit(poder);          /* z poder:   ~0.84 para 80% */

    p_conv = &P_CONV_GLOBAL.;
    p_fpd  = &P_FPD_GLOBAL.;
    margem = &MARGEM_RELATIVA.;

    /* Margem absoluta para cada mÃ©trica */
    e_conv = margem * p_conv;
    e_fpd  = margem * p_fpd;

    /* Wilson invertido: n mÃ­nimo para estimar proporÃ§Ã£o */
    n_min_conv = (z_alfa**2 * p_conv * (1 - p_conv)) / (e_conv**2);
    n_min_fpd  = (z_alfa**2 * p_fpd  * (1 - p_fpd )) / (e_fpd**2);

    /* Power analysis: n mÃ­nimo para cÃ©lula ser discriminante
       vs. mÃ©dia global (detectar desvio de 1 margem absoluta) */
    n_power_conv = ((z_alfa + z_beta)**2 *
                    (p_conv*(1-p_conv) + (p_conv+e_conv)*(1-(p_conv+e_conv))))
                   / (e_conv**2);

    n_power_fpd  = ((z_alfa + z_beta)**2 *
                    (p_fpd*(1-p_fpd) + (p_fpd+e_fpd)*(1-(p_fpd+e_fpd))))
                   / (e_fpd**2);

    /* Binding: maior entre Wilson e Power para cada mÃ©trica */
    n_binding_conv = max(n_min_conv, n_power_conv);
    n_binding_fpd  = max(n_min_fpd,  n_power_fpd);

    /* MIN_N final: maior dos dois bindings, arredondado para cima */
    min_n = ceil(max(n_binding_conv, n_binding_fpd));

    /* MIN_EVENTOS: eventos maus esperados dado min_n e FPD global
       com piso de 10 (limite de estabilidade de Poisson) */
    min_eventos = max(10, ceil(min_n * p_fpd));

    /* Salva como macro variÃ¡veis */
    call symputx('MIN_N',        min_n);
    call symputx('MIN_EVENTOS',  min_eventos);
    call symputx('Z_ALFA',       z_alfa);

    /* Log detalhado */
    put "=== DERIVAÃ‡ÃƒO DOS THRESHOLDS ===";
    put "z_alfa (IC " alpha +(-1) "): " z_alfa;
    put "z_beta (poder " poder +(-1) "): " z_beta;
    put " ";
    put "--- ConversÃ£o (p=" p_conv ") ---";
    put "  Margem absoluta aceitÃ¡vel : " e_conv;
    put "  n_min Wilson              : " n_min_conv;
    put "  n_min Power Analysis      : " n_power_conv;
    put "  n_binding (maior)         : " n_binding_conv;
    put " ";
    put "--- FPD (p=" p_fpd ") ---";
    put "  Margem absoluta aceitÃ¡vel : " e_fpd;
    put "  n_min Wilson              : " n_min_fpd;
    put "  n_min Power Analysis      : " n_power_fpd;
    put "  n_binding (maior)         : " n_binding_fpd;
    put " ";
    put "=== THRESHOLDS FINAIS ===";
    put "MIN_N       : " min_n;
    put "MIN_EVENTOS : " min_eventos;

run;

%put === THRESHOLDS DERIVADOS ===;
%put MIN_N      : &MIN_N.;
%put MIN_EVENTOS: &MIN_EVENTOS.;


/* ============================================================
   BLOCO 3 â€” AGREGAÃ‡ÃƒO POR CÃ‰LULA
   Conta aprovados, convertidos e maus para cada combinaÃ§Ã£o
   das variÃ¡veis de segmentaÃ§Ã£o informadas pelo usuÃ¡rio.
   Calcula taxas e IC de Wilson por cÃ©lula.
   ============================================================ */

/* Monta lista de variÃ¡veis para o BY/GROUP BY dinÃ¢mico */
%let VAR_SEG_COMMA = %sysfunc(tranwrd(&VAR_SEG., %str( ), %str(,)));

proc sql;
    create table WORK._CELULAS_RAW as
    select
        &VAR_SEG_COMMA.,
        count(*) as n_aprovados,
        sum(case when &VAR_CONVERTIDO. = 1 then 1 else 0 end) as n_convertidos,
        sum(case when &VAR_CONVERTIDO. = 1
                  and &VAR_MAU. = 1 then 1 else 0 end) as n_maus,

        /* Taxas */
        calculated n_convertidos / calculated n_aprovados as taxa_conversao,
        case 
            when calculated n_convertidos > 0
                then calculated n_maus / calculated n_convertidos
            else .
        end as taxa_fpd,

        /* IC Wilson para conversão - superior */
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

        /* IC Wilson para conversão - inferior */
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

        /* Amplitude do IC de conversão */
        calculated ic_sup_conv - calculated ic_inf_conv as ic_amplitude_conv,

        /* IC Wilson para FPD - superior (base: convertidos) */
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

        /* IC Wilson para FPD - inferior (base: convertidos) */
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
        end as ic_inf_fpd,

        /* Amplitude do IC de FPD */
        case
            when calculated n_convertidos > 0
                then calculated ic_sup_fpd - calculated ic_inf_fpd
            else .
        end as ic_amplitude_fpd

    from &DS_INPUT.
    where &VAR_APROVADO. = 1
    group by &VAR_SEG_COMMA.
    ;
quit;



/* ============================================================
   BLOCO 4 — CLASSIFICAÇÃO DAS CÉLULAS
   VÁLIDA    : n_aprovados >= MIN_N  E  n_maus >= MIN_EVENTOS
   INSTÁVEL  : n_aprovados >= MIN_N  MAS  n_maus < MIN_EVENTOS
               (volume suficiente mas eventos de mau insuficientes)
   INVÁLIDA  : n_aprovados < MIN_N
   VAZIA     : sem convertidos (não dá para estimar FPD)
   ============================================================ */

data &DS_OUTPUT.;
    set WORK._CELULAS_RAW;

    min_n        = &MIN_N.;
    min_eventos  = &MIN_EVENTOS.;

    if n_convertidos = 0 then
        status_celula = "VAZIA   ";
    else if n_aprovados < min_n then
        status_celula = "INVALIDA";
    else if n_maus < min_eventos then
        status_celula = "INSTAVEL";
    else
        status_celula = "VALIDA  ";

    /* Flag binária para facilitar joins nas fases seguintes */
    fl_celula_valida = (status_celula = "VALIDA  ");

	label
	    n_aprovados       = "N Aprovados na célula"
	    n_convertidos     = "N Convertidos na célula"
	    n_maus            = "N Maus na célula"
	    taxa_conversao    = "Taxa de Conversão observada"
	    taxa_fpd          = "Taxa de FPD observada"
	    ic_inf_conv       = "IC Wilson inferior - Conversão"
	    ic_sup_conv       = "IC Wilson superior - Conversão"
	    ic_amplitude_conv = "Amplitude do IC - Conversão"
	    ic_inf_fpd        = "IC Wilson inferior - FPD"
	    ic_sup_fpd        = "IC Wilson superior - FPD"
	    ic_amplitude_fpd  = "Amplitude do IC - FPD"
	    status_celula     = "Status da célula (VALIDA/INSTAVEL/INVALIDA/VAZIA)"
	    fl_celula_valida  = "Flag: célula válida para uso direto (1=sim)"
	    min_n             = "Threshold MIN_N derivado estatisticamente"
	    min_eventos       = "Threshold MIN_EVENTOS derivado estatisticamente";
run;


/* ============================================================
   BLOCO 5 — RELATÓRIO DE COBERTURA NO LOG
   Resume quantas células estão em cada status e
   qual percentual da base está coberto por células válidas.
   ============================================================ */

proc sql noprint;
    select
        count(*)                                          into :N_CELULAS        trimmed from &DS_OUTPUT.;
    select count(*) into :N_VALIDAS   trimmed from &DS_OUTPUT. where status_celula="VALIDA  ";
    select count(*) into :N_INSTAVEIS trimmed from &DS_OUTPUT. where status_celula="INSTAVEL";
    select count(*) into :N_INVALIDAS trimmed from &DS_OUTPUT. where status_celula="INVALIDA";
    select count(*) into :N_VAZIAS    trimmed from &DS_OUTPUT. where status_celula="VAZIA   ";

    select sum(n_aprovados) into :N_APR_VALIDAS   trimmed from &DS_OUTPUT. where status_celula="VALIDA  ";
    select sum(n_aprovados) into :N_APR_INSTAVEIS trimmed from &DS_OUTPUT. where status_celula="INSTAVEL";
    select sum(n_aprovados) into :N_APR_INVALIDAS trimmed from &DS_OUTPUT. where status_celula="INVALIDA";
quit;

%macro pct(num, den);
    %sysevalf(&num. / &den. * 100, ceil)
%mend;

data WORK._REL_COBERTURA;
    length categoria $50 descricao $200 valor $100;

    /* Cabeçalho */
    categoria = "Geral"; descricao = "Variáveis de segmentação"; valor = "&VAR_SEG."; output;
    categoria = "Geral"; descricao = "Total de células geradas"; valor = "&N_CELULAS."; output;

    /* Status */
    categoria = "Status"; descricao = "Válidas (células / aprovados)"; 
        valor = cats(&N_VALIDAS., " / ", &N_APR_VALIDAS.); output;

    categoria = "Status"; descricao = "Instáveis (células / aprovados)"; 
        valor = cats(&N_INSTAVEIS., " / ", &N_APR_INSTAVEIS.); output;

    categoria = "Status"; descricao = "Inválidas (células / aprovados)"; 
        valor = cats(&N_INVALIDAS., " / ", &N_APR_INVALIDAS.); output;

    categoria = "Status"; descricao = "Vazias (células)"; 
        valor = "&N_VAZIAS."; output;

    /* Cobertura */
    categoria = "Cobertura"; descricao = "Células válidas (% da base)"; 
        valor = cats(put(%pct(&N_APR_VALIDAS., &N_TOTAL_APROV.), 8.2), "%"); output;

    categoria = "Cobertura"; descricao = "Células instáveis (% da base)"; 
        valor = cats(put(%pct(&N_APR_INSTAVEIS., &N_TOTAL_APROV.), 8.2), "%"); output;

    categoria = "Cobertura"; descricao = "Células inválidas (% da base)"; 
        valor = cats(put(%pct(&N_APR_INVALIDAS., &N_TOTAL_APROV.), 8.2), "%"); output;

    /* Thresholds */
    categoria = "Thresholds"; descricao = "MIN_N"; 
        valor = cats(&MIN_N., " (alpha=", &ALPHA., ", poder=", &PODER., ", margem=", &MARGEM_RELATIVA., ")"); output;

    categoria = "Thresholds"; descricao = "MIN_EVENTOS"; 
        valor = "&MIN_EVENTOS."; output;

    /* Output */
    categoria = "Output"; descricao = "Dataset de diagnóstico"; 
        valor = "&DS_OUTPUT."; output;

    /* Macro vars */
    categoria = "Macro Variáveis"; descricao = "MIN_N"; valor = "&MIN_N."; output;
    categoria = "Macro Variáveis"; descricao = "MIN_EVENTOS"; valor = "&MIN_EVENTOS."; output;
    categoria = "Macro Variáveis"; descricao = "P_CONV_GLOBAL"; valor = "&P_CONV_GLOBAL."; output;
    categoria = "Macro Variáveis"; descricao = "P_FPD_GLOBAL"; valor = "&P_FPD_GLOBAL."; output;
run;

/* Render no Results */
proc report data=WORK._REL_COBERTURA nowd;
    title "FASE 0 — RELATÓRIO DE COBERTURA";

    column categoria descricao valor;

    define categoria / group "Bloco";
    define descricao / display "Métrica";
    define valor / display "Valor";

run;

title;


/* ============================================================
   BLOCO 6 — SALVA THRESHOLDS EM DATASET PERMANENTE
   Permite rastrear historicamente os thresholds usados
   em cada execução (auditoria e backtesting).
   ============================================================ */

data &LIB_OUT..FASE0_THRESHOLDS;
    dt_execucao      = datetime();
    variaveis_seg    = "&VAR_SEG.";
    alpha            = &ALPHA.;
    poder            = &PODER.;
    margem_relativa  = &MARGEM_RELATIVA.;
    p_conversao_glob = &P_CONV_GLOBAL.;
    p_fpd_global     = &P_FPD_GLOBAL.;
    n_total_aprov    = &N_TOTAL_APROV.;
    n_total_conv     = &N_TOTAL_CONV.;
    n_total_mau      = &N_TOTAL_MAU.;
    min_n_derivado   = &MIN_N.;
    min_eventos_der  = &MIN_EVENTOS.;
    n_celulas_total  = &N_CELULAS.;
    n_celulas_valid  = &N_VALIDAS.;
    n_celulas_inst   = &N_INSTAVEIS.;
    n_celulas_inv    = &N_INVALIDAS.;
    format dt_execucao datetime20.;
	label
	    dt_execucao      = "Data/hora da execução"
	    variaveis_seg    = "Variáveis de segmentação usadas"
	    alpha            = "Nível de significância (alpha)"
	    poder            = "Poder do teste"
	    margem_relativa  = "Margem de erro relativa aceitável"
	    p_conversao_glob = "Taxa de conversão global da base"
	    p_fpd_global     = "Taxa de FPD global da base"
	    n_total_aprov    = "Total de aprovados na base"
	    n_total_conv     = "Total de convertidos na base"
	    n_total_mau      = "Total de maus na base"
	    min_n_derivado   = "MIN_N derivado estatisticamente"
	    min_eventos_der  = "MIN_EVENTOS derivado estatisticamente"
	    n_celulas_total  = "Total de células geradas"
	    n_celulas_valid  = "Células válidas"
	    n_celulas_inst   = "Células instáveis"
	    n_celulas_inv    = "Células inválidas";
run;

/* Limpeza de temporÃ¡rios */
proc datasets library=work nolist;
    delete _CELULAS_RAW;
quit;

/* FIM FASE 0 */

/*INICIO FASE 1*/

/* ============================================================
   FASE 1 â€” CONSTRUÃ‡ÃƒO DA TABELA DE REFERÃŠNCIA
   Objetivo: Construir uma tabela com taxa de conversÃ£o e FPD
             para cada cÃ©lula vÃ¡lida. Para cÃ©lulas invÃ¡lidas,
             aplicar fallback hierÃ¡rquico colapsando dimensÃµes
             na ordem de prioridade definida pelo usuÃ¡rio.
             Para caudas sem cÃ©lula vÃ¡lida em nenhum nÃ­vel,
             aplicar extrapolaÃ§Ã£o exponencial sobre a faixa
             de score anterior confiÃ¡vel.
   ============================================================

   PRÃ‰-REQUISITO: Fase 0 jÃ¡ executada na mesma sessÃ£o SAS.
   Macro variÃ¡veis necessÃ¡rias vindas da Fase 0:
     &MIN_N., &MIN_EVENTOS., &Z_ALFA.
     &P_CONV_GLOBAL., &P_FPD_GLOBAL.

   PARÃ‚METROS QUE O USUÃRIO DEVE AJUSTAR:
   - DS_INPUT        : mesma base histÃ³rica da Fase 0
   - VAR_APROVADO    : coluna flag aprovado      (1/0)
   - VAR_CONVERTIDO  : coluna flag convertido    (1/0)
   - VAR_MAU         : coluna flag mau           (1/0)
   - VAR_SEG         : variÃ¡veis de segmentaÃ§Ã£o
                       ATENÃ‡ÃƒO: a primeira variÃ¡vel da lista
                       deve ser a de score/risco, pois Ã© ela
                       que orienta a extrapolaÃ§Ã£o exponencial
                       nas caudas. As demais serÃ£o colapsadas
                       antes do score na ordem hierÃ¡rquica.
   - VAR_SCORE_FAIXA : nome da variÃ¡vel de score/faixa
                       (deve ser a mesma primeira var de VAR_SEG)
   - K_EXPONENCIAL   : fator de aceleraÃ§Ã£o exponencial nas caudas
                       (se deixar 0, o cÃ³digo deriva dos dados)
   - DS_OUTPUT       : dataset de saÃ­da â€” tabela de referÃªncia
   - LIB_OUT         : library de saÃ­da
   ============================================================ */

/*					%let VAR_SCORE_FAIXA = SCORE_HVI3;*/
/*					%let K_EXPONENCIAL   = 0;    */
/*					%let DS_OUTPUT       = WORK.FASE1_TABELA_REF;*/
/*					%let LIB_OUT         = WORK;*/


/* ============================================================
   BLOCO 1 â€” VALIDAÃ‡ÃƒO DE PRÃ‰-REQUISITOS
   Verifica se as macro variÃ¡veis da Fase 0 estÃ£o disponÃ­veis.
   ============================================================ */

%macro valida_fase0;
    %if %symexist(MIN_N) = 0 or %symexist(MIN_EVENTOS) = 0 %then %do;
        %put ERRO: Macro variÃ¡veis da Fase 0 nÃ£o encontradas.;
        %put       Execute a Fase 0 antes de rodar a Fase 1.;
        %abort cancel;
    %end;
    %else %do;
        %put === Fase 0 detectada: MIN_N=&MIN_N. | MIN_EVENTOS=&MIN_EVENTOS. ===;
    %end;
%mend valida_fase0;

%valida_fase0;


/* ============================================================
   BLOCO 2 â€” ENUMERAÃ‡ÃƒO DOS NÃVEIS HIERÃRQUICOS
   Monta os nÃ­veis hierÃ¡rquicos de segmentaÃ§Ã£o em ordem
   decrescente de granularidade (do mais detalhado ao menos).

   Exemplo com VAR_SEG = score_faixa canal tipo_cliente:
     NÃ­vel 1 (mais granular): score_faixa canal tipo_cliente
     NÃ­vel 2               : score_faixa canal
     NÃ­vel 3 (mÃ­nimo)      : score_faixa

   REGRA: a primeira variÃ¡vel (score_faixa) nunca Ã© removida.
   As demais sÃ£o colapsadas da direita para a esquerda.
   ============================================================ */

/* Conta quantas variÃ¡veis de segmentaÃ§Ã£o foram informadas */
%let N_VARS = %sysfunc(countw(&VAR_SEG., %str( )));

%put === VariÃ¡veis de segmentaÃ§Ã£o: &N_VARS. ===;
%put === Lista: &VAR_SEG. ===;

/* Monta macro variÃ¡veis VAR_NIVELx para cada nÃ­vel hierÃ¡rquico.
   EstratÃ©gia: mantÃ©m sempre a var de score e vai removendo
   as demais da direita para a esquerda. */

/* Monta macro variÃ¡veis VAR_NIVELx para cada nÃ­vel hierÃ¡rquico */
%macro monta_niveis;
    %local i j vars_nivel;
    %global N_NIVEIS;

    %let N_NIVEIS = 0;

    /* NÃ­vel 1: todas as variÃ¡veis */
    %let N_NIVEIS = 1;
    %global VAR_NIVEL1;
    %let VAR_NIVEL1 = &VAR_SEG.;
    %put NÃ­vel 1: &VAR_NIVEL1.;

    /* NÃ­veis seguintes: remove variÃ¡veis da direita,
       mantendo sempre a primeira (score) */
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

            %put NÃ­vel &N_NIVEIS.: &&VAR_NIVEL&N_NIVEIS..;
        %end;
    %end;

    %put === Total de nÃ­veis hierÃ¡rquicos: &N_NIVEIS. ===;
%mend monta_niveis;

%monta_niveis;


/* ============================================================
   BLOCO 3 â€” AGREGAÃ‡ÃƒO EM TODOS OS NÃVEIS
   Para cada nÃ­vel hierÃ¡rquico, agrega a base e calcula
   as mÃ©tricas. Depois empilha tudo para o processo de
   seleÃ§Ã£o do melhor nÃ­vel por cÃ©lula.
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
            count(*) as n_aprovados,
            sum(case when &VAR_CONVERTIDO. = 1 then 1 else 0 end) as n_convertidos,
            sum(case when &VAR_CONVERTIDO. = 1
                      and &VAR_MAU. = 1 then 1 else 0 end) as n_maus,

            calculated n_convertidos / calculated n_aprovados as taxa_conversao,

            case 
                when calculated n_convertidos > 0
                    then calculated n_maus / calculated n_convertidos
                else .
            end as taxa_fpd,

            /* IC Wilson â€” conversÃ£o superior */
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

            /* IC Wilson â€” conversÃ£o inferior */
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

            /* IC Wilson â€” FPD superior */
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

            /* IC Wilson â€” FPD inferior */
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
        where &VAR_APROVADO. = 1
        group by &vars_comma.
        ;
    quit;

    /* Classifica cÃ©lulas neste nÃ­vel */
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


/* Executa agregaÃ§Ã£o para cada nÃ­vel */
%macro loop_niveis;
    %local i;

    %do i = 1 %to &N_NIVEIS.;
        %agrega_nivel(&i., &&VAR_NIVEL&i.);
        %put === NÃ­vel &i. agregado: &&VAR_NIVEL&i. ===;
    %end;
%mend loop_niveis;

%loop_niveis;


/* ============================================================
   BLOCO 3.1 â€” EMPILHA TODOS OS NÃVEIS
   Consolida os datasets de todos os nÃ­veis em uma Ãºnica tabela.
   ============================================================ */
%macro empilha_niveis;
    data WORK._AGG_TODOS_NIVEIS;
        set
        %do i = 1 %to &N_NIVEIS.;
            WORK._AGG_NIVEL&i.
        %end;
        ;
    run;

    %put === Dataset consolidado criado: WORK._AGG_TODOS_NIVEIS ===;
%mend empilha_niveis;

%empilha_niveis;

/* ============================================================
   BLOCO 4 â€” SELEÃ‡ÃƒO DO MELHOR NÃVEL POR CÃ‰LULA (CORRIGIDO)
   O %DO dentro de PROC SQL em open code causa erro.
   SoluÃ§Ã£o: encapsular toda a geraÃ§Ã£o do SQL dentro de
   uma %macro que resolve os loops antes de executar o SQL.
   ============================================================ */

/* Garante que VAR_SEG_COMMA estÃ¡ definido */
%let VAR_SEG_COMMA = %sysfunc(tranwrd(&VAR_SEG., %str( ), %str(,)));

/* --------------------------------------------------------
   PASSO 4.0 â€” Empilha todos os nÃ­veis vÃ¡lidos
   -------------------------------------------------------- */
data WORK._AGG_VALIDAS;
    set WORK._AGG_TODOS_NIVEIS;
    where status_celula = "VALIDA";
run;

%macro empilha_validos;
    data WORK._TODOS_VALIDOS;
        set
        %do i = 1 %to &N_NIVEIS.;
            WORK._AGG_NIVEL&i. (where=(fl_valida=1))
        %end;
        ;
    run;
%mend empilha_validos;

%empilha_validos;


/* --------------------------------------------------------
   PASSO 4.1 â€” Base Ãºnica do nÃ­vel mais granular
   -------------------------------------------------------- */
proc sql;
    create table WORK._BASE_NIVEL1_UNICA as
    select distinct
        &VAR_SEG_COMMA.
    from WORK._AGG_NIVEL1
    ;
quit;


/* --------------------------------------------------------
   PASSO 4.2 â€” Macro auxiliar:
   prefixa lista de variÃ¡veis com alias

   Exemplo:
      vars = score_faixa canal tipo_cliente
      alias = a

      retorna:
      a.score_faixa,
      a.canal,
      a.tipo_cliente
   -------------------------------------------------------- */
%macro prefix_vars(vars, alias=a);
    %local k n var;
    %let n = %sysfunc(countw(%superq(vars), %str( )));

    %do k = 1 %to &n.;
        %let var = %scan(%superq(vars), &k., %str( ));
        &alias..&var.
        %if &k. < &n. %then , ;
    %end;
%mend prefix_vars;


/* --------------------------------------------------------
   PASSO 4.3 â€” Macro auxiliar:
   monta condiÃ§Ã£o de join por nÃ­vel

   Exemplo:
      vars = score_faixa canal
      alias_base = a
      alias_join = v2

      retorna:
      v2.score_faixa = a.score_faixa
      and v2.canal   = a.canal
   -------------------------------------------------------- */
%macro join_cond(vars, alias_base=a, alias_join=v);
    %local k n var;
    %let n = %sysfunc(countw(%superq(vars), %str( )));

    %do k = 1 %to &n.;
        %let var = %scan(%superq(vars), &k., %str( ));
        &alias_join..&var. = &alias_base..&var.
        %if &k. < &n. %then and;
    %end;
%mend join_cond;


/* --------------------------------------------------------
   PASSO 4.4 â€” Seleciona o melhor nÃ­vel disponÃ­vel
   EstratÃ©gia:
   - parte da base Ãºnica do nÃ­vel mais granular
   - faz LEFT JOIN com cada nÃ­vel vÃ¡lido
   - usa COALESCE / COALESCEC para pegar o primeiro nÃ­vel
     onde houve match
   -------------------------------------------------------- */


%macro seleciona_melhor_nivel;
    %local i;

    proc sql;
        create table WORK._MELHOR_NIVEL as
        select
            %prefix_vars(&VAR_SEG., alias=a),

            /* Primeira taxa de conversÃ£o vÃ¡lida encontrada */
            coalesce(
                %do i = 1 %to &N_NIVEIS.;
                    v&i..taxa_conversao
                    %if &i. < &N_NIVEIS. %then ,;
                %end;
            ) as taxa_conversao_ref,

            /* Primeiro FPD vÃ¡lido encontrado */
            coalesce(
                %do i = 1 %to &N_NIVEIS.;
                    v&i..taxa_fpd
                    %if &i. < &N_NIVEIS. %then ,;
                %end;
            ) as taxa_fpd_ref,

            /* IC superior de conversÃ£o do nÃ­vel efetivamente usado */
            coalesce(
                %do i = 1 %to &N_NIVEIS.;
                    v&i..ic_sup_conv
                    %if &i. < &N_NIVEIS. %then ,;
                %end;
            ) as ic_sup_conv,

            /* IC inferior de conversÃ£o do nÃ­vel efetivamente usado */
            coalesce(
                %do i = 1 %to &N_NIVEIS.;
                    v&i..ic_inf_conv
                    %if &i. < &N_NIVEIS. %then ,;
                %end;
            ) as ic_inf_conv,

            /* IC superior de FPD do nÃ­vel efetivamente usado */
            coalesce(
                %do i = 1 %to &N_NIVEIS.;
                    v&i..ic_sup_fpd
                    %if &i. < &N_NIVEIS. %then ,;
                %end;
            ) as ic_sup_fpd,

            /* IC inferior de FPD do nÃ­vel efetivamente usado */
            coalesce(
                %do i = 1 %to &N_NIVEIS.;
                    v&i..ic_inf_fpd
                    %if &i. < &N_NIVEIS. %then ,;
                %end;
            ) as ic_inf_fpd,

            /* Primeiro nÃ­vel hierÃ¡rquico vÃ¡lido */
            case
                %do i = 1 %to &N_NIVEIS.;
                    when not missing(v&i..taxa_conversao) then v&i..nivel_hierarquico
                %end;
                else .
            end as nivel_usado,

            /* Lista de variÃ¡veis do nÃ­vel efetivamente usado */
            coalescec(
                %do i = 1 %to &N_NIVEIS.;
                    v&i..vars_usadas
                    %if &i. < &N_NIVEIS. %then ,;
                %end;
            ) as vars_nivel_usado length=200,

            /* Quantidades do nÃ­vel efetivamente usado */
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

    %put === Bloco 4 concluÃ­do: WORK._MELHOR_NIVEL criado ===;

%mend seleciona_melhor_nivel;

%seleciona_melhor_nivel;



/* --------------------------------------------------------
   PASSO 4.5 â€” Classifica o tipo de referÃªncia encontrada
   -------------------------------------------------------- */
data WORK._MELHOR_NIVEL;
    set WORK._MELHOR_NIVEL;
    length status_fallback $20;

    if not missing(nivel_usado) then do;
        if nivel_usado = 1 then
            status_fallback = "DIRETO";
        else
            status_fallback = "FALLBACK";
    end;
    else status_fallback = "SEM_REFERENCIA";
run;


/* --------------------------------------------------------
   VERIFICAÃ‡ÃƒO RÃPIDA â€” quantas cÃ©lulas com e sem match
   -------------------------------------------------------- */
proc sql;
    select
        count(*) as total_celulas,
        sum(case when taxa_fpd_ref ne . then 1 else 0 end) as com_referencia,
        sum(case when taxa_fpd_ref  = . then 1 else 0 end) as sem_referencia
    from WORK._MELHOR_NIVEL
    ;
quit;

%put === CÃ©lulas sem referÃªncia serÃ£o extrapoladas no Bloco 5/6 ===;



/* ============================================================
   BLOCO 5 â€” DERIVAÃ‡ÃƒO DO K EXPONENCIAL
   Se K_EXPONENCIAL = 0, deriva automaticamente das faixas
   de score que tÃªm cÃ©lulas vÃ¡lidas, calculando a taxa de
   aceleraÃ§Ã£o implÃ­cita do FPD entre faixas consecutivas.

   k = mÃ©dia(ln(FPD_n / FPD_n-1)) entre faixas vÃ¡lidas
   ============================================================ */

%macro deriva_k;

    %if &K_EXPONENCIAL. = 0 %then %do;

        /* Ordena faixas de score com FPD observado vÃƒÂ¡lido */
        proc sort data=WORK._MELHOR_NIVEL out=WORK._SCORE_ORDENADO;
            by &VAR_SCORE_FAIXA.;
        run;

        /* Calcula log-ratio entre faixas consecutivas */
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
            where log_ratio > 0;   /* sÃƒÂ³ aceleraÃƒÂ§ÃƒÂµes positivas */
        quit;

        /* Piso de seguranÃƒÂ§a: se derivaÃƒÂ§ÃƒÂ£o falhar, usa 0.15 */
        %if &K_EXP_DERIVADO. = . or &K_EXP_DERIVADO. = %then
            %let K_EXP_DERIVADO = 0.15;

        %let K_EXPONENCIAL = &K_EXP_DERIVADO.;
        %put === K exponencial derivado dos dados: &K_EXPONENCIAL. ===;

    %end;
    %else %do;
        %put === K exponencial informado pelo usuÃƒÂ¡rio: &K_EXPONENCIAL. ===;
    %end;

%mend deriva_k;
%deriva_k;



/* ============================================================
   BLOCO 6 — EXTRAPOLAÇÃO EXPONENCIAL NAS CAUDAS
   Para faixas de score sem célula válida em nenhum nível
   (taxa_fpd_ref = missing), extrapola usando a última
   faixa confiável como âncora.

   FPD_extrapolado(n) = FPD_âncora × exp(k × distância)
   Conversão extrapolada: aplica fator fixo de aceleração
   baseado na tendência observada nas faixas válidas.
   ============================================================ */

%macro extrapola_caudas;
/* --------------------------------------------------------
   PASSO 6.1 — Cria base auxiliar com score numérico
   para permitir cálculo de distância mesmo quando a faixa
   vem em formato texto (ex.: R20)
   -------------------------------------------------------- */
data WORK._MELHOR_NIVEL_AUX;
    set WORK._MELHOR_NIVEL;

    length score_char $100;
    score_char = strip(vvalue(&VAR_SCORE_FAIXA.));

    /* Extrai parte numérica da faixa (ex.: R20 -> 20) */
    score_num = input(compress(score_char, , 'kd'), best32.);
run;


/* --------------------------------------------------------
   PASSO 6.2 — Identifica a última faixa válida (âncora)
   -------------------------------------------------------- */
proc sql noprint;
    select max(score_num)
    into :ANCORA_SCORE_NUM trimmed
    from WORK._MELHOR_NIVEL_AUX
    where taxa_fpd_ref > 0
      and nivel_usado ne .;
quit;


/* Se não existir âncora válida, interrompe com mensagem clara */
%if %superq(ANCORA_SCORE_NUM)= %then %do;
    %put ERRO: Nenhuma âncora válida foi encontrada em WORK._MELHOR_NIVEL.;
    %put ERRO: Verifique se existe ao menos uma faixa com taxa_fpd_ref > 0 e nivel_usado preenchido.;
%end;
%else %do;

    /* Recupera a faixa âncora original + métricas da âncora
       incluindo os ICs para propagar proporcionalmente nas extrapolações */
    proc sql noprint;
        select score_char,
               taxa_fpd_ref,
               taxa_conversao_ref,
               ic_sup_fpd,
               ic_inf_fpd,
               ic_sup_conv,
               ic_inf_conv
        into :ANCORA_SCORE        trimmed,
             :ANCORA_FPD          trimmed,
             :ANCORA_CONV         trimmed,
             :ANCORA_IC_SUP_FPD   trimmed,
             :ANCORA_IC_INF_FPD   trimmed,
             :ANCORA_IC_SUP_CONV  trimmed,
             :ANCORA_IC_INF_CONV  trimmed
        from WORK._MELHOR_NIVEL_AUX
        where score_num = &ANCORA_SCORE_NUM.
          and taxa_fpd_ref > 0
          and nivel_usado ne .;
    quit;

    %put === Âncora para extrapolação: faixa &ANCORA_SCORE. | FPD=&ANCORA_FPD. | Conv=&ANCORA_CONV. ===;
    %put === ICs da âncora: FPD [&ANCORA_IC_INF_FPD. %str(;) &ANCORA_IC_SUP_FPD.] | Conv [&ANCORA_IC_INF_CONV. %str(;) &ANCORA_IC_SUP_CONV.] ===;


    /* --------------------------------------------------------
       PASSO 6.3 — Aplica extrapolação nas faixas sem referência
       -------------------------------------------------------- */
    data WORK._MELHOR_NIVEL_EXTRAP;
        set WORK._MELHOR_NIVEL_AUX;

        ancora_score_num = &ANCORA_SCORE_NUM.;
        ancora_fpd       = &ANCORA_FPD.;
        ancora_conv      = &ANCORA_CONV.;
        k                = &K_EXPONENCIAL.;

        /* Flag de extrapolação */
        if missing(taxa_fpd_ref) or missing(nivel_usado) then do;

            /* Distância em número de faixa */
            distancia = score_num - ancora_score_num;

            taxa_fpd_ref = ancora_fpd * exp(k * distancia);

            /* Conversão: aceleração mais suave (50% do k do FPD),
               pois a relação conversão-risco é menos íngreme */
            taxa_conversao_ref = ancora_conv * exp((k * 0.5) * distancia);

            /* Garante limites máximos */
            taxa_fpd_ref       = min(taxa_fpd_ref,       0.9999);
            taxa_conversao_ref = min(taxa_conversao_ref, 0.9999);

            nivel_usado      = 99;   /* código de extrapolação */
            vars_nivel_usado = "EXTRAPOLADO";
            fl_extrapolado   = 1;

            /* ICs para faixas extrapoladas: propaga os ICs da âncora
               proporcionalmente à taxa extrapolada.
               Lógica: mantém a mesma largura relativa do IC da âncora,
               escalando junto com a taxa extrapolada.
               Razão IC/taxa da âncora é aplicada sobre a taxa extrapolada.

               Ex: âncora FPD=0.30, ic_sup=0.36 (ratio=1.20)
                   faixa extrap FPD=0.45 -> ic_sup = 0.45 * 1.20 = 0.54 */

            /* Ratios da âncora — calculados uma vez, aplicados a cada faixa */
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

%extrapola_caudas;


/* ============================================================
   BLOCO 7 â€” TABELA DE REFERÃŠNCIA FINAL
   Consolida tudo, adiciona metadados de auditoria e
   salva o dataset de saÃ­da pronto para a Fase 2.
   ============================================================ */

data &DS_OUTPUT_FASE1.;
    set WORK._MELHOR_NIVEL_EXTRAP;

    /* Metadados de auditoria */
    dt_referencia   = datetime();
    k_exp_usado     = &K_EXPONENCIAL.;
    min_n_usado     = &MIN_N.;
    min_eventos_uso = &MIN_EVENTOS.;

    /* Classifica confiabilidade para uso na Fase 2 */
    if fl_extrapolado = 1 then
        confiabilidade = "EXTRAPOLADO ";
    else if nivel_usado = 1 then
        confiabilidade = "ALTA        ";
    else if nivel_usado <= %eval(&N_NIVEIS. - 1) then
        confiabilidade = "MEDIA       ";
    else
        confiabilidade = "BAIXA       ";

    format dt_referencia datetime20.;

label
    taxa_conversao_ref = "Taxa de conversÃ£o de referÃªncia"
    taxa_fpd_ref       = "Taxa de FPD de referÃªncia"
    nivel_usado        = "NÃ­vel hierÃ¡rquico usado (1=mais granular, 99=extrapolado)"
    vars_nivel_usado   = "VariÃ¡veis efetivamente usadas na referÃªncia"
    n_convertidos_ref  = "N convertidos que embasam a referÃªncia"
    n_maus_ref         = "N maus que embasam a referÃªncia"
    fl_extrapolado     = "Flag: premissa extrapolada exponencialmente (1=sim)"
    confiabilidade     = "NÃ­vel de confiabilidade da premissa"
    k_exp_usado        = "Fator k exponencial usado nas caudas"
    min_n_usado        = "MIN_N aplicado (vindo da Fase 0)"
    min_eventos_uso    = "MIN_EVENTOS aplicado (vindo da Fase 0)"
    ic_sup_conv        = "IC Wilson superior â€” ConversÃ£o"
    ic_inf_conv        = "IC Wilson inferior â€” ConversÃ£o"
    ic_sup_fpd         = "IC Wilson superior â€” FPD"
    ic_inf_fpd         = "IC Wilson inferior â€” FPD"
    dt_referencia      = "Data/hora de geraÃ§Ã£o da tabela";
run;


/* ============================================================
   BLOCO 8 Ã¢â‚¬â€ RELATÃƒâ€œRIO NO LOG
   ============================================================ */

proc sql noprint;
    select count(*)   into :N_REF_TOTAL    trimmed from &DS_OUTPUT_FASE1.;
    select count(*)   into :N_REF_ALTA     trimmed from &DS_OUTPUT_FASE1. where confiabilidade="ALTA        ";
    select count(*)   into :N_REF_MEDIA    trimmed from &DS_OUTPUT_FASE1. where confiabilidade="MEDIA       ";
    select count(*)   into :N_REF_BAIXA    trimmed from &DS_OUTPUT_FASE1. where confiabilidade="BAIXA       ";
    select count(*)   into :N_REF_EXTRAP   trimmed from &DS_OUTPUT_FASE1. where confiabilidade="EXTRAPOLADO ";
    select mean(taxa_fpd_ref) into :MEDIA_FPD_REF trimmed from &DS_OUTPUT_FASE1.;
quit;


/* ============================================================
   BLOCO 8 â€” RELATÃ“RIO DE CONSOLIDAÃ‡ÃƒO (RESULTS)
   ============================================================ */

/* Calcula mÃ©tricas */
proc sql noprint;
    select count(*) into :N_REF_TOTAL trimmed 
    from &DS_OUTPUT_FASE1.;

    select count(*) into :N_REF_ALTA trimmed 
    from &DS_OUTPUT_FASE1. 
    where strip(confiabilidade) = "ALTA";

    select count(*) into :N_REF_MEDIA trimmed 
    from &DS_OUTPUT_FASE1. 
    where strip(confiabilidade) = "MEDIA";

    select count(*) into :N_REF_BAIXA trimmed 
    from &DS_OUTPUT_FASE1. 
    where strip(confiabilidade) = "BAIXA";

    select count(*) into :N_REF_EXTRAP trimmed 
    from &DS_OUTPUT_FASE1. 
    where strip(confiabilidade) = "EXTRAPOLADO";

    select mean(taxa_fpd_ref) into :MEDIA_FPD_REF trimmed 
    from &DS_OUTPUT_FASE1.;
quit;
data WORK._REL_FASE1_FINAL;
    length bloco $40 descricao $200 valor $100;

    /* Geral */
    bloco = "Geral";
    descricao = "Faixas na tabela de referência";
    valor = "&N_REF_TOTAL.";
    output;

    /* Distribuição */
    bloco = "Confiabilidade";
    descricao = "ALTA (nível 1, granularidade máxima)";
    valor = cats(&N_REF_ALTA., " faixas");
    output;

    bloco = "Confiabilidade";
    descricao = "MÉDIA (nível colapsado)";
    valor = cats(&N_REF_MEDIA., " faixas");
    output;

    bloco = "Confiabilidade";
    descricao = "BAIXA (só score, sem demais variáveis)";
    valor = cats(&N_REF_BAIXA., " faixas");
    output;

    bloco = "Confiabilidade";
    descricao = "EXTRAPOLADO (sem dados observados)";
    valor = cats(&N_REF_EXTRAP., " faixas");
    output;

    /* Métricas */
    bloco = "Métricas";
    descricao = "FPD médio da tabela de referência";
    valor = "&MEDIA_FPD_REF.";
    output;

    bloco = "Métricas";
    descricao = "K exponencial usado";
    valor = "&K_EXPONENCIAL.";
    output;

    bloco = "Métricas";
    descricao = "Âncora de extrapolação";
    valor = cats("Faixa ", "&ANCORA_SCORE.");
    output;

    /* Output */
    bloco = "Output";
    descricao = "Dataset de referência";
    valor = "&DS_OUTPUT_FASE1.";
    output;

    /* Aviso */
    bloco = "Atenção";
    descricao = "Revisar faixas extrapoladas antes do uso";
    valor = "Estimativas sem dados observados";
    output;

run;


/* ============================================================
   EXIBE NO RESULTS
   ============================================================ */
proc report data=WORK._REL_FASE1_FINAL nowd;
    title "FASE 1 — TABELA DE REFERÊNCIA GERADA";

    column bloco descricao valor;

    define bloco / group "Seção";
    define descricao / display "Descrição";
    define valor / display "Valor";

run;

title;


/* Limpeza de temporÃƒÂ¡rios */
proc datasets library=work nolist;
    delete _AGG_NIVEL: _TODOS_VALIDOS _BASE_NIVEL1_UNICA
           _MELHOR_NIVEL _MELHOR_NIVEL_EXTRAP
           _SCORE_ORDENADO _CALC_K;
quit;

/* FIM FASE 1 */


/* ============================================================
   FASE 2 — APLICAÇÃO NA BASE NOVA
   Objetivo: Enriquecer uma base nova (proposta a proposta)
             com as premissas de conversão e FPD vindas da
             tabela de referência gerada na Fase 1.

   Cada linha da base nova recebe:
     - prob_conversao   : probabilidade decimal de conversão
     - prob_fpd         : probabilidade decimal de inadimplência
     - nivel_usado      : granularidade da premissa aplicada
     - vars_nivel_usado : variáveis efetivamente usadas no match
     - confiabilidade   : ALTA / MEDIA / BAIXA / EXTRAPOLADO
     - fl_extrapolado   : 1 se a premissa foi extrapolada

   O join é feito primeiro tentando a combinação completa
   de variáveis de segmentação. Se não encontrar match,
   desce hierarquicamente até o nível mínimo (só score).
   ============================================================

   PRÉ-REQUISITO: Fases 0 e 1 já executadas.
   Macro variáveis necessárias: &VAR_SEG., &VAR_SCORE_FAIXA.,
   &N_NIVEIS., &VAR_NIVEL1. ... &VAR_NIVEL[N].

   PARÂMETROS QUE O USUÁRIO DEVE AJUSTAR:
   - DS_NOVO         : base nova a ser enriquecida
                       (mesma estrutura de variáveis da base
                       histórica, sem necessidade das flags
                       de convertido/mau — são o target)ESTOU INI
   - DS_TABELA_REF   : tabela de referência gerada na Fase 1
                       (padrão: WORK.FASE1_TABELA_REF)
   - VAR_SEG         : mesmas variáveis usadas nas Fases 0/1
   - VAR_SCORE_FAIXA : variável de score/faixa (chave primária
                       do join com a tabela de referência)
   - DS_OUTPUT       : dataset de saída enriquecido
   - LIB_OUT         : library de saída
   - FL_MANTER_ORIG  : 1 = mantém todas as colunas originais
                       0 = mantém só ID + variáveis de join
                           + premissas (output mais enxuto)
   ============================================================ */

/*			%let DS_NOVO         = WORK.BASE_SRS_GS_SUM_AMOSTRA */
					/*INDIQUE AQUI A BASE QUE SERÁ ENRIQUECIDA*/;
/*			%let DS_TABELA_REF   = WORK.FASE1_TABELA_REF;*/
/*			%let DS_OUTPUT_FASE2       = INF.BASE_SRS_GS_TRATADA_INF; */
					/*WORK.FASE2_BASE_ENRIQUECIDA;*/
/*			%let LIB_OUT         = WORK;*/
/*			%let FL_MANTER_ORIG  = 1;   */
					/* 1 = mantÃ©m todas as colunas originais */




/* ============================================================
   BLOCO 1 â€” VALIDAÃ‡ÃƒO DE PRÃ‰-REQUISITOS
   Verifica existÃªncia da tabela de referÃªncia e das
   macro variÃ¡veis necessÃ¡rias das fases anteriores.
   ============================================================ */

%macro valida_prereqs_f2;

    /* Verifica macro variÃ¡veis da Fase 1 */
    %if %symexist(N_NIVEIS) = 0 %then %do;
        %put AVISO: &N_NIVEIS. nÃ£o encontrado. Assumindo estrutura padrÃ£o de 3 nÃ­veis.;
        %let N_NIVEIS = 3;
    %end;

    /* Verifica existÃªncia da tabela de referÃªncia */
    %if %sysfunc(exist(&DS_TABELA_REF.)) = 0 %then %do;
        %put ERRO: Tabela de referÃªncia &DS_TABELA_REF. nÃ£o encontrada.;
        %put       Execute a Fase 1 antes de rodar a Fase 2.;
        %abort cancel;
    %end;

    /* Verifica existÃªncia da base nova */
    %if %sysfunc(exist(&DS_NOVO.)) = 0 %then %do;
        %put ERRO: Base nova &DS_NOVO. nÃ£o encontrada.;
        %abort cancel;
    %end;

    %put === PrÃ©-requisitos validados ===;
    %put === Tabela de referÃªncia : &DS_TABELA_REF. ===;
    %put === Base nova            : &DS_NOVO. ===;
    %put === VariÃ¡veis de join    : &VAR_SEG. ===;

%mend valida_prereqs_f2;
%valida_prereqs_f2;


/* ============================================================
   BLOCO 2 â€” PREPARAÃ‡ÃƒO DA TABELA DE REFERÃŠNCIA
   Extrai da tabela de referÃªncia apenas as colunas
   necessÃ¡rias para o join: chaves + premissas.
   Garante uma linha por combinaÃ§Ã£o de segmentaÃ§Ã£o.
   ============================================================ */

%let VAR_SEG_COMMA = %sysfunc(tranwrd(&VAR_SEG., %str( ), %str(,)));

proc sql;
    create table WORK._REF_JOIN as
    select
        &VAR_SEG_COMMA.,
        taxa_conversao_ref,
        taxa_fpd_ref,
        nivel_usado,
        vars_nivel_usado,
        confiabilidade,
        fl_extrapolado,
        n_convertidos_ref,
        n_maus_ref,
        ic_sup_conv,
        ic_inf_conv,
        ic_sup_fpd,
        ic_inf_fpd
    from &DS_TABELA_REF.
    /* Garante uma linha por combinaÃ§Ã£o â€” pega a de maior granularidade */
    group by &VAR_SEG_COMMA.
    having nivel_usado = min(nivel_usado);
quit;


/* ============================================================
   BLOCO 3 â€” JOIN HIERÃRQUICO NA BASE NOVA
   EstratÃ©gia em cascata:
     1. Tenta match completo (todas as vars de segmentaÃ§Ã£o)
     2. Se nÃ£o encontrar, tenta nÃ­veis colapsados sequencialmente
     3. Fallback final: join sÃ³ por score_faixa

   Usa LEFT JOIN para garantir que nenhuma proposta seja
   perdida â€” propostas sem match recebem flag de alerta.
   ============================================================ */

%macro join_hierarquico;

    %let N_VARS = %sysfunc(countw(&VAR_SEG., %str( )));

    /* --------------------------------------------------------
       PASSO 3.1 â€” Join no nÃ­vel mais granular (todas as vars)
    -------------------------------------------------------- */
    %let JOIN_COND_1 = ;
    %do j = 1 %to &N_VARS.;
        %let var_j = %scan(&VAR_SEG., &j., %str( ));
        %if &j. = 1 %then
            %let JOIN_COND_1 = b.&var_j. = a.&var_j.;
        %else
            %let JOIN_COND_1 = &JOIN_COND_1. and b.&var_j. = a.&var_j.;
    %end;

    proc sql;
        create table WORK._JOIN_NIVEL1 as
        select
            a.*,
            b.taxa_conversao_ref    as _conv_n1,
            b.taxa_fpd_ref          as _fpd_n1,
            b.nivel_usado           as _nivel_n1,
            b.vars_nivel_usado      as _vars_n1,
            b.confiabilidade        as _conf_n1,
            b.fl_extrapolado        as _extrap_n1,
            b.n_convertidos_ref     as _nconv_n1,
            b.n_maus_ref            as _nmaus_n1,
            b.ic_sup_conv           as _icsconv_n1,
            b.ic_inf_conv           as _icicconv_n1,
            b.ic_sup_fpd            as _icsfpd_n1,
            b.ic_inf_fpd            as _icifpd_n1
        from &DS_NOVO. a
        left join WORK._REF_JOIN b
            on &JOIN_COND_1.;
    quit;

    /* --------------------------------------------------------
       PASSO 3.2 â€” Para linhas sem match no nÃ­vel 1,
       tenta nÃ­veis colapsados sequencialmente
    -------------------------------------------------------- */
    %if &N_VARS. > 1 %then %do;

        /* ComeÃ§a com o resultado do nÃ­vel 1 */
        data WORK._JOIN_ATUAL;
            set WORK._JOIN_NIVEL1;
        run;

        %do nivel = 2 %to &N_VARS.;

            /* Monta lista de vars para este nÃ­vel colapsado */
            %let vars_nivel_k = ;
            %do j = 1 %to %eval(&N_VARS. - &nivel. + 1);
                %let vars_nivel_k = &vars_nivel_k. %scan(&VAR_SEG., &j., %str( ));
            %end;
            %let vars_nivel_k = %sysfunc(strip(&vars_nivel_k.));
            %let vars_k_comma = %sysfunc(tranwrd(&vars_nivel_k., %str( ), %str(,)));

            /* Monta condiÃ§Ã£o de join para este nÃ­vel */
            %let n_vars_k = %sysfunc(countw(&vars_nivel_k., %str( )));
            %let JOIN_COND_K = ;
            %do j = 1 %to &n_vars_k.;
                %let var_j = %scan(&vars_nivel_k., &j., %str( ));
                %if &j. = 1 %then
                    %let JOIN_COND_K = b.&var_j. = a.&var_j.;
                %else
                    %let JOIN_COND_K = &JOIN_COND_K. and b.&var_j. = a.&var_j.;
            %end;

            /* Agrega tabela de referÃªncia para este nÃ­vel colapsado */
            proc sql;
                create table WORK._REF_NIVEL_K as
                select
                    &vars_k_comma.,
                    taxa_conversao_ref,
                    taxa_fpd_ref,
                    nivel_usado,
                    vars_nivel_usado,
                    confiabilidade,
                    fl_extrapolado,
                    n_convertidos_ref,
                    n_maus_ref,
                    ic_sup_conv,
                    ic_inf_conv,
                    ic_sup_fpd,
                    ic_inf_fpd
                from &DS_TABELA_REF.
                group by &vars_k_comma.
                having nivel_usado = min(nivel_usado);

                /* Join apenas para linhas ainda sem match */
                create table WORK._JOIN_NIVEL_K as
                select
                    a.*,
                    case when a._conv_n1 is null
                         then b.taxa_conversao_ref
                         else a._conv_n1   end as _conv_n1,
                    case when a._fpd_n1  is null
                         then b.taxa_fpd_ref
                         else a._fpd_n1    end as _fpd_n1,
                    case when a._nivel_n1 is null
                         then b.nivel_usado
                         else a._nivel_n1  end as _nivel_n1,
                    case when a._vars_n1 is null
                         then b.vars_nivel_usado
                         else a._vars_n1   end as _vars_n1,
                    case when a._conf_n1 is null
                         then b.confiabilidade
                         else a._conf_n1   end as _conf_n1,
                    case when a._extrap_n1 is null
                         then b.fl_extrapolado
                         else a._extrap_n1 end as _extrap_n1,
                    case when a._nconv_n1 is null
                         then b.n_convertidos_ref
                         else a._nconv_n1  end as _nconv_n1,
                    case when a._nmaus_n1 is null
                         then b.n_maus_ref
                         else a._nmaus_n1  end as _nmaus_n1,
                    case when a._icsconv_n1 is null
                         then b.ic_sup_conv
                         else a._icsconv_n1 end as _icsconv_n1,
                    case when a._icicconv_n1 is null
                         then b.ic_inf_conv
                         else a._icicconv_n1 end as _icicconv_n1,
                    case when a._icsfpd_n1 is null
                         then b.ic_sup_fpd
                         else a._icsfpd_n1  end as _icsfpd_n1,
                    case when a._icifpd_n1 is null
                         then b.ic_inf_fpd
                         else a._icifpd_n1  end as _icifpd_n1
                from WORK._JOIN_ATUAL a
                left join WORK._REF_NIVEL_K b
                    on &JOIN_COND_K.
                    and a._conv_n1 is null;   /* sÃ³ preenche quem ainda nÃ£o tem */
            quit;

            /* Atualiza base de trabalho */
            data WORK._JOIN_ATUAL;
                set WORK._JOIN_NIVEL_K;
            run;

            proc datasets library=work nolist;
                delete _REF_NIVEL_K _JOIN_NIVEL_K;
            quit;

        %end; /* fim loop de nÃ­veis colapsados */

    %end; /* fim if N_VARS > 1 */
    %else %do;
        data WORK._JOIN_ATUAL;
            set WORK._JOIN_NIVEL1;
        run;
    %end;

%mend join_hierarquico;
%join_hierarquico;


/* ============================================================
   BLOCO 4 â€” CONSOLIDAÃ‡ÃƒO E RENOMEAÃ‡ÃƒO FINAL
   Renomeia colunas internas para nomes limpos.
   Adiciona flag de alerta para propostas sem match algum.
   MantÃ©m ou descarta colunas originais conforme FL_MANTER_ORIG.
   ============================================================ */

data &DS_OUTPUT_FASE2.;
/*data INF.BASE_SRS_GS_TRATADA_INF;*/
    set WORK._JOIN_ATUAL;

    /* Renomeia para nomes finais */
    rename
        _conv_n1    = prob_conversao
        _fpd_n1     = prob_fpd
        _nivel_n1   = nivel_premissa
        _vars_n1    = vars_premissa
        _conf_n1    = confiabilidade_premissa
        _extrap_n1  = fl_premissa_extrapolada
        _nconv_n1   = n_convertidos_referencia
        _nmaus_n1   = n_maus_referencia
        _icsconv_n1 = ic_sup_conversao
        _icicconv_n1= ic_inf_conversao
        _icsfpd_n1  = ic_sup_fpd
        _icifpd_n1  = ic_inf_fpd;

    /* Flag de alerta: proposta sem match em nenhum nÃ­vel */
    fl_sem_premissa = (_conv_n1 = .);

    /* Data de aplicaÃ§Ã£o das premissas */
    dt_aplicacao = datetime();
    format dt_aplicacao datetime20.;

	label
	    prob_conversao            = "Probabilidade de conversão (premissa)"
	    prob_fpd                  = "Probabilidade de FPD (premissa)"
	    nivel_premissa            = "Nível hierárquico da premissa usada"
	    vars_premissa             = "Variáveis usadas na premissa"
	    confiabilidade_premissa   = "Confiabilidade da premissa (ALTA/MEDIA/BAIXA/EXTRAPOLADO)"
	    fl_premissa_extrapolada   = "Flag: premissa extrapolada exponencialmente (1=sim)"
	    fl_sem_premissa           = "Flag: proposta sem premissa disponível — requer revisão manual"
	    n_convertidos_referencia  = "N convertidos que embasam a premissa"
	    n_maus_referencia         = "N maus que embasam a premissa"
	    ic_sup_conversao          = "IC Wilson superior — conversão"
	    ic_inf_conversao          = "IC Wilson inferior — conversão"
	    ic_sup_fpd                = "IC Wilson superior — FPD"
	    ic_inf_fpd                = "IC Wilson inferior — FPD"
	    dt_aplicacao              = "Data/hora de aplicação das premissas";

    %if &FL_MANTER_ORIG. = 0 %then %do;
        keep &VAR_SEG_COMMA.
             prob_conversao prob_fpd
             nivel_premissa vars_premissa confiabilidade_premissa
             fl_premissa_extrapolada fl_sem_premissa
             n_convertidos_referencia n_maus_referencia
             ic_sup_conversao ic_inf_conversao
             ic_sup_fpd ic_inf_fpd
             dt_aplicacao;
    %end;

run;

/* ============================================================
   BLOCO 5 — RELATÓRIO DE COBERTURA (RESULTS)
   Informa quantas propostas receberam premissa e em qual
   nível, e quantas ficaram sem match.
   ============================================================ */

proc sql noprint;
    select count(*)
    into :N_TOTAL_NOVO trimmed
    from &DS_OUTPUT_FASE2.;

    select count(*)
    into :N_COM_ALTA trimmed
    from &DS_OUTPUT_FASE2.
    where strip(confiabilidade_premissa) = "ALTA";

    select count(*)
    into :N_COM_MEDIA trimmed
    from &DS_OUTPUT_FASE2.
    where strip(confiabilidade_premissa) = "MEDIA";

    select count(*)
    into :N_COM_BAIXA trimmed
    from &DS_OUTPUT_FASE2.
    where strip(confiabilidade_premissa) = "BAIXA";

    select count(*)
    into :N_COM_EXTRAP trimmed
    from &DS_OUTPUT_FASE2.
    where strip(confiabilidade_premissa) = "EXTRAPOLADO";

    select count(*)
    into :N_SEM_PREMISSA trimmed
    from &DS_OUTPUT_FASE2.
    where fl_sem_premissa = 1;

    select mean(prob_conversao), mean(prob_fpd)
    into :MEDIA_CONV_NOVO trimmed,
         :MEDIA_FPD_NOVO  trimmed
    from &DS_OUTPUT_FASE2.
    where fl_sem_premissa = 0;
quit;

%macro pct2(num, den);
    %sysevalf((&num. / &den.) * 100, floor)
%mend;


/* ============================================================
   MONTA BASE DO RELATÓRIO
   ============================================================ */
data WORK._REL_FASE2_FINAL;
    length bloco $40 descricao $200 valor $120;

    /* Geral */
    bloco = "Geral";
    descricao = "Base nova";
    valor = "&DS_NOVO.";
    output;

    bloco = "Geral";
    descricao = "Total de propostas";
    valor = "&N_TOTAL_NOVO.";
    output;

    /* Cobertura por confiabilidade */
    bloco = "Cobertura por confiabilidade";
    descricao = "ALTA";
    valor = cats(&N_COM_ALTA., " propostas (", %pct2(&N_COM_ALTA., &N_TOTAL_NOVO.), "%)");
    output;

    bloco = "Cobertura por confiabilidade";
    descricao = "MÉDIA";
    valor = cats(&N_COM_MEDIA., " propostas (", %pct2(&N_COM_MEDIA., &N_TOTAL_NOVO.), "%)");
    output;

    bloco = "Cobertura por confiabilidade";
    descricao = "BAIXA";
    valor = cats(&N_COM_BAIXA., " propostas (", %pct2(&N_COM_BAIXA., &N_TOTAL_NOVO.), "%)");
    output;

    bloco = "Cobertura por confiabilidade";
    descricao = "EXTRAPOLADO";
    valor = cats(&N_COM_EXTRAP., " propostas (", %pct2(&N_COM_EXTRAP., &N_TOTAL_NOVO.), "%)");
    output;

    bloco = "Cobertura por confiabilidade";
    descricao = "SEM PREMISSA";
    valor = cats(&N_SEM_PREMISSA., " propostas — REQUER REVISÃO MANUAL");
    output;

    /* Médias */
    bloco = "Médias das premissas aplicadas";
    descricao = "Conversão esperada";
    valor = "&MEDIA_CONV_NOVO.";
    output;

    bloco = "Médias das premissas aplicadas";
    descricao = "FPD esperado";
    valor = "&MEDIA_FPD_NOVO.";
    output;

    /* Output */
    bloco = "Output";
    descricao = "Dataset de saída";
    valor = "&DS_OUTPUT_FASE2.";
    output;

    /* Atenção */
    %if &N_SEM_PREMISSA. > 0 %then %do;
        bloco = "Atenção";
        descricao = "Propostas sem premissa disponível";
        valor = cats(&N_SEM_PREMISSA., " propostas");
        output;

        bloco = "Atenção";
        descricao = "Ação recomendada";
        valor = "Filtrar fl_sem_premissa=1 para revisão manual antes da simulação da Fase 3";
        output;
    %end;
run;


/* ============================================================
   EXIBE NO RESULTS
   ============================================================ */
proc report data=WORK._REL_FASE2_FINAL nowd;
    title "FASE 2 — RELATÓRIO DE APLICAÇÃO DE PREMISSAS";

    column bloco descricao valor;

    define bloco / group "Seção";
    define descricao / display "Descrição";
    define valor / display "Valor";

run;

title;


/* ============================================================
   BLOCO 6 â€” DISTRIBUIÃ‡ÃƒO DIAGNÃ“STICA POR FAIXA DE SCORE
   Gera uma visÃ£o agregada por score mostrando o volume
   de propostas e as premissas mÃ©dias aplicadas.
   Ãštil para validaÃ§Ã£o visual antes de rodar a Fase 3.
   ============================================================ */

proc sql;
    create table &LIB_OUT..FASE2_DIAGNOSTICO_SCORE as
	select
        &VAR_SCORE_FAIXA.,
        count(*)                        as n_propostas,
        mean(prob_conversao)            as premissa_conv_media,
        mean(prob_fpd)                  as premissa_fpd_media,
        sum(prob_conversao)             as conversoes_esperadas,
        sum(prob_conversao * prob_fpd)  as maus_esperados,
        min(confiabilidade_premissa)    as confiabilidade_minima,
        sum(fl_premissa_extrapolada)    as n_extrapoladas,
        sum(fl_sem_premissa)            as n_sem_premissa
    from &DS_OUTPUT_FASE2.
    group by &VAR_SCORE_FAIXA.
    order by &VAR_SCORE_FAIXA.;
quit;

%put === VisÃ£o diagnÃ³stica por score salva em: &LIB_OUT..FASE2_DIAGNOSTICO_SCORE ===;


/* Limpeza de temporÃ¡rios */
proc datasets library=work nolist;
    delete _REF_JOIN _JOIN_NIVEL1 _JOIN_ATUAL;
quit;

/* FIM FASE 2 */

