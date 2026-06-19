/* ============================================================
   m02_diagnostico.sas  -  E2: Diagnostico estatistico (Fase 0)
   ------------------------------------------------------------
   OBJETIVO
     Re-embrulhar a Fase 0 de "1 - Inferiencia.sas" (l. 25-515)
     como macro agnostica a base, consumindo as 3 colunas de
     contagem do motor unificado (n_aprovados / n_convertidos /
     n_maus) em vez de count(*)/sum(case...), e trocando os PUT
     no log por relatorio HTML com explicabilidade e recomendacao.

     A logica estatistica e IDENTICA ao legado (wiki pag. 6):
       - metricas globais (P_CONV_GLOBAL, P_FPD_GLOBAL);
       - thresholds via Wilson invertido + power analysis;
       - IC de Wilson por celula (conversao e FPD);
       - classificacao VALIDA / INSTAVEL / INVALIDA / VAZIA.

     A unica diferenca e a parametrizacao (nomes vindos do master)
     e o consumo das 3 contagens, que torna o codigo identico em
     ANALITICA e SUMARIZADA (wiki pag. 5 - Motor Unificado):
       global    : sum(n_aprovados), sum(n_convertidos), sum(n_maus)
       por celula: group by VAR_SEG, sum(n_*)
     Como n_aprovados ja codifica FL_APROVADOS (=FL_APROVADOS no
     grao analitico; soma de aprovados no sumarizado), nao ha mais
     o "where FL_APROVADOS=1" do legado. Para reproduzir fielmente
     o efeito daquele filtro (celulas formadas so a partir de
     volume aprovado) e evitar divisao 0/0, a agregacao por celula
     usa "having sum(n_aprovados) > 0".

   ------------------------------------------------------------
   PARAMETROS (todos vem do 00_MASTER.sas - nada cravado aqui)

     ds_base          base do m01 com as 3 contagens (ANALITICA ou SUMARIZADA)
     var_seg          vars de segmentacao (default &VAR_SEG); a ordem importa
                      (1a = score = ancora; ultima = 1a a colapsar no fallback)
     margem_relativa  margem de erro relativa aceitavel (ex.: 0.40)
     alpha            nivel de significancia (ex.: 0.07 -> IC 93%)
     poder            poder do teste (ex.: 0.75)

     col_aprovados    coluna de contagem de aprovados   (default n_aprovados)
     col_convertidos  coluna de contagem de convertidos (default n_convertidos)
     col_maus         coluna de contagem de maus        (default n_maus)

     ds_diagnostico   dataset de saida com o diagnostico por celula
                      (default WORK.FASE0_DIAGNOSTICO)
     lib_out          library para o dataset permanente de thresholds
                      (default WORK) -> &lib_out..FASE0_THRESHOLDS
     gerar_thresholds 1 = grava FASE0_THRESHOLDS (auditoria/backtest)
     relatorio        1 = emite os relatorios HTML (cobertura + recomendacao)
     limite_cobertura % de volume aprovado em celulas VALIDAS abaixo do qual
                      a recomendacao alerta cobertura baixa (default 95)
     limite_fallback  fracao de volume aprovado em celulas nao-validas, dentro
                      de um valor da dimensao colapsavel, acima da qual dispara
                      o alerta de risco (ex.: PAP/grupo MEDIA) (default 0.30)

   ENTRADAS  : &ds_base (saida do m01).
   SAIDAS    : &ds_diagnostico (diagnostico por celula) +
               macro vars GLOBAIS exportadas para a Fase 1:
                 MIN_N, MIN_EVENTOS, Z_ALFA, P_CONV_GLOBAL, P_FPD_GLOBAL.
               (opcional) &lib_out..FASE0_THRESHOLDS.
   DEPENDE DE: E0 (m00_setup) e E1 (m01_montar_base).

   ------------------------------------------------------------
   EXEMPLO DE USO (no 00_MASTER.sas):

     %include "macros/m02_diagnostico.sas";
     %diagnostico(
        ds_base         = INF.BASE_MODELAGEM_AM,
        var_seg         = SCORE_HVI3 IDENTIFICA_GRUPO_MODELO CANAL_PCO_AJUSTADO,
        margem_relativa = 0.40,
        alpha           = 0.07,
        poder           = 0.75,
        ds_diagnostico  = WORK.FASE0_DIAGNOSTICO
     );
     -> com 0.40 / 0.07 / 0.75 deve derivar MIN_N=230 e MIN_EVENTOS=62.
   ============================================================ */

