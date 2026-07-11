# Matriz de Barramento (Bus Matrix)

A matriz de barramento cruza **processos de negócio** (linhas) com **dimensões
conformadas** (colunas). Seu propósito é revelar quais dimensões são
compartilhadas — é o compartilhamento que permite navegar (*drill across*) entre
fatos diferentes sem que os números briguem entre si.

---

## Ressalva honesta sobre este modelo

Uma matriz de barramento clássica tem **vários processos de negócio** nas linhas
(vendas, estoque, expedição), cada um com sua tabela fato, e mostra onde eles se
tocam. Este DW cobre **um único processo de negócio** — o *registro de ocorrência
criminal*.

As seis linhas abaixo são, portanto, **seis tabelas fato do mesmo processo**, em
granularidades diferentes — não seis processos. A matriz continua útil, mas o que
ela demonstra aqui é outra coisa: a **conformidade entre os níveis de agregação**.
Ou seja, que `dim_month` é o *rollup* de `dim_date` e não uma dimensão paralela
inventada, e que por isso o snapshot mensal pode ser comparado ao fato atômico sem
divergir.

Registrar isso é mais defensável do que fingir seis processos onde há um.

---

## Matriz

| Tabela fato (grão) | Tipo | date | month ▽ | time_of_day | hour ▽ | crime_type | crime_category ▽ | location | location_type | block | community_area |
|---|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| **fct_crimes**<br>*uma ocorrência* | Transação | ✕ | | ✕ | | ✕ | | ✕ | ✕ | ✕ | |
| **fct_monthly_crime_types**<br>*mês × tipo* | Snapshot periódico | | ✕ | | | ✕ | | | | | |
| **fct_crime_types_cumulative**<br>*mês × tipo (denso)* | Snapshot cumulativo | | ✕ | | | ✕ | | | | | |
| **fct_monthly_area_crimes**<br>*mês × área × categoria* | Snapshot periódico | | ✕ | | | | ✕ | | | | ✕ |
| **fct_hourly_crime_profile**<br>*hora × dia-semana × tipo* | Agregado (perfil) | | | | ✕ | ✕ | | | | | |
| **fct_block_location_profile**<br>*quarteirão × tipo de local* | Agregado (perfil) | | | | | | | | ✕ | ✕ | |

▽ = **dimensão shrunken** (rollup conformado de outra dimensão da matriz).

---

## Dimensões conformadas

| Dimensão | Grão | Linhas | Conformidade |
|---|---|---|---|
| `dim_date` | dia | 9.311 | Dimensão base |
| `dim_month` ▽ | mês | 306 | Rollup de `dim_date` |
| `dim_time_of_day` | minuto | 1.440 | Dimensão base |
| `dim_hour` ▽ | hora | 24 | Rollup de `dim_time_of_day` |
| `dim_crime_type` | IUCR | 418 | Dimensão base |
| `dim_crime_category` ▽ | `primary_type` | 33 | Rollup de `dim_crime_type` |
| `dim_location` | combinação administrativa | 2.446 | Dimensão base |
| `dim_location_type` | tipo de local | 219 | Dimensão base |
| `dim_block` | quarteirão | 65.968 | Dimensão base |
| `dim_community_area` | área comunitária | 79 | Independente (atributo de `dim_location`, promovido a dimensão para o snapshot geográfico) |

### Por que as shrunken são construídas a partir das dimensões-base

`dim_month` é gerada **de `dim_date`**, não do staging. `dim_hour` vem de
`dim_time_of_day`. `dim_crime_category` vem de `dim_crime_type`. Isso não é
detalhe de implementação — é a definição de conformidade: garante que "março de
2015" ou "ROUBO" signifiquem exatamente a mesma coisa nos dois níveis.

Se cada uma fosse derivada independentemente do staging, elas poderiam divergir em
silêncio (um filtro a mais aqui, um `trim` a menos ali) e o *drill across* entre o
snapshot mensal e o fato atômico passaria a dar números diferentes para a mesma
pergunta.

---

## Drill across — o que a matriz habilita

As colunas compartilhadas mostram por onde é seguro atravessar fatos:

- `dim_crime_type` aparece em **4 dos 6 fatos** — é a espinha dorsal do modelo.
  Permite ir do "quantos roubos por mês" (snapshot) ao "em que hora acontecem"
  (perfil) até "quais ocorrências específicas" (fato atômico).
- `dim_month` conecta os três fatos mensais entre si.
- `dim_block` conecta o fato atômico ao perfil composicional — é o caminho para
  ir de "este quarteirão tem mix violento" a "quais foram os crimes".

Onde **não** há coluna compartilhada, não há drill across — e isso é intencional.
`fct_hourly_crime_profile` não tem dimensão de tempo calendário porque **colapsa**
o tempo de propósito: é uma forma 24×7 sobre 25 anos, não uma série temporal.
Cruzá-la com `dim_month` seria um erro de categoria.

---

## Verificação automatizada

A conformidade não é só documentada — é **testada**. Cada fato derivado tem um
teste em `dbt/tests/` que reconcilia sua soma com `count(*)` de `fct_crimes`:

| Teste | Garante |
|---|---|
| `assert_monthly_snapshot_reconciles_to_fct_crimes` | Snapshot mensal não perde nem duplica crimes |
| `assert_area_snapshot_reconciles_to_fct_crimes` | Membro desconhecido (-1) recolhe os 613.724 sem área |
| `assert_hourly_profile_reconciles_to_fct_crimes` | Perfil 24×7 contém todos os crimes |
| `assert_block_profile_reconciles_to_fct_crimes` | Membro desconhecido recolhe os 16.283 sem tipo de local |
| `assert_cumulative_ends_at_grand_total` | Total corrente termina no total geral de cada tipo |
| `assert_block_shares_sum_to_one` | Participações somam 1,0 dentro de cada quarteirão |
| `assert_monthly_crime_types_grain` | Grão (mês, tipo) é único |

Mais os testes de `unique` / `not_null` / `relationships` declarados em
`schema.yml`. Total: **91 testes**, todos passando (`dbt build`).
