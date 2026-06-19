LIBNAME INF "/sasdata/Credito_Estudos/POL/ARTHUR_FONTANA/INFERENCIA";
LIBNAME LOG_NOVO "/sasdata/Credito/LOGS_PCO/B2C/";

DATA LOG;
SET 
/*LOG_NOVO.LOGS_PCO_B2C_202509 (where=(IDENTIFICA_NOVA_ARVORE = "NOVO FLUXO B2C" and ORIGEM = "AM" AND FL_DEDUP_CNL_DIA = 1) keep=LOGIN_SOLICITANTE NR_PROPOSTA NR_DOC SAFRA_CNST  DT_CNST RISCO_CEP_CALC_PCO ORIGEM CANAL_PCO_DECISAO OPERACAO TP_PEDIDO BUREAU_PCO RESTRITIVOS_SERASA RGNL_CNST DS_VAR_PRINCIPAL FAIXA_SCORE DS_VAR_ADICIONAL MODELO_ADICIONAL DECISAO_ANALISE REASON_CODE DS_REASON_CODE CD_SCORE POLITICA_NOVA IDENTIFICA_NOVA_ARVORE IDENTIFICA_GRUPO_MODELO GALHO_ARVORE FL_DEDUP_CNL_DIA)*/
/*LOG_NOVO.LOGS_PCO_B2C_202510 (where=(IDENTIFICA_NOVA_ARVORE = "NOVO FLUXO B2C" and ORIGEM = "AM" AND FL_DEDUP_CNL_DIA = 1) keep=LOGIN_SOLICITANTE NR_PROPOSTA NR_DOC SAFRA_CNST  DT_CNST RISCO_CEP_CALC_PCO ORIGEM CANAL_PCO_DECISAO OPERACAO TP_PEDIDO BUREAU_PCO RESTRITIVOS_SERASA RGNL_CNST DS_VAR_PRINCIPAL FAIXA_SCORE DS_VAR_ADICIONAL MODELO_ADICIONAL DECISAO_ANALISE REASON_CODE DS_REASON_CODE CD_SCORE POLITICA_NOVA IDENTIFICA_NOVA_ARVORE IDENTIFICA_GRUPO_MODELO GALHO_ARVORE FL_DEDUP_CNL_DIA)*/
/*LOG_NOVO.LOGS_PCO_B2C_202511 (where=(IDENTIFICA_NOVA_ARVORE = "NOVO FLUXO B2C" and ORIGEM = "AM" AND FL_DEDUP_CNL_DIA = 1) keep=LOGIN_SOLICITANTE NR_PROPOSTA NR_DOC SAFRA_CNST  DT_CNST RISCO_CEP_CALC_PCO ORIGEM CANAL_PCO_DECISAO OPERACAO TP_PEDIDO BUREAU_PCO RESTRITIVOS_SERASA RGNL_CNST DS_VAR_PRINCIPAL FAIXA_SCORE DS_VAR_ADICIONAL MODELO_ADICIONAL DECISAO_ANALISE REASON_CODE DS_REASON_CODE CD_SCORE POLITICA_NOVA IDENTIFICA_NOVA_ARVORE IDENTIFICA_GRUPO_MODELO GALHO_ARVORE FL_DEDUP_CNL_DIA)*/
/*LOG_NOVO.LOGS_PCO_B2C_202512 (where=(IDENTIFICA_NOVA_ARVORE = "NOVO FLUXO B2C" and ORIGEM = "AM" AND FL_DEDUP_CNL_DIA = 1) keep=LOGIN_SOLICITANTE NR_PROPOSTA NR_DOC SAFRA_CNST  DT_CNST RISCO_CEP_CALC_PCO ORIGEM CANAL_PCO_DECISAO OPERACAO TP_PEDIDO BUREAU_PCO RESTRITIVOS_SERASA RGNL_CNST DS_VAR_PRINCIPAL FAIXA_SCORE DS_VAR_ADICIONAL MODELO_ADICIONAL DECISAO_ANALISE REASON_CODE DS_REASON_CODE CD_SCORE POLITICA_NOVA IDENTIFICA_NOVA_ARVORE IDENTIFICA_GRUPO_MODELO GALHO_ARVORE FL_DEDUP_CNL_DIA)*/
/*LOG_NOVO.LOGS_PCO_B2C_202601 (where=(IDENTIFICA_NOVA_ARVORE = "NOVO FLUXO B2C" and ORIGEM = "AM" AND FL_DEDUP_CNL_DIA = 1) keep=LOGIN_SOLICITANTE NR_PROPOSTA NR_DOC SAFRA_CNST  DT_CNST RISCO_CEP_CALC_PCO ORIGEM CANAL_PCO_DECISAO OPERACAO TP_PEDIDO BUREAU_PCO RESTRITIVOS_SERASA RGNL_CNST DS_VAR_PRINCIPAL FAIXA_SCORE DS_VAR_ADICIONAL MODELO_ADICIONAL DECISAO_ANALISE REASON_CODE DS_REASON_CODE CD_SCORE POLITICA_NOVA IDENTIFICA_NOVA_ARVORE IDENTIFICA_GRUPO_MODELO GALHO_ARVORE FL_DEDUP_CNL_DIA)*/
/*LOG_NOVO.LOGS_PCO_B2C_202602 (where=(IDENTIFICA_NOVA_ARVORE = "NOVO FLUXO B2C" and ORIGEM = "AM" AND FL_DEDUP_CNL_DIA = 1) keep=LOGIN_SOLICITANTE NR_PROPOSTA NR_DOC SAFRA_CNST  DT_CNST RISCO_CEP_CALC_PCO ORIGEM CANAL_PCO_DECISAO OPERACAO TP_PEDIDO BUREAU_PCO RESTRITIVOS_SERASA RGNL_CNST DS_VAR_PRINCIPAL FAIXA_SCORE DS_VAR_ADICIONAL MODELO_ADICIONAL DECISAO_ANALISE REASON_CODE DS_REASON_CODE CD_SCORE POLITICA_NOVA IDENTIFICA_NOVA_ARVORE IDENTIFICA_GRUPO_MODELO GALHO_ARVORE FL_DEDUP_CNL_DIA)*/
/*LOG_NOVO.LOGS_PCO_B2C_202603 (where=(IDENTIFICA_NOVA_ARVORE = "NOVO FLUXO B2C" and ORIGEM = "AM" AND FL_DEDUP_CNL_DIA = 1) keep=LOGIN_SOLICITANTE NR_PROPOSTA NR_DOC SAFRA_CNST  DT_CNST RISCO_CEP_CALC_PCO ORIGEM CANAL_PCO_DECISAO OPERACAO TP_PEDIDO BUREAU_PCO RESTRITIVOS_SERASA RGNL_CNST DS_VAR_PRINCIPAL FAIXA_SCORE DS_VAR_ADICIONAL MODELO_ADICIONAL DECISAO_ANALISE REASON_CODE DS_REASON_CODE CD_SCORE POLITICA_NOVA IDENTIFICA_NOVA_ARVORE IDENTIFICA_GRUPO_MODELO GALHO_ARVORE FL_DEDUP_CNL_DIA)*/
/*LOG_NOVO.LOGS_PCO_B2C_202604 (where=(IDENTIFICA_NOVA_ARVORE = "NOVO FLUXO B2C" and ORIGEM = "AM" AND FL_DEDUP_CNL_DIA = 1) keep=LOGIN_SOLICITANTE NR_PROPOSTA NR_DOC SAFRA_CNST  DT_CNST RISCO_CEP_CALC_PCO ORIGEM CANAL_PCO_DECISAO OPERACAO TP_PEDIDO BUREAU_PCO RESTRITIVOS_SERASA RGNL_CNST DS_VAR_PRINCIPAL FAIXA_SCORE DS_VAR_ADICIONAL MODELO_ADICIONAL DECISAO_ANALISE REASON_CODE DS_REASON_CODE CD_SCORE POLITICA_NOVA IDENTIFICA_NOVA_ARVORE IDENTIFICA_GRUPO_MODELO GALHO_ARVORE FL_DEDUP_CNL_DIA)*/
LOG_NOVO.LOGS_PCO_B2C_202605 (where=(IDENTIFICA_NOVA_ARVORE = "NOVO FLUXO B2C" and ORIGEM = "AM" AND FL_DEDUP_CNL_DIA = 1) keep=LOGIN_SOLICITANTE NR_PROPOSTA NR_DOC SAFRA_CNST  DT_CNST RISCO_CEP_CALC_PCO ORIGEM CANAL_PCO_DECISAO OPERACAO TP_PEDIDO BUREAU_PCO RESTRITIVOS_SERASA RGNL_CNST DS_VAR_PRINCIPAL FAIXA_SCORE DS_VAR_ADICIONAL MODELO_ADICIONAL DECISAO_ANALISE REASON_CODE DS_REASON_CODE CD_SCORE POLITICA_NOVA IDENTIFICA_NOVA_ARVORE IDENTIFICA_GRUPO_MODELO GALHO_ARVORE FL_DEDUP_CNL_DIA)
LOG_NOVO.LOGS_PCO_B2C_202606 (where=(IDENTIFICA_NOVA_ARVORE = "NOVO FLUXO B2C" and ORIGEM = "AM" AND FL_DEDUP_CNL_DIA = 1) keep=LOGIN_SOLICITANTE NR_PROPOSTA NR_DOC SAFRA_CNST  DT_CNST RISCO_CEP_CALC_PCO ORIGEM CANAL_PCO_DECISAO OPERACAO TP_PEDIDO BUREAU_PCO RESTRITIVOS_SERASA RGNL_CNST DS_VAR_PRINCIPAL FAIXA_SCORE DS_VAR_ADICIONAL MODELO_ADICIONAL DECISAO_ANALISE REASON_CODE DS_REASON_CODE CD_SCORE POLITICA_NOVA IDENTIFICA_NOVA_ARVORE IDENTIFICA_GRUPO_MODELO GALHO_ARVORE FL_DEDUP_CNL_DIA)
;


