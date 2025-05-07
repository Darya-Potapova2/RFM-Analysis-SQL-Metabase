-- Cумма продаж
with all_transactions as (
	select card as client_id,
		datetime::date as transaction_date,
		max(datetime::date) over () as current_dt, 
		summ_with_disc as summ
	from bonuscheques
	where card similar to '200%'
	and {{date}}
	and {{apteka}}
),

