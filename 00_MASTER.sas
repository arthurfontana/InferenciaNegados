/* ============================================================================
   00_MASTER.sas  -  E6: Orquestrador do motor de inferencia de negados (Vivo)
   ----------------------------------------------------------------------------
   VOCE DEFINE TUDO AQUI E RODA BLOCO A BLOCO.

   Sistema de inferencia de negados (reject inference) para politica de credito,
   100% SAS. Este master:
     - centraliza TODOS os parametros (nada cravado dentro das macros);
     - faz %include das macros m00..m05 (uma macro por fase);
     - decide, pelo OBJETIVO, quais fases rodam;
     - traz blocos comentados com exemplos preenchidos por fase.

   Fluxo do funil (so ha comportamento observado p/ aprovado-E-convertido):
     Solicitantes -> [politica] -> Aprovados -> [conversao] -> Altas -> [FPD] -> Maus

   ----------------------------------------------------------------------------
   DOIS INTERRUPTORES (wiki pag. 3 - Arquitetura-Alvo)

     OBJETIVO   REFERENCIA -> m01 -> m02 -> m03 (+ m04 backtest opcional)
                              Gera/recalibra a TABELA DE REFERENCIA a partir da
                              base historica (que tem os targets observados).
                INFERENCIA -> m01 -> m04 -> m05
                              Aplica uma tabela de referencia JA EXISTENTE numa
                              base nova (sem targets) e exporta o CSV.
                COMPLETO   -> m01 -> m02 -> m03 -> m04 -> m05
                              Tudo numa tacada (sobre a base com targets:
                              backtest + export).

     MODO_BASE  ANALITICA  -> mantem a CHAVE (1 linha/proposta).
                SUMARIZADA -> dropa a chave no m01 e soma ao grao
                              VAR_SEG + DIMS_SAIDA (de ~13M p/ dezenas de
                              milhares de linhas). A matematica e a mesma
                              (motor unificado, wiki pag. 5).

   ----------------------------------------------------------------------------
   INVENTARIO COMPLETO DE PARAMETROS (wiki pag. 4)

   GLOBAIS (sempre)
     OBJETIVO         REFERENCIA | INFERENCIA | COMPLETO
     MODO_BASE        ANALITICA  | SUMARIZADA
     LIB_*            caminhos das libraries (ART/INF/ONED/LOG_NOVO ...)
     VAR_SEG          vars de segmentacao; ORDEM IMPORTA (1a = score = ancora)
     VAR_SCORE_FAIXA  var de score/faixa (deve ser a 1a de VAR_SEG)
     DIMS_SAIDA       dimensoes extras mantidas no grao sumarizado e no CSV

   MONTAGEM DA BASE - m01 (fase b)
     DS_FONTE                 lista de base(s) de entrada
     WHERE_FONTE              filtro de leitura
     KEEP_FONTE               (opcional) colunas a manter na leitura (I/O)
     RENOMEAR                 (opcional) de-para de nomes (raw -> canonico)
     CHAVE                    chave da proposta (dedup + grao analitico)
     COL_DS_PRINCIPAL / COL_FX_SCORE        colunamento do score -> SCORE_*
     COL_DS_ADICIONAL / COL_MODELO_ADICIONAL colunamento adicional -> ADICIONAL_*
     EXPR_APROVADO            regra de FL_APROVADOS
     EXPR_ALTAS               regra de FL_ALTAS (conversao)        [so REFERENCIA]
     DS_TARGET_MAU            base de onde vem o mau                [so REFERENCIA]
     CHAVE_MAU                chave de cruzamento com o mau         [so REFERENCIA]
     COLS_TARGET              colunas a trazer do target (flags+mau)[so REFERENCIA]
     VAR_MAU                  coluna do mau/FPD                     [so REFERENCIA]

   DIAGNOSTICO - m02 (fase 0)
     MARGEM_RELATIVA  0.40    ALPHA  0.07    PODER  0.75
     DS_DIAGNOSTICO   dataset de diagnostico (saida)
       -> deriva e exporta MIN_N, MIN_EVENTOS, Z_ALFA, P_CONV_GLOBAL, P_FPD_GLOBAL

   TABELA DE REFERENCIA - m03 (fase 1)
     K_EXPONENCIAL    0 (0 = derivar dos dados)
     DS_TABELA_REF    tabela de referencia (saida da m03 / entrada da m04)

   APLICAR / EXPORTAR - m04 / m05 (fase e)
     DS_NOVO          base a enriquecer (default = saida do m01)
     DS_OUTPUT_INF    base enriquecida (saida da m04)
     FL_MANTER_ORIG   1 = mantem todas as colunas originais
     PESO_FISICO      coluna que pondera o fisico (n_aprovados | n_propostas)
     CAMINHO_CSV      arquivo CSV de saida p/ o simulador

   GANCHO PAP (opcional, desligado por padrao) - ver CONTEXTO.md secao 6
     CANAIS_EXCLUIR   canais a excluir/tratar a parte (vazio = nada)

   TOGGLES DESTE MASTER
     RODAR_M01        1 = (re)monta a base; 0 = reaproveita DS_NOVO existente
     RODAR_BACKTEST   1 = roda m04 em modo backtest no REFERENCIA

   REGRA DE MANUTENCAO: parametro novo NASCE aqui e e repassado as macros -
   nunca cravado dentro da logica.
   ============================================================================ */


