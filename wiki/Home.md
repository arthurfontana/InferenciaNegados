# Inferência de Negados (Vivo) — Wiki de Reconstrução

> **Status:** **Sessão 3 concluída** (épicos E4, E5 e E6: `macros/m04_aplicar_inferencia.sas`, `macros/m05_exportar.sas` e `00_MASTER.sas`; E0–E3 prontos das Sessões 1 e 2). **Reconstrução completa** — as 3 sessões fecharam a jornada `m00 → m05 + master`. Falta o smoke test ponta a ponta no SASApp do usuário. Roadmap em [Roadmap](08-Roadmap-3-Sessoes).
>
> Esta wiki guarda **todo o contexto, diagnóstico e arquitetura** decididos na sessão de planejamento para que cada sessão futura (memória zerada) consiga evoluir o código sem perder contexto.

## O que é este projeto

Sistema de **inferência de negados (reject inference)** para política de crédito, 100% em SAS. Objetivo: simular o impacto de mudar pontos de corte de score **antes** de implementar — quantas vendas (altas) incrementais e qual inadimplência (FPD) resultante. Detalhe completo em `CONTEXTO.md` e `CLAUDE.md` na raiz do repo.

## Por que esta reconstrução

O código atual (3 arquivos) funciona e está validado, mas:
- está **amarrado às bases** (nomes de tabela/coluna/filtros cravados em vários lugares);
- tem **duplicação massiva** (a Fase 2 e o colunamento existem em duas cópias);
- não tem um **modo sumarizado** de verdade (roda analítico em 13–14M linhas);
- joga os outputs importantes no **log via `PUT`** em vez de relatórios legíveis.

A meta é uma jornada fluida: **um `00_MASTER.sas`** onde você define tudo uma vez e roda bloco a bloco, com **macros agnósticas às bases**.

## Índice

1. [Contexto e Objetivo](01-Contexto-e-Objetivo)
2. [Diagnóstico do Código Atual](02-Diagnostico-do-Codigo-Atual)
3. [Arquitetura-Alvo](03-Arquitetura-Alvo)
4. [Inventário de Parâmetros](04-Inventario-de-Parametros)
5. [Motor Unificado (Analítica × Sumarizada)](05-Motor-Unificado)
6. [Regras de Ouro e Armadilhas](06-Regras-de-Ouro-e-Armadilhas)
7. [Backlog de Épicos](07-Backlog-de-Epicos)
8. [Roadmap das 3 Sessões](08-Roadmap-3-Sessoes)
9. [Prompts das Sessões](09-Prompts-das-Sessoes)

## Decisões da sessão de planejamento

| Decisão | Escolha |
|---|---|
| Abordagem de entrega | **Incremental, macro por macro** (sem runtime SAS aqui → reduz risco de erro de sintaxe em massa) |
| Organização dos arquivos | **Um arquivo por fase + `00_MASTER.sas`** |
| Lógica estatística validada | **Manter idêntica** (Wilson, power, extrapolação, regras do `prob_mau`) — só re-embrulhar em macros agnósticas |

## Status dos épicos

| Épico | Arquivo | Sessão | Status |
|---|---|---|---|
| [E0 — Setup & convenções](07-Backlog-de-Epicos#e0) | `macros/m00_setup.sas` | 1 | ✅ feito (Sessão 1) |
| [E1 — Montagem da base](07-Backlog-de-Epicos#e1) | `macros/m01_montar_base.sas` | 1 | ✅ feito (Sessão 1) |
| [E2 — Diagnóstico (Fase 0)](07-Backlog-de-Epicos#e2) | `macros/m02_diagnostico.sas` | 2 | ✅ feito (Sessão 2) |
| [E3 — Tabela de referência (Fase 1)](07-Backlog-de-Epicos#e3) | `macros/m03_tabela_referencia.sas` | 2 | ✅ feito (Sessão 2) |
| [E4 — Aplicar inferência (Fase 2)](07-Backlog-de-Epicos#e4) | `macros/m04_aplicar_inferencia.sas` | 3 | ✅ feito (Sessão 3) |
| [E5 — Exportar](07-Backlog-de-Epicos#e5) | `macros/m05_exportar.sas` | 3 | ✅ feito (Sessão 3) |
| [E6 — Master & integração](07-Backlog-de-Epicos#e6) | `00_MASTER.sas` | 3 | ✅ feito (Sessão 3) |

> Ao concluir um épico, marque ✅ aqui e atualize a página do épico.
