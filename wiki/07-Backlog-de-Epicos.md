# 7. Backlog de Épicos

Cada épico = 1 macro/arquivo. Construir na ordem (dependências indicadas). Toda macro é **agnóstica à base** (parâmetros vêm do master) e a lógica estatística é **idêntica** ao legado.

Convenções para todos:
- Cabeçalho do arquivo com: objetivo, parâmetros esperados, pré-requisitos, saídas.
- Encoding **Latin-1** preservado nos `.sas`.
- Fechar todos os blocos (`quit;`/`run;`).
- Não cravar nome de tabela/coluna/filtro dentro da lógica.

---

<a id="e0"></a>
## E0 — Setup & convenções · `macros/m00_setup.sas` · Sessão 1

**Objetivo:** estabelecer o terreno comum: libnames parametrizáveis, `ODS HTML` ligado, `options validvarname=v7`, e as macro vars globais (`OBJETIVO`, `MODO_BASE`, `VAR_SEG`, `VAR_SCORE_FAIXA`).

**Entradas:** valores definidos no master.
**Saídas:** sessão SAS configurada; nenhum dataset.

**Definition of Done:**
- [x] `%macro setup(...)` que recebe os caminhos das libraries e emite os `LIBNAME`.
- [x] Liga `ODS HTML` (saídas legíveis) e desliga `PUT` como canal principal.
- [x] Declara/valida `OBJETIVO` ∈ {REFERENCIA, INFERENCIA, COMPLETO} e `MODO_BASE` ∈ {ANALITICA, SUMARIZADA}, abortando com mensagem clara se inválido.
- [x] Documenta no topo o inventário de parâmetros ([pág. 4](04-Inventario-de-Parametros)).

**Depende de:** nada.

> ✅ **Concluído na Sessão 1** — `macros/m00_setup.sas`. `%setup` emite os `LIBNAME` só dos caminhos preenchidos (+ `libs_extra`), liga `options validvarname=v7 mprint`, abre `ODS HTML`, fecha o `LISTING` e valida `OBJETIVO`/`MODO_BASE` via `indexw` com `%abort cancel`. Arquivo em Latin-1.

---

<a id="e1"></a>
## E1 — Montagem da base · `macros/m01_montar_base.sas` · Sessão 1

**Objetivo:** unificar o que hoje está duplicado em `0 - Gerar base...` e `2 - Aplicar...`. Ler base(s), cruzar o mau, derivar flags, fazer o **colunamento agnóstico** dos scores e **sumarizar ao grão escolhido**.

**Entradas:** `DS_FONTE`, `WHERE_FONTE`, `CHAVE`, `COL_DS_PRINCIPAL`/`COL_FX_SCORE`, `COL_DS_ADICIONAL`/`COL_MODELO_ADICIONAL`, `EXPR_APROVADO`, `EXPR_ALTAS`, `DS_TARGET_MAU`/`CHAVE_MAU`/`VAR_MAU` (se REFERENCIA), `VAR_SEG`, `DIMS_SAIDA`, `MODO_BASE`.
**Saídas:** base de modelagem pronta para o motor, com as 3 colunas de contagem (`n_aprovados`, `n_convertidos`, `n_maus`).

**Definition of Done:**
- [x] Leitura de `DS_FONTE` (lista) com `WHERE_FONTE` parametrizado — sem meses/filtros cravados.
- [x] Cruzamento opcional com `DS_TARGET_MAU` por `CHAVE_MAU` (só quando há target).
- [x] `FL_APROVADOS`/`FL_ALTAS` derivados de `EXPR_APROVADO`/`EXPR_ALTAS`.
- [x] **Colunamento robusto:** PROC TRANSPOSE como hoje, mas os nomes `SCORE_*`/`ADICIONAL_*` resolvidos **automaticamente** via `dictionary.columns` (eliminar os renames com 26 underscores).
- [x] Normalização `CANAL_PCO_AJUSTADO` parametrizável (mapa de-para), uma vez só.
- [x] Geração das 3 colunas de contagem (ver [Motor Unificado](05-Motor-Unificado)).
- [x] `MODO_BASE=SUMARIZADA` → `GROUP BY VAR_SEG DIMS_SAIDA` somando contagens, dropando `CHAVE`/`NR_DOC`. `ANALITICA` → mantém `CHAVE`.
- [x] Comparar contagens totais (aprovados/altas/maus) com o legado para garantir equivalência.

**Depende de:** E0.

