/* ============================================================
   m04_aplicar_inferencia.sas  -  E4: Aplicar inferencia (Fase 2)
   ------------------------------------------------------------
   OBJETIVO
     Macro UNICA da Fase 2 (hoje duplicada em "1 - Inferiencia.sas"
     l. 1412-1935 e "2 - Aplicar Inferencia.sas" l. 283-827).
     Enriquece uma base com as premissas de conversao e FPD vindas
     da tabela de referencia (Fase 1), via join hierarquico em
     cascata. Funciona em ANALITICA e SUMARIZADA (motor unificado,
     wiki pag. 5): a unica diferenca e o GRAO da linha, nao a
     matematica.

     A LOGICA DO JOIN E IDENTICA ao legado (join_hierarquico,
     cascata por nivel, LEFT JOIN, fallback do mais granular ao
     mais colapsado). So a parametrizacao muda (nomes vindos do
     master) e o calculo dos fisicos passa a usar as contagens
     do motor (n_aprovados / n_propostas).

   ------------------------------------------------------------
   COMO O FISICO E CALCULADO (wiki pag. 5 - Motor Unificado)

       fisico_altas = peso * taxa_conversao_ref
       fisico_maus  = peso * taxa_conversao_ref * taxa_fpd_ref

     onde "peso" = coluna de contagem que pondera a celula:
       - ANALITICA  : peso = n_aprovados (0/1) -> fisico por aprovado
       - SUMARIZADA : peso = n_aprovados (contagem) -> fisico agregado

     Em ANALITICA, alem dos fisicos, mantem-se
       prob_mau = prob_conversao * prob_fpd
     (paridade com o legado; vale SO na analitica - regra de ouro 4).

   PESO_FISICO (decisao de negocio - ver PENDENCIAS no commit):
     Default = n_aprovados (DoD E4 / Motor Unificado / regra de
     ouro 3 "considerar apenas FL_APROVADOS=1"). O legado do
     "2 - Aplicar" somava prob_conversao sobre TODAS as propostas
     (incl. reprovados) -> fisico sobre n_propostas, que e a
     semantica de "simular abertura para reprovados" (excecao da
     regra 3). Para reproduzir exatamente o CSV do legado, basta
     chamar com peso_fisico=n_propostas.

   ------------------------------------------------------------
   REGRAS DE OURO RESPEITADAS (wiki pag. 6)
     1. FPD = SUM(fisico_maus)/SUM(fisico_altas) - NUNCA
        SUM(prob_mau)/count(aprovados). (usado no backtest)
     2. NUNCA filtra FL_ALTAS=1 no grao granular - o peso
        (n_aprovados) distribui a probabilidade entre todos os
        aprovados.
     3. Backtest considera apenas a populacao aprovada (o peso
        n_aprovados zera reprovados automaticamente).
     4. prob_mau = prob_conv * prob_fpd SO na analitica; na
        sumarizada usa-se fisico_altas/fisico_maus (este m04 nao
        cria prob_mau em SUMARIZADA).

   ARMADILHAS SAS RESPEITADAS
     - %DO de geracao dinamica de SQL fica DENTRO de %macro
       (join_hierarquico).
     - Join hierarquico usa TODAS as vars do nivel.
     - ICs lidos SEM sufixo _ref (ic_sup_conv, ...) da Fase 1.
     - Fecha todos os blocos (quit;/run;).

   ------------------------------------------------------------
   PARAMETROS (todos vem do 00_MASTER.sas - nada cravado aqui)

     ds_novo          base a enriquecer (do m01). REFERENCIA =
                      base historica (backtest); INFERENCIA =
                      base nova a simular.
     ds_tabela_ref    tabela de referencia da Fase 1 (entrada)
                      (default &DS_TABELA_REF, ex.: INF.TABELA_REF_MV)
     ds_output_inf    dataset de saida enriquecido
                      (default &DS_OUTPUT_INF, ex.: INF.LOG_05_06_MV_INF)
     var_seg          vars de segmentacao (default &VAR_SEG); ordem
                      importa (1a = score = ancora)
     var_score_faixa  var de score/faixa (default &VAR_SCORE_FAIXA)
     modo_base        ANALITICA | SUMARIZADA (default &MODO_BASE)
     fl_manter_orig   1 = mantem todas as colunas originais;
                      0 = mantem so VAR_SEG + premissas (default &FL_MANTER_ORIG)
     col_aprovados    coluna de contagem de aprovados   (default n_aprovados)
     col_propostas    coluna de contagem de propostas   (default n_propostas)
     col_convertidos  coluna de contagem de convertidos (default n_convertidos)
     col_maus         coluna de contagem de maus        (default n_maus)
     peso_fisico      coluna que pondera o fisico (default &col_aprovados;
                      use n_propostas p/ reproduzir o legado)
     backtest         AUTO | SIM | NAO (default AUTO: roda se
                      OBJETIVO=REFERENCIA e a base tiver os reais)
     relatorio        1 = emite relatorios HTML (cobertura + backtest)
     ds_diag_score    dataset opcional de diagnostico por score
                      (vazio = nao gera)

   PRE-REQUISITO: Fase 1 (m03_tabela_referencia) gerou &ds_tabela_ref.
     Macro vars uteis da Fase 1 (N_NIVEIS) sao re-derivadas aqui se
     ausentes (a Fase 2 nao depende delas; deriva de var_seg).

   ENTRADAS  : &ds_novo + &ds_tabela_ref.
   SAIDAS    : &ds_output_inf com prob_conversao, prob_fpd,
               prob_mau (analitica), fisico_altas, fisico_maus,
               nivel_premissa, vars_premissa, confiabilidade_premissa,
               fl_premissa_extrapolada, fl_sem_premissa,
               n_convertidos_referencia, n_maus_referencia, ICs.
   DEPENDE DE: E0 (m00_setup), E1 (m01_montar_base), E3 (m03).

   ------------------------------------------------------------
   EXEMPLO DE USO (no 00_MASTER.sas):

     %include "macros/m04_aplicar_inferencia.sas";
     %aplicar_inferencia(
        ds_novo        = INF.LOG_05_06_MV,
        ds_tabela_ref  = INF.TABELA_REF_MV,
        ds_output_inf  = INF.LOG_05_06_MV_INF,
        var_seg        = SCORE_HVI3 IDENTIFICA_GRUPO_MODELO CANAL_PCO_AJUSTADO,
        modo_base      = SUMARIZADA,
        fl_manter_orig = 1
     );
   ============================================================ */


