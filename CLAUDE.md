# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## O que é este projeto

Sistema de **inferência de negados (reject inference)** para política de crédito da Vivo, escrito 100% em SAS. Objetivo: simular o impacto de mudar pontos de corte de score **antes** de implementar — quantas vendas (altas) incrementais e qual inadimplência (FPD) resultante.

O funil de crédito tem três estágios sequenciais com atrito, e só há comportamento observado para quem foi **aprovado E converteu**:

```
Solicitantes → [política] → Aprovados → [conversão] → Altas (vendas) → [inadimplência] → Maus
```

Para reprovados e não-convertidos não há dado, então o sistema **infere** conversão e FPD por célula (combinação de variáveis de segmentação) a partir da base histórica.

`CONTEXTO.md` é o briefing completo do projeto (problema, decisões, parâmetros validados, problemas em aberto). **Leia-o antes de mexer em qualquer lógica estatística** — ele contém o histórico de erros já cometidos e resolvidos. A `wiki/` aprofunda partes específicas (arquitetura, motor unificado, parâmetros etc.) e é sincronizada automaticamente para a GitHub Wiki via `.github/workflows/sync-wiki.yml` em cada push para `main`.

## Status da reconstrução (junho 2026)

A jornada de refatoração em 3 sessões está **completa**: todos os épicos E0–E6 foram implementados e o `00_MASTER.sas` + `macros/` cobrem o pipeline ponta a ponta. **Pendente:** smoke test ponta a ponta no SASApp do usuário (checklist na PARTE E do master). Os arquivos legados permanecem como referência enquanto o master não for validado em produção.

## Como rodar / testar (importante)

- **Não há runtime SAS neste ambiente.** O código não pode ser executado, compilado ou "lintado" aqui. Erros de sintaxe só aparecem quando o usuário roda no SAS Enterprise Guide (SASApp). Trate todo código gerado como "às cegas" — revise sintaxe manualmente.
- **As versões validadas são as do usuário**, que já corrigiu erros de sintaxe nos códigos originais. Não presuma que o que está no repo é descartável.
- Não há build, testes automatizados, package manager ou CI. O "teste" é o backtest estatístico (real vs inferido) rodado dentro do próprio SAS — com a macro `%validar_confianca` (em `inferencia_simplificada.sas`) ou pelo path `OBJETIVO=REFERENCIA` com `RODAR_BACKTEST=1` no `00_MASTER.sas`.

## Arquitetura atual — dois sistemas em paralelo

O repo tem **dois sistemas funcionais** que convivem durante a migração:

### Sistema novo (00_MASTER.sas + macros/) — alvo de longo prazo

Ponto de entrada: **`00_MASTER.sas`**. Define todos os parâmetros e orquestra as macros via `%pipeline`. Nenhum nome de tabela/coluna/filtro está cravado dentro das macros — tudo vem por parâmetro do master.

**Estrutura interna do master (5 partes):**

| Parte | Conteúdo |
|---|---|
| A | Todos os `%let` (interruptores, toggles, segmentação, parâmetros validados, datasets, montagem da base, gancho PAP) |
| B | `%include` de m00..m05 (ajuste `DIR_MACROS` conforme o ambiente) |
| C | Chamada de `%setup` (libnames + ODS HTML) |
| D | Macro `%pipeline` — decide quais fases rodam por `OBJETIVO` (toda lógica de `%if/%do` fica dentro de `%macro`) |
| E | Smoke test ponta a ponta documentado (checklist para o SASApp) |

**Dois interruptores principais** (editados no topo do master):

```sas
%let OBJETIVO  = REFERENCIA;   /* REFERENCIA | INFERENCIA | COMPLETO */
%let MODO_BASE = SUMARIZADA;   /* ANALITICA  | SUMARIZADA            */
```

| OBJETIVO | Macros executadas | Uso |
|---|---|---|
| `REFERENCIA` | m01 → m02 → m03 (+ m04 backtest se `RODAR_BACKTEST=1`) | Gera/recalibra `INF.TABELA_REF_MV` a partir da base histórica com targets |
| `INFERENCIA` | m01 → m04 → m05 | Aplica tabela de referência já existente numa base nova e exporta CSV |
| `COMPLETO` | m01 → m02 → m03 → m04 → m05 | Tudo numa tacada |

