# 9. Prompts das Sessões

Cole o prompt correspondente **no início** de cada sessão futura (memória zerada). Cada um já aponta para as páginas da wiki e os arquivos legados com todo o contexto necessário.

Regras válidas para **todas** as sessões:
- Ler `CONTEXTO.md`, `CLAUDE.md` e as páginas da wiki citadas **antes** de codar.
- Lógica estatística **idêntica** ao legado — só re-embrulhar e parametrizar.
- Macros **agnósticas à base**: nada de tabela/coluna/filtro cravado.
- `.sas` em **ISO-8859-1 / Latin-1** — preservar encoding.
- Sem runtime SAS: revisar sintaxe manualmente, fechar todos os blocos.
- Ao final: commitar na branch, atualizar status do épico na Home e na pág. 7.

---

## Prompt — Sessão 1 (E0 + E1: Fundação & Base)

```
Estou reconstruindo o sistema de inferência de negados conforme o planejamento na wiki
do repositório. Esta é a SESSÃO 1, que entrega os épicos E0 e E1.

Antes de codar, leia: CONTEXTO.md, CLAUDE.md e as páginas da wiki (pasta wiki/):
Home, 01-Contexto-e-Objetivo, 03-Arquitetura-Alvo, 04-Inventario-de-Parametros,
05-Motor-Unificado, 06-Regras-de-Ouro-e-Armadilhas, 07-Backlog-de-Epicos (épicos E0 e E1).
Use como fonte da lógica os arquivos legados "0 - Gerar base para referencia da Inferencia.sas"
e "2 - Aplicar Inferencia.sas".

Construa:
1) macros/m00_setup.sas (E0): libnames parametrizáveis, ODS HTML, options validvarname=v7,
   validação de OBJETIVO e MODO_BASE.
2) macros/m01_montar_base.sas (E1): uma única macro %montar_base(...) que lê DS_FONTE (lista)
   com WHERE_FONTE, cruza opcionalmente DS_TARGET_MAU por CHAVE_MAU, deriva FL_APROVADOS/FL_ALTAS
   a partir de EXPR_APROVADO/EXPR_ALTAS, faz o colunamento dos scores (PROC TRANSPOSE) resolvendo
   os nomes SCORE_*/ADICIONAL_* automaticamente via dictionary.columns (sem o hardcode de 26
   underscores), normaliza CANAL_PCO_AJUSTADO de forma parametrizável, gera as 3 colunas de
   contagem (n_aprovados, n_convertidos, n_maus) e, se MODO_BASE=SUMARIZADA, agrupa por
   VAR_SEG + DIMS_SAIDA somando as contagens e dropando NR_PROPOSTA/NR_DOC; se ANALITICA, mantém a chave.

Respeite o Motor Unificado (pág. 5) e as Regras de Ouro (pág. 6). Não reescreva matemática.
Cumpra a Definition of Done de E0 e E1 na pág. 7. Ao terminar, commite na branch e atualize o
status dos épicos na Home e na pág. 7.
```

---

## Prompt — Sessão 2 (E2 + E3: Motor estatístico)

```
Reconstrução do sistema de inferência de negados — SESSÃO 2, épicos E2 e E3. Os épicos E0 e E1
já estão prontos (macros/m00_setup.sas e macros/m01_montar_base.sas).

Antes de codar, leia: CONTEXTO.md, CLAUDE.md e as páginas da wiki: Home, 03-Arquitetura-Alvo,
04-Inventario-de-Parametros, 05-Motor-Unificado, 06-Regras-de-Ouro-e-Armadilhas,
07-Backlog-de-Epicos (E2 e E3). A fonte da lógica é "1 - Inferiencia.sas": Fase 0 (linhas ~25–515)
e Fase 1 (linhas ~517–1409). Mantenha a lógica IDÊNTICA.

Construa:
1) macros/m02_diagnostico.sas (E2): %diagnostico(...) re-embrulhando a Fase 0 (Wilson invertido +
   power analysis para MIN_N/MIN_EVENTOS, classificação VÁLIDA/INSTÁVEL/INVÁLIDA/VAZIA), consumindo
   as 3 colunas de contagem (funciona em ANALITICA e SUMARIZADA). Troque os PUT no log por relatório
   HTML (PROC REPORT) e adicione um bloco de explicabilidade + recomendação automático (interpretar
   cobertura, sinalizar risco do PAP/grupo MÉDIA, sugerir próxima ação).
2) macros/m03_tabela_referencia.sas (E3): %tabela_referencia(...) reaproveitando monta_niveis,
   agrega_nivel, loop_niveis, empilha_niveis, empilha_validos, prefix_vars, join_cond,
   seleciona_melhor_nivel, deriva_k, extrapola_caudas. Fallback nunca colapsa o score; extrapolação
   exponencial com ICs propagados proporcionalmente à âncora; ICs SEM sufixo _ref.

Com os parâmetros validados (MARGEM_RELATIVA=0.40, ALPHA=0.07, PODER=0.75) o resultado deve dar
MIN_N=230 e MIN_EVENTOS=62. Cumpra a Definition of Done de E2 e E3 (pág. 7). Ao terminar, commite
na branch e atualize o status na Home e na pág. 7.
```

---

## Prompt — Sessão 3 (E4 + E5 + E6: Aplicação & Orquestração)

```
Reconstrução do sistema de inferência de negados — SESSÃO 3, épicos E4, E5 e E6. E0–E3 já estão
prontos (macros/m00..m03).

Antes de codar, leia: CONTEXTO.md, CLAUDE.md e as páginas da wiki: Home, 03-Arquitetura-Alvo,
04-Inventario-de-Parametros, 05-Motor-Unificado, 06-Regras-de-Ouro-e-Armadilhas,
07-Backlog-de-Epicos (E4, E5, E6), 08-Roadmap-3-Sessoes. A fonte da lógica da Fase 2 é
"1 - Inferiencia.sas" (linhas ~1412–1935) e "2 - Aplicar Inferencia.sas" (linhas ~283–827).

Construa:
1) macros/m04_aplicar_inferencia.sas (E4): macro ÚNICA da Fase 2 (hoje duplicada) reaproveitando
   join_hierarquico. ANALITICA = join linha a linha com prob_mau = prob_conv × prob_fpd;
   SUMARIZADA = físico_altas = n_aprovados × conv e físico_maus = n_aprovados × conv × fpd
   (Motor Unificado, pág. 5). Flag fl_sem_premissa; backtest opcional quando OBJETIVO=REFERENCIA;
   relatório HTML de cobertura.
2) macros/m05_exportar.sas (E5): sumarização por DIMS_SAIDA (SUM dos físicos, sem multiplicar somas
   entre si — regra de ouro 4) + PROC EXPORT CSV (delimiter ';') para CAMINHO_CSV parametrizado.
3) 00_MASTER.sas (E6): cabeçalho com o inventário completo de parâmetros (pág. 4), %include de
   m00..m05, blocos de chamada por fase com exemplos preenchidos, e a lógica de OBJETIVO
   (REFERENCIA | INFERENCIA | COMPLETO) decidindo quais macros rodam.

Cumpra a Definition of Done de E4, E5 e E6 (pág. 7) e o checklist de validação da Sessão 3 (pág. 8).
Ao terminar, commite na branch, atualize o status na Home e na pág. 7, e registre pendências abertas.
```

---

> Granularidade: os prompts são **por sessão** (3). Se preferir avançar mais devagar, dá para abrir uma sessão por épico — basta pedir só o épico desejado citando a página correspondente da pág. 7.
