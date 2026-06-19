/* ============================================================
   m00_setup.sas  -  E0: Setup e convencoes
   ------------------------------------------------------------
   OBJETIVO
     Estabelecer o terreno comum para o motor de inferencia de
     negados, de forma agnostica as bases:
       - LIBNAMEs parametrizaveis (nada de caminho cravado na logica);
       - options validvarname=v7 (necessario para o colunamento do m01);
       - ODS HTML ligado (saidas legiveis em vez de PUT no log);
       - validacao das macro vars globais OBJETIVO e MODO_BASE,
         abortando com mensagem clara se invalidas.

   Fonte da logica (libnames/options): cabecalho de
     "0 - Gerar base para referencia da Inferencia.sas",
     "1 - Inferiencia.sas" e "2 - Aplicar Inferencia.sas".

   ------------------------------------------------------------
   INVENTARIO DE PARAMETROS (ver wiki pag. 4 - Inventario de Parametros)

   Globais que o 00_MASTER.sas define ANTES de chamar %setup:
     OBJETIVO         REFERENCIA | INFERENCIA | COMPLETO
     MODO_BASE        ANALITICA  | SUMARIZADA
     VAR_SEG          vars de segmentacao; a ordem importa
                      (1a = score = ancora). Ex.:
                      SCORE_HVI3 IDENTIFICA_GRUPO_MODELO CANAL_PCO_AJUSTADO
     VAR_SCORE_FAIXA  var de score/faixa (deve ser a 1a de VAR_SEG)
     DIMS_SAIDA       dimensoes extras mantidas no grao sumarizado/CSV

   Parametros do proprio %setup (libnames + ODS):
     lib_art, lib_inf, lib_oned, lib_log_novo, lib_julia
     libs_extra   pares "NOME=caminho" adicionais, separados por |
     ods_saida    pasta para o ODS HTML (vazio = destino padrao do EG)
     ods_arquivo  nome do arquivo HTML (default inferencia_relatorios.html)
     validar      1 = valida OBJETIVO/MODO_BASE e aborta se invalido

   ENTRADAS  : macro vars globais definidas no master + caminhos das libs.
   SAIDAS    : sessao SAS configurada (libnames, options, ODS). Nenhum dataset.
   DEPENDE DE: nada.

   ------------------------------------------------------------
   EXEMPLO DE USO (no 00_MASTER.sas):

     %let OBJETIVO         = REFERENCIA;
     %let MODO_BASE        = SUMARIZADA;
     %let VAR_SEG          = SCORE_HVI3 IDENTIFICA_GRUPO_MODELO CANAL_PCO_AJUSTADO;
     %let VAR_SCORE_FAIXA  = SCORE_HVI3;

     %include "macros/m00_setup.sas";
     %setup(
        lib_art      = /sasdata/Credito_Estudos/POL/ARTHUR_FONTANA,
        lib_inf      = /sasdata/Credito_Estudos/POL/ARTHUR_FONTANA/INFERENCIA,
        lib_oned     = /sasdata/Credito/ONEDATA/FPD,
        lib_log_novo = /sasdata/Credito/LOGS_PCO/B2C/,
        ods_saida    = /sasdata/Credito_Estudos/POL/ARTHUR_FONTANA/INFERENCIA/relatorios
     );
   ============================================================ */

%macro setup(
    lib_art      = ,
    lib_inf      = ,
    lib_oned     = ,
    lib_log_novo = ,
    lib_julia    = ,
    libs_extra   = ,
    ods_saida    = ,
    ods_arquivo  = inferencia_relatorios.html,
    validar      = 1
);

    /* ---------------------------------------------------------
       1) Options de sessao
          validvarname=v7 e indispensavel: o colunamento do m01
          gera nomes de coluna dinamicos via PROC TRANSPOSE.
          mprint ligado ajuda a depurar codigo gerado "as cegas"
          (sem runtime SAS no ambiente de desenvolvimento).
    --------------------------------------------------------- */
    options validvarname=v7 mprint;

    /* ---------------------------------------------------------
       2) LIBNAMEs (so emite os que vierem preenchidos)
    --------------------------------------------------------- */
    %if %length(&lib_art)      %then %do; libname ART      "&lib_art";      %end;
    %if %length(&lib_inf)      %then %do; libname INF      "&lib_inf";      %end;
    %if %length(&lib_oned)     %then %do; libname ONED     "&lib_oned";     %end;
    %if %length(&lib_log_novo) %then %do; libname LOG_NOVO "&lib_log_novo"; %end;
    %if %length(&lib_julia)    %then %do; libname JULIA    "&lib_julia";    %end;

    /* libs adicionais no formato "NOME1=caminho1|NOME2=caminho2" */
    %if %length(&libs_extra) %then %do;
        %local _i _par _nm _cm;
        %let _i = 1;
        %do %while(%scan(&libs_extra, &_i, |) ne );
            %let _par = %scan(&libs_extra, &_i, |);
            %let _nm  = %scan(&_par, 1, =);
            %let _cm  = %scan(&_par, 2, =);
            libname &_nm "&_cm";
            %let _i = %eval(&_i + 1);
        %end;
    %end;

    /* ---------------------------------------------------------
       3) Validacao das macro vars globais OBJETIVO e MODO_BASE
    --------------------------------------------------------- */
    %if &validar = 1 %then %do;

        %if not %symexist(OBJETIVO) %then %do;
            %put ERROR: macro var global OBJETIVO nao definida.;
            %put ERROR- Defina no master, ex.: %nrstr(%let OBJETIVO = REFERENCIA;);
            %abort cancel;
        %end;
        %if %sysfunc(indexw(REFERENCIA INFERENCIA COMPLETO, %upcase(&OBJETIVO))) = 0 %then %do;
            %put ERROR: OBJETIVO=&OBJETIVO invalido.;
            %put ERROR- Use REFERENCIA, INFERENCIA ou COMPLETO.;
            %abort cancel;
        %end;

        %if not %symexist(MODO_BASE) %then %do;
            %put ERROR: macro var global MODO_BASE nao definida.;
            %put ERROR- Defina no master, ex.: %nrstr(%let MODO_BASE = SUMARIZADA;);
            %abort cancel;
        %end;
        %if %sysfunc(indexw(ANALITICA SUMARIZADA, %upcase(&MODO_BASE))) = 0 %then %do;
            %put ERROR: MODO_BASE=&MODO_BASE invalido.;
            %put ERROR- Use ANALITICA ou SUMARIZADA.;
            %abort cancel;
        %end;

    %end;

    /* ---------------------------------------------------------
       4) ODS: saidas legiveis (em vez de PUT no log)
    --------------------------------------------------------- */
    ods listing close;
    %if %length(&ods_saida) %then %do;
        ods html path="&ods_saida" body="&ods_arquivo" style=htmlblue;
    %end;
    %else %do;
        ods html;   /* destino padrao do EG / SAS Studio */
    %end;

    /* ---------------------------------------------------------
       5) Eco da configuracao
    --------------------------------------------------------- */
    %put NOTE: ===== m00_setup concluido =====;
    %put NOTE: OBJETIVO  = &OBJETIVO;
    %put NOTE: MODO_BASE = &MODO_BASE;
    %if %symexist(VAR_SEG)         %then %put NOTE: VAR_SEG         = &VAR_SEG;;
    %if %symexist(VAR_SCORE_FAIXA) %then %put NOTE: VAR_SCORE_FAIXA = &VAR_SCORE_FAIXA;;

%mend setup;
