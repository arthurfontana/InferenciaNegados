# CONTEXTO — Sistema de Inferência e Simulação de Política de Crédito (Vivo)

> Documento de briefing para retomar o projeto em nova sessão (Claude Code, chat, ou outro modelo). Cole este arquivo no início da sessão para restabelecer todo o contexto.

---

## 1. PROBLEMA CENTRAL

### O que se quer resolver
Simular o impacto de mudanças na política de crédito **antes** de implementá-las. Especificamente, responder: se eu abrir/restringir um ponto de corte de score em um cluster específico, **quantas vendas (altas) incrementais terei e qual será a inadimplência resultante?**

### O desafio estatístico
O fluxo de crédito tem três estágios sequenciais, cada um com atrito:

```
Solicitantes → [política de crédito] → Aprovados → [conversão] → Altas (vendas) → [inadimplência] → Maus
```

- **Taxa de aprovação:** alta (~70% na maioria dos clusters)
- **Taxa de conversão (altas):** baixa a média (~30-50%) — nem todo aprovado vira cliente
- **Inadimplência (FPD):** medida sobre quem converteu

O problema é o **viés de seleção**: só temos comportamento observado (conversão + inadimplência) para quem foi **aprovado E converteu**. Para reprovados e não-convertidos, não há dado. Para simular abertura de política, precisamos **inferir** o comportamento desses grupos não observados. Isso é, na essência, um problema de **reject inference**.

### A necessidade prática
- Bases muito grandes: ~13-14 milhões de registros, 2 meses de safra
- O usuário tem um **simulador de políticas próprio** (aplicação externa) que recebe uma **base sumarizada** (não analítica). No simulador, o usuário indica qual galho/regra da política mudar e o app segmenta automaticamente entre parte estática (não muda) e parte impactada (muda de decisão).
- A lógica do simulador externo:
  - **Parte estática:** propostas cuja decisão não muda entre política atual e proposta → usa físicos REAIS (altas e inadimplência observadas)
  - **Parte simulada:** propostas que mudam de decisão → usa físicos INFERIDOS
  - `Nova_inadimplencia = (Inad_estatica + Inad_proposta) / (Altas_estatica + Altas_proposta)`
  - `Novas_altas = Altas_estatica + Altas_proposta`

---

## 2. ABORDAGEM EM 4 FASES

O sistema foi construído em SAS, em 4 fases encadeadas, mais um script master de orquestração.

### Fase 0 — Diagnóstico Estatístico
- Lê a base histórica e deriva **automaticamente** os thresholds `MIN_N` (mínimo de aprovados por célula) e `MIN_EVENTOS` (mínimo de maus por célula).
- Usa **intervalo de Wilson** invertido e **power analysis** para derivar os thresholds a partir de parâmetros de negócio (margem de erro relativa, alpha, poder).
- Classifica cada célula (combinação das variáveis de segmentação) em: VÁLIDA / INSTÁVEL / INVÁLIDA / VAZIA.
- Output: dataset de diagnóstico + macro variáveis `MIN_N`, `MIN_EVENTOS`, `P_CONV_GLOBAL`, `P_FPD_GLOBAL`, `Z_ALFA`.

**Fórmulas-chave:**
```
z_alfa = probit(1 - alpha/2)
n_min_wilson = z_alfa² × p × (1-p) / (margem_relativa × p)²
MIN_N = ceil(max(n_min para conversão, n_min para FPD))
MIN_EVENTOS = max(10, ceil(MIN_N × P_FPD_GLOBAL))
```

### Fase 1 — Tabela de Referência (com fallback hierárquico)
- Reagrega a base histórica e calcula `taxa_conversao_ref` e `taxa_fpd_ref` por célula.
- Para células inválidas, aplica **fallback hierárquico**: colapsa dimensões na ordem definida (mantém sempre o score, colapsa as demais da direita para a esquerda).
- Para faixas sem dados em nenhum nível, aplica **extrapolação exponencial**: `FPD = FPD_ancora × exp(k × distancia)`, onde k é derivado automaticamente da curva de risco observada.
- Calcula ICs de Wilson (`ic_sup_conv`, `ic_inf_conv`, `ic_sup_fpd`, `ic_inf_fpd`) por célula. Nas faixas extrapoladas, os ICs são propagados proporcionalmente à âncora (ratio IC/taxa da âncora aplicado à taxa extrapolada).
- Output: tabela de referência com `confiabilidade` (ALTA / MÉDIA / BAIXA / EXTRAPOLADO) por célula.

### Fase 2 — Aplicação na Base (enriquecimento)
- Faz join hierárquico em cascata: tenta match no nível mais granular, colapsa até achar célula válida.
- Atribui a cada proposta: `prob_conversao`, `prob_fpd`, `nivel_premissa`, `confiabilidade_premissa`, `fl_premissa_extrapolada`, `fl_sem_premissa`, e os ICs.
- Output: base enriquecida proposta a proposta.

### Fase 3 — Simulação de Política
- Recebe cenários de corte definidos via macro `%add_cenario`.
- Para cada cenário, agrega: volume aprovado, conversões esperadas, maus esperados, FPD médio, e deltas vs. cenário base.
- Output: painel comparativo de cenários.

