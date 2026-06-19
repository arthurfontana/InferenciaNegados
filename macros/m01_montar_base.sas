/* ============================================================
   m01_montar_base.sas  -  E1: Montagem da base
   ------------------------------------------------------------
   OBJETIVO
     Unificar, numa unica macro agnostica a base, o que hoje
     esta duplicado em "0 - Gerar base para referencia da
     Inferencia.sas" (caminho REFERENCIA, com targets observados)
     e em "2 - Aplicar Inferencia.sas" (caminho INFERENCIA, base
     nova sem targets).

     A macro faz, na ordem do legado:
       1) le base(s) de entrada com WHERE/KEEP parametrizados;
       2) renomeia colunas descritivas (mapa opcional);
       3) deduplica por CHAVE;
       4) (so REFERENCIA) cruza a base de mau/FPD por CHAVE_MAU;
       5) deriva FL_PROPOSTA / FL_APROVADOS / FL_ALTAS e remove
          linhas sem as 4 colunas do pivot;
       6) COLUNAMENTO robusto: PROC TRANSPOSE como no legado, mas
          os nomes SCORE_* / ADICIONAL_* sao resolvidos
          automaticamente via dictionary.columns (sem os renames
          cravados com 26 underscores);
       7) normaliza CANAL_PCO_AJUSTADO (mapa de-para, num lugar so)
          e colapsa score sem info (""/R99) para a pior faixa;
       8) gera as 3 colunas de contagem do motor unificado
          (n_aprovados, n_convertidos, n_maus) + n_propostas;
       9) entrega no grao escolhido:
          ANALITICA  -> mantem CHAVE (1 linha/proposta, 0/1);
          SUMARIZADA -> GROUP BY VAR_SEG + DIMS_SAIDA somando as
                        contagens e dropando CHAVE/CHAVE_SEC;
      10) imprime um resumo de contagens para conferir x legado.

     A matematica das 3 contagens segue o Motor Unificado
     (wiki pag. 5):
       n_aprovados   = FL_APROVADOS
       n_convertidos = FL_APROVADOS * FL_ALTAS
       n_maus        = FL_APROVADOS * FL_ALTAS * VAR_MAU

   ------------------------------------------------------------
   PARAMETROS (todos vem do 00_MASTER.sas - nada cravado aqui)

     -- Leitura --
     ds_fonte         lista de base(s) de entrada (nomes separados por espaco)
     where_fonte      filtro de leitura (aplicado como opcao de dataset por membro)
     keep_fonte       (opcional) lista KEEP para reduzir I/O na leitura
     renomear         (opcional) mapa "OLD=NEW OLD2=NEW2" aplicado por RENAME

     -- Chave / dedup --
     chave            chave da proposta (default NR_PROPOSTA)
     chave_sec        chave secundaria a dropar no sumarizado (default NR_DOC)
     dedup            1 = PROC SORT NODUPKEY BY chave (default 1)

     -- Alvo (mau) - so quando ha target (REFERENCIA) --
     ds_target_mau    base de onde vem o mau (ex.: ONED.FPD_ONEDATA)
     chave_mau        chave de cruzamento com a base de mau (default NR_PROPOSTA)
     cols_target      colunas a trazer do target (ex.: as flags de FL_ALTAS + VAR_MAU)
     var_mau          coluna que representa o mau/FPD (ex.: fl_atrs_parc_over_30)

     -- Flags --
     expr_aprovado    regra de FL_APROVADOS (ex.: DECISAO_ANALISE="APROVADO")
     expr_altas       regra de FL_ALTAS (so REFERENCIA)

     -- Colunamento (nomes das 4 colunas do pivot na FONTE) --
     col_ds_principal      coluna que NOMEIA o score    (default DS_VAR_PRINCIPAL)
     col_fx_score          coluna que traz o VALOR score (default FAIXA_SCORE)
     col_ds_adicional      coluna que NOMEIA o adicional (default DS_VAR_ADICIONAL)
     col_modelo_adicional  coluna com o VALOR adicional  (default MODELO_ADICIONAL)

     -- Segmentacao / saida --
     var_seg          vars de segmentacao (default &VAR_SEG)
     var_score_faixa  var de score/faixa  (default &VAR_SCORE_FAIXA)
     dims_saida       dimensoes extras mantidas no grao sumarizado

     -- Canal e score --
     col_canal           coluna de canal cru (default CANAL_PCO_DECISAO)
     col_canal_ajustado  coluna de canal normalizado (default CANAL_PCO_AJUSTADO)
     score_pior_faixa    faixa-ancora para score sem info (default R20)
     score_sem_info      valor de score "sem info" alem de "" (default R99)

     -- Modo / saida --
     modo_base        ANALITICA | SUMARIZADA (default &MODO_BASE)
     ds_saida         dataset de saida (default WORK.BASE_MODELAGEM)
     comparar_legado  1 = imprime resumo de contagens (default 1)

   ENTRADAS  : base(s) de log + (se REFERENCIA) base de mau.
   SAIDAS    : &ds_saida pronta para o motor, com n_aprovados /
               n_convertidos / n_maus / n_propostas.
   DEPENDE DE: E0 (m00_setup ja rodado: libnames + validvarname=v7).

   ------------------------------------------------------------
   EXEMPLO REFERENCIA (equivale ao "0 - Gerar base..."):

     %montar_base(
       ds_fonte    = LOG_NOVO.LOGS_PCO_B2C_202605 LOG_NOVO.LOGS_PCO_B2C_202606,
       where_fonte = %str(IDENTIFICA_NOVA_ARVORE="NOVO FLUXO B2C" and ORIGEM="AM" and FL_DEDUP_CNL_DIA=1),
       keep_fonte  = LOGIN_SOLICITANTE NR_PROPOSTA NR_DOC SAFRA_CNST DT_CNST
                     RISCO_CEP_CALC_PCO ORIGEM CANAL_PCO_DECISAO OPERACAO TP_PEDIDO
                     BUREAU_PCO RESTRITIVOS_SERASA RGNL_CNST DS_VAR_PRINCIPAL FAIXA_SCORE
                     DS_VAR_ADICIONAL MODELO_ADICIONAL DECISAO_ANALISE REASON_CODE
                     DS_REASON_CODE CD_SCORE POLITICA_NOVA IDENTIFICA_NOVA_ARVORE
                     IDENTIFICA_GRUPO_MODELO GALHO_ARVORE FL_DEDUP_CNL_DIA,
       renomear    = SAFRA_CNST=SAFRA RISCO_CEP_CALC_PCO=RISCO_CIDADE_SERASA
                     ORIGEM=SISTEMA CD_SCORE=OFERTA,
       ds_target_mau = ONED.FPD_ONEDATA,
       chave_mau     = NR_PROPOSTA,
       cols_target   = fl_ftra_parc_over_30 fl_atrs_parc_over_30 FL_REDUTOR
                       FL_FATURADO FL_PLNO_ZERO FL_LNHA_FICT FL_DEDUP_CONTA,
       var_mau       = fl_atrs_parc_over_30,
       expr_aprovado = %str(DECISAO_ANALISE="APROVADO"),
       expr_altas    = %str(FL_FATURADO=1 and FL_REDUTOR=0 and FL_PLNO_ZERO=0
                            and FL_LNHA_FICT=0 and FL_DEDUP_CONTA=1),
       dims_saida    = SAFRA RISCO_CIDADE_SERASA SISTEMA CANAL_PCO_DECISAO OPERACAO
                       TP_PEDIDO DECISAO_ANALISE IDENTIFICA_NOVA_ARVORE
                       IDENTIFICA_GRUPO_MODELO GALHO_ARVORE,
       ds_saida      = INF.BASE_MODELAGEM_AM
     );

   EXEMPLO INFERENCIA (equivale ao "2 - Aplicar Inferencia.sas",
   base nova sem targets): basta omitir ds_target_mau/cols_target/
   var_mau/expr_altas.
   ============================================================ */

