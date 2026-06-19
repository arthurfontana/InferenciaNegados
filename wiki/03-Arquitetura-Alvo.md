# 3. Arquitetura-Alvo

## Estrutura de arquivos

```
InferenciaNegados/
├── 00_MASTER.sas                 ← você define TUDO aqui e roda bloco a bloco (E6)
├── macros/
│   ├── m00_setup.sas             libnames, ODS HTML, options, macro vars globais (E0)
│   ├── m01_montar_base.sas       lê base(s), cruza mau, deriva flags, colunamento,
│   │                             sumariza ao grão escolhido (E1)
│   ├── m02_diagnostico.sas       Fase 0: MIN_N/MIN_EVENTOS + classificação + HTML (E2)
│   ├── m03_tabela_referencia.sas Fase 1: níveis, melhor nível, extrapolação (E3)
│   ├── m04_aplicar_inferencia.sas Fase 2: enriquece a base (analítica OU sumarizada) (E4)
│   └── m05_exportar.sas          sumarização final + CSV p/ o simulador (E5)
├── 0 - Gerar base ....sas        (legado — referência, será aposentado)
├── 1 - Inferiencia.sas           (legado — fonte da lógica validada)
└── 2 - Aplicar Inferencia.sas    (legado — fonte da lógica validada)
```

> Os 3 arquivos legados **permanecem no repo** durante a reconstrução como fonte-verdade da lógica validada. Só serão aposentados quando o master rodar ponta a ponta no SAS do usuário.

## Os dois interruptores do master

No topo do `00_MASTER.sas`:

```sas
%let OBJETIVO  = REFERENCIA;   /* REFERENCIA | INFERENCIA | COMPLETO */
%let MODO_BASE = SUMARIZADA;   /* ANALITICA  | SUMARIZADA            */
```

### Fluxo por OBJETIVO

| OBJETIVO | Macros executadas | Uso |
|---|---|---|
| `REFERENCIA` | m01 → m02 → m03 (+ m04 backtest opcional) | Gerar/recalibrar `INF.TABELA_REF_*` a partir da base histórica com targets |
| `INFERENCIA` | m01 → m04 → m05 | Aplicar tabela de referência **já existente** numa base nova e exportar |
| `COMPLETO` | m01 → m02 → m03 → m04 → m05 | Tudo numa tacada |

### MODO_BASE

`ANALITICA` mantém a chave (`NR_PROPOSTA`) — 1 linha/proposta.
`SUMARIZADA` dropa a chave **desde o m01** e soma para o grão `VAR_SEG + DIMS_SAIDA` — reduz de ~13M para dezenas de milhares de linhas, acelerando tudo. A matemática é a mesma (ver [Motor Unificado](05-Motor-Unificado)).

## Mapa fases do usuário (a–e) → macros

| Fase pedida pelo usuário | Macro |
|---|---|
| (a) Definição do objetivo (gerar referência × só inferência) | `%let OBJETIVO` no master |
| (b) Base(s) de entrada + chave + var de mau/altas + colunamento + analítica/sumarizada | `m01_montar_base` |
| (c) Diagnóstico (Fase 0) com saída **HTML** + explicabilidade/recomendação | `m02_diagnostico` |
| (d) Inferência em si — geração da tabela de referência | `m03_tabela_referencia` |
| (e) Enriquecimento da base com a inferência | `m04_aplicar_inferencia` (+ `m05_exportar`) |

## Princípios de design

1. **Macros agnósticas à base:** nenhum nome de tabela/coluna/filtro cravado dentro da lógica — tudo vem por parâmetro do master.
2. **DRY:** colunamento e Fase 2 existem **uma vez** (em m01 e m04). Fim das cópias.
3. **Lógica idêntica:** as macros estatísticas (m02/m03/m04) são re-embrulhos do que já está validado em `1 - Inferiencia.sas`. Não reescrever a matemática.
4. **Saídas legíveis:** `ODS HTML` ligado no m00; diagnósticos via `PROC REPORT`/`PROC PRINT`, não `PUT` no log.
5. **Colunamento robusto:** resolver os nomes transpostos automaticamente (via `dictionary.columns` casando `SCORE_%`/`ADICIONAL_%`), eliminando os renames com 26 underscores.
6. **Encoding:** os `.sas` permanecem **ISO-8859-1 / Latin-1**. Nunca converter para UTF-8.