> ✅ **Concluído na Sessão 1** — `macros/m01_montar_base.sas`. `%montar_base` unifica os caminhos REFERENCIA (com target de mau) e INFERENCIA (sem target), detectados por `ds_target_mau`/`var_mau` e `expr_altas`. Ordem fiel ao legado: leitura (WHERE/KEEP por membro) → join opcional do mau → dedup `NODUPKEY` → flags → colunamento (TRANSPOSE + rename automático que tira o padding de `_`) → de-para de canal + score `""`/`R99`→pior faixa → 3 contagens (`n_aprovados`/`n_convertidos`/`n_maus` + `n_propostas`) → grão (`ANALITICA` mantém `CHAVE`; `SUMARIZADA` agrega por `VAR_SEG`+`DIMS_SAIDA` deduplicando tokens) → resumo `PROC PRINT` para conferir contra o legado. Arquivo em Latin-1.

---

<a id="e2"></a>
## E2 — Diagnóstico (Fase 0) · `macros/m02_diagnostico.sas` · Sessão 2

**Objetivo:** re-embrulhar a Fase 0 do `1 - Inferiencia.sas` (l. 25–515) como macro, consumindo as 3 colunas de contagem, e **trocar os `PUT` por relatório HTML** com explicabilidade e recomendação.

**Entradas:** base do E1, `VAR_SEG`, `MARGEM_RELATIVA`, `ALPHA`, `PODER`.
**Saídas:** `DS_DIAGNOSTICO` + macro vars `MIN_N`, `MIN_EVENTOS`, `Z_ALFA`, `P_CONV_GLOBAL`, `P_FPD_GLOBAL`.

**Definition of Done:**
- [x] Métricas globais + Wilson invertido + power analysis **idênticos** ao legado (mesmos `MIN_N=230`, `MIN_EVENTOS=62` nos parâmetros validados).
- [x] Classificação VÁLIDA/INSTÁVEL/INVÁLIDA/VAZIA por célula.
- [x] Funciona em ANALITICA e SUMARIZADA (via `sum(n_*)`).
- [x] **Relatório HTML** (`PROC REPORT`) com: thresholds derivados, cobertura por status, % da base coberta.
- [x] **Bloco de explicabilidade + recomendação** automático: interpreta a cobertura, sinaliza risco (ex.: alerta PAP / grupo MÉDIA), e sugere próxima ação — texto que o usuário traz de volta para a IA.

**Depende de:** E1.

> ✅ **Concluído na Sessão 2** — `macros/m02_diagnostico.sas`. `%diagnostico` consome as 3 contagens do motor (`sum(n_aprovados/n_convertidos/n_maus)` → idêntico em ANALITICA/SUMARIZADA; `having sum(n_aprovados)>0` reproduz o `where FL_APROVADOS=1` do legado e evita 0/0). Blocos: (1) globais → `P_CONV_GLOBAL`/`P_FPD_GLOBAL`; (2) Wilson invertido + power analysis **verbatim** → exporta `MIN_N`/`MIN_EVENTOS`/`Z_ALFA` como **GLOBAIS** (`call symputx(...,'G')`, essencial p/ a Fase 1 enxergar); (3) IC de Wilson por célula (fórmulas idênticas, `calculated`); (4) classificação VÁLIDA/INSTÁVEL/INVÁLIDA/VAZIA; (5) `PROC REPORT` de cobertura (células + volume aprovado + % da base por status); (6) **explicabilidade**: risco de fallback por dimensão colapsável (última de `VAR_SEG`) que aflora o problema do PAP dinamicamente, + recomendações textuais (cobertura, thresholds, próxima ação); (7) `FASE0_THRESHOLDS` permanente. Math conferida fora do SAS: 0.40/0.07/0.75 → `MIN_N=230`, `MIN_EVENTOS=62` (binding = power analysis do FPD). Escrito em **ASCII puro** (sem acentos) p/ neutralizar o risco de encoding, igual ao m00/m01.

---

<a id="e3"></a>
## E3 — Tabela de referência (Fase 1) · `macros/m03_tabela_referencia.sas` · Sessão 2

**Objetivo:** re-embrulhar a Fase 1 (`1 - Inferiencia.sas` l. 517–1409) como macro. Lógica **idêntica**.

**Entradas:** base do E1, `VAR_SEG`, `VAR_SCORE_FAIXA`, `K_EXPONENCIAL`, macro vars do E2.
**Saídas:** `DS_TABELA_REF` com `taxa_conversao_ref`, `taxa_fpd_ref`, ICs de Wilson, `nivel_usado`, `confiabilidade`.

