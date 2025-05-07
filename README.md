# 🧪 RFM-анализ клиентской базы аптечной сети с PostgreSQL

## 📌 Цель проекта
Провести сегментацию клиентов аптечной сети методом RFM в PostgresSQL и подготовить рекомендации для персонализированной СМС-рассылки.

## 🛠 Использованные инструменты
- **SQL:** оконные функции (OVER()), агрегирующие функции (SUM, COUNT, MIN), перцентили (PERCENTILE_CONT), CTE, условная логика (CASE) для классификации клиентов, CROSS JOIN для сравнения с пороговыми значениями
- **BI:** Metabase для построения дашборда

## ⚙️ Метрики
Применена классическая RFM-модель:

- **Recency (R)** — давность, количество дней с последней покупки клиента
- **Frequency (F)** — частота, количество покупок клиента за анализируемый период
- **Monetary (M)** — деньги, общая сумма покупок 

На основании перцентилей клиенты были классифицированы и объединены в сегменты (VIP, Спящие, Перспективные и др.).

[🔗 Пример исходных данных](data/sample_data.csv)

## SQL-запрос для расчёта и сегментации
<details>
<summary>🔗 SQL-запрос: нажмите, чтобы раскрыть</summary>

````sql
-- Вывести таблицу всех покупок со столбцами: номер бонусной карты, дата покупки, сумма покупки.
with all_transactions as (
 	select card as client_id, doc_id,
      	datetime::date as transaction_date,
      	max(datetime::date) over () as current_dt,
      	summ_with_disc as summ
 	from bonuscheques
 	where card similar to '200%'
),
 
-- Вывести показатели: recency, frequency, monetary
fin_calculations as (
 	select client_id,
      	min(current_dt - transaction_date) as recency,
      	count(distinct doc_id) as frequency,
      	sum(summ) as monetary
 	from all_transactions
 	group by client_id
),
 
-- Расчет пороговых значений через 33 и 66 перцентили
percentiles as (
 	select
      	percentile_cont(0.33) within group (order by recency) as recency_perc33,
      	percentile_cont(0.66) within group (order by recency) as recency_perc66,
      	percentile_cont(0.33) within group (order by frequency) as frequency_perc33,
      	percentile_cont(0.66) within group (order by frequency) as frequency_perc66,
      	percentile_cont(0.33) within group (order by monetary) as monetary_perc33,
      	percentile_cont(0.66) within group (order by monetary) as monetary_perc66
 	from fin_calculations
),
 
-- Присвоить клиентам группы по трем показателям
rfm as (
 	select client_id, f.recency, f.frequency, f.monetary,
      	case
           	when f.recency > recency_perc66 then 3
           	when f.recency > recency_perc33 then 2
           	else 1
      	end as recency_gr,
      	case
           	when f.frequency > frequency_perc66 then 1
           	when f.frequency > frequency_perc33 then 2
           	else 3
      	end as frequency_gr,
      	case
           	when f.monetary > monetary_perc66 then 1
           	when f.monetary > monetary_perc33 then 2
           	else 3
      	end as monetary_gr
      	from fin_calculations f
      	cross join percentiles p
),
 
-- Вывести объединенный столбец RFM
all_rfm as (
 	select client_id, recency, recency_gr,
 	frequency, frequency_gr,
 	monetary, monetary_gr,
 	concat(recency_gr, frequency_gr, monetary_gr) as rfm
 	from rfm
 	order by rfm
)
 
-- Посчитать количество клиентов в каждой группе
/*select rfm, count(*)
from all_rfm
group by rfm*/
 
-- клиенты с распределением по сегментам
select *,
 	case
      	when rfm in ('111') then 'VIP-клиенты'
      	when rfm in ('121', '131', '123', '122', '113', '112') then 'Перспективные'
      	when rfm in ('133', '132') then 'Новички'
      	when rfm in ('211', '212', '213', '221', '222', '223', '231', '232', '233') then 'Спящие'
      	when rfm in ('313', '312', '311') then 'Бывшие лояльные'
      	when rfm in ('321', '322', '323') then 'Уходящие'
      	when rfm in ('331', '332', '333') then 'Потерянные'
 	end as segment
from all_rfm
````
</details>

## Сегменты и рекомендации (кратко)
| Сегмент           | Характеристика                     | Рекомендации по СМС-рассылке                      |
| ----------------- | ---------------------------------- | ------------------------------------------------- |
| **VIP**           | Покупают регулярно, часто и на большую сумму (111)       | Эксклюзивные предложения, персональные акции, приглашение в премиальную программу лояльности, подарки за крупные заказы     |
| **Перспективные** | Покупают на большую сумму (131); покупают регулярно, но на небольшую сумму (121, 122, 123, 113, 112)    | Участие в программе лояльности, подборка с персональными рекомендациями. Акции, направленные на увеличение среднего чека               |
| **Новички**      | Одна покупка, низкий или средний чек  | Welcome-цепочка, промокод на вторую покупку        |
| **Спящие**       | Покупали не так давно, их еще можно вернуть (211, 212, 213, 221, 222, 223, 231, 232, 233)             | Напоминание о товарах, которые они покупали; ​​персонализированные подборки           |
| **Бывшие лояльные**        | Покупали часто, но давно (313, 312, 311) | Бонусы за возвращение, реактивирование через заботу |
| **Уходящие**        | Покупали достаточно давно и редко (321, 322, 323) | Акции на популярные товары или новинки; опрос |


## 📊 Дашборд
Интерактивный дашборд создан в **Metabase**, с возможностью фильтрации по периодам и аптекам.

[🔗 Ссылка на дашборд](http://metabase.simulative.ru/public/dashboard/771cd146-cb05-4dd6-8968-6565297fb38b)

<img src="dashboard/screenshots/dash_all.png" alt="Настройка cron" width="1000"/>

## 📄 SQL-запросы
Все визуализации основаны на SQL. Несколько примеров:

- [Сумма продаж](sql/metabase/01_sum.sql)
- [Расчет количества клиентов в каждом сегменте](sql/metabase/02_clients.sql) 

## 📁 Структура репозитория

```bash
rfm-metabase/
│
├── data/                  
│   └── sample_data.csv    # Пример данных
│
├── sql/                   
│   ├── rfm_query/        # SQL-запрос для сегментации
│   ├── metabase_query/   # SQL-запросы для построения графиков
│
├── dashboard/             
│   ├── screenshots/        # Скриншоты дашборда
│   └── dashboard_link.txt  # Ссылка  на дашборд
│
└── README.md              
```
