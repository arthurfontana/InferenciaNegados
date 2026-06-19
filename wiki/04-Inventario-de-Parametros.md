# 4. Inventário de Parâmetros

Lista canônica do que o `00_MASTER.sas` precisa que o usuário defina. A coluna **Quando** indica em que caminho é obrigatório.

## Globais (sempre)

| Parâmetro | Exemplo | Descrição |
|---|---|---|
| `OBJETIVO` | `REFERENCIA` | `REFERENCIA` \| `INFERENCIA` \| `COMPLETO` |
| `MODO_BASE` | `SUMARIZADA` | `ANALITICA` \| `SUMARIZADA` |
| `LIB_*` (libnames) | `/sasdata/.../INFERENCIA` | Caminhos das libraries (ART, INF, ONED, LOG_NOVO …) |
| `VAR_SEG` | `SCORE_HVI3 IDENTIFICA_GRUPO_MODELO CANAL_PCO_AJUSTADO` | Vars de segmentação; **ordem importa** (1ª = score = âncora) |
| `VAR_SCORE_FAIXA` | `SCORE_HVI3` | Var de score/faixa (deve ser a 1ª de `VAR_SEG`) |
| `DIMS_SAIDA` | `SAFRA RISCO_CIDADE_SERASA CANAL_PCO_DECISAO GALHO_ARVORE …` | Dimensões extras mantidas no grão sumarizado e no CSV final |

## Montagem da base — `m01` (fase b)

| Parâmetro | Exemplo | Quando | Descrição |
|---|---|---|---|
| `DS_FONTE` | `LOG_NOVO.LOGS_PCO_B2C_202605 LOG_NOVO.LOGS_PCO_B2C_202606` | sempre | Lista de base(s) de entrada |
| `WHERE_FONTE` | `IDENTIFICA_NOVA_ARVORE="NOVO FLUXO B2C" and ORIGEM="AM" and FL_DEDUP_CNL_DIA=1` | sempre | Filtro de leitura |
| `CHAVE` | `NR_PROPOSTA` | sempre | Chave da proposta (dedup + grão analítico) |
| `COL_DS_PRINCIPAL` / `COL_FX_SCORE` | `DS_VAR_PRINCIPAL` / `FAIXA_SCORE` | sempre | Colunamento: qual coluna nomeia o score e qual traz o valor → gera `SCORE_*` |
| `COL_DS_ADICIONAL` / `COL_MODELO_ADICIONAL` | `DS_VAR_ADICIONAL` / `MODELO_ADICIONAL` | sempre | Colunamento adicional → gera `ADICIONAL_*` |
| `EXPR_APROVADO` | `DECISAO_ANALISE="APROVADO"` | sempre | Regra de `FL_APROVADOS` |
| `EXPR_ALTAS` | `FL_FATURADO=1 and FL_REDUTOR=0 and FL_PLNO_ZERO=0 and FL_LNHA_FICT=0 and FL_DEDUP_CONTA=1` | só REFERENCIA | Regra de `FL_ALTAS` (conversão) |
| `DS_TARGET_MAU` | `ONED.FPD_ONEDATA` | só REFERENCIA | Base de onde vem o mau |
| `CHAVE_MAU` | `NR_PROPOSTA` | só REFERENCIA | Chave de cruzamento com a base de mau |
| `VAR_MAU` | `fl_atrs_parc_over_30` | só REFERENCIA | Coluna que representa o mau/FPD |

> No modo `INFERENCIA` a base nova **não tem** targets (são justamente o que se infere) → `EXPR_ALTAS`, `DS_TARGET_MAU`, `CHAVE_MAU`, `VAR_MAU` não se aplicam.

## Diagnóstico — `m02` (fase 0)

| Parâmetro | Exemplo (validado) |
|---|---|
| `MARGEM_RELATIVA` | `0.40` |
| `ALPHA` | `0.07` |
| `PODER` | `0.75` |
| `DS_DIAGNOSTICO` (saída) | `WORK.FASE0_DIAGNOSTICO` |

Deriva e exporta: `MIN_N`, `MIN_EVENTOS`, `Z_ALFA`, `P_CONV_GLOBAL`, `P_FPD_GLOBAL`.

## Tabela de referência — `m03` (fase 1)

| Parâmetro | Exemplo |
|---|---|
| `K_EXPONENCIAL` | `0` (0 = derivar dos dados) |
| `DS_TABELA_REF` (saída) | `INF.TABELA_REF_MV` |

## Aplicar / Exportar — `m04` / `m05` (fase e)

| Parâmetro | Exemplo | Macro |
|---|---|---|
| `DS_NOVO` | `INF.LOG_05_06_MV` | m04 |
| `DS_TABELA_REF` (entrada) | `INF.TABELA_REF_MV` | m04 |
| `DS_OUTPUT_INF` (saída) | `INF.LOG_05_06_MV_INF` | m04 |
| `FL_MANTER_ORIG` | `1` | m04 |
| `CAMINHO_CSV` | `/sasdata/.../INFERENCIA/saida_sum.csv` | m05 |

## Gancho do PAP (opcional, desligado por padrão)

| Parâmetro | Exemplo | Descrição |
|---|---|---|
| `CANAIS_EXCLUIR` | `PAP` | Canais a excluir/tratar à parte (ver `CONTEXTO.md §6`). Vazio = nada. |

> **Regra de manutenção:** qualquer novo parâmetro nasce no cabeçalho do `00_MASTER.sas` e é repassado às macros — nunca cravado dentro da lógica.
