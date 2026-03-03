-- temp_tables.sql
-- Progetto: Bank Customer Analytics

use banca;

-- età clienti
-- uso 365.25 per gli anni bisestili
drop temporary table if exists banca.temp_eta_cliente;
create temporary table banca.temp_eta_cliente as
select
	id_cliente,
	floor(datediff(curdate(), data_nascita) / 365.25) as eta
from banca.cliente;


-- numero conti per cliente
drop temporary table if exists banca.temp_numero_conti;
create temporary table banca.temp_numero_conti as
select
	id_cliente,
	count(distinct id_conto) as numero_conti_posseduti
from banca.conto
group by id_cliente;


-- conti per tipologia
-- MySQL non supporta PIVOT, quindi uso SUM(CASE WHEN) per ogni tipo
drop temporary table if exists banca.temp_conti_tipologia;
create temporary table banca.temp_conti_tipologia as
select
	co.id_cliente,
	sum(case when tc.desc_tipo_conto = 'Conto Base'     then 1 else 0 end) as conto_base,
	sum(case when tc.desc_tipo_conto = 'Conto Business' then 1 else 0 end) as conto_business,
	sum(case when tc.desc_tipo_conto = 'Conto Privati'  then 1 else 0 end) as conto_privati,
	sum(case when tc.desc_tipo_conto = 'Conto Famiglie' then 1 else 0 end) as conto_famiglie
from banca.conto co
	left join banca.tipo_conto tc on co.id_tipo_conto = tc.id_tipo_conto
group by co.id_cliente;


-- transazioni totali entrata/uscita
-- segno '+' = entrata, '-' = uscita
drop temporary table if exists banca.temp_transazioni_totali;
create temporary table banca.temp_transazioni_totali as
select
	co.id_cliente,
	sum(case when tt.segno = '-' then 1 else 0 end)        as transazioni_uscita_totali,
	sum(case when tt.segno = '+' then 1 else 0 end)        as transazioni_entrata_totali,
	sum(case when tt.segno = '-' then t.importo else 0 end) as importo_uscita_totale,
	sum(case when tt.segno = '+' then t.importo else 0 end) as importo_entrata_totale
from banca.transazioni t
	left join banca.conto co             on t.id_conto     = co.id_conto
	left join banca.tipo_transazione tt  on t.id_tipo_trans = tt.id_tipo_transazione
group by co.id_cliente;


-- transazioni per tipologia di conto
-- combino segno + tipo conto nello stesso CASE WHEN per evitare join aggiuntivi
drop temporary table if exists banca.temp_transazioni_tipologia;
create temporary table banca.temp_transazioni_tipologia as
select
	co.id_cliente,
	-- conteggio uscite per tipo conto
	sum(case when tt.segno = '-' and tc.desc_tipo_conto = 'Conto Base'     then 1 else 0 end) as trans_uscita_conto_base,
	sum(case when tt.segno = '-' and tc.desc_tipo_conto = 'Conto Business' then 1 else 0 end) as trans_uscita_conto_business,
	sum(case when tt.segno = '-' and tc.desc_tipo_conto = 'Conto Privati'  then 1 else 0 end) as trans_uscita_conto_privati,
	sum(case when tt.segno = '-' and tc.desc_tipo_conto = 'Conto Famiglie' then 1 else 0 end) as trans_uscita_conto_famiglie,
	-- conteggio entrate per tipo conto
	sum(case when tt.segno = '+' and tc.desc_tipo_conto = 'Conto Base'     then 1 else 0 end) as trans_entrata_conto_base,
	sum(case when tt.segno = '+' and tc.desc_tipo_conto = 'Conto Business' then 1 else 0 end) as trans_entrata_conto_business,
	sum(case when tt.segno = '+' and tc.desc_tipo_conto = 'Conto Privati'  then 1 else 0 end) as trans_entrata_conto_privati,
	sum(case when tt.segno = '+' and tc.desc_tipo_conto = 'Conto Famiglie' then 1 else 0 end) as trans_entrata_conto_famiglie,
	-- importi uscite per tipo conto
	sum(case when tt.segno = '-' and tc.desc_tipo_conto = 'Conto Base'     then t.importo else 0 end) as importo_uscita_conto_base,
	sum(case when tt.segno = '-' and tc.desc_tipo_conto = 'Conto Business' then t.importo else 0 end) as importo_uscita_conto_business,
	sum(case when tt.segno = '-' and tc.desc_tipo_conto = 'Conto Privati'  then t.importo else 0 end) as importo_uscita_conto_privati,
	sum(case when tt.segno = '-' and tc.desc_tipo_conto = 'Conto Famiglie' then t.importo else 0 end) as importo_uscita_conto_famiglie,
	-- importi entrate per tipo conto
	sum(case when tt.segno = '+' and tc.desc_tipo_conto = 'Conto Base'     then t.importo else 0 end) as importo_entrata_conto_base,
	sum(case when tt.segno = '+' and tc.desc_tipo_conto = 'Conto Business' then t.importo else 0 end) as importo_entrata_conto_business,
	sum(case when tt.segno = '+' and tc.desc_tipo_conto = 'Conto Privati'  then t.importo else 0 end) as importo_entrata_conto_privati,
	sum(case when tt.segno = '+' and tc.desc_tipo_conto = 'Conto Famiglie' then t.importo else 0 end) as importo_entrata_conto_famiglie
