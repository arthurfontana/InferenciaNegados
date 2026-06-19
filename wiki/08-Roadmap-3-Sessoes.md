# 8. Roadmap das 3 Sessões

Entrega **incremental, macro por macro**. Entre uma sessão e outra, **você valida no SASApp** (não há runtime SAS no ambiente do agente).

| Sessão | Épicos | Foco | Por que juntos |
|---|---|---|---|
| **1 — Fundação & Base** | [E0](07-Backlog-de-Epicos#e0) + [E1](07-Backlog-de-Epicos#e1) | Setup + montagem agnóstica da base, colunamento robusto, modo analítica/sumarizada | É a maior mudança real (o resto é re-embrulho). Precisa estar sólida antes do motor. |
| **2 — Motor estatístico** | [E2](07-Backlog-de-Epicos#e2) + [E3](07-Backlog-de-Epicos#e3) | Fase 0 (diagnóstico HTML + recomendação) + Fase 1 (tabela de referência) | Lógica idêntica ao legado; consome a base do E1. |
| **3 — Aplicação & Orquestração** | [E4](07-Backlog-de-Epicos#e4) + [E5](07-Backlog-de-Epicos#e5) + [E6](07-Backlog-de-Epicos#e6) | Fase 2 dual-mode + export CSV + master + smoke test ponta a ponta | Fecha a jornada; depende de tudo anterior. |

## Checklist de validação entre sessões

Depois de cada sessão, rode no SAS e confirme antes de abrir a próxima:

**Após Sessão 1 (E0+E1):**
- [ ] `m01` roda sem erro de sintaxe nos dois modos (`ANALITICA`/`SUMARIZADA`).
- [ ] Totais de aprovados/altas/maus batem com o legado (`0 - Gerar base...`).
- [ ] Colunamento gera `SCORE_*`/`ADICIONAL_*` corretos sem o hardcode de underscores.
- [ ] No modo sumarizado, a base reduziu de ~13M para o esperado (dezenas de milhares).

**Após Sessão 2 (E2+E3):**
- [ ] `MIN_N=230`, `MIN_EVENTOS=62` com os parâmetros validados (0.40/0.07/0.75).
- [ ] Relatório HTML da Fase 0 aparece no Results com explicabilidade.
- [ ] `INF.TABELA_REF_*` reproduz a confiabilidade ~96% ALTA do legado.

**Após Sessão 3 (E4+E5+E6):**
- [ ] Backtest (real × inferido) dentro do desvio aceitável (~1pp no grupo ALTA).
- [ ] CSV exportado idêntico em estrutura ao do `2 - Aplicar...`.
- [ ] `00_MASTER.sas` roda ponta a ponta nos 3 valores de `OBJETIVO`.

## Regra de fechamento de cada sessão

Toda sessão deve, ao final:
1. Commitar na branch de trabalho com mensagem descritiva.
2. Atualizar o **status do épico** na [Home](Home) e na [pág. 7](07-Backlog-de-Epicos) (⬜→✅).
3. Anotar pendências/decisões abertas para a sessão seguinte.