### Master
- Orquestra as 4 fases com parâmetros centralizados e propaga via `%include`.

---

## 3. A MÉTRICA CHAVE: prob_mau

**O conceito mais importante do projeto.** Por proposta:

```
prob_mau = prob_conversao × prob_fpd
         = P(converte) × P(inadimple | converte)
         = P(converte E inadimple)   ← probabilidade conjunta
```

### Como calcular taxas corretamente
```
Físico de altas inferidas   = SUM(prob_conversao)
Físico de maus inferidos    = SUM(prob_mau)
Taxa de inadimplência (FPD) = SUM(prob_mau) / SUM(prob_conversao)
```

### Regras de ouro (erros já cometidos e resolvidos)
1. **NUNCA dividir SUM(prob_mau) por count(aprovados).** Isso dá "taxa de perda sobre aprovação", não FPD. Gera número ~metade do FPD real quando conversão é ~50%.
2. **NUNCA filtrar FL_ALTAS=1 na base granular.** prob_conversao é probabilidade a priori distribuída entre TODOS os aprovados. Somar só os convertidos pega fração da probabilidade. O backtest correto é sempre sobre TODOS os aprovados, sem separar por FL_ALTAS.
3. **SEMPRE filtrar FL_APROVADOS=1** quando comparar inferido vs real (a menos que esteja simulando abertura para reprovados). Reprovados têm prob_conversao atribuída e inflam o total se não filtrados.
4. **CUIDADO com base sumarizada vs analítica:** na base SUMARIZADA, `prob_conversao` e `prob_fpd` podem ser SOMAS de físicos (não proporções 0-1). Multiplicar dois físicos entre si gera números absurdos. A fórmula `prob_mau = prob_conv × prob_fpd` só vale na base ANALÍTICA (1 linha por proposta, valores entre 0 e 1).

### Validação do backtest (amostra de 1.000 e base completa)
- Conversão: desvio de ~+1,5% a +2,3% (projetado ligeiramente acima do real)
- FPD físico: desvio < 0,01% na base completa
- Modelo está **bem calibrado**.

---

## 4. VARIÁVEIS DA BASE (nomes reais)

```
FL_APROVADOS           → flag aprovado (1/0)
FL_ALTAS               → flag convertido / venda realizada (1/0)
fl_atrs_parc_over_30   → flag mau / inadimplência (1/0, missing para não convertidos)
SCORE_HVI3             → faixa de score/risco (R01 melhor ... R20 pior; Vazio/R99 = sem score)
IDENTIFICA_GRUPO_MODELO → grupo do cliente (ex: "G1 - CLIENTE RELACION BOM", "G3 - CLIENTE NOVO", "G5 - CLIENTE COM DIVIDA")
CANAL_PCO_AJUSTADO     → canal (DIGITAL, PAP, CROSSELING, OUTBOUND, URA_ATIVACAO, OUTROS)
prob_conversao         → inferência de conversão (Fase 2)
prob_fpd               → inferência de FPD (Fase 2)
NR_PROPOSTA            → identificador da proposta (mantido para rastreabilidade no SAS)
```

### Variáveis de segmentação usadas (VAR_SEG)
```
SCORE_HVI3 IDENTIFICA_GRUPO_MODELO CANAL_PCO_AJUSTADO
```
(ordem importa: SCORE_HVI3 é a âncora, nunca colapsada; CANAL é colapsado primeiro no fallback)

---

## 5. PARÂMETROS — EVOLUÇÃO E VALORES VALIDADOS

| Parâmetro | Inicial | Intermediário | **Atual (validado)** |
|---|---|---|---|
| MARGEM_RELATIVA | 0.30 | 0.50 | **0.40** |
| ALPHA | 0.05 | 0.10 | **0.07** |
| PODER | 0.80 | 0.70 | **0.75** |
| K_EXPONENCIAL | 0 (auto) | 0 (auto) | **0 (auto)** |

### Resultado com parâmetros atuais (0.40 / 0.07 / 0.75)
- MIN_N = 230, MIN_EVENTOS = 62
- 99% das células válidas
- Cobertura ALTA = 96% das propostas
- P_CONV_GLOBAL ≈ 49,86%, P_FPD_GLOBAL ≈ 26,95%
- K exponencial derivado ≈ 0,30, âncora em R20

---

## 6. PROBLEMA EM ABERTO: CANAL PAP

### Diagnóstico
O grupo MÉDIA (premissa colapsada, sem canal) tem desvio de FPD de -11,24% e altas inferidas **10x maiores** que o real. Investigação revelou:

- **Todas as 230 células MÉDIA** têm `nivel_premissa = 2` (colapsou o canal → usa SCORE + GRUPO).
- O problema concentra-se no **canal PAP**:
  - PAP tem conversão real de ~0,6% a 1,3% por célula
  - A premissa herdada (SCORE + GRUPO, sem canal) tem conversão ~49% (puxada por DIGITAL e outros canais)
  - Premissa fica **até 85x acima do real** em algumas células PAP