**Toggles adicionais:**

```sas
%let RODAR_M01      = 1;   /* 0 = reaproveita DS_NOVO existente, pula m01 */
%let RODAR_BACKTEST = 1;   /* 1 = roda m04 em modo backtest no REFERENCIA  */
```

`MODO_BASE=SUMARIZADA` dropa a chave (`NR_PROPOSTA`) no `m01` e soma ao grão `VAR_SEG + DIMS_SAIDA`, reduzindo de ~13M para dezenas de milhares de linhas. A matemática é idêntica nos dois modos (ver Motor Unificado abaixo).

**Macros (`macros/`)** — carregadas via `%include` no master:

| Macro | Fase | O que faz |
|---|---|---|
| `m00_setup.sas` | E0 | Libnames (`INF`/`ONED`/`LOG_NOVO` + `libs_extra` para pares adicionais), `options validvarname=v7 mprint`, ODS HTML, valida OBJETIVO/MODO_BASE (aborta com `%abort cancel` se inválido) |
| `m01_montar_base.sas` | E1 | Lê base(s), renomeia, deduplica por `CHAVE`, cruza FPD, deriva flags, pivota SCORE_*/ADICIONAL_* via PROC TRANSPOSE + rename automático (sem underscores de padding), normaliza canal/score, gera 3 contagens do motor, entrega no grão escolhido |
| `m02_diagnostico.sas` | E2 (Fase 0) | Deriva MIN_N/MIN_EVENTOS (Wilson + power analysis), classifica células, exporta macro vars GLOBAIS, relatório HTML de cobertura, bloco de explicabilidade/recomendação, detecção de risco de fallback por dimensão colapsável (sinal do PAP), grava `FASE0_THRESHOLDS` para auditoria |
| `m03_tabela_referencia.sas` | E3 (Fase 1) | Agrega por nível hierárquico, fallback, extrapolação exponencial nas caudas, ICs de Wilson (sem sufixo `_ref`), confiabilidade ALTA/MÉDIA/BAIXA/EXTRAPOLADO; usa 10 macros auxiliares (`monta_niveis`, `agrega_nivel`, `loop_niveis`, `empilha_niveis`, `empilha_validos`, `prefix_vars`, `join_cond`, `seleciona_melhor_nivel`, `deriva_k`, `extrapola_caudas`) |
| `m04_aplicar_inferencia.sas` | E4 (Fase 2) | Join hierárquico em cascata (`join_hierarquico`), atribui prob_conversao/prob_fpd/fisicos a cada proposta ou célula, backtest (`backtest=AUTO/SIM/NAO`), relatório de cobertura por confiabilidade, flag `fl_sem_premissa` |
| `m05_exportar.sas` | E5 | Sumariza por VAR_SEG + DIMS_SAIDA, exporta CSV (delimitador `;`) para o simulador externo; auto-seleciona métricas por modo (`metrica_conv`/`metrica_mau` para sobrepor) |

### Sistema legado (arquivos numerados) — fonte-verdade da lógica validada

Os 3 arquivos abaixo **permanecem no repo** como referência enquanto o master não roda ponta a ponta no SAS do usuário:

1. **`0 - Gerar base para referencia da Inferencia.sas`** — constrói `INF.BASE_MODELAGEM_AM` (base histórica com targets observados).
2. **`1 - Inferiencia.sas`** — motor completo (Fases 0/1/2 encadeadas num único arquivo).
3. **`2 - Aplicar Inferencia.sas`** — reaplica a Fase 2 em base nova sem targets e exporta CSV.

Esses três arquivos precisam rodar **na mesma sessão SAS, em ordem**, pois compartilham macro variáveis.

### inferencia_simplificada.sas — alternativa standalone

Versão enxuta e autossuficiente com duas macros (`%gerar_inferencia` / `%aplicar_inferencia`) e uma terceira opcional (`%validar_confianca`). Corta o que não é essencial (derivação automática de MIN_N/MIN_EVENTOS, extrapolação exponencial, ICs de Wilson, relatórios HTML) e usa o fallback GLOBAL no lugar da extrapolação.

