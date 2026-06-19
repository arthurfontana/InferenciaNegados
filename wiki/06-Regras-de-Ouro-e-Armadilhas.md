# 6. Regras de Ouro e Armadilhas

> Erros já cometidos e resolvidos. **Reler antes de mexer.** Fonte: `CLAUDE.md` e `CONTEXTO.md §3, §8`.

## Regras de ouro do `prob_mau`

1. **NUNCA** divida `SUM(prob_mau)` por `count(aprovados)` — isso dá "perda sobre aprovação", não FPD. Use `SUM(prob_mau)/SUM(prob_conversao)`.
2. **NUNCA** filtre `FL_ALTAS=1` na base granular — `prob_conversao` é probabilidade a priori distribuída entre **todos** os aprovados; o backtest correto é sobre todos os aprovados.
3. **SEMPRE** filtre/considere apenas `FL_APROVADOS=1` ao comparar inferido × real (exceto quando simular abertura para reprovados).
4. `prob_mau = prob_conv × prob_fpd` **só vale na base analítica**. Na sumarizada, `prob_conversao`/`prob_fpd` podem ser somas de físicos — multiplicá-las gera números absurdos. Use `n_aprovados × conv × fpd` (ver [Motor Unificado](05-Motor-Unificado)).

## Armadilhas SAS (deste projeto)

- **`%DO` dentro de `PROC SQL` em open code** → erro "The %DO statement is not valid in open code". Toda geração dinâmica de SQL (joins/coalesce por nível) **precisa estar dentro de uma `%macro`** que resolve os loops antes do `PROC SQL`. É por isso que `seleciona_melhor_nivel`, `join_hierarquico` etc. são macros.
- **Join hierárquico usa TODAS as variáveis do nível**, não só o score (nível 1 = score+grupo+canal; nível 2 = score+grupo; nível 3 = só score).
- **ICs saem da Fase 1 sem sufixo `_ref`** (`ic_sup_conv`, não `ic_sup_conv_ref`) para a Fase 2 reconhecer.
- **Vazio/R99 (sem score)** → tratar como `R20` antes da Fase 0; não extrapolar como faixa além de R20.
- **ICs em faixas extrapoladas:** propagar proporcionalmente à âncora (ratio IC/taxa), não banda fixa ±20%.
- **Sempre fechar blocos:** `quit;` em `PROC SQL`, `run;` em DATA step; conferir `;`.
- **Larguras default:** `best12.` trunca campos numéricos longos — cuidado.

## Encoding — crítico

- Os `.sas` estão em **ISO-8859-1 / Latin-1**, não UTF-8. Comentários têm acentos PT-BR.
- Ao editar, **preserve o encoding original**. Não converta para UTF-8 nem "corrija" mojibake em massa, ou corromperá o arquivo.
- As páginas desta **wiki** e os `.md` da raiz são UTF-8 normais — só os `.sas` é que são Latin-1.

## Ambiente

- **Sem runtime SAS** no ambiente do agente. Código é escrito "às cegas"; erros de sintaxe só aparecem quando o usuário roda no **SAS Enterprise Guide (SASApp)**.
- Por isso a entrega é **incremental, macro por macro**: o usuário valida cada uma no SAS antes de seguir.
- Não há build/teste/CI. O "teste" é o **backtest estatístico** (real × inferido) descrito em `CONTEXTO.md §3`.

## Fidelidade da lógica

Decisão da sessão de planejamento: **manter a lógica estatística idêntica**. As macros novas (m02/m03/m04) devem ser **re-embrulhos** do que está em `1 - Inferiencia.sas`, com a única diferença sendo a parametrização (nomes vindos do master) e o consumo das 3 colunas de contagem. Não reescrever Wilson/power/extrapolação.
