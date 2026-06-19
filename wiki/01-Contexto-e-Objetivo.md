# 1. Contexto e Objetivo

> Resumo operacional. O briefing completo (histórico de erros, calibração, problema do PAP) está em `CONTEXTO.md` na raiz do repo — **leia-o antes de mexer em lógica estatística**.

## O problema

Simular o impacto de mudar pontos de corte de score **antes** de implementar: se eu abrir/restringir um corte num cluster, **quantas altas incrementais e qual FPD resultante?**

O funil tem 3 estágios com atrito e só há comportamento observado para quem foi **aprovado E converteu**:

```
Solicitantes → [política] → Aprovados → [conversão] → Altas (vendas) → [inadimplência] → Maus
```

Para reprovados e não-convertidos **não há dado** → o sistema **infere** conversão e FPD por célula (combinação de variáveis de segmentação) a partir da base histórica. É um problema de **reject inference**.

## A métrica central: `prob_mau`

Por proposta, na base **analítica** (1 linha/proposta, valores 0–1):

```
prob_mau = prob_conversao × prob_fpd = P(converte E inadimple)

Físico de altas inferidas = SUM(prob_conversao)
Físico de maus inferidos  = SUM(prob_mau)
Taxa de FPD               = SUM(prob_mau) / SUM(prob_conversao)
```

As **regras de ouro** (erros já cometidos) estão em [Regras de Ouro e Armadilhas](06-Regras-de-Ouro-e-Armadilhas) — releia sempre.

## Variáveis-chave

```
FL_APROVADOS            flag aprovado (1/0)
FL_ALTAS                flag convertido / venda (1/0)
fl_atrs_parc_over_30    flag mau / inadimplência (VAR_MAU; missing p/ não-convertidos)
SCORE_HVI3              faixa de score (R01 melhor … R20 pior; ""/R99 → tratado como R20)
IDENTIFICA_GRUPO_MODELO grupo do cliente (G1 bom, G3 novo, G5 com dívida, …)
CANAL_PCO_AJUSTADO      canal normalizado (DIGITAL, PAP, CROSSELING, OUTBOUND, URA_ATIVACAO, OUTROS)
NR_PROPOSTA / NR_DOC    chaves (alvo de remoção no modo SUMARIZADO)
```

Variáveis de segmentação (`VAR_SEG`, **a ordem importa**):
`SCORE_HVI3 IDENTIFICA_GRUPO_MODELO CANAL_PCO_AJUSTADO`
- `SCORE_HVI3` é a **âncora** — nunca colapsada na hierarquia/extrapolação.
- `CANAL` é o **primeiro a ser colapsado** no fallback.

## Parâmetros validados (não mudar sem motivo)

`MARGEM_RELATIVA=0.40`, `ALPHA=0.07`, `PODER=0.75`, `K_EXPONENCIAL=0` (auto-derivado).
Resultado: `MIN_N=230`, `MIN_EVENTOS=62`, ~99% das células válidas, cobertura ALTA ~96%, `P_CONV_GLOBAL≈49,86%`, `P_FPD_GLOBAL≈26,95%`.

## Objetivo da reconstrução

Transformar 3 scripts amarrados em uma **jornada por um `00_MASTER.sas`**:
- você define **todos** os parâmetros uma vez, no topo;
- escolhe o **objetivo** (gerar tabela de referência × só rodar inferência) e o **modo da base** (analítica × sumarizada);
- roda **bloco a bloco**, cada bloco chamando uma **macro agnóstica à base**;
- recebe os diagnósticos em **relatórios legíveis (HTML/Results)** com explicabilidade e recomendação.

Mapa fase→macro em [Arquitetura-Alvo](03-Arquitetura-Alvo).
