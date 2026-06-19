# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## O que é este projeto

Sistema de **inferência de negados (reject inference)** para política de crédito da Vivo, escrito 100% em SAS. Objetivo: simular o impacto de mudar pontos de corte de score **antes** de implementar — quantas vendas (altas) incrementais e qual inadimplência (FPD) resultante.

O funil de crédito tem três estágios sequenciais com atrito, e só há comportamento observado para quem foi **aprovado E converteu**:

```
Solicitantes → [política] → Aprovados → [conversão] → Altas (vendas) → [inadimplência] → Maus
```

Para reprovados e não-convertidos não há dado, então o sistema **infere** conversão e FPD por célula (combinação de variáveis de segmentação) a partir da base histórica.

`CONTEXTO.md` é o briefing completo do projeto (problema, decisões, parâmetros validados, problemas em aberto). **Leia-o antes de mexer em qualquer lógica estatística** — ele contém o histórico de erros já cometidos e resolvidos.

## Como rodar / testar (importante)

- **Não há runtime SAS neste ambiente.** O código não pode ser executado, compilado ou "lintado" aqui. Erros de sintaxe só aparecem quando o usuário roda no SAS Enterprise Guide (SASApp). Trate todo código gerado como "às cegas" — revise sintaxe manualmente.
- **As versões em produção são as do usuário**, que já corrigiu erros de sintaxe nos códigos originais. Não presuma que o que está no repo é descartável.
- Não há build, testes automatizados, package manager ou CI. O "teste" é o backtest estatístico descrito em `CONTEXTO.md §3` (real vs inferido), rodado dentro do próprio SAS.

## Arquitetura e fluxo de dados

Três arquivos `.sas`, numerados pela ordem de execução. **As fases compartilham macro variáveis e precisam rodar na mesma sessão SAS, na ordem.**

1. **`0 - Gerar base para referencia da Inferencia.sas`** — Constrói a **base histórica de modelagem** (`INF.BASE_MODELAGEM_AM`). Lê os logs de decisão PCO (`LOG_NOVO.LOGS_PCO_B2C_YYYYMM`), faz left join com a base de FPD (`ONED.FPD_ONEDATA`), deriva as flags (`FL_APROVADOS`, `FL_ALTAS`, `FL_PROPOSTA`), pivota `DS_VAR_PRINCIPAL`/`FX_SCORE` → colunas `SCORE_*` e `DS_VAR_ADICIONAL`/`MODELO_ADICIONAL` → colunas `ADICIONAL_*` via `PROC TRANSPOSE`, deduplica por `NR_PROPOSTA` e sumariza. Esta base **tem os targets observados** (conversão e mau).

2. **`1 - Inferiencia.sas`** — O **motor de inferência**. Contém três fases encadeadas num único arquivo:
   - **Fase 0 — Diagnóstico estatístico:** deriva automaticamente `MIN_N` e `MIN_EVENTOS` (via intervalo de Wilson invertido + power analysis a partir de `MARGEM_RELATIVA`/`ALPHA`/`PODER`), classifica cada célula em VÁLIDA/INSTÁVEL/INVÁLIDA/VAZIA e exporta macro vars (`MIN_N`, `MIN_EVENTOS`, `Z_ALFA`, `P_CONV_GLOBAL`, `P_FPD_GLOBAL`).
   - **Fase 1 — Tabela de referência:** agrega a base em todos os níveis hierárquicos, seleciona o melhor nível por célula com **fallback hierárquico** (colapsa dimensões da direita para a esquerda, **nunca colapsa o score**), e aplica **extrapolação exponencial** (`FPD = FPD_âncora × exp(k × distância)`) nas faixas de cauda sem dado. Gera `INF.TABELA_REF_MV` com `taxa_conversao_ref`, `taxa_fpd_ref`, ICs de Wilson e `confiabilidade` (ALTA/MÉDIA/BAIXA/EXTRAPOLADO).
   - **Fase 2 — Aplicação:** join hierárquico em cascata da tabela de referência na base, atribuindo `prob_conversao`/`prob_fpd` proposta a proposta. Aqui roda sobre a própria base histórica (backtest).

3. **`2 - Aplicar Inferencia.sas`** — Reaproveita a **mesma Fase 2** do arquivo 1, mas aplicada à **base nova a simular** (`INF.LOG_05_06_MV`, sem targets observados — eles são justamente o que se quer inferir). Reconstrói essa base com o mesmo pivot do arquivo 0 (só `FL_PROPOSTA`/`FL_APROVADOS`), enriquece com `INF.TABELA_REF_MV` → `INF.LOG_05_06_MV_INF`, sumariza (`SUM(PROB_CONVERSAO)`, `SUM(PROB_MAU)`) e **exporta CSV** para o simulador de política externo.