RUN;


PROC SQL;
CREATE TABLE LOG_05_06 AS
SELECT 
NR_PROPOSTA,
NR_DOC,
SAFRA_CNST AS SAFRA,
DT_CNST,
RISCO_CEP_CALC_PCO AS RISCO_CIDADE_SERASA,
ORIGEM AS SISTEMA,
CANAL_PCO_DECISAO,
LOGIN_SOLICITANTE,
OPERACAO,
TP_PEDIDO,
BUREAU_PCO,
RESTRITIVOS_SERASA,
RGNL_CNST,
DS_VAR_PRINCIPAL,
FAIXA_SCORE AS FX_SCORE,
DS_VAR_ADICIONAL,
MODELO_ADICIONAL,
DECISAO_ANALISE,
REASON_CODE,
DS_REASON_CODE,
CD_SCORE AS OFERTA,
POLITICA_NOVA,
IDENTIFICA_NOVA_ARVORE,
IDENTIFICA_GRUPO_MODELO,
GALHO_ARVORE,
FL_DEDUP_CNL_DIA
FROM LOG;
RUN;

DATA BASE_SRS_GS;
SET LOG_05_06 (where=(SAFRA >= 202510 and IDENTIFICA_NOVA_ARVORE = "NOVO FLUXO B2C") KEEP=NR_DOC NR_PROPOSTA SAFRA	RISCO_CIDADE_SERASA	SISTEMA	CANAL_PCO_DECISAO	OPERACAO	TP_PEDIDO	DS_VAR_PRINCIPAL	FX_SCORE	DS_VAR_ADICIONAL	MODELO_ADICIONAL	DECISAO_ANALISE	REASON_CODE	DS_REASON_CODE	IDENTIFICA_GRUPO_MODELO	GALHO_ARVORE IDENTIFICA_NOVA_ARVORE);