/* ============================================================================
   PARTE A - PARAMETROS GLOBAIS (edite aqui)
   ============================================================================ */

/* --- interruptores --- */
%let OBJETIVO   = REFERENCIA;     /* REFERENCIA | INFERENCIA | COMPLETO */
%let MODO_BASE  = SUMARIZADA;     /* ANALITICA  | SUMARIZADA            */

/* --- toggles --- */
%let RODAR_M01      = 1;          /* 1 = (re)monta a base no m01        */
%let RODAR_BACKTEST = 1;          /* 1 = backtest no m04 (REFERENCIA)   */

/* --- segmentacao (ORDEM IMPORTA: 1a = score = ancora) --- */
%let VAR_SEG         = SCORE_HVI3 IDENTIFICA_GRUPO_MODELO CANAL_PCO_AJUSTADO;
%let VAR_SCORE_FAIXA = SCORE_HVI3;

/* --- dimensoes extras mantidas no grao sumarizado e no CSV final --- */
%let DIMS_SAIDA =
    SAFRA RISCO_CIDADE_SERASA SISTEMA CANAL_PCO_DECISAO CANAL_PCO_AJUSTADO
    OPERACAO TP_PEDIDO DECISAO_ANALISE REASON_CODE DS_REASON_CODE
    IDENTIFICA_NOVA_ARVORE IDENTIFICA_GRUPO_MODELO GALHO_ARVORE SCORE_HVI3
    ADICIONAL_G1_BHV ADICIONAL_REST ADICIONAL_G4_BHV ADICIONAL_G5_BHV
    ADICIONAL_HVI4 ADICIONAL_G7_BHV;

/* --- parametros do motor (validados: 0.40/0.07/0.75; MIN_N=230, MIN_EVENTOS=62) --- */
%let MARGEM_RELATIVA = 0.40;
%let ALPHA           = 0.07;
%let PODER           = 0.75;
%let K_EXPONENCIAL   = 0;         /* 0 = derivar dos dados */

/* --- datasets de saida das fases --- */
%let DS_BASE         = INF.BASE_MODELAGEM_AM;   /* saida do m01 (base do motor) */
%let DS_DIAGNOSTICO  = INF.FASE0_DIAGNOSTICO;   /* saida do m02 */
%let DS_TABELA_REF   = INF.TABELA_REF_MV;       /* saida do m03 / entrada do m04 */
%let DS_NOVO         = &DS_BASE;                /* base a enriquecer no m04      */
%let DS_OUTPUT_INF   = INF.BASE_MODELAGEM_AM_INF; /* saida do m04 */
%let FL_MANTER_ORIG  = 1;
%let PESO_FISICO     = n_aprovados;             /* n_aprovados (DoD) | n_propostas (legado) */
%let CAMINHO_CSV     = /sasdata/Credito_Estudos/POL/ARTHUR_FONTANA/INFERENCIA/saida_inferencia_sum.csv;