### Distribuição do problema por canal
| Canal | Total na base | Em MÉDIA | % do canal em MÉDIA |
|---|---|---|---|
| DIGITAL | 3.592.041 | 0 | 0% |
| CROSSELING | 2.644.820 | 2.193 | 0,1% |
| OUTROS | 3.124.031 | 3.171 | 0,1% |
| OUTBOUND | 762.400 | 4.437 | 0,6% |
| URA_ATIVACAO | 303.709 | 6.007 | 2,0% |
| **PAP** | **232.425** | **121.706** | **52,4%** |

**Conclusão:** apenas o PAP tem problema real. Os demais canais têm <2% do volume em MÉDIA. O grupo MÉDIA inteiro = 1,3% da base total (137.514 de 10,6M).

### Opções de tratamento do PAP (decisão pendente)
1. **Excluir PAP das simulações** — rápido, mas perde 52% do canal
2. **Premissa manual para PAP** — usar conversão/FPD histórico conhecido do canal
3. **Reprocessar Fase 1 com PAP separado** — colapsar mantendo filtro de canal (score + PAP, não score + todos os canais)
4. **Remover CANAL da segmentação** — testar se, controlando por score, o FPD do PAP é similar ao de outros canais. Se sim, canal não precisa ser dimensão e a premissa fica score + grupo (com volume suficiente). Se não, PAP é estruturalmente diferente e precisa tratamento separado.

**Teste sugerido para decidir:** comparar FPD por canal controlando por score. Query pronta no histórico.

---

## 7. DECISÕES TÉCNICAS IMPORTANTES

1. **Vazio/R99 (sem score):** não devem ser extrapolados como faixas além de R20. Tratar separadamente ou filtrar antes da Fase 0. Após ajuste, EXTRAPOLADO zerou.

2. **ICs em faixas extrapoladas:** propagar proporcionalmente à âncora (ratio IC/taxa da âncora), não banda fixa de ±20%.

3. **Nomes dos ICs:** devem sair da Fase 1 SEM sufixo `_ref` (`ic_sup_conv`, não `ic_sup_conv_ref`) para a Fase 2 reconhecer.

4. **Base sumarizada vs analítica:** Fases 0 e 1 funcionam igual em ambas. Fase 2 precisa adaptação para sumarizada (multiplicar contagens pela taxa da célula em vez de join proposta a proposta). Fase 3 é indiferente.

---

## 8. ARMADILHAS DE SINTAXE SAS (erros já cometidos)

1. **`%DO` dentro de `PROC SQL` em open code** → ERRO "The %DO statement is not valid in open code". Solução: encapsular toda a geração do SQL dentro de uma `%macro`, montando o texto do SQL em macro variáveis ANTES de executar o PROC SQL.

2. **Join hierárquico deve usar TODAS as variáveis do nível**, não só o score. No nível 1, o join precisa ser por score + grupo + canal; no nível 2, score + grupo; no nível 3, só score. Erro comum: fazer todos os níveis só por score.

3. **`best12.` default em SAS** trunca CNPJ de 14 dígitos (contexto de outro projeto, mas relevante: cuidado com larguras default em campos numéricos longos).

4. **Sempre fechar blocos** (`quit;` em PROC SQL, `run;` em DATA step) e verificar ponto e vírgula. SAS não é executável neste ambiente, então erros de sintaxe só aparecem no SAS do usuário.

---

## 9. AMBIENTE E FERRAMENTAS

- **SAS:** SAS Enterprise Guide (SASApp). Sem runtime SAS disponível para validação automática — código é gerado "às cegas", erros de sintaxe aparecem só na execução do usuário.
- **Libraries:** `WORK` (temporário), `ART` / `INF` / `CREDPOL` (permanentes, nomes variam).
- **Simulador de política:** aplicação externa própria do usuário, recebe base SUMARIZADA.
- **Idioma de trabalho:** português brasileiro.
- **Linguagem secundária:** Excel para apresentação de resultados (precisa de bases sumarizadas que somam direto com SUM/tabela dinâmica).

---

## 10. PRÓXIMOS PASSOS SUGERIDOS

1. **Decidir tratamento do canal PAP** (ver seção 6) — rodar o teste de FPD por canal controlando por score.
2. **Adaptar Fase 2 para base sumarizada** se for rodar tudo sumarizado (ganho enorme de performance em 13-14M registros).
3. **Migrar para repositório GitHub** com versionamento das 4 fases + master nas versões validadas pelo usuário (que já corrigiu vários erros de sintaxe nos códigos originais).
4. **Documentar a calibração final dos parâmetros** depois de resolver o PAP.

---

## 11. NOTAS SOBRE O HISTÓRICO DO PROJETO

- Os códigos SAS gerados originalmente continham erros de sintaxe que o usuário corrigiu manualmente. As versões em produção são as do usuário, não as originais geradas.
- O backtest do modelo (real vs inferido) está validado e funciona — desvio de ~1pp no grupo ALTA, que é o limite estrutural aceitável para crédito.
- O processo está em uso e entregando o resultado necessário; os refinamentos pendentes são o tratamento do PAP e a possível migração para base sumarizada.
