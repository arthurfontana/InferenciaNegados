/* ============================================================
   m05_exportar.sas  -  E5: Exportar (sumarizacao final + CSV)
   ------------------------------------------------------------
   OBJETIVO
     Sumarizar a base enriquecida pelo m04 ao grao de saida
     (VAR_SEG + DIMS_SAIDA) e exportar um CSV (delimitador ';')
     para o simulador de politica externo. Re-embrulho agnostico
     do bloco final de "2 - Aplicar Inferencia.sas" (l. 769-827):
     o PROC SQL de sumarizacao + o PROC EXPORT.

     Estrutura do CSV (identica ao legado):
         <DIMS de saida ...>
         FL_PROPOSTA      = SUM(n_propostas)
         FL_APROVADOS     = SUM(n_aprovados)
         PROB_CONVERSAO   = SUM(<metrica de conversao>)
         PROB_MAU         = SUM(<metrica de maus>)

   ------------------------------------------------------------
   QUAL METRICA SOMAR (DoD E5 + regra de ouro 4)

     Por modo (auto), espelhando o DoD:
       ANALITICA  -> PROB_CONVERSAO = SUM(prob_conversao)
                     PROB_MAU       = SUM(prob_mau)
       SUMARIZADA -> PROB_CONVERSAO = SUM(fisico_altas)
                     PROB_MAU       = SUM(fisico_maus)

     REGRA DE OURO 4: NUNCA multiplicar somas entre si. Aqui so
     SE SOMA (nunca SUM(conv)*SUM(fpd)); por isso na sumarizada
     usam-se os fisicos ja prontos do m04 (peso*conv, peso*conv*fpd),
     nunca prob_mau (que so vale na analitica).

     NOTA DE SEMANTICA (ver PENDENCIAS): com o m04 no default
     (peso_fisico=n_aprovados), a SUMARIZADA produz fisico SOBRE
     APROVADOS; a ANALITICA (somando prob_conversao em todas as
     linhas, incl. reprovados) produz fisico SOBRE PROPOSTAS, igual
     ao legado "2 - Aplicar". Para alinhar os dois modos ao mesmo
     fisico, ajuste peso_fisico no m04 (n_propostas reproduz o
     legado) OU informe metrica_conv/metrica_mau aqui.

   ------------------------------------------------------------
   PARAMETROS (todos vem do 00_MASTER.sas)

     ds_entrada      base enriquecida do m04 (default &DS_OUTPUT_INF)
     dims_saida      dimensoes de saida do grao/CSV (default &DIMS_SAIDA)
     var_seg         vars de segmentacao (default &VAR_SEG); entram
                     no grao junto com dims_saida (dedup de tokens)
     caminho_csv     arquivo CSV de saida (default &CAMINHO_CSV)
     ds_sumarizado   dataset sumarizado de saida (default
                     &ds_entrada._SUM)
     modo_base       ANALITICA | SUMARIZADA (default &MODO_BASE)
     col_propostas   coluna de contagem de propostas (default n_propostas)
     col_aprovados   coluna de contagem de aprovados (default n_aprovados)
     metrica_conv    coluna a somar como PROB_CONVERSAO
                     (vazio = auto por modo)
     metrica_mau     coluna a somar como PROB_MAU
                     (vazio = auto por modo)
     exportar_csv    1 = roda o PROC EXPORT (0 = so o dataset _SUM)
     relatorio       1 = imprime um resumo do que foi exportado

   ENTRADAS  : &ds_entrada (do m04).
   SAIDAS    : &ds_sumarizado + arquivo CSV em &caminho_csv.
   DEPENDE DE: E4 (m04_aplicar_inferencia).

   ------------------------------------------------------------
   EXEMPLO DE USO (no 00_MASTER.sas):

     %include "macros/m05_exportar.sas";
     %exportar(
        ds_entrada   = INF.LOG_05_06_MV_INF,
        dims_saida   = SAFRA RISCO_CIDADE_SERASA SISTEMA CANAL_PCO_DECISAO
                       CANAL_PCO_AJUSTADO OPERACAO TP_PEDIDO DECISAO_ANALISE
                       REASON_CODE DS_REASON_CODE IDENTIFICA_NOVA_ARVORE
                       IDENTIFICA_GRUPO_MODELO GALHO_ARVORE SCORE_HVI3
                       ADICIONAL_G1_BHV ADICIONAL_REST ADICIONAL_G4_BHV
                       ADICIONAL_G5_BHV ADICIONAL_HVI4 ADICIONAL_G7_BHV,
        caminho_csv  = /sasdata/Credito_Estudos/POL/ARTHUR_FONTANA/INFERENCIA/saida_sum.csv
     );
   ============================================================ */