/* --- montagem da base (m01) --- */
%let DS_FONTE    = LOG_NOVO.LOGS_PCO_B2C_202605 LOG_NOVO.LOGS_PCO_B2C_202606;
%let WHERE_FONTE = IDENTIFICA_NOVA_ARVORE="NOVO FLUXO B2C" and ORIGEM="AM" and FL_DEDUP_CNL_DIA=1;
%let KEEP_FONTE  =
    LOGIN_SOLICITANTE NR_PROPOSTA NR_DOC SAFRA_CNST DT_CNST RISCO_CEP_CALC_PCO
    ORIGEM CANAL_PCO_DECISAO OPERACAO TP_PEDIDO BUREAU_PCO RESTRITIVOS_SERASA
    RGNL_CNST DS_VAR_PRINCIPAL FAIXA_SCORE DS_VAR_ADICIONAL MODELO_ADICIONAL
    DECISAO_ANALISE REASON_CODE DS_REASON_CODE CD_SCORE POLITICA_NOVA
    IDENTIFICA_NOVA_ARVORE IDENTIFICA_GRUPO_MODELO GALHO_ARVORE FL_DEDUP_CNL_DIA;
%let RENOMEAR    = SAFRA_CNST=SAFRA RISCO_CEP_CALC_PCO=RISCO_CIDADE_SERASA ORIGEM=SISTEMA CD_SCORE=OFERTA;
%let CHAVE       = NR_PROPOSTA;
%let COL_DS_PRINCIPAL     = DS_VAR_PRINCIPAL;
%let COL_FX_SCORE         = FAIXA_SCORE;
%let COL_DS_ADICIONAL     = DS_VAR_ADICIONAL;
%let COL_MODELO_ADICIONAL = MODELO_ADICIONAL;
%let EXPR_APROVADO = DECISAO_ANALISE="APROVADO";

/* --- alvo/conversao: SO no caminho REFERENCIA/COMPLETO --- */
%let EXPR_ALTAS    = FL_FATURADO=1 and FL_REDUTOR=0 and FL_PLNO_ZERO=0 and FL_LNHA_FICT=0 and FL_DEDUP_CONTA=1;
%let DS_TARGET_MAU = ONED.FPD_ONEDATA;
%let CHAVE_MAU     = NR_PROPOSTA;
%let COLS_TARGET   = fl_atrs_parc_over_30 fl_atrs_parc_over_60 FL_REDUTOR FL_FATURADO FL_PLNO_ZERO FL_LNHA_FICT FL_DEDUP_CONTA;
%let VAR_MAU       = fl_atrs_parc_over_30;

/* --- gancho PAP (opcional; vazio = desligado) - ver CONTEXTO.md secao 6 --- */
%let CANAIS_EXCLUIR = ;

/* >>> No caminho INFERENCIA, a base nova NAO tem targets. Esvazie estes:
       %let EXPR_ALTAS=;  %let DS_TARGET_MAU=;  %let VAR_MAU=;  %let COLS_TARGET=;
       e aponte DS_FONTE/WHERE_FONTE/DS_BASE/DS_NOVO p/ a base a simular.    <<< */


/* ============================================================================
   PARTE B - %INCLUDE DAS MACROS (m00..m05)
   Ajuste o caminho da pasta macros/ conforme o seu ambiente.
   ============================================================================ */
%let DIR_MACROS = /sasdata/Credito_Estudos/POL/ARTHUR_FONTANA/INFERENCIA/macros;

%include "&DIR_MACROS./m00_setup.sas";
%include "&DIR_MACROS./m01_montar_base.sas";
%include "&DIR_MACROS./m02_diagnostico.sas";
%include "&DIR_MACROS./m03_tabela_referencia.sas";
%include "&DIR_MACROS./m04_aplicar_inferencia.sas";
%include "&DIR_MACROS./m05_exportar.sas";


/* ============================================================================
   PARTE C - SETUP (E0): libnames, options, ODS HTML, validacao de OBJETIVO/MODO
   ============================================================================ */
%setup(
    lib_art      = /sasdata/Credito_Estudos/POL/ARTHUR_FONTANA,
    lib_inf      = /sasdata/Credito_Estudos/POL/ARTHUR_FONTANA/INFERENCIA,
    lib_oned     = /sasdata/Credito/ONEDATA/FPD,
    lib_log_novo = /sasdata/Credito/LOGS_PCO/B2C/,
    ods_saida    = /sasdata/Credito_Estudos/POL/ARTHUR_FONTANA/INFERENCIA/relatorios
);


