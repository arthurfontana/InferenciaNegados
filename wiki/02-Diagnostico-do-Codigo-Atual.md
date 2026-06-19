# 2. Diagnóstico do Código Atual

Estado em que a reconstrução começa. Os 3 arquivos na raiz:

| # | Arquivo | Linhas | Papel |
|---|---|---|---|
| 0 | `0 - Gerar base para referencia da Inferencia.sas` | 328 | Constrói a base histórica de modelagem (com targets observados) |
| 1 | `1 - Inferiencia.sas` | 1937 | Motor: Fases 0 (diagnóstico), 1 (tabela ref) e 2 (aplicação/backtest) num só arquivo |
| 2 | `2 - Aplicar Inferencia.sas` | 827 | Reconstrói a base nova (sem targets) + reaplica a Fase 2 + exporta CSV |

## Vício 1 — unificado demais

Fases 0, 1 e 2 vivem juntas no arquivo 1. Para "só rodar inferência" você é obrigado a passar pela construção inteira da tabela de referência.

## Vício 2 — duplicado (o arquivo 2 é ~80% copy-paste)

| Bloco | No arquivo 0 | No arquivo 2 | Situação |
|---|---|---|---|
| Leitura dos logs `LOGS_PCO_B2C` | l. 7–22 | l. 5–20 | idêntico |
| `SELECT` → `LOG_05_06` | l. 25–55 | l. 23–53 | idêntico |
| Colunamento dos scores (PROC TRANSPOSE) | l. 150–282 | l. 77–209 | **verbatim** |
| Rename `SCORE_HVI3____________ AS …` | l. 305–312 | l. 228–235 | hardcoded frágil |
| Normalização `CANAL_PCO_AJUSTADO` | (arq.1 l. 29–50) | l. 250–271 | duplicado |
| **Fase 2 inteira** (`join_hierarquico` + relatório) | (arq.1 l. 1464–1933) | l. 335–767 | **verbatim** |

Resultado: Fase 2 e colunamento existem em **duas cópias** que precisam ser mantidas em sincronia na mão.

## Vício 3 — amarração às bases

- LIBNAMEs e nomes de tabela cravados no topo de cada arquivo.
- Filtros cravados **dentro** de DATA steps: `SAFRA IN (202509…)` (arq.1 l. 26), `SAFRA>=202510` (arq.0 l. 123), `OPERACAO="MOVEL"`, `SISTEMA="AM"`.
- Nomes das colunas transpostas cravados com 26 underscores: `SCORE_HVI3______________________` — muda a `DS_VAR_PRINCIPAL` e quebra **silenciosamente**.
- `GROUP BY` por posição (`1,2,…,25`) que tem de bater exatamente com o pivot.
- Parâmetros espalhados: `%let` em arq.1 l. 62–82, arq.2 l. 323–331, + filtros soltos.

## Vício 4 — a "sumarização" não sumariza

`INF.BASE_MODELAGEM_AM` faz `GROUP BY` **mantendo `NR_PROPOSTA` e `NR_DOC`** (arq.0 l. 326) → continua 1 linha por proposta = analítica de 13–14M linhas. A Fase 2 então faz join **linha a linha**. É o gargalo de performance a eliminar (ver [Motor Unificado](05-Motor-Unificado)).

## O que está bom e deve ser preservado

- A **matemática** (Wilson invertido + power analysis para `MIN_N`/`MIN_EVENTOS`; fallback hierárquico; extrapolação exponencial `FPD = FPD_âncora × exp(k·dist)`; ICs de Wilson). Está calibrada e validada — **manter idêntica**.
- As macros já corretas que serão reaproveitadas: `monta_niveis`, `agrega_nivel`, `loop_niveis`, `empilha_niveis`, `empilha_validos`, `prefix_vars`, `join_cond`, `seleciona_melhor_nivel`, `deriva_k`, `extrapola_caudas`, `join_hierarquico`.
- Os relatórios já em `PROC REPORT` (Fase 1/2) — serão padronizados em HTML e estendidos com explicabilidade.

## Problema em aberto herdado

**Canal PAP** (`CONTEXTO.md §6`): ~52% do volume do PAP cai no grupo MÉDIA (premissa colapsada sem canal), com conversão herdada até 85x acima do real. **Não resolver embutido** — a reconstrução deve apenas deixar um *gancho de parâmetro* para tratar/excluir canais específicos, e a decisão fica para depois.