**Definition of Done:**
- [x] Reaproveita `monta_niveis`, `agrega_nivel`, `loop_niveis`, `empilha_niveis`, `empilha_validos`, `prefix_vars`, `join_cond`, `seleciona_melhor_nivel`, `deriva_k`, `extrapola_caudas`.
- [x] Fallback hierárquico **nunca colapsa o score**; colapsa da direita para a esquerda.
- [x] Extrapolação exponencial `FPD = FPD_âncora × exp(k·dist)`; ICs propagados proporcionalmente à âncora.
- [x] ICs **sem sufixo `_ref`** (compatível com Fase 2).
- [x] Relatório HTML de confiabilidade (ALTA/MÉDIA/BAIXA/EXTRAPOLADO).

**Depende de:** E1, E2.

> ✅ **Concluído na Sessão 2** — `macros/m03_tabela_referencia.sas`. As 10 macros auxiliares do legado (`monta_niveis`, `agrega_nivel`, `loop_niveis`, `empilha_niveis`, `empilha_validos`, `prefix_vars`, `join_cond`, `seleciona_melhor_nivel`, `deriva_k`, `extrapola_caudas`) foram portadas **verbatim** na lógica; só `agrega_nivel` mudou a fonte de contagem (`sum(n_*)` + `having sum(n_aprovados)>0` no lugar de `count(*)`/`where FL_APROVADOS=1`) — idêntico em ANALITICA/SUMARIZADA. A driver `%tabela_referencia` monta o contexto (nomes do legado em **macro vars GLOBAIS** p/ as auxiliares e p/ que `ANCORA_*`/`K_EXP_DERIVADO`, setadas dentro das macros via `INTO`, sobrevivam até os relatórios) e chama tudo na ordem. Mantidos: score (1ª var) **nunca** colapsado; fallback colapsa da direita p/ a esquerda; join hierárquico por **todas** as vars do nível; toda geração com `%do` **dentro** de `%macro` (armadilha do `%DO` em open code); extrapolação `FPD = FPD_âncora·exp(k·dist)` com ICs proporcionais à âncora; ICs **sem** sufixo `_ref`; `confiabilidade` ALTA/MÉDIA/BAIXA/EXTRAPOLADO; `PROC REPORT` final de confiabilidade. Pré-requisito validado via `%valida_fase0` (aborta se faltarem `MIN_N`/`MIN_EVENTOS`/`Z_ALFA`). Escrito em **ASCII puro**.

---

<a id="e4"></a>
## E4 — Aplicar inferência (Fase 2) · `macros/m04_aplicar_inferencia.sas` · Sessão 3

**Objetivo:** macro **única** da Fase 2 (hoje duplicada em arq.1 e arq.2). Enriquece a base com as premissas.

**Entradas:** `DS_NOVO`, `DS_TABELA_REF`, `VAR_SEG`, `VAR_SCORE_FAIXA`, `MODO_BASE`, `FL_MANTER_ORIG`, `DS_OUTPUT_INF`.
**Saídas:** base enriquecida com `prob_conversao`, `prob_fpd`, `prob_mau`/físicos, `nivel_premissa`, `confiabilidade_premissa`, ICs.

**Definition of Done:**
- [x] Reaproveita `join_hierarquico` (cascata por nível).
- [x] **ANALITICA:** join linha a linha (como hoje), `prob_mau = prob_conv × prob_fpd`.
- [x] **SUMARIZADA:** `físico_altas = n_aprovados × conv`, `físico_maus = n_aprovados × conv × fpd` (ver [Motor Unificado](05-Motor-Unificado)).
- [x] Flag `fl_sem_premissa` para propostas/células sem match.
- [x] Backtest opcional (real × inferido) quando `OBJETIVO=REFERENCIA`, respeitando as regras de ouro.
- [x] Relatório HTML de cobertura das premissas.

**Depende de:** E3 (tabela de referência existente).

> ✅ **Concluído na Sessão 3** — `macros/m04_aplicar_inferencia.sas`. A `join_hierarquico` foi **portada verbatim** do legado (cascata por nível, `LEFT JOIN`, fallback do mais granular ao mais colapsado, join por **todas** as vars do nível), agnóstica via GLOBAIS (`DS_NOVO_F2`/`DS_TABELA_REF_F2`/`VARSEG_F2`) e com a geração dinâmica de SQL **dentro** da `%macro` (armadilha do `%DO` em open code). A driver `%aplicar_inferencia` enriquece a base com `prob_conversao`/`prob_fpd` + metadados (`nivel_premissa`, `vars_premissa`, `confiabilidade_premissa`, `fl_premissa_extrapolada`, `fl_sem_premissa`, `n_*_referencia`, ICs **sem** `_ref`). **Dual-mode:** `prob_mau = prob_conv × prob_fpd` só na ANALITICA (regra de ouro 4); `fisico_altas = peso × conv` e `fisico_maus = peso × conv × fpd` nos dois modos (`peso` = `peso_fisico`, default `n_aprovados`). **Backtest** (`backtest=AUTO`, dispara quando a base tem os reais) sempre pondera por `n_aprovados` (independente de `peso_fisico`) e calcula `FPD = SUM(fisico_maus)/SUM(fisico_altas)` — respeita as 4 regras de ouro. `PROC REPORT` de cobertura por confiabilidade (células + volume). Bugs de sintaxe corrigidos antes do commit (KEEP com vírgulas/`;` solto, `%then` sem `%do`). Escrito em **ASCII puro**. **PENDÊNCIA:** semântica do físico — `n_aprovados` (DoD/Motor, sobre aprovados) × `n_propostas` (legado "2 - Aplicar", sobre todas as propostas / abertura p/ reprovados). Default = `n_aprovados`; troca por `peso_fisico=n_propostas`.