**Nota sobre `CONTEXTO.md`:** ele descreve um desenho de **4 fases + master** de orquestração. No repositório atual existem apenas as Fases 0/1/2; a **Fase 3 (simulação) é feita pelo simulador externo** do usuário, que recebe a base sumarizada/CSV. Não invente um arquivo de Fase 3 ou master que não está no repo.

## A métrica central: `prob_mau`

O conceito mais importante. Por proposta, na base **analítica** (1 linha/proposta, valores 0–1):

```
prob_mau = prob_conversao × prob_fpd = P(converte E inadimple)

Físico de altas inferidas = SUM(prob_conversao)
Físico de maus inferidos  = SUM(prob_mau)
Taxa de FPD               = SUM(prob_mau) / SUM(prob_conversao)
```

**Regras de ouro (erros já cometidos — não repita):**
1. **NUNCA** divida `SUM(prob_mau)` por `count(aprovados)` — isso dá "perda sobre aprovação", não FPD.
2. **NUNCA** filtre `FL_ALTAS=1` na base granular — `prob_conversao` é probabilidade a priori distribuída entre **todos** os aprovados; o backtest correto é sobre todos os aprovados.
3. **SEMPRE** filtre `FL_APROVADOS=1` ao comparar inferido vs real (exceto quando simular abertura para reprovados).
4. `prob_mau = prob_conv × prob_fpd` **só vale na base analítica**. Na base **sumarizada**, `prob_conversao`/`prob_fpd` já podem ser somas de físicos — multiplicá-las gera números absurdos.

## Variáveis-chave da base

```
FL_APROVADOS            flag aprovado (1/0)
FL_ALTAS                flag convertido / venda (1/0)
fl_atrs_parc_over_30    flag mau / inadimplência (VAR_MAU; missing p/ não-convertidos)
SCORE_HVI3              faixa de score (R01 melhor … R20 pior; ""/R99 = sem score → tratado como R20)
IDENTIFICA_GRUPO_MODELO grupo do cliente (G1 bom, G3 novo, G5 com dívida, …)
CANAL_PCO_AJUSTADO      canal normalizado (DIGITAL, PAP, CROSSELING, OUTBOUND, URA_ATIVACAO, OUTROS)
NR_PROPOSTA             identificador da proposta
```

Variáveis de segmentação (`VAR_SEG`, **a ordem importa**):
`SCORE_HVI3 IDENTIFICA_GRUPO_MODELO CANAL_PCO_AJUSTADO` — `SCORE_HVI3` é a âncora (nunca colapsada na hierarquia/extrapolação); `CANAL` é o primeiro a ser colapsado no fallback.

## Parâmetros validados (atuais)

`MARGEM_RELATIVA=0.40`, `ALPHA=0.07`, `PODER=0.75`, `K_EXPONENCIAL=0` (auto-derivado). Resultado: `MIN_N=230`, `MIN_EVENTOS=62`, ~99% das células válidas, cobertura ALTA ~96%. Ajustados nos `%let` no topo do arquivo `1 - Inferiencia.sas`. Histórico de calibração em `CONTEXTO.md §5`.

## Armadilhas (SAS e este repo)

- **Encoding:** os `.sas` estão em **ISO-8859-1 / Latin-1**, não UTF-8. Comentários têm acentos PT-BR. Ao editar, preserve o encoding original — não converta para UTF-8 nem "corrija" os caracteres acentuados mojibake em massa, ou você corromperá o arquivo.
- **`%DO` dentro de `PROC SQL` em open code** → erro "The %DO statement is not valid in open code". Toda geração dinâmica de SQL (joins/coalesce por nível) **precisa estar dentro de uma `%macro`** que resolve os loops antes do `PROC SQL` — é por isso que `seleciona_melhor_nivel`, `join_hierarquico` etc. são macros.
- **Join hierárquico usa TODAS as variáveis do nível**, não só o score (nível 1 = score+grupo+canal; nível 2 = score+grupo; nível 3 = só score).
- **ICs saem da Fase 1 sem sufixo `_ref`** (`ic_sup_conv`, não `ic_sup_conv_ref`) para a Fase 2 reconhecer.
- Sempre fechar blocos (`quit;` em PROC SQL, `run;` em DATA step).

## Problema em aberto

**Canal PAP** (`CONTEXTO.md §6`): ~52% do volume do PAP cai no grupo MÉDIA (premissa colapsada sem canal), com conversão herdada até 85x acima do real. Decisão de tratamento pendente. Antes de "consertar" o fallback genérico, leia a seção — o problema é específico do PAP, não da lógica geral.

## Idioma

Trabalho em **português brasileiro** (comentários, relatórios, comunicação). Resultados costumam ser apresentados em Excel, exigindo bases sumarizadas que somam direto com `SUM`/tabela dinâmica.
