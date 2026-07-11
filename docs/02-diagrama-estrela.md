# Diagrama do Modelo Estrela

Os diagramas abaixo usam Mermaid e são renderizados nativamente pelo GitHub/GitLab.

---

## 1. Estrela principal — `fct_crimes` (fato de transação)

Grão: **uma ocorrência criminal reportada** (8.587.983 linhas).

```mermaid
erDiagram
    DIM_DATE          ||--o{ FCT_CRIMES : "date_key"
    DIM_TIME_OF_DAY   ||--o{ FCT_CRIMES : "time_key"
    DIM_CRIME_TYPE    ||--o{ FCT_CRIMES : "crime_type_key"
    DIM_LOCATION      ||--o{ FCT_CRIMES : "location_key"
    DIM_LOCATION_TYPE ||--o{ FCT_CRIMES : "location_type_key"
    DIM_BLOCK         ||--o{ FCT_CRIMES : "block_key"

    FCT_CRIMES {
        bigint crime_id PK
        text   case_number "dimensao degenerada"
        int    date_key FK
        int    time_key FK
        text   crime_type_key FK
        text   location_key FK
        text   location_type_key FK
        text   block_key FK
        bool   arrest "medida"
        bool   domestic "medida"
        int    is_crime "contador = 1"
    }

    DIM_DATE {
        int  date_key PK "YYYYMMDD"
        date full_date
        int  year
        int  quarter
        int  month
        text month_name
        int  day_of_week
        bool is_weekend
    }

    DIM_TIME_OF_DAY {
        int  time_key PK "HHMM"
        int  hour_24
        int  minute
        text day_part
        bool is_midnight_default "flag de qualidade"
    }

    DIM_CRIME_TYPE {
        text crime_type_key PK "md5(iucr)"
        text iucr "chave natural"
        text primary_type
        text description
        text fbi_code
    }

    DIM_LOCATION {
        text location_key PK "md5(beat|district|ward|community_area)"
        text beat
        text district
        int  ward
        int  community_area
    }

    DIM_LOCATION_TYPE {
        text location_type_key PK
        text location_type "STREET, APARTMENT..."
        bool is_unknown
    }

    DIM_BLOCK {
        text block_key PK "md5(block)"
        text block "chave natural"
    }
```

**Cardinalidades:** `dim_date` 9.311 · `dim_time_of_day` 1.440 · `dim_crime_type`
418 · `dim_location` 2.446 · `dim_location_type` 219 · `dim_block` 65.968.

---

## 2. Estrelas derivadas

Todos os fatos abaixo são construídos **a partir de `fct_crimes`** e usam
**dimensões conformadas** (as *shrunken* estão marcadas).

### 2.1 `fct_monthly_crime_types` — snapshot periódico
### 2.2 `fct_crime_types_cumulative` — snapshot cumulativo

```mermaid
erDiagram
    DIM_MONTH      ||--o{ FCT_MONTHLY_CRIME_TYPES : "month_key"
    DIM_CRIME_TYPE ||--o{ FCT_MONTHLY_CRIME_TYPES : "crime_type_key"
    DIM_MONTH      ||--o{ FCT_CRIME_TYPES_CUMULATIVE : "month_key"
    DIM_CRIME_TYPE ||--o{ FCT_CRIME_TYPES_CUMULATIVE : "crime_type_key"

    DIM_MONTH {
        int  month_key PK "YYYYMM - shrunken de dim_date"
        date first_day_of_month
        int  year
        int  quarter
        text month_name
    }

    FCT_MONTHLY_CRIME_TYPES {
        int  month_key FK
        text crime_type_key FK
        int  crime_count "aditiva"
        int  arrest_count "aditiva"
        int  domestic_count "aditiva"
        int  distinct_blocks "NAO aditiva"
    }

    FCT_CRIME_TYPES_CUMULATIVE {
        int  month_key FK
        text crime_type_key FK
        int  crime_count "aditiva"
        int  cumulative_crime_count "NAO aditiva entre meses"
        int  ytd_crime_count "NAO aditiva entre meses"
    }
```

### 2.3 `fct_monthly_area_crimes` — snapshot periódico geográfico