FL_PROPOSTA = 1;

IF DECISAO_ANALISE = "APROVADO" THEN FL_APROVADOS = 1; ELSE FL_APROVADOS = 0;

IF DS_VAR_PRINCIPAL = "" OR FX_SCORE = "" OR DS_VAR_ADICIONAL = "" OR MODELO_ADICIONAL = "" THEN DELETE;

RUN;


/*===========================================================
  OBJETIVO:
    - Criar SCORE_<DS_VAR_PRINCIPAL>  = FX_SCORE
    - Criar ADICIONAL_<DS_VAR_ADICIONAL> = MODELO_ADICIONAL
      * Se DS_VAR_ADICIONAL vazio -> usar DS_VAR_PRINCIPAL
 
  ENTRADA : BASE_SRS_GS
  SAÍDA   : BASE_SRS_GS_tratada
===========================================================*/
 
options validvarname=v7;
 
/*-----------------------------------------------------------
  1) Descobre automaticamente as colunas chave (BY):
     "todas as colunas" menos as 4 que participam do pivot
-----------------------------------------------------------*/
proc sql noprint;
  select name
    into :bycols separated by ' '
  from dictionary.columns
  where libname = 'WORK'
    and memname = 'BASE_SRS_GS'
    and upcase(name) not in
      ('DS_VAR_PRINCIPAL','FX_SCORE','DS_VAR_ADICIONAL','MODELO_ADICIONAL');
