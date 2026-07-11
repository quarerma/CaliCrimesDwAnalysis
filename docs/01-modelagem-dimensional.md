# Modelagem Dimensional — Chicago Crimes DW

Documentação dos processos de negócio, granularidades, dimensões e fatos.

Fonte: *Crimes — 2001 to Present*, Chicago Police Department (CLEAR).
Volume: **8.587.983** ocorrências, de 2001 até 2026.
Stack: PostgreSQL 16 + dbt 1.11 (`dw_staging` → `dw_marts`).

---

## 1. Processo de negócio

O data warehouse cobre **um único processo de negócio**:

> **Registro de ocorrência criminal** — o momento em que um crime é reportado
> e registrado pelo Departamento de Polícia de Chicago.

Vale explicitar isto, porque as **seis tabelas fato** deste modelo **não são seis
processos**: são o mesmo processo observado em granularidades e recortes
diferentes. Uma matriz de barramento clássica (ver `03-matriz-barramento.md`)
ganha força quando há vários processos (vendas, estoque, expedição); aqui o seu
papel é outro — evidenciar a **conformidade das dimensões** entre os diferentes
níveis de agregação do mesmo processo.

### Processos que a fonte NÃO suporta

Documentado por honestidade analítica — e porque delimita o que o modelo pode
responder:

| Processo | Por que não é possível |
|---|---|
| Ciclo de vida da prisão | A fonte tem o booleano `arrest`, mas **nenhuma data de prisão**, denúncia ou sentença. Sem datas de marco não existe *accumulating snapshot* (Kimball) nem análise de tempo de resolução. |
| Taxa de criminalidade *per capita* | Não há dado populacional. Toda medida geográfica é **contagem bruta** — ver a seção "Métricas-armadilha". |

---

## 2. Granularidade

A granularidade do fato atômico é declarada primeiro; todo o resto deriva dela.

| Tabela | Granularidade | Linhas |
|---|---|---|
| `fct_crimes` | **uma ocorrência criminal reportada** | 8.587.983 |
| `fct_monthly_crime_types` | um (mês × tipo de crime) ocorrido | 75.552 |
| `fct_crime_types_cumulative` | um (mês × tipo de crime) — **denso** | 127.908 |
| `fct_monthly_area_crimes` | um (mês × área comunitária × categoria) | 382.043 |
| `fct_hourly_crime_profile` | um (hora × dia da semana × tipo) | 48.403 |
| `fct_block_location_profile` | um (quarteirão × tipo de local) | 632.399 |

Todas as tabelas derivadas são construídas **a partir de `fct_crimes`**, nunca do
staging. Se lessem o staging, um filtro adicionado ao fato atômico faria as
tabelas contarem histórias diferentes em silêncio. Testes de reconciliação
(`dbt/tests/`) garantem que `sum(crime_count)` de cada snapshot continua igual a
`count(*)` do fato atômico.

---

## 3. Dimensões (10)

| Dimensão | Grão | Linhas | Observação |
|---|---|---|---|
| `dim_date` | dia | 9.311 | `date_key` = YYYYMMDD |
| `dim_month` | mês | 306 | **Shrunken** de `dim_date` (YYYYMM) |
| `dim_time_of_day` | minuto do dia | 1.440 | Spine gerado, não derivado dos dados |
| `dim_hour` | hora | 24 | **Shrunken** de `dim_time_of_day` |
| `dim_crime_type` | código IUCR | 418 | Chave natural: IUCR |
| `dim_crime_category` | `primary_type` | 33 | **Shrunken** de `dim_crime_type` |
| `dim_location` | combinação administrativa | 2.446 | beat / district / ward / community area |
| `dim_location_type` | tipo de local | 219 | STREET, APARTMENT, … + membro desconhecido |
| `dim_block` | quarteirão | 65.968 | Chave natural: `block` |
| `dim_community_area` | área comunitária | 79 | 1–77 + membro desconhecido (-1) |

### 3.1 Decisões de projeto relevantes

**Data e hora são dimensões SEPARADAS.** Uma dimensão combinada em grão de minuto
custaria ~306 meses × 1.440 minutos ≈ 13 milhões de linhas — maior que boa parte
do star. Separadas, são 306 e 1.440 linhas, e `fct_crimes` carrega as duas FKs.

**Tipo de local foi separado da geografia administrativa.** `location_description`
é **independente** de beat/ward/community area: qualquer quarteirão pode ter crime
na rua, em apartamento ou na calçada. Atributos independentes espremidos na mesma
dimensão viram produto cartesiano — era exatamente o que inflava `dim_location` de
**2.446 para 84.501 linhas**. Separados, o produto cartesiano desaparece.