```mermaid
erDiagram
    DIM_MONTH          ||--o{ FCT_MONTHLY_AREA_CRIMES : "month_key"
    DIM_COMMUNITY_AREA ||--o{ FCT_MONTHLY_AREA_CRIMES : "community_area_key"
    DIM_CRIME_CATEGORY ||--o{ FCT_MONTHLY_AREA_CRIMES : "crime_category_key"

    DIM_COMMUNITY_AREA {
        int  community_area_key PK "1-77, -1 = desconhecido"
        int  community_area
        bool is_unknown
    }

    DIM_CRIME_CATEGORY {
        text crime_category_key PK "shrunken de dim_crime_type"
        text primary_type "33 categorias"
    }

    FCT_MONTHLY_AREA_CRIMES {
        int  month_key FK
        int  community_area_key FK
        text crime_category_key FK
        int  crime_count "ARMADILHA: contagem bruta"
        int  arrest_count
        int  domestic_count
    }
```

### 2.4 `fct_hourly_crime_profile` — perfil temporal (agregado)

```mermaid
erDiagram
    DIM_HOUR       ||--o{ FCT_HOURLY_CRIME_PROFILE : "hour_key"
    DIM_CRIME_TYPE ||--o{ FCT_HOURLY_CRIME_PROFILE : "crime_type_key"

    DIM_HOUR {
        int  hour_key PK "0-23 - shrunken de dim_time_of_day"
        text day_part
        bool is_midnight_default
    }

    FCT_HOURLY_CRIME_PROFILE {
        int  hour_key FK
        text crime_type_key FK
        int  day_of_week "atributo conformado de dim_date"
        text day_name
        int  crime_count
        int  arrest_count
        int  domestic_count
    }
```

### 2.5 `fct_block_location_profile` — perfil composicional (agregado)

```mermaid
erDiagram
    DIM_BLOCK         ||--o{ FCT_BLOCK_LOCATION_PROFILE : "block_key"
    DIM_LOCATION_TYPE ||--o{ FCT_BLOCK_LOCATION_PROFILE : "location_type_key"

    FCT_BLOCK_LOCATION_PROFILE {
        text    block_key FK
        text    location_type_key FK
        int     crime_count "aditiva"
        int     block_crime_count "NAO aditiva - repete por linha"
        numeric share_of_block "semiaditiva - soma 1.0 no quarteirao"
    }
```

---

## 3. Linhagem (DAG dbt)

Todo fato derivado nasce de `fct_crimes` — nunca do staging. É o que garante que
nenhuma tabela possa divergir do fato atômico.

```mermaid
flowchart LR
    SRC[(orm.crimes)] --> STG[stg_crimes]

    STG --> DD[dim_date]
    STG --> DT[dim_time_of_day]
    STG --> DCT[dim_crime_type]
    STG --> DL[dim_location]
    STG --> DLT[dim_location_type]
    STG --> DB[dim_block]
    STG --> DCA[dim_community_area]

    DD  --> DM[dim_month]
    DT  --> DH[dim_hour]
    DCT --> DCC[dim_crime_category]

    STG --> FC[fct_crimes]
    DD  -.-> FC
    DT  -.-> FC
    DCT -.-> FC
    DL  -.-> FC
    DLT -.-> FC
    DB  -.-> FC

    FC --> FMCT[fct_monthly_crime_types]
    FC --> FMAC[fct_monthly_area_crimes]
    FC --> FHCP[fct_hourly_crime_profile]
    FC --> FBLP[fct_block_location_profile]
    FMCT --> FCTC[fct_crime_types_cumulative]

    classDef dim fill:#e8f0fe,stroke:#4285f4
    classDef fact fill:#fce8e6,stroke:#ea4335
    class DD,DT,DCT,DL,DLT,DB,DCA,DM,DH,DCC dim
    class FC,FMCT,FMAC,FHCP,FBLP,FCTC fact
```

> `fct_crime_types_cumulative` deriva de `fct_monthly_crime_types` (e não
> diretamente do fato atômico) porque só precisa densificar e acumular um
> resultado que aquele snapshot já calculou.