quit;
 
%put NOTE: BYCOLS = &bycols.;
 
/* Se quiser definir BY manualmente, comente o PROC SQL acima e use:
   %let bycols = NR_DOC SAFRA;
*/
 
/*-----------------------------------------------------------
  Função inline (via lógica repetida) para "sanitizar" nomes:
   - UPPER
   - troca caracteres inválidos por "_"
   - garante 1º char válido (letra ou "_")
   - trunca para caber em 32 chars (limite SAS V7)
-----------------------------------------------------------*/
 
/*-----------------------------------------------------------
  2) Prepara dataset para SCORE_<DS_VAR_PRINCIPAL>
-----------------------------------------------------------*/
data _principal_prep;
  set BASE_SRS_GS;
 
  length _id $32 _raw $200;
 
  _raw = upcase(strip(DS_VAR_PRINCIPAL));
  _raw = prxchange('s/[^A-Z0-9_]/_/o', -1, _raw);
 
  /* garante início válido */
  if not (('A' <= substr(_raw,1,1) <= 'Z') or substr(_raw,1,1) = '_') then
    _raw = cats('_', _raw);
 
  /* trunca para caber: 32 - length('SCORE_') = 26 */
  _raw = substr(_raw, 1, 32 - length('SCORE_'));
  _id  = cats('SCORE_', _raw);
 
  _value = FX_SCORE;
 
  keep &bycols _id _value;
run;
 
/*-----------------------------------------------------------
  3) Prepara dataset para ADICIONAL_<DS_VAR_ADICIONAL ou DS_VAR_PRINCIPAL>
-----------------------------------------------------------*/
data _adicional_prep;
  set BASE_SRS_GS;
 
  length _id $32 _raw $200 _ds $200;
 
  _ds  = coalescec(strip(DS_VAR_ADICIONAL), strip(DS_VAR_PRINCIPAL));
  _raw = upcase(strip(_ds));
  _raw = prxchange('s/[^A-Z0-9_]/_/o', -1, _raw);
 
  /* garante início válido */
  if not (('A' <= substr(_raw,1,1) <= 'Z') or substr(_raw,1,1) = '_') then
    _raw = cats('_', _raw);
 
  /* trunca para caber: 32 - length('ADICIONAL_') = 22 */
  _raw = substr(_raw, 1, 32 - length('ADICIONAL_'));
  _id  = cats('ADICIONAL_', _raw);
 
  _value = MODELO_ADICIONAL;
 
  keep &bycols _id _value;