**`block` é dimensão, não atributo degenerado.** Uma dimensão degenerada é um
identificador no **grão do fato** (`case_number`, único por crime — por isso fica
no fato, sem tabela). `block` se repete ~130 vezes em média entre 65.968 valores:
é atributo repetitivo, portanto material de dimensão.

**Membros desconhecidos (unknown members).** 613.724 crimes (7,1%) não têm área
comunitária e 16.283 não têm tipo de local. Em vez de FK nula — que derruba linhas
de *inner joins* e faz os totais divergirem —, apontam para um membro explícito
(`-1` / sentinela). É por isso que as FKs podem ser `not_null` **e** os fatos ainda
reconciliam exatamente com `fct_crimes`.

**Dimensões shrunken conformadas.** `dim_month`, `dim_hour` e `dim_crime_category`
são *rollups* construídos **a partir** das dimensões-base, não do staging. Isso
garante que "março de 2015" ou "ROUBO" signifiquem a mesma coisa nos dois níveis —
condição para que os fatos agregados sejam navegáveis contra o fato atômico.

---

## 4. Fatos (6)

### 4.1 `fct_crimes` — Fato de TRANSAÇÃO
Grão: uma ocorrência. 8.587.983 linhas.
FKs: `dim_date`, `dim_time_of_day`, `dim_crime_type`, `dim_location`,
`dim_location_type`, `dim_block`.
Dimensão degenerada: `case_number`.
Medidas: `arrest`, `domestic` (booleanas), `is_crime` (contador constante = 1).

### 4.2 `fct_monthly_crime_types` — SNAPSHOT PERIÓDICO
Grão: mês × tipo de crime. Atualizado ao final de cada mês.
Medidas aditivas: `crime_count`, `arrest_count`, `domestic_count`.
**Esparso**: par (mês, tipo) sem crime não gera linha.

### 4.3 `fct_crime_types_cumulative` — SNAPSHOT CUMULATIVO
Grão: mês × tipo de crime, **denso**. Reescrito ao final de cada mês.
Medidas: acumulado desde o início (`cumulative_*`) e no ano (`ytd_*`).

> **Não é um *accumulating snapshot* de Kimball.** Aquele tipo tem uma linha por
> *instância do processo* (um crime), com uma FK de data por marco — reportado /
> preso / denunciado / julgado — e a linha é **reescrita** conforme o caso avança.
> A fonte de Chicago não tem essas datas: só o booleano `arrest`. Não há nada a
> acumular por caso. Este é um snapshot **cumulativo** (totais correntes).

É **denso** de propósito: se um mês sem ocorrências simplesmente não tivesse
linha, a curva acumulada saltaria o buraco e distorceria a forma do gráfico.

### 4.4 `fct_monthly_area_crimes` — SNAPSHOT PERIÓDICO
Grão: mês × área comunitária × categoria de crime.
Responde "**onde** o crime está subindo" (o 4.2 responde "**qual** crime sobe").

Área comunitária, e não ward: **wards são redesenhados a cada censo**, então uma
série histórica por ward compara pedaços diferentes de chão consigo mesma. As
fronteiras das áreas comunitárias são estáveis — é a única geografia da fonte que
sustenta tendência de longo prazo honesta.

Categoria (33) e não IUCR (418): em grão de IUCR a tabela teria 1,35 M linhas —
apenas 6× menor que o fato atômico, retorno ruim para um agregado. Em grão de
categoria são 382 mil (22× menor), e categoria é o nível em que a pergunta é
realmente feita.

### 4.5 `fct_hourly_crime_profile` — AGREGADO (perfil temporal)
Grão: hora × dia da semana × tipo de crime.