/* ============================================================================
   PARTE D - ORQUESTRACAO POR OBJETIVO
   Toda a logica de %if fica DENTRO de %macro (armadilha do %if/%do em open
   code). Cada bloco abaixo traz a CHAMADA DE EXEMPLO da sua fase; a macro
   %pipeline decide o que roda conforme &OBJETIVO.
   ============================================================================ */
%macro pipeline;

    %local _obj;
    %let _obj = %upcase(&OBJETIVO);

    /* ------------------------------------------------------------------
       FASE b - MONTAGEM DA BASE (m01)  [todos os objetivos]
       REFERENCIA/COMPLETO: com target (mau + flags de conversao).
       INFERENCIA: sem target (esvazie EXPR_ALTAS/DS_TARGET_MAU/VAR_MAU).
       ------------------------------------------------------------------ */
    %if &RODAR_M01. = 1 %then %do;
        %montar_base(
            ds_fonte            = &DS_FONTE,
            where_fonte         = %nrbquote(&WHERE_FONTE),
            keep_fonte          = &KEEP_FONTE,
            renomear            = &RENOMEAR,
            chave               = &CHAVE,
            ds_target_mau       = &DS_TARGET_MAU,
            chave_mau           = &CHAVE_MAU,
            cols_target         = &COLS_TARGET,
            var_mau             = &VAR_MAU,
            expr_aprovado       = %nrbquote(&EXPR_APROVADO),
            expr_altas          = %nrbquote(&EXPR_ALTAS),
            col_ds_principal    = &COL_DS_PRINCIPAL,
            col_fx_score        = &COL_FX_SCORE,
            col_ds_adicional    = &COL_DS_ADICIONAL,
            col_modelo_adicional= &COL_MODELO_ADICIONAL,
            var_seg             = &VAR_SEG,
            var_score_faixa     = &VAR_SCORE_FAIXA,
            dims_saida          = &DIMS_SAIDA,
            modo_base           = &MODO_BASE,
            ds_saida            = &DS_BASE
        );
    %end;
    %else %do;
        %put NOTE: === RODAR_M01=0: reaproveitando base existente &DS_NOVO ===;
    %end;

    /* ------------------------------------------------------------------
       FASE 0 - DIAGNOSTICO (m02)  [REFERENCIA, COMPLETO]
       Deriva MIN_N / MIN_EVENTOS / Z_ALFA / P_*_GLOBAL (GLOBAIS) + HTML.
       ------------------------------------------------------------------ */
    %if &_obj. = REFERENCIA or &_obj. = COMPLETO %then %do;
        %diagnostico(
            ds_base         = &DS_BASE,
            var_seg         = &VAR_SEG,
            margem_relativa = &MARGEM_RELATIVA,
            alpha           = &ALPHA,
            poder           = &PODER,
            ds_diagnostico  = &DS_DIAGNOSTICO
        );
    %end;

    /* ------------------------------------------------------------------
       FASE 1 - TABELA DE REFERENCIA (m03)  [REFERENCIA, COMPLETO]
       Niveis + fallback hierarquico + extrapolacao -> &DS_TABELA_REF.
       ------------------------------------------------------------------ */
    %if &_obj. = REFERENCIA or &_obj. = COMPLETO %then %do;
        %tabela_referencia(
            ds_base         = &DS_BASE,
            var_seg         = &VAR_SEG,
            var_score_faixa = &VAR_SCORE_FAIXA,
            k_exponencial   = &K_EXPONENCIAL,
            ds_tabela_ref   = &DS_TABELA_REF
        );
    %end;

    /* ------------------------------------------------------------------
       FASE 2 - APLICAR INFERENCIA (m04)
       REFERENCIA: backtest opcional sobre a base com targets.
       INFERENCIA/COMPLETO: enriquece a base -> &DS_OUTPUT_INF.
       ------------------------------------------------------------------ */
    %if &_obj. = INFERENCIA or &_obj. = COMPLETO %then %do;
        %aplicar_inferencia(
            ds_novo        = &DS_NOVO,
            ds_tabela_ref  = &DS_TABELA_REF,
            ds_output_inf  = &DS_OUTPUT_INF,
            var_seg        = &VAR_SEG,
            var_score_faixa= &VAR_SCORE_FAIXA,
            modo_base      = &MODO_BASE,
            fl_manter_orig = &FL_MANTER_ORIG,
            peso_fisico    = &PESO_FISICO,
            backtest       = AUTO
        );
    %end;
    %else %if &_obj. = REFERENCIA and &RODAR_BACKTEST. = 1 %then %do;
        /* backtest: aplica a referencia recem-gerada na propria base historica */
        %aplicar_inferencia(
            ds_novo        = &DS_BASE,
            ds_tabela_ref  = &DS_TABELA_REF,
            ds_output_inf  = &DS_OUTPUT_INF,
            var_seg        = &VAR_SEG,
            var_score_faixa= &VAR_SCORE_FAIXA,
            modo_base      = &MODO_BASE,
            fl_manter_orig = &FL_MANTER_ORIG,
            peso_fisico    = &PESO_FISICO,
            backtest       = SIM
        );
    %end;

    /* ------------------------------------------------------------------
       FASE e - EXPORTAR (m05)  [INFERENCIA, COMPLETO]
       Sumariza por VAR_SEG + DIMS_SAIDA e gera o CSV p/ o simulador.
       ------------------------------------------------------------------ */
    %if &_obj. = INFERENCIA or &_obj. = COMPLETO %then %do;
        %exportar(
            ds_entrada   = &DS_OUTPUT_INF,
            dims_saida   = &DIMS_SAIDA,
            var_seg      = &VAR_SEG,
            caminho_csv  = &CAMINHO_CSV,
            modo_base    = &MODO_BASE
        );
    %end;

    %put NOTE: ===== PIPELINE concluido (OBJETIVO=&OBJETIVO, MODO_BASE=&MODO_BASE) =====;