run;
 
/*-----------------------------------------------------------
  4) (Opcional, mas recomendado) Tratar duplicidades:
     Se existir mais de uma linha com mesmo BY + _id,
     mantém a última ocorrência (ordem do dataset).
     -> Ajuste aqui se quiser MAX/MIN etc.
-----------------------------------------------------------*/
proc sort data=_principal_prep; by &bycols _id; run;
proc sort data=_adicional_prep; by &bycols _id; run;
 
data _principal_prep2;
  set _principal_prep;
  by &bycols _id;
  if last._id;
run;
 
data _adicional_prep2;
  set _adicional_prep;
  by &bycols _id;
  if last._id;
run;
 
/*-----------------------------------------------------------
  5) Transpose (wide) para criar colunas dinâmicas
-----------------------------------------------------------*/
proc transpose data=_principal_prep2 out=_principal_wide(drop=_name_);
  by &bycols;
  id _id;
  var _value;
run;
 
proc transpose data=_adicional_prep2 out=_adicional_wide(drop=_name_);
  by &bycols;
  id _id;
  var _value;
run;
 
/*-----------------------------------------------------------
  6) Junta os dois blocos (SCORE_* e ADICIONAL_*)
-----------------------------------------------------------*/
proc sort data=_principal_wide; by &bycols; run;
proc sort data=_adicional_wide; by &bycols; run;
 
data BASE_SRS_GS_tratada;
  merge _principal_wide _adicional_wide;
  by &bycols;
run;
 
/*-----------------------------------------------------------
  7) Limpeza (opcional)
-----------------------------------------------------------*/
proc datasets library=work nolist;
  delete _principal_prep _principal_prep2 _principal_wide
         _adicional_prep _adicional_prep2 _adicional_wide;
quit;

PROC SQL;
CREATE TABLE INF.LOG_05_06 AS
SELECT 
 NR_PROPOSTA
,NR_DOC
,SAFRA
,RISCO_CIDADE_SERASA	
,SISTEMA	
,CANAL_PCO_DECISAO	
,OPERACAO	
,TP_PEDIDO	
,DECISAO_ANALISE	
,REASON_CODE	
,DS_REASON_CODE	
,IDENTIFICA_NOVA_ARVORE	
,IDENTIFICA_GRUPO_MODELO	
,GALHO_ARVORE	
,SCORE_HVI3______________________	AS SCORE_HVI3
/*,SCORE_BVS_______________________	AS SCORE_BVS*/
,ADICIONAL_G1_BHV________________	AS ADICIONAL_G1_BHV
,ADICIONAL_REST__________________	AS ADICIONAL_REST
,ADICIONAL_G4_BHV________________	AS ADICIONAL_G4_BHV
,ADICIONAL_G5_BHV________________	AS ADICIONAL_G5_BHV
,ADICIONAL_HVI4__________________	AS ADICIONAL_HVI4
,ADICIONAL_G7_BHV________________	AS ADICIONAL_G7_BHV


,SUM(FL_PROPOSTA)		  AS FL_PROPOSTA
,SUM(FL_APROVADOS)		  AS FL_APROVADOS


FROM BASE_SRS_GS_TRATADA
GROUP BY 1,	2,	3,	4,	5,	6,	7,	8,	9,	10,	11,	12,	13,	14,	15,	16,	17,	18,	19,	20,	21;
QUIT;