from banca.transazioni t
	left join banca.conto co             on t.id_conto       = co.id_conto
	left join banca.tipo_conto tc        on co.id_tipo_conto = tc.id_tipo_conto
	left join banca.tipo_transazione tt  on t.id_tipo_trans  = tt.id_tipo_transazione
group by co.id_cliente;


-- tabella finale
-- IFNULL su ogni colonna perché i LEFT JOIN possono restituire NULL
-- per clienti senza conti o senza transazioni
create table banca.final_table as
select
	cl.id_cliente, nome, cognome, data_nascita, eta, numero_conti_posseduti,
	ifnull(conto_base,     0) as conto_base,
	ifnull(conto_business, 0) as conto_business,
	ifnull(conto_privati,  0) as conto_privati,
	ifnull(conto_famiglie, 0) as conto_famiglie,
	ifnull(transazioni_uscita_totali,  0) as transazioni_uscita_totali,
	ifnull(transazioni_entrata_totali, 0) as transazioni_entrata_totali,
	ifnull(importo_uscita_totale,  0) as importo_uscita_totale,
	ifnull(importo_entrata_totale, 0) as importo_entrata_totale,
	ifnull(trans_uscita_conto_base,     0) as trans_uscita_conto_base,
	ifnull(trans_uscita_conto_business, 0) as trans_uscita_conto_business,
	ifnull(trans_uscita_conto_privati,  0) as trans_uscita_conto_privati,
	ifnull(trans_uscita_conto_famiglie, 0) as trans_uscita_conto_famiglie,
	ifnull(trans_entrata_conto_base,     0) as trans_entrata_conto_base,
	ifnull(trans_entrata_conto_business, 0) as trans_entrata_conto_business,
	ifnull(trans_entrata_conto_privati,  0) as trans_entrata_conto_privati,
	ifnull(trans_entrata_conto_famiglie, 0) as trans_entrata_conto_famiglie,
	ifnull(importo_uscita_conto_base,     0) as importo_uscita_conto_base,
	ifnull(importo_uscita_conto_business, 0) as importo_uscita_conto_business,
	ifnull(importo_uscita_conto_privati,  0) as importo_uscita_conto_privati,
	ifnull(importo_uscita_conto_famiglie, 0) as importo_uscita_conto_famiglie,
	ifnull(importo_entrata_conto_base,     0) as importo_entrata_conto_base,
	ifnull(importo_entrata_conto_business, 0) as importo_entrata_conto_business,
	ifnull(importo_entrata_conto_privati,  0) as importo_entrata_conto_privati,
	ifnull(importo_entrata_conto_famiglie, 0) as importo_entrata_conto_famiglie
from banca.cliente cl
	left join banca.temp_eta_cliente         tec  on cl.id_cliente = tec.id_cliente
	left join banca.temp_numero_conti        tnc  on cl.id_cliente = tnc.id_cliente
	left join banca.temp_conti_tipologia     tct  on cl.id_cliente = tct.id_cliente
	left join banca.temp_transazioni_totali  ttt  on cl.id_cliente = ttt.id_cliente
	left join banca.temp_transazioni_tipologia tttt on cl.id_cliente = tttt.id_cliente;