/* ============================================================
   JOIN HIERARQUICO EM CASCATA (portado VERBATIM do legado)
   Le os GLOBAIS DS_NOVO_F2 / DS_TABELA_REF_F2 / VARSEG_F2,
   setados pela driver. Toda a geracao com %do fica DENTRO desta
   macro (armadilha do %DO em open code). Produz WORK._JOIN_ATUAL
   com as colunas internas _conv_n1 ... _icifpd_n1.
   ============================================================ */
%macro join_hierarquico;

    %local N_VARS j var_j nivel vars_nivel_k vars_k_comma n_vars_k
           JOIN_COND_1 JOIN_COND_K;

    %let N_VARS = %sysfunc(countw(&VARSEG_F2., %str( )));

    /* --------------------------------------------------------
       PASSO 1 - Join no nivel mais granular (todas as vars)
    -------------------------------------------------------- */
    %let JOIN_COND_1 = ;
    %do j = 1 %to &N_VARS.;
        %let var_j = %scan(&VARSEG_F2., &j., %str( ));
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
        from &DS_NOVO_F2. a
        left join WORK._REF_JOIN b
            on &JOIN_COND_1.;
    quit;

    /* --------------------------------------------------------
       PASSO 2 - Para linhas sem match no nivel 1, tenta os
       niveis colapsados sequencialmente (direita -> esquerda)
    -------------------------------------------------------- */
    %if &N_VARS. > 1 %then %do;

        data WORK._JOIN_ATUAL;
            set WORK._JOIN_NIVEL1;
        run;

        %do nivel = 2 %to &N_VARS.;

            /* lista de vars deste nivel colapsado (mantem o score) */
            %let vars_nivel_k = ;
            %do j = 1 %to %eval(&N_VARS. - &nivel. + 1);
                %let vars_nivel_k = &vars_nivel_k. %scan(&VARSEG_F2., &j., %str( ));
            %end;
            %let vars_nivel_k = %sysfunc(strip(&vars_nivel_k.));
            %let vars_k_comma = %sysfunc(tranwrd(&vars_nivel_k., %str( ), %str(,)));

            /* condicao de join deste nivel (TODAS as vars do nivel) */
            %let n_vars_k = %sysfunc(countw(&vars_nivel_k., %str( )));
            %let JOIN_COND_K = ;
            %do j = 1 %to &n_vars_k.;
                %let var_j = %scan(&vars_nivel_k., &j., %str( ));
                %if &j. = 1 %then
                    %let JOIN_COND_K = b.&var_j. = a.&var_j.;
                %else
                    %let JOIN_COND_K = &JOIN_COND_K. and b.&var_j. = a.&var_j.;
            %end;

            proc sql;
                /* agrega a referencia neste nivel colapsado */
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
                from &DS_TABELA_REF_F2.
                group by &vars_k_comma.
                having nivel_usado = min(nivel_usado);

                /* preenche SO quem ainda nao tem premissa */
                create table WORK._JOIN_NIVEL_K as
                select
                    a.*,
                    case when a._conv_n1 is null
                         then b.taxa_conversao_ref else a._conv_n1   end as _conv_n1,
                    case when a._fpd_n1  is null
                         then b.taxa_fpd_ref       else a._fpd_n1    end as _fpd_n1,
                    case when a._nivel_n1 is null
                         then b.nivel_usado        else a._nivel_n1  end as _nivel_n1,
                    case when a._vars_n1 is null
                         then b.vars_nivel_usado   else a._vars_n1   end as _vars_n1,
                    case when a._conf_n1 is null
                         then b.confiabilidade     else a._conf_n1   end as _conf_n1,
                    case when a._extrap_n1 is null
                         then b.fl_extrapolado     else a._extrap_n1 end as _extrap_n1,
                    case when a._nconv_n1 is null
                         then b.n_convertidos_ref  else a._nconv_n1  end as _nconv_n1,
                    case when a._nmaus_n1 is null
                         then b.n_maus_ref         else a._nmaus_n1  end as _nmaus_n1,
                    case when a._icsconv_n1 is null
                         then b.ic_sup_conv        else a._icsconv_n1 end as _icsconv_n1,
                    case when a._icicconv_n1 is null
                         then b.ic_inf_conv        else a._icicconv_n1 end as _icicconv_n1,
                    case when a._icsfpd_n1 is null
                         then b.ic_sup_fpd         else a._icsfpd_n1  end as _icsfpd_n1,
                    case when a._icifpd_n1 is null
                         then b.ic_inf_fpd         else a._icifpd_n1  end as _icifpd_n1
                from WORK._JOIN_ATUAL a
                left join WORK._REF_NIVEL_K b
                    on &JOIN_COND_K.
                    and a._conv_n1 is null;
            quit;

            data WORK._JOIN_ATUAL;
                set WORK._JOIN_NIVEL_K;
            run;

            proc datasets library=work nolist;
                delete _REF_NIVEL_K _JOIN_NIVEL_K;
            quit;

        %end; /* fim loop de niveis colapsados */

    %end; /* fim if N_VARS > 1 */
    %else %do;
        data WORK._JOIN_ATUAL;
            set WORK._JOIN_NIVEL1;
        run;
    %end;

    %put NOTE: === join_hierarquico concluido: WORK._JOIN_ATUAL ===;