DATA INF.LOG_05_06 INF.LOG_05_06_MV INF.LOG_05_06_FX_TT;
SET INF.LOG_05_06;
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

OUTPUT INF.LOG_05_06;
IF SISTEMA = "AM" AND OPERACAO =  "MOVEL" THEN OUTPUT INF.LOG_05_06_MV;
IF SISTEMA = "AM" AND OPERACAO ne "MOVEL" THEN OUTPUT INF.LOG_05_06_FX_TT;

RUN;




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

			%let DS_NOVO         = INF.LOG_05_06_MV;
/*					INDIQUE AQUI A BASE QUE SERÁ ENRIQUECIDA;*/
			%let DS_TABELA_REF   = INF.TABELA_REF_MV;
			%let DS_OUTPUT_FASE2 = INF.LOG_05_06_MV_INF; 
/*					WORK.FASE2_BASE_ENRIQUECIDA;*/
			%let LIB_OUT         = WORK;
			%let FL_MANTER_ORIG  = 1;   
/*					 1 = mantÃ©m todas as colunas originais */
%let VAR_SEG         = SCORE_HVI3 IDENTIFICA_GRUPO_MODELO CANAL_PCO_AJUSTADO;   /* ajuste aqui */



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

%let VAR_CONV_PROJ = prob_conversao;
%let VAR_FPD_PROJ  = prob_fpd;

data &DS_OUTPUT_FASE2.;
/*data INF.BASE_SRS_GS_TRATADA_INF;*/
    set WORK._JOIN_ATUAL;

    prob_mau = _conv_n1 * _fpd_n1;
/*    fl_mau_real = coalesce(&VAR_MAU., 0);*/


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


PROC SQL;
CREATE TABLE &DS_OUTPUT_FASE2._SUM AS
SELECT 
 SAFRA	
,RISCO_CIDADE_SERASA	
,SISTEMA	
,CANAL_PCO_DECISAO	
,CANAL_PCO_AJUSTADO
,OPERACAO	
,tp_pedido	
,DECISAO_ANALISE	
,REASON_CODE	
,DS_REASON_CODE	
,IDENTIFICA_NOVA_ARVORE	
,IDENTIFICA_GRUPO_MODELO	
,GALHO_ARVORE	
,SCORE_HVI3	
,ADICIONAL_G1_BHV	
,ADICIONAL_REST	
,ADICIONAL_G4_BHV	
,ADICIONAL_G5_BHV	
,ADICIONAL_HVI4	
,ADICIONAL_G7_BHV	
,SUM(FL_PROPOSTA) AS FL_PROPOSTA
,SUM(FL_APROVADOS) AS FL_APROVADOS	
,SUM(PROB_CONVERSAO) AS 	PROB_CONVERSAO
,SUM(PROB_MAU) AS PROB_MAU
FROM &DS_OUTPUT_FASE2.
GROUP BY
 SAFRA	
,RISCO_CIDADE_SERASA	
,SISTEMA	
,CANAL_PCO_DECISAO	
,CANAL_PCO_AJUSTADO
,OPERACAO	
,tp_pedido	
,DECISAO_ANALISE	
,REASON_CODE	
,DS_REASON_CODE	
,IDENTIFICA_NOVA_ARVORE	
,IDENTIFICA_GRUPO_MODELO	
,GALHO_ARVORE	
,SCORE_HVI3	
,ADICIONAL_G1_BHV	
,ADICIONAL_REST	
,ADICIONAL_G4_BHV	
,ADICIONAL_G5_BHV	
,ADICIONAL_HVI4	
,ADICIONAL_G7_BHV;
QUIT;

proc export 
    data=&DS_OUTPUT_FASE2._SUM
    outfile="/sasdata/Credito_Estudos/POL/ARTHUR_FONTANA/INFERENCIA/&DS_OUTPUT_FASE2._SUM.csv" 
    dbms=csv 
    replace;
    delimiter=';';   /* define o ; como separador */

run;