%macro diagnostico(
    ds_base=,
    var_seg=&VAR_SEG,
    margem_relativa=&MARGEM_RELATIVA,
    alpha=&ALPHA,
    poder=&PODER,
    col_aprovados=n_aprovados,
    col_convertidos=n_convertidos,
    col_maus=n_maus,
    ds_diagnostico=WORK.FASE0_DIAGNOSTICO,
    lib_out=WORK,
    gerar_thresholds=1,
    relatorio=1,
    limite_cobertura=95,
    limite_fallback=0.30
);

    %local var_seg_comma
           N_TOTAL_APROV N_TOTAL_CONV N_TOTAL_MAU
           N_CELULAS N_VALIDAS N_INSTAVEIS N_INVALIDAS N_VAZIAS
           N_APR_VALIDAS N_APR_INSTAVEIS N_APR_INVALIDAS N_APR_VAZIAS
           _nvars_seg _dim_colaps _WORST_DIM _WORST_PCT _WORST_VOL;

    /* macro vars exportadas para a Fase 1 - precisam ser GLOBAIS */
    %global MIN_N MIN_EVENTOS Z_ALFA P_CONV_GLOBAL P_FPD_GLOBAL;

    options validvarname=v7;

    %if %length(&ds_base) = 0 %then %do;
        %put ERROR: m02_diagnostico - parametro ds_base obrigatorio.;
        %abort cancel;
    %end;

    %let var_seg_comma = %sysfunc(tranwrd(%sysfunc(strip(&var_seg)), %str( ), %str(,)));
    %let _nvars_seg    = %sysfunc(countw(&var_seg, %str( )));
    %let _dim_colaps   = %scan(&var_seg, &_nvars_seg, %str( ));

    %put NOTE: ===== m02_diagnostico: base=&ds_base | var_seg=&var_seg =====;

    /* ========================================================
       BLOCO 1 - METRICAS GLOBAIS
       Motor unificado: as 3 contagens ja codificam o filtro de
       aprovados; basta soma-las (vale em ANALITICA e SUMARIZADA).
       ======================================================== */
    proc sql noprint;
        select sum(&col_aprovados), sum(&col_convertidos), sum(&col_maus)
          into :N_TOTAL_APROV trimmed, :N_TOTAL_CONV trimmed, :N_TOTAL_MAU trimmed
        from &ds_base;
    quit;

    %let P_CONV_GLOBAL = %sysevalf(&N_TOTAL_CONV / &N_TOTAL_APROV);
    %let P_FPD_GLOBAL  = %sysevalf(&N_TOTAL_MAU  / &N_TOTAL_CONV);

    %put NOTE: === METRICAS GLOBAIS ===;
    %put NOTE: N Aprovados   : &N_TOTAL_APROV;
    %put NOTE: N Convertidos : &N_TOTAL_CONV;
    %put NOTE: N Maus        : &N_TOTAL_MAU;
    %put NOTE: Conversao     : &P_CONV_GLOBAL;
    %put NOTE: FPD Global    : &P_FPD_GLOBAL;

    /* ========================================================
       BLOCO 2 - THRESHOLDS ESTATISTICOS (logica identica)
       Wilson invertido + power analysis. O binding (maior dos
       quatro candidatos) vira MIN_N. MIN_EVENTOS = MIN_N x FPD
       global, com piso de 10 (estabilidade de Poisson).
       ======================================================== */
    data _null_;
        alpha  = &alpha;
        poder  = &poder;
        z_alfa = probit(1 - alpha/2);   /* z bicaudal */
        z_beta = probit(poder);         /* z poder    */

        p_conv = &P_CONV_GLOBAL;
        p_fpd  = &P_FPD_GLOBAL;
        margem = &margem_relativa;

        /* margem absoluta por metrica */
        e_conv = margem * p_conv;
        e_fpd  = margem * p_fpd;

        /* Wilson invertido: n minimo para estimar proporcao */
        n_min_conv = (z_alfa**2 * p_conv * (1 - p_conv)) / (e_conv**2);
        n_min_fpd  = (z_alfa**2 * p_fpd  * (1 - p_fpd )) / (e_fpd**2);

        /* power analysis: n minimo para a celula discriminar da media */
        n_power_conv = ((z_alfa + z_beta)**2 *
                        (p_conv*(1-p_conv) + (p_conv+e_conv)*(1-(p_conv+e_conv))))
                       / (e_conv**2);
        n_power_fpd  = ((z_alfa + z_beta)**2 *
                        (p_fpd*(1-p_fpd) + (p_fpd+e_fpd)*(1-(p_fpd+e_fpd))))
                       / (e_fpd**2);

        /* binding: maior entre Wilson e power para cada metrica */
        n_binding_conv = max(n_min_conv, n_power_conv);
        n_binding_fpd  = max(n_min_fpd,  n_power_fpd);

        /* MIN_N final: maior dos dois bindings, arredondado p/ cima */
        min_n = ceil(max(n_binding_conv, n_binding_fpd));

        /* MIN_EVENTOS: maus esperados dado min_n e FPD global, piso 10 */
        min_eventos = max(10, ceil(min_n * p_fpd));

        /* exporta como GLOBAIS (scope 'G') p/ a Fase 1 */
        call symputx('MIN_N',       min_n,       'G');
        call symputx('MIN_EVENTOS', min_eventos, 'G');
        call symputx('Z_ALFA',      z_alfa,      'G');

        put "=== DERIVACAO DOS THRESHOLDS ===";
        put "z_alfa (IC alpha=" alpha +(-1) "): " z_alfa;
        put "z_beta (poder=" poder +(-1) "): " z_beta;
        put "--- Conversao (p=" p_conv ") ---";
        put "  n_min Wilson         : " n_min_conv;
        put "  n_min Power Analysis : " n_power_conv;
        put "--- FPD (p=" p_fpd ") ---";
        put "  n_min Wilson         : " n_min_fpd;
        put "  n_min Power Analysis : " n_power_fpd;
        put "=== THRESHOLDS FINAIS ===";
        put "MIN_N       : " min_n;
        put "MIN_EVENTOS : " min_eventos;
    run;

    %put NOTE: === THRESHOLDS DERIVADOS: MIN_N=&MIN_N | MIN_EVENTOS=&MIN_EVENTOS ===;

    /* ========================================================
       BLOCO 3 - AGREGACAO POR CELULA + IC DE WILSON
       Formulas de IC identicas ao legado; so a fonte das
       contagens muda (sum(n_*) em vez de count/sum(case)).
       ======================================================== */
    proc sql;
        create table WORK._CELULAS_RAW as
        select
            &var_seg_comma,
            sum(&col_aprovados)   as n_aprovados,
            sum(&col_convertidos) as n_convertidos,
            sum(&col_maus)        as n_maus,

            /* taxas */
            calculated n_convertidos / calculated n_aprovados as taxa_conversao,
            case
                when calculated n_convertidos > 0
                    then calculated n_maus / calculated n_convertidos
                else .
            end as taxa_fpd,

            /* IC Wilson conversao - superior */
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

            /* IC Wilson conversao - inferior */
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

            /* amplitude do IC de conversao */
            calculated ic_sup_conv - calculated ic_inf_conv as ic_amplitude_conv,

            /* IC Wilson FPD - superior (base: convertidos) */
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

            /* IC Wilson FPD - inferior (base: convertidos) */
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

            /* amplitude do IC de FPD */
            case
                when calculated n_convertidos > 0
                    then calculated ic_sup_fpd - calculated ic_inf_fpd
                else .
            end as ic_amplitude_fpd

        from &ds_base
        group by &var_seg_comma
        having sum(&col_aprovados) > 0   /* equiv. ao "where FL_APROVADOS=1" do legado */
        ;
    quit;

    /* ========================================================
       BLOCO 4 - CLASSIFICACAO DAS CELULAS (identica ao legado)
         VALIDA   : n_aprovados >= MIN_N  E  n_maus >= MIN_EVENTOS
         INSTAVEL : n_aprovados >= MIN_N  MAS  n_maus < MIN_EVENTOS
         INVALIDA : n_aprovados < MIN_N
         VAZIA    : sem convertidos (nao da p/ estimar FPD)
       ======================================================== */
    data &ds_diagnostico;
        set WORK._CELULAS_RAW;

        min_n       = &MIN_N;
        min_eventos = &MIN_EVENTOS;

        length status_celula $8;
        if n_convertidos = 0 then
            status_celula = "VAZIA";
        else if n_aprovados < min_n then
            status_celula = "INVALIDA";
        else if n_maus < min_eventos then
            status_celula = "INSTAVEL";
        else
            status_celula = "VALIDA";

        fl_celula_valida = (status_celula = "VALIDA");

        label
            n_aprovados       = "N Aprovados na celula"
            n_convertidos     = "N Convertidos na celula"
            n_maus            = "N Maus na celula"
            taxa_conversao    = "Taxa de Conversao observada"
            taxa_fpd          = "Taxa de FPD observada"
            ic_inf_conv       = "IC Wilson inferior - Conversao"
            ic_sup_conv       = "IC Wilson superior - Conversao"
            ic_amplitude_conv = "Amplitude do IC - Conversao"
            ic_inf_fpd        = "IC Wilson inferior - FPD"
            ic_sup_fpd        = "IC Wilson superior - FPD"
            ic_amplitude_fpd  = "Amplitude do IC - FPD"
            status_celula     = "Status da celula (VALIDA/INSTAVEL/INVALIDA/VAZIA)"
            fl_celula_valida  = "Flag: celula valida para uso direto (1=sim)"
            min_n             = "Threshold MIN_N derivado estatisticamente"
            min_eventos       = "Threshold MIN_EVENTOS derivado estatisticamente";
    run;

    /* ========================================================
       BLOCO 5 - COBERTURA (celulas e volume aprovado por status)
       ======================================================== */
    proc sql noprint;
        select count(*) into :N_CELULAS   trimmed from &ds_diagnostico;
        select count(*) into :N_VALIDAS   trimmed from &ds_diagnostico where strip(status_celula)="VALIDA";
        select count(*) into :N_INSTAVEIS trimmed from &ds_diagnostico where strip(status_celula)="INSTAVEL";
        select count(*) into :N_INVALIDAS trimmed from &ds_diagnostico where strip(status_celula)="INVALIDA";
        select count(*) into :N_VAZIAS    trimmed from &ds_diagnostico where strip(status_celula)="VAZIA";

        select sum(n_aprovados) into :N_APR_VALIDAS   trimmed from &ds_diagnostico where strip(status_celula)="VALIDA";
        select sum(n_aprovados) into :N_APR_INSTAVEIS trimmed from &ds_diagnostico where strip(status_celula)="INSTAVEL";
        select sum(n_aprovados) into :N_APR_INVALIDAS trimmed from &ds_diagnostico where strip(status_celula)="INVALIDA";
        select sum(n_aprovados) into :N_APR_VAZIAS    trimmed from &ds_diagnostico where strip(status_celula)="VAZIA";
    quit;

    /* garante numeros (status pode nao ter nenhuma celula) */
    %if %superq(N_APR_VALIDAS)   = %then %let N_APR_VALIDAS   = 0;
    %if %superq(N_APR_INSTAVEIS) = %then %let N_APR_INSTAVEIS = 0;
    %if %superq(N_APR_INVALIDAS) = %then %let N_APR_INVALIDAS = 0;
    %if %superq(N_APR_VAZIAS)    = %then %let N_APR_VAZIAS    = 0;

    %if &relatorio = 1 %then %do;

        data WORK._REL_COBERTURA;
            length categoria $24 descricao $60 valor $100;

            categoria="Geral";      descricao="Variaveis de segmentacao";    valor="&var_seg";  output;
            categoria="Geral";      descricao="Base diagnosticada";          valor="&ds_base";  output;
            categoria="Geral";      descricao="Total de celulas geradas";    valor=strip(put(&N_CELULAS, comma12.)); output;

            categoria="Status";     descricao="Validas (celulas / aprovados)";
                valor=cats(put(&N_VALIDAS,comma10.)," / ",put(&N_APR_VALIDAS,comma14.));   output;
            categoria="Status";     descricao="Instaveis (celulas / aprovados)";
                valor=cats(put(&N_INSTAVEIS,comma10.)," / ",put(&N_APR_INSTAVEIS,comma14.)); output;
            categoria="Status";     descricao="Invalidas (celulas / aprovados)";
                valor=cats(put(&N_INVALIDAS,comma10.)," / ",put(&N_APR_INVALIDAS,comma14.)); output;
            categoria="Status";     descricao="Vazias (celulas / aprovados)";
                valor=cats(put(&N_VAZIAS,comma10.)," / ",put(&N_APR_VAZIAS,comma14.));     output;

            categoria="Cobertura";  descricao="Validas (% do volume aprovado)";
                valor=cats(put(&N_APR_VALIDAS/&N_TOTAL_APROV*100,8.2),"%");   output;
            categoria="Cobertura";  descricao="Instaveis (% do volume aprovado)";
                valor=cats(put(&N_APR_INSTAVEIS/&N_TOTAL_APROV*100,8.2),"%"); output;
            categoria="Cobertura";  descricao="Invalidas (% do volume aprovado)";
                valor=cats(put(&N_APR_INVALIDAS/&N_TOTAL_APROV*100,8.2),"%"); output;
            categoria="Cobertura";  descricao="Vazias (% do volume aprovado)";
                valor=cats(put(&N_APR_VAZIAS/&N_TOTAL_APROV*100,8.2),"%");    output;

            categoria="Globais";    descricao="Conversao global";            valor=cats(put(&P_CONV_GLOBAL*100,8.2),"%"); output;
            categoria="Globais";    descricao="FPD global";                  valor=cats(put(&P_FPD_GLOBAL*100,8.2),"%");  output;

            categoria="Thresholds"; descricao="MIN_N";
                valor=cats(&MIN_N," (alpha=",&alpha,", poder=",&poder,", margem=",&margem_relativa,")"); output;
            categoria="Thresholds"; descricao="MIN_EVENTOS";                 valor="&MIN_EVENTOS"; output;
            categoria="Thresholds"; descricao="Z_ALFA";                      valor="&Z_ALFA";      output;
        run;

        title "FASE 0 - RELATORIO DE COBERTURA";
        proc report data=WORK._REL_COBERTURA nowd;
            column categoria descricao valor;
            define categoria / group   "Bloco";
            define descricao / display "Metrica";
            define valor     / display "Valor";
        run;
        title;

        /* ----------------------------------------------------
           BLOCO 6 - RISCO POR DIMENSAO COLAPSAVEL
           A ultima var de VAR_SEG e a 1a a colapsar no fallback.
           Mostra, para cada valor dela, quanto do volume aprovado
           esta em celulas NAO-validas (que dependerao de fallback).
           E o sinal estrutural do problema do PAP (CONTEXTO sec.6).
           ---------------------------------------------------- */
        %let _WORST_DIM=; %let _WORST_PCT=0; %let _WORST_VOL=0;

        %if &_nvars_seg > 1 %then %do;

            proc sql;
                create table WORK._RISCO_DIM as
                select
                    &_dim_colaps as dim_valor length=64,
                    sum(n_aprovados) as vol_total,
                    sum(case when strip(status_celula)="VALIDA" then n_aprovados else 0 end) as vol_valida,
                    sum(case when strip(status_celula) ne "VALIDA" then n_aprovados else 0 end) as vol_fallback,
                    case when sum(n_aprovados) > 0
                         then sum(case when strip(status_celula) ne "VALIDA" then n_aprovados else 0 end)
                              / sum(n_aprovados)
                         else 0 end as pct_fallback
                from &ds_diagnostico
                group by &_dim_colaps
                order by vol_fallback desc;
            quit;

            title "FASE 0 - RISCO DE FALLBACK POR '&_dim_colaps'";
            title2 "Volume aprovado em celulas nao-validas (dependera de fallback hierarquico)";
            proc report data=WORK._RISCO_DIM nowd;
                column dim_valor vol_total vol_valida vol_fallback pct_fallback;
                define dim_valor    / display "&_dim_colaps";
                define vol_total    / display "Aprovados (total)"   format=comma14.;
                define vol_valida   / display "Em celula VALIDA"    format=comma14.;
                define vol_fallback / display "Em celula nao-valida" format=comma14.;
                define pct_fallback / display "% que usara fallback" format=percent8.1;
            run;
            title;

            /* pior valor da dimensao (maior volume em fallback) */
            proc sql noprint;
                select dim_valor, pct_fallback, vol_total
                  into :_WORST_DIM trimmed, :_WORST_PCT trimmed, :_WORST_VOL trimmed
                from WORK._RISCO_DIM
                order by vol_fallback desc;
            quit;

            %if %superq(_WORST_DIM) = %then %let _WORST_DIM=;
            %if %superq(_WORST_PCT) = %then %let _WORST_PCT=0;
            %if %superq(_WORST_VOL) = %then %let _WORST_VOL=0;

        %end;

        /* ----------------------------------------------------
           BLOCO 6b - EXPLICABILIDADE + RECOMENDACAO
           Texto interpretavel (o usuario traz de volta p/ a IA).
           ---------------------------------------------------- */
        data WORK._FASE0_RECOMENDACAO;
            length prioridade $10 topico $28 mensagem $400;

            pct_valida   = &N_APR_VALIDAS   / &N_TOTAL_APROV * 100;
            pct_instavel = &N_APR_INSTAVEIS / &N_TOTAL_APROV * 100;
            pct_invalida = &N_APR_INVALIDAS / &N_TOTAL_APROV * 100;
            pct_vazia    = &N_APR_VAZIAS    / &N_TOTAL_APROV * 100;

            /* 1) leitura da cobertura */
            topico = "Cobertura";
            if pct_valida >= &limite_cobertura then do;
                prioridade = "OK";
                mensagem = cats("Cobertura ALTA adequada: ", put(pct_valida,8.2),
                    "% do volume aprovado cai em celulas VALIDAS (>= &limite_cobertura.%). ",
                    "A base sustenta premissas diretas na maioria das celulas.");
            end;
            else if pct_valida >= (&limite_cobertura - 5) then do;
                prioridade = "ATENCAO";
                mensagem = cats("Cobertura LIMITROFE: ", put(pct_valida,8.2),
                    "% do volume aprovado em celulas VALIDAS (alvo >= &limite_cobertura.%). ",
                    "Boa parte vai depender de fallback hierarquico na Fase 1.");
            end;
            else do;
                prioridade = "ALERTA";
                mensagem = cats("Cobertura BAIXA: apenas ", put(pct_valida,8.2),
                    "% do volume aprovado em celulas VALIDAS. ",
                    "Muitas celulas dependerao de fallback/extrapolacao, elevando a incerteza.");
            end;
            output;

            /* 2) celulas sem evento de mau / sem convertidos */
            topico = "Eventos de mau";
            if pct_instavel + pct_vazia >= 5 then prioridade = "ATENCAO";
            else prioridade = "OK";
            mensagem = cats("INSTAVEIS=", put(pct_instavel,6.2), "% e VAZIAS=", put(pct_vazia,6.2),
                "% do volume aprovado. INSTAVEL tem volume mas poucos maus (< MIN_EVENTOS=&MIN_EVENTOS.); ",
                "VAZIA nao tem convertidos para estimar FPD.");
            output;

            /* 3) interpretacao dos thresholds derivados */
            topico = "Thresholds";
            prioridade = "INFO";
            mensagem = cats("MIN_N=&MIN_N. e MIN_EVENTOS=&MIN_EVENTOS. derivados de ",
                "alpha=&alpha., poder=&poder., margem=&margem_relativa. ",
                "(conv global=", put(&P_CONV_GLOBAL*100,6.2), "%, FPD global=", put(&P_FPD_GLOBAL*100,6.2),
                "%). Para AUMENTAR cobertura: suba MARGEM_RELATIVA, suba ALPHA ou reduza PODER ",
                "(thresholds menores). Para premissas mais robustas: faca o inverso.");
            output;

            /* 4) alerta de risco na dimensao colapsavel (ex.: PAP) */
            %if &_nvars_seg > 1 %then %do;
                topico = "Risco &_dim_colaps";
                _wpct = &_WORST_PCT;          /* fracao 0-1 */
                _wvol = &_WORST_VOL;
                _wshare_base = _wvol / &N_TOTAL_APROV;
                if _wpct >= &limite_fallback and _wshare_base >= 0.01 then do;
                    prioridade = "ALERTA";
                    mensagem = cats("O valor '", strip("&_WORST_DIM"), "' de &_dim_colaps. concentra risco: ",
                        put(_wpct*100,6.1), "% do seu volume aprovado (", put(_wvol,comma14.),
                        " aprovados) esta em celulas NAO-validas e herdara premissa colapsada na Fase 1. ",
                        "Padrao do problema do PAP / grupo MEDIA - ver CONTEXTO.md secao 6 antes de usar nas simulacoes.");
                end;
                else do;
                    prioridade = "OK";
                    mensagem = cats("Nenhum valor de &_dim_colaps. concentra risco relevante de fallback ",
                        "(pior caso: '", strip("&_WORST_DIM"), "' com ", put(_wpct*100,6.1),
                        "% do volume em celulas nao-validas).");
                end;
                output;
                drop _wpct _wvol _wshare_base;
            %end;

            /* 5) proxima acao sugerida */
            topico = "Proxima acao";
            if pct_valida >= &limite_cobertura then do;
                prioridade = "OK";
                mensagem = "Cobertura suficiente: prossiga para a Fase 1 (m03_tabela_referencia) com os mesmos parametros.";
            end;
            else do;
                prioridade = "ATENCAO";
                mensagem = "Reavalie MARGEM_RELATIVA/ALPHA/PODER (ou a segmentacao) e rode a Fase 0 de novo antes da Fase 1, OU prossiga ciente de que o fallback/extrapolacao cobrira as celulas fracas.";
            end;
            output;

            keep prioridade topico mensagem;
        run;

        title "FASE 0 - EXPLICABILIDADE E RECOMENDACAO";
        proc report data=WORK._FASE0_RECOMENDACAO nowd;
            column prioridade topico mensagem;
            define prioridade / display "Prioridade" width=10;
            define topico     / display "Topico"     width=28;
            define mensagem   / display "Leitura / recomendacao" flow width=120;
        run;
        title;

    %end;  /* relatorio */

    /* ========================================================
       BLOCO 7 - DATASET PERMANENTE DE THRESHOLDS (auditoria)
       ======================================================== */
    %if &gerar_thresholds = 1 %then %do;
        data &lib_out..FASE0_THRESHOLDS;
            dt_execucao      = datetime();
            variaveis_seg    = "&var_seg";
            base_diagnostico = "&ds_base";
            alpha            = &alpha;
            poder            = &poder;
            margem_relativa  = &margem_relativa;
            p_conversao_glob = &P_CONV_GLOBAL;
            p_fpd_global     = &P_FPD_GLOBAL;
            n_total_aprov    = &N_TOTAL_APROV;
            n_total_conv     = &N_TOTAL_CONV;
            n_total_mau      = &N_TOTAL_MAU;
            min_n_derivado   = &MIN_N;
            min_eventos_der  = &MIN_EVENTOS;
            z_alfa           = &Z_ALFA;
            n_celulas_total  = &N_CELULAS;
            n_celulas_valid  = &N_VALIDAS;
            n_celulas_inst   = &N_INSTAVEIS;
            n_celulas_inv    = &N_INVALIDAS;
            n_celulas_vazia  = &N_VAZIAS;
            format dt_execucao datetime20.;
            label
                dt_execucao      = "Data/hora da execucao"
                variaveis_seg    = "Variaveis de segmentacao usadas"
                base_diagnostico = "Base diagnosticada"
                alpha            = "Nivel de significancia (alpha)"
                poder            = "Poder do teste"
                margem_relativa  = "Margem de erro relativa aceitavel"
                p_conversao_glob = "Taxa de conversao global da base"
                p_fpd_global     = "Taxa de FPD global da base"
                n_total_aprov    = "Total de aprovados na base"
                n_total_conv     = "Total de convertidos na base"
                n_total_mau      = "Total de maus na base"
                min_n_derivado   = "MIN_N derivado estatisticamente"
                min_eventos_der  = "MIN_EVENTOS derivado estatisticamente"
                z_alfa           = "Z critico (alpha)"
                n_celulas_total  = "Total de celulas geradas"
                n_celulas_valid  = "Celulas validas"
                n_celulas_inst   = "Celulas instaveis"
                n_celulas_inv    = "Celulas invalidas"
                n_celulas_vazia  = "Celulas vazias";
        run;
    %end;

    /* ========================================================
       BLOCO 8 - LIMPEZA
       ======================================================== */
    proc datasets library=work nolist;
        delete _CELULAS_RAW
        %if &relatorio = 1 %then %do; _REL_COBERTURA _FASE0_RECOMENDACAO
            %if &_nvars_seg > 1 %then %do; _RISCO_DIM %end;
        %end;
        ;
    quit;

    %put NOTE: ===== m02_diagnostico concluido =====;
    %put NOTE: Diagnostico  : &ds_diagnostico;
    %put NOTE: MIN_N=&MIN_N | MIN_EVENTOS=&MIN_EVENTOS | Z_ALFA=&Z_ALFA;
    %put NOTE: P_CONV_GLOBAL=&P_CONV_GLOBAL | P_FPD_GLOBAL=&P_FPD_GLOBAL;

%mend diagnostico;