%macro montar_base(
    /* leitura */
    ds_fonte=, where_fonte=, keep_fonte=, renomear=,
    /* chave / dedup */
    chave=NR_PROPOSTA, chave_sec=NR_DOC, dedup=1,
    /* alvo (mau) - so REFERENCIA */
    ds_target_mau=, chave_mau=NR_PROPOSTA, cols_target=, var_mau=,
    /* flags */
    expr_aprovado=, expr_altas=,
    /* colunamento (nomes na fonte) */
    col_ds_principal=DS_VAR_PRINCIPAL, col_fx_score=FAIXA_SCORE,
    col_ds_adicional=DS_VAR_ADICIONAL, col_modelo_adicional=MODELO_ADICIONAL,
    /* segmentacao / saida */
    var_seg=&VAR_SEG, var_score_faixa=&VAR_SCORE_FAIXA, dims_saida=,
    /* canal e score */
    col_canal=CANAL_PCO_DECISAO, col_canal_ajustado=CANAL_PCO_AJUSTADO,
    score_pior_faixa=R20, score_sem_info=R99,
    /* modo / saida */
    modo_base=&MODO_BASE, ds_saida=WORK.BASE_MODELAGEM,
    comparar_legado=1
);

    %local _tem_target _tem_altas i membro setlist cols_b c j grp grp_comma
           _tp _ta _tc _tm bycols renclean;

    /* Tem target de mau? (REFERENCIA) */
    %let _tem_target = %eval(%length(&ds_target_mau) > 0 and %length(&var_mau) > 0);
    /* Deriva FL_ALTAS? */
    %let _tem_altas  = %eval(%length(&expr_altas) > 0);

    options validvarname=v7;

    %put NOTE: ===== m01_montar_base: modo=&modo_base | target=&_tem_target | altas=&_tem_altas =====;

    /* ---------------------------------------------------------
       1) Leitura: aplica WHERE/KEEP como opcoes de dataset
          POR MEMBRO (igual ao legado, eficiente em I/O).
    --------------------------------------------------------- */
    %let setlist=;
    %let i=1;
    %do %while(%scan(&ds_fonte,&i,%str( )) ne );
        %let membro=%scan(&ds_fonte,&i,%str( ));
        %let setlist=&setlist &membro(%if %length(&where_fonte) %then %do;where=(&where_fonte) %end;%if %length(&keep_fonte) %then %do;keep=&keep_fonte %end;);
        %let i=%eval(&i+1);
    %end;

    data _mb_log;
        set &setlist;
        %if %length(&renomear) %then %do; rename &renomear; %end;
    run;

    /* ---------------------------------------------------------
       2) Cruzamento opcional com a base de mau (so REFERENCIA)
          (igual ao legado: o join vem ANTES do dedup)
    --------------------------------------------------------- */
    %if &_tem_target %then %do;

        /* monta lista "b.col" das colunas vindas do target */
        %let cols_b=;
        %let j=1;
        %do %while(%scan(&cols_target,&j,%str( )) ne );
            %let c=%scan(&cols_target,&j,%str( ));
            %let cols_b=&cols_b, b.&c;
            %let j=%eval(&j+1);
        %end;

        %if %length(&cols_target) = 0 %then
            %put WARNING: ds_target_mau informado mas cols_target vazio - nenhuma coluna de mau sera trazida.;

        proc sql;
            create table _mb_alvo as
            select a.* &cols_b
            from _mb_log a
            left join &ds_target_mau b
              on a.&chave = b.&chave_mau;
        quit;

    %end;
    %else %do;
        data _mb_alvo; set _mb_log; run;
    %end;

    /* ---------------------------------------------------------
       3) Dedup por chave (apos o join, como no legado)
    --------------------------------------------------------- */
    %if &dedup = 1 %then %do;
        proc sort data=_mb_alvo nodupkey; by &chave; run;
    %end;

    /* ---------------------------------------------------------
       4) Flags + remocao de linhas sem as 4 colunas do pivot
    --------------------------------------------------------- */
    data _mb_base;
        set _mb_alvo;

        FL_PROPOSTA = 1;

        if &expr_aprovado then FL_APROVADOS = 1; else FL_APROVADOS = 0;

        %if &_tem_altas %then %do;
            FL_ALTAS = (&expr_altas);
        %end;

        if &col_ds_principal = "" or &col_fx_score = ""
           or &col_ds_adicional = "" or &col_modelo_adicional = "" then delete;
    run;

    /* ---------------------------------------------------------
       5) COLUNAMENTO
          5a) BY = todas as colunas menos as 4 do pivot
    --------------------------------------------------------- */
    proc sql noprint;
        select name
          into :bycols separated by ' '
        from dictionary.columns
        where libname = 'WORK'
          and memname = '_MB_BASE'
          and upcase(name) not in (
                %upcase("&col_ds_principal"), %upcase("&col_fx_score"),
                %upcase("&col_ds_adicional"), %upcase("&col_modelo_adicional"));
    quit;

    %put NOTE: BYCOLS = &bycols;

    /* 5b) prep SCORE_<DS_VAR_PRINCIPAL> = valor do score */
    data _mb_prin_prep;
        set _mb_base;
        length _id $32 _raw $200;
        _raw = upcase(strip(&col_ds_principal));
        _raw = prxchange('s/[^A-Z0-9_]/_/o', -1, _raw);
        if not (('A' <= substr(_raw,1,1) <= 'Z') or substr(_raw,1,1) = '_') then
            _raw = cats('_', _raw);
        _raw = substr(_raw, 1, 32 - length('SCORE_'));
        _id  = cats('SCORE_', _raw);
        _value = &col_fx_score;
        keep &bycols _id _value;
    run;

    /* 5c) prep ADICIONAL_<DS_VAR_ADICIONAL ou DS_VAR_PRINCIPAL> = valor adicional */
    data _mb_adic_prep;
        set _mb_base;
        length _id $32 _raw $200 _ds $200;
        _ds  = coalescec(strip(&col_ds_adicional), strip(&col_ds_principal));
        _raw = upcase(strip(_ds));
        _raw = prxchange('s/[^A-Z0-9_]/_/o', -1, _raw);
        if not (('A' <= substr(_raw,1,1) <= 'Z') or substr(_raw,1,1) = '_') then
            _raw = cats('_', _raw);
        _raw = substr(_raw, 1, 32 - length('ADICIONAL_'));
        _id  = cats('ADICIONAL_', _raw);
        _value = &col_modelo_adicional;
        keep &bycols _id _value;
    run;

    /* 5d) deduplica por BY + _id (mantem ultima ocorrencia) */
    proc sort data=_mb_prin_prep; by &bycols _id; run;
    proc sort data=_mb_adic_prep; by &bycols _id; run;

    data _mb_prin_prep2; set _mb_prin_prep; by &bycols _id; if last._id; run;
    data _mb_adic_prep2; set _mb_adic_prep; by &bycols _id; if last._id; run;

    /* 5e) transpose (wide) */
    proc transpose data=_mb_prin_prep2 out=_mb_prin_wide(drop=_name_);
        by &bycols; id _id; var _value;
    run;
    proc transpose data=_mb_adic_prep2 out=_mb_adic_wide(drop=_name_);
        by &bycols; id _id; var _value;
    run;

    /* 5f) junta os dois blocos */
    proc sort data=_mb_prin_wide; by &bycols; run;
    proc sort data=_mb_adic_wide; by &bycols; run;

    data _mb_wide;
        merge _mb_prin_wide _mb_adic_wide;
        by &bycols;
    run;

    /* 5g) COLUNAMENTO ROBUSTO: resolve nomes SCORE_*/ADICIONAL_*
           automaticamente, removendo eventuais underscores de
           padding deixados pelo transpose (elimina os renames
           cravados com 26 underscores do legado). */
    proc sql noprint;
        select catx('=', name, prxchange('s/_+$//o', -1, strip(name)))
          into :renclean separated by ' '
        from dictionary.columns
        where libname = 'WORK'
          and memname = '_MB_WIDE'
          and ( upcase(name) like 'SCORE\_%'     escape '\'
             or upcase(name) like 'ADICIONAL\_%' escape '\' )
          and strip(name) ne prxchange('s/_+$//o', -1, strip(name));
    quit;

    %if %length(&renclean) %then %do;
        proc datasets library=work nolist;
            modify _mb_wide;
            rename &renclean;
        quit;
    %end;

    /* ---------------------------------------------------------
       6) Canal normalizado (mapa de-para, num lugar so) +
          score sem info -> pior faixa + 3 contagens do motor
    --------------------------------------------------------- */
    data _mb_motor;
        set _mb_wide;

        length &col_canal_ajustado $30;

        if &col_canal in ("CANAIS INTERNOS","CANAL NAO MAPEADO","INBOUND",
                          "LOJA PROPRIA","LOJAS PROPRIAS","OUTROS","RETENCAO",
                          "REVENDA","SINERGIA B2B2C","WEB DEALERS","WEB_DEALERS")
            then &col_canal_ajustado = "OUTROS";
        else if &col_canal in ("CROSS SELLING","CROSSELING")
            then &col_canal_ajustado = "CROSSELING";
        else if &col_canal = "DIGITAL"  then &col_canal_ajustado = "DIGITAL";
        else if &col_canal = "OUTBOUND" then &col_canal_ajustado = "OUTBOUND";
        else if &col_canal in ("PAP","PAP 2.0","PAP TORDESILHAS")
            then &col_canal_ajustado = "PAP";
        else if &col_canal in ("URA ATIVACAO","URA_ATIVACAO")
            then &col_canal_ajustado = "URA_ATIVACAO";
        else &col_canal_ajustado = "OUTROS";   /* fallback */

        /* score sem info (""/R99) colapsa para a pior faixa (ancora) */
        if &var_score_faixa = "" or &var_score_faixa = "&score_sem_info"
            then &var_score_faixa = "&score_pior_faixa";

        /* 3 colunas de contagem do motor unificado (wiki pag. 5) */
        n_propostas = FL_PROPOSTA;
        n_aprovados = FL_APROVADOS;
        %if &_tem_altas %then %do;
            n_convertidos = FL_APROVADOS * FL_ALTAS;
        %end;
        %if &_tem_target and &_tem_altas %then %do;
            n_maus = FL_APROVADOS * FL_ALTAS * coalesce(&var_mau, 0);
        %end;
    run;

    /* ---------------------------------------------------------
       7) Grao de saida
    --------------------------------------------------------- */
    %if %upcase(&modo_base) = ANALITICA %then %do;

        /* mantem a CHAVE (1 linha por proposta, contagens 0/1) */
        data &ds_saida;
            set _mb_motor;
        run;

    %end;
    %else %do;

        /* SUMARIZADA: soma as contagens ao grao VAR_SEG + DIMS_SAIDA,
           dropando CHAVE/CHAVE_SEC.
           Monta o grao deduplicando tokens (DIMS_SAIDA pode repetir
           colunas que ja estao em VAR_SEG) para nao gerar coluna
           duplicada no SELECT/GROUP BY. */
        %local _tok k;
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

        proc sql;
            create table &ds_saida as
            select &grp_comma,
                   sum(n_propostas) as n_propostas,
                   sum(n_aprovados) as n_aprovados
                   %if &_tem_altas %then , sum(n_convertidos) as n_convertidos;
                   %if &_tem_target and &_tem_altas %then , sum(n_maus) as n_maus;
            from _mb_motor
            group by &grp_comma;
        quit;

    %end;

    /* ---------------------------------------------------------
       8) Resumo de contagens (conferir contra o legado)
    --------------------------------------------------------- */
    %if &comparar_legado = 1 %then %do;

        proc sql noprint;
            select sum(n_propostas), sum(n_aprovados)
              into :_tp trimmed, :_ta trimmed
            from &ds_saida;
            %if &_tem_altas %then %do;
                select sum(n_convertidos) into :_tc trimmed from &ds_saida;
            %end;
            %if &_tem_target and &_tem_altas %then %do;
                select sum(n_maus) into :_tm trimmed from &ds_saida;
            %end;
        quit;

        data _mb_resumo;
            length metrica $40 valor $40;
            metrica = "Base de saida";              valor = "&ds_saida";                              output;
            metrica = "Modo";                       valor = "%upcase(&modo_base)";                   output;
            metrica = "Propostas (FL_PROPOSTA)";    valor = strip(put(&_tp, comma20.));              output;
            metrica = "Aprovados (FL_APROVADOS)";   valor = strip(put(&_ta, comma20.));              output;
            %if &_tem_altas %then %do;
            metrica = "Convertidos (FL_ALTAS)";     valor = strip(put(&_tc, comma20.));              output;
            metrica = "Taxa de conversao";          valor = strip(put(&_tc/&_ta, percent8.2));       output;
            %end;
            %if &_tem_target and &_tem_altas %then %do;
            metrica = "Maus (n_maus)";              valor = strip(put(&_tm, comma20.));              output;
            metrica = "Taxa de FPD";                valor = strip(put(&_tm/&_tc, percent8.2));       output;
            %end;
        run;

        title "m01 - Resumo da base montada (conferir contra o legado)";
        proc print data=_mb_resumo noobs label;
            label metrica = "Metrica" valor = "Valor";
        run;
        title;

    %end;

    /* ---------------------------------------------------------
       9) Limpeza dos intermediarios
    --------------------------------------------------------- */
    proc datasets library=work nolist;
        delete _mb_log _mb_alvo _mb_base
               _mb_prin_prep _mb_prin_prep2 _mb_prin_wide
               _mb_adic_prep _mb_adic_prep2 _mb_adic_wide
               _mb_wide _mb_motor;
    quit;

    %put NOTE: ===== m01_montar_base concluido -> &ds_saida =====;

%mend montar_base;