---

<a id="e5"></a>
## E5 — Exportar · `macros/m05_exportar.sas` · Sessão 3

**Objetivo:** sumarização final por `DIMS_SAIDA` + `PROC EXPORT` CSV para o simulador externo.

**Entradas:** base do E4, `DIMS_SAIDA`, `CAMINHO_CSV`.
**Saídas:** dataset sumarizado + arquivo CSV (delimitador `;`).

**Definition of Done:**
- [x] `GROUP BY DIMS_SAIDA` com `SUM(FL_PROPOSTA)`, `SUM(FL_APROVADOS)`, `SUM(prob_conversao/físico_altas)`, `SUM(prob_mau/físico_maus)`.
- [x] **Não** multiplicar somas entre si (regra de ouro 4).
- [x] `PROC EXPORT` para `CAMINHO_CSV` parametrizado, `dbms=csv`, `delimiter=';'`.

**Depende de:** E4.

> ✅ **Concluído na Sessão 3** — `macros/m05_exportar.sas`. `%exportar` sumariza a base do m04 ao grão **VAR_SEG + DIMS_SAIDA** (mesma dedup de tokens do m01 sumarizado, garantindo que o grão do CSV bata com a base e com o legado) e gera o CSV (`PROC EXPORT dbms=csv delimiter=';'`). Colunas do CSV **idênticas em estrutura** ao legado: `FL_PROPOSTA`=SUM(n_propostas), `FL_APROVADOS`=SUM(n_aprovados), `PROB_CONVERSAO` e `PROB_MAU`. Métricas auto por modo (espelha o DoD): ANALITICA → `SUM(prob_conversao)`/`SUM(prob_mau)`; SUMARIZADA → `SUM(fisico_altas)`/`SUM(fisico_maus)` — **só soma, nunca `SUM×SUM`** (regra de ouro 4). `metrica_conv`/`metrica_mau` permitem sobrepor. Resumo final via `PROC PRINT` (totais + FPD agregada). Escrito em **ASCII puro**.

---

<a id="e6"></a>
## E6 — Master & integração · `00_MASTER.sas` · Sessão 3

**Objetivo:** o orquestrador. `%include` de todas as macros + blocos de chamada com **exemplos preenchidos**, governados por `OBJETIVO`/`MODO_BASE`.

**Definition of Done:**
- [x] Cabeçalho = inventário completo de parâmetros ([pág. 4](04-Inventario-de-Parametros)).
- [x] `%include "macros/m00_setup.sas"` … até `m05`.
- [x] Blocos comentados por fase, cada um com a chamada de macro de exemplo.
- [x] Lógica de `OBJETIVO` decide quais macros rodam.
- [x] Smoke test ponta a ponta documentado (o usuário roda no SASApp).

**Depende de:** E0–E5.

> ✅ **Concluído na Sessão 3** — `00_MASTER.sas`. Cabeçalho com os **dois interruptores** (`OBJETIVO`/`MODO_BASE`) e o **inventário completo de parâmetros** (pág. 4). PARTE A centraliza todos os `%let` (globais, segmentação, parâmetros validados 0.40/0.07/0.75, datasets de saída, montagem da base com os filtros/colunas reais do legado, gancho PAP opcional). PARTE B faz `%include` de m00..m05; PARTE C chama `%setup`; PARTE D é a `%macro pipeline` que decide o que roda por `OBJETIVO` (REFERENCIA→m01→m02→m03+backtest; INFERENCIA→m01→m04→m05; COMPLETO→tudo), com toda a lógica de `%if` **dentro** de `%macro` (armadilha do `%if`/`%do` em open code) e cada fase com sua chamada de exemplo preenchida. PARTE E documenta o **smoke test ponta a ponta** (os 3 valores de `OBJETIVO`, esperados, e a nota da semântica do físico). Toggles `RODAR_M01`/`RODAR_BACKTEST`. Escrito em **ASCII puro**.
