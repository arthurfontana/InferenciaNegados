# 5. Motor Unificado (Analítica × Sumarizada)

O ponto técnico que destrava performance **sem** violar nenhuma regra de ouro.

## A ideia

O motor (Fases 0/1/2) sempre consome **3 colunas de contagem por linha** e sempre agrega com `SUM`:

```
n_aprovados      contagem de aprovados
n_convertidos    contagem de convertidos (⊆ aprovados)
n_maus           contagem de maus (⊆ convertidos)
```

O que muda entre os modos é só o **grão** da linha, não a matemática.

### Modo ANALITICA
Cada linha = 1 proposta, mantém `NR_PROPOSTA`:
```
n_aprovados   = FL_APROVADOS                       (0/1)
n_convertidos = FL_APROVADOS * FL_ALTAS            (0/1)
n_maus        = FL_APROVADOS * FL_ALTAS * VAR_MAU  (0/1)
```

### Modo SUMARIZADA
Cada linha = 1 célula (`VAR_SEG + DIMS_SAIDA`), sem chave. As 3 colunas já vêm **somadas** no `m01`. Cai de ~13M para dezenas de milhares de linhas.

## Por que Fase 0/1 ficam idênticas

Hoje a Fase 0/1 faz, por célula:
```sql
count(*)                                   -- aprovados (com WHERE FL_APROVADOS=1)
sum(case when convertido=1 ...)            -- convertidos
sum(case when convertido=1 and mau=1 ...)  -- maus
```

No motor unificado vira, em **um código só** para os dois modos:
```sql
sum(n_aprovados) sum(n_convertidos) sum(n_maus)  group by <célula>
```

As fórmulas de Wilson/power usam **contagens**, que continuam disponíveis. Nada de estatística muda.

## Por que Fase 2 fica idêntica nos dois modos

A inferência por célula usa a **mesma fórmula**:

```
físico_altas = n_aprovados × taxa_conversao_ref
físico_maus  = n_aprovados × taxa_conversao_ref × taxa_fpd_ref
```

- **ANALITICA:** `n_aprovados = 1` por aprovado ⇒ `físico_altas = taxa_conversao_ref = prob_conversao`, `físico_maus = prob_conversao × prob_fpd = prob_mau`. Idêntico ao código atual.
- **SUMARIZADA:** `n_aprovados` é a contagem da célula ⇒ o produto já entrega o físico agregado, sem join linha a linha.

E as taxas finais saem certas:
```
Taxa de FPD = SUM(físico_maus) / SUM(físico_altas)
```

## Aderência às regras de ouro

- ✔ **Nunca** dividir `SUM(prob_mau)` por `count(aprovados)` — a taxa de FPD usa `SUM(físico_maus)/SUM(físico_altas)`.
- ✔ **Nunca** filtrar `FL_ALTAS=1` no grão granular — `n_aprovados` distribui a probabilidade entre **todos** os aprovados.
- ✔ `prob_mau = prob_conv × prob_fpd` **só na analítica**: no sumarizado o produto correto é `n_aprovados × conv × fpd`, nunca `SUM(conv) × SUM(fpd)`.

> Detalhe das regras em [Regras de Ouro e Armadilhas](06-Regras-de-Ouro-e-Armadilhas).

## Implicação para o `m01`

O `m01` é onde os dois modos divergem fisicamente:
- monta as 3 colunas de contagem;
- se `MODO_BASE=SUMARIZADA`, faz `GROUP BY VAR_SEG DIMS_SAIDA` somando-as e **dropando `NR_PROPOSTA`/`NR_DOC`**;
- se `ANALITICA`, mantém a chave e as 3 colunas em 0/1.

Daí para frente (m02/m03/m04) o código é único.