%mend join_hierarquico;


/* ============================================================
   DRIVER - %aplicar_inferencia
   ============================================================ */
%macro aplicar_inferencia(
    ds_novo=,
    ds_tabela_ref=&DS_TABELA_REF,
    ds_output_inf=&DS_OUTPUT_INF,
    var_seg=&VAR_SEG,
    var_score_faixa=&VAR_SCORE_FAIXA,
    modo_base=&MODO_BASE,
    fl_manter_orig=&FL_MANTER_ORIG,
    col_aprovados=n_aprovados,
    col_propostas=n_propostas,
    col_convertidos=n_convertidos,
    col_maus=n_maus,
    peso_fisico=,
    backtest=AUTO,
    relatorio=1,
    ds_diag_score=
);

    options validvarname=v7;

    %local _modo _lib _mem _tem_real _roda_bt
           _napr _ialt _imau _ralt _rmau
           _conv_inf _conv_real _fpd_inf _fpd_real
           _dev_conv _dev_fpd
           N_TOTAL N_VOL N_ALTA N_MEDIA N_BAIXA N_EXTRAP N_SEM VOL_SEM;

    /* defaults dependentes */
    %if %length(&fl_manter_orig) = 0 %then %let fl_manter_orig = 1;
    %if %length(&peso_fisico)     = 0 %then %let peso_fisico = &col_aprovados;
    %let _modo = %upcase(&modo_base);

    /* ---------- validacoes ---------- */
    %if %length(&ds_novo) = 0 %then %do;
        %put ERROR: m04_aplicar_inferencia - parametro ds_novo obrigatorio.;
        %abort cancel;
    %end;
    %if %sysfunc(exist(&ds_tabela_ref.)) = 0 %then %do;
        %put ERROR: Tabela de referencia &ds_tabela_ref nao encontrada. Rode a Fase 1 (m03) antes.;
        %abort cancel;
    %end;
    %if %sysfunc(exist(&ds_novo.)) = 0 %then %do;
        %put ERROR: Base &ds_novo nao encontrada (rode o m01 antes).;
        %abort cancel;
    %end;

    /* contexto p/ a macro auxiliar join_hierarquico (GLOBAIS) */
    %global DS_NOVO_F2 DS_TABELA_REF_F2 VARSEG_F2 VARSEG_F2_COMMA;
    %let DS_NOVO_F2       = &ds_novo;
    %let DS_TABELA_REF_F2 = &ds_tabela_ref;
    %let VARSEG_F2        = &var_seg;
    %let VARSEG_F2_COMMA  = %sysfunc(tranwrd(%sysfunc(strip(&var_seg)), %str( ), %str(,)));

    %put NOTE: ===== m04_aplicar_inferencia: base=&ds_novo | modo=&_modo | peso=&peso_fisico =====;
    %put NOTE: === Tabela de referencia: &ds_tabela_ref ===;
    %put NOTE: === Variaveis de join   : &var_seg ===;

    /* ---------- a base tem os reais? (p/ backtest) ---------- */
    %if %index(&ds_novo, .) = 0 %then %do;
        %let _lib = WORK; %let _mem = &ds_novo;
    %end;
    %else %do;
        %let _lib = %scan(&ds_novo, 1, .); %let _mem = %scan(&ds_novo, 2, .);
    %end;
    proc sql noprint;
        select count(*) into :_tem_real trimmed
        from dictionary.columns
        where libname = upcase("&_lib") and memname = upcase("&_mem")
          and upcase(name) = upcase("&col_convertidos");
    quit;

    %let _roda_bt = 0;
    %if %upcase(&backtest) = SIM %then %let _roda_bt = &_tem_real;
    %else %if %upcase(&backtest) = AUTO %then %do;
        /* AUTO: roda o backtest sempre que a base tiver os reais observados
           (REFERENCIA/COMPLETO tem; a base nova do INFERENCIA nao tem). */
        %if &_tem_real > 0 %then %let _roda_bt = 1;
    %end;

    /* ========================================================
       BLOCO 1 - PREPARA A TABELA DE REFERENCIA P/ O JOIN
       Uma linha por combinacao de segmentacao (a de maior
       granularidade). Identico ao legado.
       ======================================================== */
    proc sql;
        create table WORK._REF_JOIN as
        select
            &VARSEG_F2_COMMA.,
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
        from &ds_tabela_ref.
        group by &VARSEG_F2_COMMA.
        having nivel_usado = min(nivel_usado);
    quit;

    /* ========================================================
       BLOCO 2 - JOIN HIERARQUICO EM CASCATA
       ======================================================== */
    %join_hierarquico;

    /* ========================================================
       BLOCO 3 - CONSOLIDACAO + FISICOS + RENOMEACAO FINAL
       prob_mau so na ANALITICA (regra de ouro 4); fisicos nos
       dois modos (peso * conv [* fpd]).
       ======================================================== */
    data &ds_output_inf.;
        set WORK._JOIN_ATUAL;

        /* fisicos do motor unificado (ponderados pelo peso) */
        fisico_altas = &peso_fisico. * _conv_n1;
        fisico_maus  = &peso_fisico. * _conv_n1 * _fpd_n1;

        %if &_modo. = ANALITICA %then %do;
            /* paridade com o legado: vale SO na analitica */
            prob_mau = _conv_n1 * _fpd_n1;
        %end;

        /* flag de alerta: celula/proposta sem premissa em nenhum nivel */
        fl_sem_premissa = (_conv_n1 = .);

        dt_aplicacao = datetime();
        format dt_aplicacao datetime20.;

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

        label
            prob_conversao            = "Probabilidade de conversao (premissa)"
            prob_fpd                  = "Probabilidade de FPD (premissa)"
            %if &_modo. = ANALITICA %then %do;
            prob_mau                  = "Prob. conjunta conv*fpd (so analitica)"
            %end;
            fisico_altas              = "Fisico de altas inferidas (peso*conv)"
            fisico_maus               = "Fisico de maus inferidos (peso*conv*fpd)"
            nivel_premissa            = "Nivel hierarquico da premissa usada"
            vars_premissa             = "Variaveis usadas na premissa"
            confiabilidade_premissa   = "Confiabilidade (ALTA/MEDIA/BAIXA/EXTRAPOLADO)"
            fl_premissa_extrapolada   = "Flag: premissa extrapolada (1=sim)"
            fl_sem_premissa           = "Flag: sem premissa disponivel (revisao manual)"
            n_convertidos_referencia  = "N convertidos que embasam a premissa"
            n_maus_referencia         = "N maus que embasam a premissa"
            ic_sup_conversao          = "IC Wilson superior - conversao"
            ic_inf_conversao          = "IC Wilson inferior - conversao"
            ic_sup_fpd                = "IC Wilson superior - FPD"
            ic_inf_fpd                = "IC Wilson inferior - FPD"
            dt_aplicacao              = "Data/hora de aplicacao das premissas";

        %if &fl_manter_orig. = 0 %then %do;
            keep &VARSEG_F2.
                 &col_propostas &col_aprovados
                 /* mantem os reais p/ o backtest, se a base os tiver */
                 %if &_tem_real. > 0 %then %do; &col_convertidos &col_maus %end;
                 prob_conversao prob_fpd
                 %if &_modo. = ANALITICA %then %do; prob_mau %end;
                 fisico_altas fisico_maus
                 nivel_premissa vars_premissa confiabilidade_premissa
                 fl_premissa_extrapolada fl_sem_premissa
                 n_convertidos_referencia n_maus_referencia
                 ic_sup_conversao ic_inf_conversao
                 ic_sup_fpd ic_inf_fpd
                 dt_aplicacao;
        %end;
    run;

    /* ========================================================
       BLOCO 4 - RELATORIO HTML DE COBERTURA DAS PREMISSAS
       Cobertura por confiabilidade em CELULAS e em VOLUME
       (n_propostas), valido nos dois modos.
       ======================================================== */
    %if &relatorio. = 1 %then %do;

        proc sql noprint;
            select count(*), sum(&col_propostas)
              into :N_TOTAL trimmed, :N_VOL trimmed
              from &ds_output_inf.;
            select sum(&col_propostas) into :N_ALTA   trimmed from &ds_output_inf. where strip(confiabilidade_premissa)="ALTA";
            select sum(&col_propostas) into :N_MEDIA  trimmed from &ds_output_inf. where strip(confiabilidade_premissa)="MEDIA";
            select sum(&col_propostas) into :N_BAIXA  trimmed from &ds_output_inf. where strip(confiabilidade_premissa)="BAIXA";
            select sum(&col_propostas) into :N_EXTRAP trimmed from &ds_output_inf. where strip(confiabilidade_premissa)="EXTRAPOLADO";
            select count(*), sum(&col_propostas)
              into :N_SEM trimmed, :VOL_SEM trimmed
              from &ds_output_inf. where fl_sem_premissa = 1;
        quit;

        %if %superq(N_ALTA)=  %then %let N_ALTA   = 0;
        %if %superq(N_MEDIA)= %then %let N_MEDIA  = 0;
        %if %superq(N_BAIXA)= %then %let N_BAIXA  = 0;
        %if %superq(N_EXTRAP)=%then %let N_EXTRAP = 0;
        %if %superq(N_SEM)=   %then %let N_SEM    = 0;
        %if %superq(VOL_SEM)= %then %let VOL_SEM  = 0;

        data WORK._REL_FASE2_COB;
            length bloco $24 descricao $52 valor $80;
            total_vol = &N_VOL.;

            bloco="Geral"; descricao="Base enriquecida";            valor="&ds_novo";                                      output;
            bloco="Geral"; descricao="Modo";                        valor="&_modo";                                       output;
            bloco="Geral"; descricao="Celulas/linhas na saida";     valor=strip(put(&N_TOTAL., comma20.));                output;
            bloco="Geral"; descricao="Volume (n_propostas)";        valor=strip(put(&N_VOL., comma20.));                  output;

            bloco="Cobertura (volume)"; descricao="ALTA (nivel 1)";
                valor=cats(strip(put(&N_ALTA., comma20.))," (",strip(put(&N_ALTA./total_vol,percent8.1)),")");           output;
            bloco="Cobertura (volume)"; descricao="MEDIA (colapsado)";
                valor=cats(strip(put(&N_MEDIA., comma20.))," (",strip(put(&N_MEDIA./total_vol,percent8.1)),")");         output;
            bloco="Cobertura (volume)"; descricao="BAIXA (so score)";
                valor=cats(strip(put(&N_BAIXA., comma20.))," (",strip(put(&N_BAIXA./total_vol,percent8.1)),")");         output;
            bloco="Cobertura (volume)"; descricao="EXTRAPOLADO";
                valor=cats(strip(put(&N_EXTRAP., comma20.))," (",strip(put(&N_EXTRAP./total_vol,percent8.1)),")");       output;
            bloco="Cobertura (volume)"; descricao="SEM PREMISSA";
                valor=cats(strip(put(&VOL_SEM., comma20.))," (",strip(put(&VOL_SEM./total_vol,percent8.1)),") - REVISAR"); output;

            bloco="Output"; descricao="Dataset de saida";           valor="&ds_output_inf";                               output;
            %if &N_SEM. > 0 %then %do;
            bloco="Atencao"; descricao="Celulas sem premissa";      valor=cats(strip(put(&N_SEM., comma20.))," - filtrar fl_sem_premissa=1"); output;
            %end;
            drop total_vol;
        run;

        title "FASE 2 - COBERTURA DAS PREMISSAS APLICADAS";
        proc report data=WORK._REL_FASE2_COB nowd;
            column bloco descricao valor;
            define bloco     / group   "Secao";
            define descricao / display "Descricao";
            define valor     / display "Valor";
        run;
        title;

    %end;

    /* ========================================================
       BLOCO 5 - BACKTEST (real x inferido) - so REFERENCIA
       Respeita as regras de ouro:
         inferido_altas = SUM(n_aprovados * prob_conversao)
         inferido_maus  = SUM(n_aprovados * prob_conversao * prob_fpd)
         FPD            = SUM(inferido_maus)/SUM(inferido_altas)
       Comparado contra os reais SUM(n_convertidos)/SUM(n_maus),
       sobre a MESMA populacao (celulas com premissa).
       ======================================================== */
    %if &_roda_bt. = 1 %then %do;

        proc sql noprint;
            select
                sum(&col_aprovados.),
                sum(&col_aprovados. * prob_conversao),
                sum(&col_aprovados. * prob_conversao * prob_fpd),
                sum(&col_convertidos.),
                sum(&col_maus.)
              into :_napr trimmed, :_ialt trimmed, :_imau trimmed,
                   :_ralt trimmed, :_rmau trimmed
              from &ds_output_inf.
              where fl_sem_premissa = 0;
        quit;

        /* guardas: evita "napr = ;" se algum sum vier vazio (sem linhas) */
        %if %superq(_napr)= %then %let _napr = .;
        %if %superq(_ialt)= %then %let _ialt = .;
        %if %superq(_imau)= %then %let _imau = .;
        %if %superq(_ralt)= %then %let _ralt = .;
        %if %superq(_rmau)= %then %let _rmau = .;

        data WORK._REL_FASE2_BT;
            length bloco $24 descricao $52 valor $80;

            napr = &_napr.;  ialt = &_ialt.;  imau = &_imau.;
            ralt = &_ralt.;  rmau = &_rmau.;

            conv_inf = ialt / napr;          conv_real = ralt / napr;
            fpd_inf  = imau / ialt;          fpd_real  = rmau / ralt;
            dev_conv = conv_inf - conv_real; dev_fpd   = fpd_inf - fpd_real;

            bloco="Populacao";   descricao="Aprovados no backtest";      valor=strip(put(napr, comma20.)); output;

            bloco="Conversao";   descricao="Altas reais (n_convertidos)"; valor=strip(put(ralt, comma20.)); output;
            bloco="Conversao";   descricao="Altas inferidas (fisico)";    valor=strip(put(ialt, comma20.1)); output;
            bloco="Conversao";   descricao="Taxa conversao real";         valor=strip(put(conv_real, percent8.2)); output;
            bloco="Conversao";   descricao="Taxa conversao inferida";     valor=strip(put(conv_inf,  percent8.2)); output;
            bloco="Conversao";   descricao="Desvio (inf - real) p.p.";    valor=strip(put(dev_conv*100, 8.2)); output;

            bloco="FPD";         descricao="Maus reais (n_maus)";         valor=strip(put(rmau, comma20.)); output;
            bloco="FPD";         descricao="Maus inferidos (fisico)";     valor=strip(put(imau, comma20.1)); output;
            bloco="FPD";         descricao="FPD real";                    valor=strip(put(fpd_real, percent8.2)); output;
            bloco="FPD";         descricao="FPD inferida";                valor=strip(put(fpd_inf,  percent8.2)); output;
            bloco="FPD";         descricao="Desvio (inf - real) p.p.";    valor=strip(put(dev_fpd*100, 8.2)); output;

            bloco="Regras ouro"; descricao="FPD = SUM(maus_inf)/SUM(altas_inf)"; valor="OK - nao usa count(aprovados)"; output;
            bloco="Regras ouro"; descricao="Ponderado por n_aprovados";          valor="OK - nao filtra FL_ALTAS";      output;

            keep bloco descricao valor;
        run;

        title "FASE 2 - BACKTEST (REAL x INFERIDO, sobre aprovados)";
        proc report data=WORK._REL_FASE2_BT nowd;
            column bloco descricao valor;
            define bloco     / group   "Secao";
            define descricao / display "Metrica";
            define valor     / display "Valor";
        run;
        title;

        %put NOTE: === Backtest: conv_real=&_ralt vs conv_inf=&_ialt | fpd reais=&_rmau vs inf=&_imau ===;

    %end;
    %else %do;
        %put NOTE: === Backtest nao executado (backtest=&backtest, OBJETIVO=%superq(OBJETIVO), tem_real=&_tem_real) ===;
    %end;

    /* ========================================================
       BLOCO 6 - DIAGNOSTICO POR SCORE (opcional)
       Visao agregada por faixa de score (validacao visual).
       NUNCA multiplica somas entre si: usa os fisicos ja prontos.
       ======================================================== */
    %if %length(&ds_diag_score) %then %do;
        proc sql;
            create table &ds_diag_score. as
            select
                &var_score_faixa.,
                count(*)                     as n_celulas,
                sum(&col_propostas.)         as n_propostas,
                sum(&col_aprovados.)         as n_aprovados,
                mean(prob_conversao)         as conv_media,
                mean(prob_fpd)               as fpd_media,
                sum(fisico_altas)            as altas_inferidas,
                sum(fisico_maus)             as maus_inferidos,
                min(confiabilidade_premissa) as confiabilidade_min,
                sum(fl_premissa_extrapolada) as n_extrapoladas,
                sum(fl_sem_premissa)         as n_sem_premissa
            from &ds_output_inf.
            group by &var_score_faixa.
            order by &var_score_faixa.;
        quit;
        %put NOTE: === Diagnostico por score salvo em &ds_diag_score ===;
    %end;

    /* ---------- limpeza ---------- */
    proc datasets library=work nolist;
        delete _REF_JOIN _JOIN_NIVEL1 _JOIN_ATUAL
               %if &relatorio. = 1 %then %do; _REL_FASE2_COB %end;
               %if &_roda_bt.   = 1 %then %do; _REL_FASE2_BT %end;
        ;
    quit;

    %put NOTE: ===== m04_aplicar_inferencia concluido -> &ds_output_inf =====;

%mend aplicar_inferencia;