**Não é um snapshot periódico.** Os fatos mensais *avançam* no tempo; este
**colapsa** o tempo: agrupa 25 anos em um único perfil 24×7 ("como é uma terça-feira
às 3h da manhã"). É uma **forma**, não uma série temporal — não deve ser plotado
como tendência.

### 4.6 `fct_block_location_profile` — AGREGADO (perfil composicional)
Grão: quarteirão × tipo de local. Medidas: `crime_count`, `block_crime_count`,
`share_of_block`.

Existe **no lugar de** um atributo `dominant_location_type` em `dim_block` — ver
"Métricas-armadilha" abaixo.

### 4.7 Aditividade das medidas

| Medida | Aditividade |
|---|---|
| `crime_count`, `arrest_count`, `domestic_count` | **Aditiva** |
| `cumulative_*`, `ytd_*` | **Não aditiva** entre meses (já são somas; somar duplica) |
| `distinct_blocks` | **Não aditiva** (dupla contagem de quarteirões) |
| `block_crime_count` | **Não aditiva** (repete em cada linha do quarteirão) |
| `share_of_block` | **Semiaditiva** (soma 1,0 dentro de um quarteirão apenas) |

**Nenhuma taxa é armazenada.** Taxa não se soma: somar ou tirar média de
percentuais entre meses dá resposta errada. Guarda-se numerador e denominador, e a
divisão é feita no BI sobre as **somas**: `sum(arrest_count) / sum(crime_count)`.

---

## 5. Métricas-armadilha (*trap metrics*)

Seção deliberada: são medidas que **parecem** válidas e não são.

### 5.1 Contagem bruta por geografia
Sem dado populacional, `crime_count` por área ou quarteirão ordena os locais por
**quão movimentados** são, não por **quão perigosos**. O Loop sempre parecerá
terrível porque 250 mil pessoas passam por lá todo dia.

**Contorno dentro dos dados disponíveis:** comparar a **composição** do crime
(participação de violento sobre o total *daquele* local), não o volume. Composição
é **autonormalizante** — não depende do movimento do local. "Quais quarteirões têm
mix anormalmente violento" é respondível; "qual quarteirão é o mais perigoso", não.

### 5.2 Tipo de local dominante por quarteirão
Rotular cada quarteirão com seu tipo de local mais frequente **parece** funcionar:
em 65.063 quarteirões, o tipo modal responde por **52,6%** dos crimes em média.

É artefato. Restringindo a quarteirões com volume real (≥100 crimes), a
participação modal **desaba para 36,2%**. Os 52,6% são sustentados por quarteirões
minúsculos — um com 2 crimes, ambos na rua, marca 100% sobre nada. **A métrica
parece mais forte exatamente onde sabe menos.**

Concretamente, o quarteirão mais movimentado de Chicago (`001XX N STATE ST`) é
54,5% DEPARTMENT STORE — mas também 11,3% varejo pequeno, 7,7% plataforma de metrô,
4,7% trem, 4,1% restaurante. Rotulá-lo "DEPARTMENT STORE" é a resposta modal e é
inútil: é um corredor de **varejo e transporte**, e a metade de transporte é a
parte interessante.

Por isso o modelo guarda a **distribuição inteira**
(`fct_block_location_profile`), não um rótulo.

### 5.3 Hora zero
Meia-noite é a hora mais frequente da base (~503 mil crimes, contra ~493 mil da
verdadeira hora de pico) **porque boletins com hora desconhecida assumem 00:00**.
É artefato, não onda de crime noturno. `dim_hour.is_midnight_default` marca a
linha; filtre-a antes de concluir qualquer coisa sobre madrugada.

---

## 6. Qualidade de dados tratada no modelo

| Problema | Tratamento |
|---|---|
| Categoria renomeada: `CRIM SEXUAL ASSAULT` → `CRIMINAL SEXUAL ASSAULT` (13 códigos IUCR) | `dim_crime_type` desempata por **uso mais recente**, não por frequência. Ordenar por `count(*)` elegeria o rótulo *aposentado* (ex.: IUCR 0281 tem 15.282 crimes no rótulo velho contra 8.660 no novo) e todo crime de 2021 em diante apareceria com um nome que Chicago não usa mais. Tratamento **Tipo 1** (sobrescrita). |
| 613.724 crimes sem área comunitária; código `0` é placeholder (só 1–77 são válidos) | Membro desconhecido `-1`; `0` marcado `is_unknown`. |
| 16.283 crimes sem tipo de local | Membro desconhecido sentinela. **`OTHER` (269.917) não é `UNKNOWN`**: é categoria real ("outro lugar"), resposta registrada. Fundi-las inflaria `OTHER` e esconderia a lacuna. |
| Hora desconhecida → 00:00 | Flag `is_midnight_default`. |
| Coordenadas | `x_coordinate`/`y_coordinate` são a mesma informação de `latitude`/`longitude` em outra projeção (914.239 pares distintos e 96.948 nulos em ambos). Redundantes — descartadas. |

---

## 7. Próximos passos

1. **População por área comunitária** (via `dbt seed`) — transforma toda contagem
   em taxa e neutraliza a armadilha 5.1. É a melhoria de maior impacto analítico.
2. **Chave inteira em vez de hash**, se a largura do fato virar problema:
   `md5(...)::uuid` ocupa 16 bytes contra 33 do hash em texto. Migrar **todas** as
   chaves de uma vez — um star com tipos de chave misturados é pior que um
   levemente largo.