%macro exportar(
    ds_entrada=&DS_OUTPUT_INF,
    dims_saida=&DIMS_SAIDA,
    var_seg=&VAR_SEG,
    caminho_csv=&CAMINHO_CSV,
    ds_sumarizado=,
    modo_base=&MODO_BASE,
    col_propostas=n_propostas,
    col_aprovados=n_aprovados,
    metrica_conv=,
    metrica_mau=,
    exportar_csv=1,
    relatorio=1
);

    options validvarname=v7;

    %local _modo grp grp_comma _tok k _n _tp _ta _tc _tm;

    /* ---------- validacoes ---------- */
    %if %length(&ds_entrada) = 0 %then %do;
        %put ERROR: m05_exportar - parametro ds_entrada obrigatorio.;
        %abort cancel;
    %end;
    %if %sysfunc(exist(&ds_entrada.)) = 0 %then %do;
        %put ERROR: Base &ds_entrada nao encontrada (rode o m04 antes).;
        %abort cancel;
    %end;

    %let _modo = %upcase(&modo_base);
    %if %length(&ds_sumarizado) = 0 %then %let ds_sumarizado = &ds_entrada._SUM;

    /* metricas a somar (auto por modo, espelhando o DoD E5) */
    %if %length(&metrica_conv) = 0 %then %do;
        %if &_modo. = ANALITICA %then %let metrica_conv = prob_conversao;
        %else                         %let metrica_conv = fisico_altas;
    %end;
    %if %length(&metrica_mau) = 0 %then %do;
        %if &_modo. = ANALITICA %then %let metrica_mau = prob_mau;
        %else                         %let metrica_mau = fisico_maus;
    %end;

    /* ---------- monta o grao: VAR_SEG + DIMS_SAIDA (dedup tokens)
       mesma logica do m01 sumarizado, p/ o grao do CSV bater com a
       base e com o legado. ---------- */
    %let grp = ;
    %let k = 1;
    %do %while(%scan(&var_seg,&k,%str( )) ne );
        %let grp = &grp %scan(&var_seg,&k,%str( ));
        %let k = %eval(&k+1);
    %end;
    %let k = 1;
    %do %while(%scan(&dims_saida,&k,%str( )) ne );
        %let _tok = %scan(&dims_saida,&k,%str( ));
        %if not %sysfunc(indexw(%upcase(&grp), %upcase(&_tok))) %then
            %let grp = &grp &_tok;
        %let k = %eval(&k+1);
    %end;
    %let grp = %sysfunc(compbl(&grp));
    %let grp_comma = %sysfunc(tranwrd(&grp, %str( ), %str(,)));

    %put NOTE: ===== m05_exportar: entrada=&ds_entrada | modo=&_modo =====;
    %put NOTE: === Grao do CSV: &grp ===;
    %put NOTE: === Metricas: PROB_CONVERSAO=SUM(&metrica_conv) | PROB_MAU=SUM(&metrica_mau) ===;

    /* ========================================================
       BLOCO 1 - SUMARIZACAO AO GRAO DE SAIDA
       Apenas SOMA contagens e fisicos (nunca multiplica somas).
       ======================================================== */
    proc sql;
        create table &ds_sumarizado. as
        select
            &grp_comma.,
            sum(&col_propostas.) as FL_PROPOSTA   label="Propostas (SUM n_propostas)",
            sum(&col_aprovados.) as FL_APROVADOS  label="Aprovados (SUM n_aprovados)",
            sum(&metrica_conv.)  as PROB_CONVERSAO label="Altas inferidas (SUM &metrica_conv)",
            sum(&metrica_mau.)   as PROB_MAU       label="Maus inferidos (SUM &metrica_mau)"
        from &ds_entrada.
        group by &grp_comma.;
    quit;

    /* ========================================================
       BLOCO 2 - EXPORT CSV (delimitador ';')
       ======================================================== */
    %if &exportar_csv. = 1 %then %do;
        %if %length(&caminho_csv) = 0 %then %do;
            %put ERROR: exportar_csv=1 mas caminho_csv vazio. Informe CAMINHO_CSV no master.;
            %abort cancel;
        %end;

        proc export
            data=&ds_sumarizado.
            outfile="&caminho_csv."
            dbms=csv
            replace;
            delimiter=';';
        run;

        %put NOTE: === CSV exportado: &caminho_csv ===;
    %end;
    %else %do;
        %put NOTE: === exportar_csv=0: CSV nao gerado (apenas &ds_sumarizado) ===;
    %end;

    /* ========================================================
       BLOCO 3 - RESUMO DO QUE FOI EXPORTADO
       ======================================================== */
    %if &relatorio. = 1 %then %do;

        proc sql noprint;
            select count(*), sum(FL_PROPOSTA), sum(FL_APROVADOS),
                   sum(PROB_CONVERSAO), sum(PROB_MAU)
              into :_n trimmed, :_tp trimmed, :_ta trimmed,
                   :_tc trimmed, :_tm trimmed
              from &ds_sumarizado.;
        quit;

        data WORK._REL_FASE2_EXP;
            length metrica $44 valor $80;
            tc = &_tc.; tm = &_tm.;
            metrica="Dataset sumarizado";        valor="&ds_sumarizado";                     output;
            metrica="Arquivo CSV";               valor="&caminho_csv";                       output;
            metrica="Linhas no grao de saida";   valor=strip(put(&_n., comma20.));           output;
            metrica="Total FL_PROPOSTA";         valor=strip(put(&_tp., comma20.));          output;
            metrica="Total FL_APROVADOS";        valor=strip(put(&_ta., comma20.));          output;
            metrica="Total PROB_CONVERSAO";      valor=strip(put(tc, comma20.1));            output;
            metrica="Total PROB_MAU";            valor=strip(put(tm, comma20.1));            output;
            metrica="FPD agregada (PROB_MAU/PROB_CONVERSAO)";
                if tc > 0 then valor=strip(put(tm/tc, percent8.2)); else valor="(s/conversao)"; output;
            keep metrica valor;
        run;

        title "FASE 2 - EXPORT: RESUMO DA BASE SUMARIZADA";
        proc print data=WORK._REL_FASE2_EXP noobs label;
            label metrica="Metrica" valor="Valor";
        run;
        title;

        proc datasets library=work nolist; delete _REL_FASE2_EXP; quit;
    %end;

    %put NOTE: ===== m05_exportar concluido -> &ds_sumarizado =====;

%mend exportar;