**Estrutura do arquivo:**
- **Bloco de parâmetros no topo** (`%let VAR_SEG`, `%let COL_APROVADOS`, `%let COL_CONVERTIDOS`, `%let COL_MAUS`, `%let MIN_N=230`, `%let MIN_EVENTOS=62`, `%let MODO`, `%let BACKTEST`): todos os valores configuráveis expostos antes das macros, com comentários descrevendo o efeito de cada parâmetro e a faixa sugerida.
- **`%gerar_inferencia`**: agrega por célula em níveis hierárquicos (colapsa da direita para a esquerda; SCORE nunca é colapsado), usa `GLOBAL` como último nível de fallback (sem extrapolação exponencial).
- **`%aplicar_inferencia`**: join em cascata idêntico ao m04, atribui prob_conversao/prob_fpd/prob_mau/físicos.
- **`%validar_confianca`**: backtest real × inferido com análise de sensibilidade (`sensibilidade=SIM`), útil para medir o impacto de alterar MIN_N/MIN_EVENTOS antes de adotar no master.

Útil para explorar/debugar a lógica sem o pipeline completo. Arquivo em ASCII puro (sem acentos) para evitar problemas de encoding.

## Motor Unificado (ANALITICA × SUMARIZADA)

O motor consome sempre **3 colunas de contagem** e agrega com `SUM`:

```
n_aprovados      = FL_APROVADOS
n_convertidos    = FL_APROVADOS × FL_ALTAS
n_maus           = FL_APROVADOS × FL_ALTAS × VAR_MAU
```

Em `ANALITICA`, as 3 colunas são flags 0/1 por proposta. Em `SUMARIZADA`, já vêm somadas por célula desde o `m01`. O código dos estágios seguintes (m02/m03/m04) é **idêntico** nos dois modos — só o grão da linha muda.

Cálculo dos físicos (m04):
```
fisico_altas = PESO × taxa_conversao_ref
fisico_maus  = PESO × taxa_conversao_ref × taxa_fpd_ref
```

**`PESO_FISICO`** determina sobre quem o físico é calculado. O default atual no master é `n_propostas` (compatível com o CSV do legado `2 - Aplicar`, que soma sobre **todas** as propostas incluindo reprovados — semântica de abertura para reprovados). Para o físico **apenas sobre aprovados** (regra de ouro 3 / DoD do Motor Unificado), use `PESO_FISICO=n_aprovados`.

## A métrica central: `prob_mau`

O conceito mais importante. Por proposta, na base **analítica** (1 linha/proposta, valores 0–1):

```
prob_mau = prob_conversao × prob_fpd = P(converte E inadimple)

Físico de altas inferidas = SUM(prob_conversao)   [ou SUM(fisico_altas) no sumarizado]
Físico de maus inferidos  = SUM(prob_mau)          [ou SUM(fisico_maus) no sumarizado]
Taxa de FPD               = SUM(fisico_maus) / SUM(fisico_altas)
```

**Regras de ouro (erros já cometidos — não repita):**
1. **NUNCA** divida `SUM(prob_mau)` por `count(aprovados)` — isso dá "perda sobre aprovação", não FPD.
2. **NUNCA** filtre `FL_ALTAS=1` na base granular — `prob_conversao` é probabilidade a priori distribuída entre **todos** os aprovados.
3. **SEMPRE** filtre `FL_APROVADOS=1` ao comparar inferido vs real (exceto quando simular abertura para reprovados).
4. `prob_mau = prob_conv × prob_fpd` **só vale na base analítica**. Na base **sumarizada**, use `fisico_altas`/`fisico_maus` — multiplicar somas entre si gera números absurdos.

## Variáveis-chave da base

```
FL_APROVADOS            flag aprovado (1/0)
FL_ALTAS                flag convertido / venda (1/0)
fl_atrs_parc_over_30    flag mau / inadimplência (VAR_MAU; missing p/ não-convertidos)
SCORE_HVI3              faixa de score (R01 melhor … R20 pior; ""/R99 = sem score → tratado como R20)
IDENTIFICA_GRUPO_MODELO grupo do cliente (G1 bom, G3 novo, G5 com dívida, …)
CANAL_PCO_AJUSTADO      canal normalizado (DIGITAL, PAP, CROSSELING, OUTBOUND, URA_ATIVACAO, OUTROS)
NR_PROPOSTA             identificador da proposta (chave; dropado no modo SUMARIZADA)
```