%mend pipeline;

%pipeline;

/* fecha o ODS HTML aberto no %setup */
ods html close;
ods listing;


/* ============================================================================
   PARTE E - SMOKE TEST PONTA A PONTA (rode no SASApp - checklist wiki pag. 8)

   Apos a Sessao 3 (E4+E5+E6), confirmar:
     [ ] m04 backtest (real x inferido) dentro do desvio aceitavel (~1pp ALTA);
     [ ] CSV exportado identico EM ESTRUTURA ao do "2 - Aplicar..."
         (FL_PROPOSTA, FL_APROVADOS, PROB_CONVERSAO, PROB_MAU + DIMS);
     [ ] 00_MASTER roda ponta a ponta nos 3 valores de OBJETIVO.

   Roteiro sugerido (cada passo e uma execucao do master, ajustando o topo):

     1) REFERENCIA  (gera a tabela de referencia + backtest)
          %let OBJETIVO = REFERENCIA;  %let MODO_BASE = SUMARIZADA;
        Esperado: MIN_N=230, MIN_EVENTOS=62; ~96% das celulas ALTA;
                  backtest com desvio de conversao/FPD pequeno.

     2) INFERENCIA  (aplica a referencia numa base nova + CSV)
          %let OBJETIVO = INFERENCIA;
          %let EXPR_ALTAS=;  %let DS_TARGET_MAU=;  %let VAR_MAU=;  %let COLS_TARGET=;
          aponte DS_FONTE/WHERE_FONTE/DS_BASE/DS_NOVO p/ a base a simular.
        Esperado: relatorio de cobertura das premissas + CSV em &CAMINHO_CSV.

     3) COMPLETO    (tudo numa tacada sobre a base com targets)
          %let OBJETIVO = COMPLETO;
        Esperado: diagnostico + referencia + enriquecimento + backtest + CSV.

   OBS. SEMANTICA DO FISICO (ver cabecalho do m04/m05): no default
   PESO_FISICO=n_aprovados, o fisico e SOBRE APROVADOS (regra de ouro 3). O
   legado "2 - Aplicar" somava sobre TODAS as propostas (n_propostas, semantica
   de "abertura para reprovados"). Para reproduzir exatamente o CSV legado,
   defina %nrstr(%let PESO_FISICO = n_propostas;).
   ============================================================================ */