Variáveis de segmentação (`VAR_SEG`, **a ordem importa**):
`SCORE_HVI3 IDENTIFICA_GRUPO_MODELO CANAL_PCO_AJUSTADO` — `SCORE_HVI3` é a âncora (nunca colapsada na hierarquia/extrapolação); `CANAL` é o primeiro a ser colapsado no fallback.

## Parâmetros validados (atuais)

`MARGEM_RELATIVA=0.40`, `ALPHA=0.07`, `PODER=0.75`, `K_EXPONENCIAL=0` (auto-derivado). Resultado: `MIN_N=230`, `MIN_EVENTOS=62`, ~99% das células válidas, cobertura ALTA ~96%, `P_CONV_GLOBAL≈49,86%`, `P_FPD_GLOBAL≈26,95%`, k exponencial derivado ≈ 0,30, âncora em R20. Definidos nos `%let` no topo do `00_MASTER.sas` (ou no bloco de parâmetros do `inferencia_simplificada.sas`). Histórico de calibração em `CONTEXTO.md §5`.

## Armadilhas (SAS e este repo)

- **Encoding:** os `.sas` legados estão em **ISO-8859-1 / Latin-1**, não UTF-8. Os arquivos de `macros/` e `inferencia_simplificada.sas` são ASCII puro de propósito. Ao editar arquivos legados, preserve o encoding original.
- **`%DO` dentro de `PROC SQL` em open code** → erro "The %DO statement is not valid in open code". Toda geração dinâmica de SQL **precisa estar dentro de uma `%macro`** — é por isso que `seleciona_melhor_nivel`, `join_hierarquico` etc. são macros.
- **`%if/%do` em open code** → mesmo problema. Toda lógica condicional que usa `OBJETIVO` fica dentro de `%macro pipeline` no master.
- **Join hierárquico usa TODAS as variáveis do nível**: nível 1 = score+grupo+canal; nível 2 = score+grupo; nível 3 = só score.
- **ICs saem da m03/Fase 1 sem sufixo `_ref`** (`ic_sup_conv`, não `ic_sup_conv_ref`) para o m04/Fase 2 reconhecer.
- **`options validvarname=v7`** é obrigatório antes do colunamento do m01 (PROC TRANSPOSE gera nomes `SCORE_*`/`ADICIONAL_*`).
- **Macro vars GLOBAIS da Fase 0** (`MIN_N`, `MIN_EVENTOS`, `Z_ALFA`, `P_CONV_GLOBAL`, `P_FPD_GLOBAL`) precisam ser exportadas com `call symputx(..., 'G')` para sobreviver entre macros na mesma sessão.
- **Macro vars GLOBAIS da Fase 1** (`ANCORA_*`, `K_EXP_DERIVADO`, `N_NIVEIS`, `VAR_NIVEL*`) precisam ser declaradas com `%global` dentro da driver `%tabela_referencia` para as macros auxiliares as enxergarem.
- Sempre fechar blocos (`quit;` em PROC SQL, `run;` em DATA step).

## Problema em aberto

**Canal PAP** (`CONTEXTO.md §6`): ~52% do volume do PAP cai no grupo MÉDIA (premissa colapsada sem canal), com conversão herdada até 85x acima do real. O parâmetro `CANAIS_EXCLUIR` no master está preparado para tratar isso (atualmente vazio = desligado), mas a decisão de abordagem está pendente. O `m02_diagnostico` já detecta automaticamente o risco via `limite_fallback=0.30` (alerta quando >30% do volume de um valor da dimensão colapsável cai em células não-válidas). Leia `CONTEXTO.md §6` antes de alterar o fallback genérico — o problema é específico do PAP.

## Idioma

Trabalho em **português brasileiro** (comentários, relatórios, comunicação). Resultados são apresentados em Excel via bases sumarizadas que somam direto com `SUM`/tabela dinâmica.
