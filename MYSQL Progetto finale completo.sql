-- età clienti (uso 365.25 per considerare gli anni bisestili)
DROP TEMPORARY TABLE IF EXISTS banca.temp_eta_cliente;
CREATE TEMPORARY TABLE banca.temp_eta_cliente AS
SELECT id_cliente,
    FLOOR(DATEDIFF(CURDATE(), data_nascita) / 365.25) AS eta
FROM banca.cliente;

-- numero conti per cliente
DROP TEMPORARY TABLE IF EXISTS banca.temp_numero_conti;
CREATE TEMPORARY TABLE banca.temp_numero_conti AS
SELECT id_cliente, COUNT(DISTINCT id_conto) AS numero_conti_posseduti -- DISTINCT per evitare duplicati
FROM banca.conto
GROUP BY id_cliente;

-- conti per tipologia (uso CASE WHEN per pivottare le tipologie in colonne)
DROP TEMPORARY TABLE IF EXISTS banca.temp_conti_tipologia;
CREATE TEMPORARY TABLE banca.temp_conti_tipologia AS
SELECT co.id_cliente,
    SUM(CASE WHEN tc.desc_tipo_conto = 'Conto Base' THEN 1 ELSE 0 END) AS conto_base,
    SUM(CASE WHEN tc.desc_tipo_conto = 'Conto Business' THEN 1 ELSE 0 END) AS conto_business,
    SUM(CASE WHEN tc.desc_tipo_conto = 'Conto Privati' THEN 1 ELSE 0 END) AS conto_privati,
    SUM(CASE WHEN tc.desc_tipo_conto = 'Conto Famiglie' THEN 1 ELSE 0 END) AS conto_famiglie
FROM banca.conto co
LEFT JOIN banca.tipo_conto tc ON co.id_tipo_conto = tc.id_tipo_conto
GROUP BY co.id_cliente;

-- transazioni totali entrata/uscita
-- segno '+' = entrata, segno '-' = uscita
DROP TEMPORARY TABLE IF EXISTS banca.temp_transazioni_totali;
CREATE TEMPORARY TABLE banca.temp_transazioni_totali AS
SELECT co.id_cliente,
    SUM(CASE WHEN tt.segno = '-' THEN 1 ELSE 0 END) AS transazioni_uscita_totali,
    SUM(CASE WHEN tt.segno = '+' THEN 1 ELSE 0 END) AS transazioni_entrata_totali,
    SUM(CASE WHEN tt.segno = '-' THEN t.importo ELSE 0 END) AS importo_uscita_totale,
    SUM(CASE WHEN tt.segno = '+' THEN t.importo ELSE 0 END) AS importo_entrata_totale
FROM banca.transazioni t
LEFT JOIN banca.conto co ON t.id_conto = co.id_conto
LEFT JOIN banca.tipo_transazione tt ON t.id_tipo_trans = tt.id_tipo_transazione
GROUP BY co.id_cliente;

-- transazioni per tipologia di conto
-- combino segno e tipo conto nello stesso CASE WHEN per evitare join aggiuntivi
-- nota: MySQL non supporta la sintassi PIVOT, quindi ogni combinazione
-- segno/tipo_conto va scritta come colonna separata con SUM(CASE WHEN)
DROP TEMPORARY TABLE IF EXISTS banca.temp_transazioni_tipologia;
CREATE TEMPORARY TABLE banca.temp_transazioni_tipologia AS
SELECT co.id_cliente,
    SUM(CASE WHEN tt.segno = '-' AND tc.desc_tipo_conto = 'Conto Base' THEN 1 ELSE 0 END) AS trans_uscita_conto_base,
    SUM(CASE WHEN tt.segno = '-' AND tc.desc_tipo_conto = 'Conto Business' THEN 1 ELSE 0 END) AS trans_uscita_conto_business,
    SUM(CASE WHEN tt.segno = '-' AND tc.desc_tipo_conto = 'Conto Privati' THEN 1 ELSE 0 END) AS trans_uscita_conto_privati,
    SUM(CASE WHEN tt.segno = '-' AND tc.desc_tipo_conto = 'Conto Famiglie' THEN 1 ELSE 0 END) AS trans_uscita_conto_famiglie,
    SUM(CASE WHEN tt.segno = '+' AND tc.desc_tipo_conto = 'Conto Base' THEN 1 ELSE 0 END) AS trans_entrata_conto_base,
    SUM(CASE WHEN tt.segno = '+' AND tc.desc_tipo_conto = 'Conto Business' THEN 1 ELSE 0 END) AS trans_entrata_conto_business,
    SUM(CASE WHEN tt.segno = '+' AND tc.desc_tipo_conto = 'Conto Privati' THEN 1 ELSE 0 END) AS trans_entrata_conto_privati,
    SUM(CASE WHEN tt.segno = '+' AND tc.desc_tipo_conto = 'Conto Famiglie' THEN 1 ELSE 0 END) AS trans_entrata_conto_famiglie,
    SUM(CASE WHEN tt.segno = '-' AND tc.desc_tipo_conto = 'Conto Base' THEN t.importo ELSE 0 END) AS importo_uscita_conto_base,
    SUM(CASE WHEN tt.segno = '-' AND tc.desc_tipo_conto = 'Conto Business' THEN t.importo ELSE 0 END) AS importo_uscita_conto_business,
    SUM(CASE WHEN tt.segno = '-' AND tc.desc_tipo_conto = 'Conto Privati' THEN t.importo ELSE 0 END) AS importo_uscita_conto_privati,
    SUM(CASE WHEN tt.segno = '-' AND tc.desc_tipo_conto = 'Conto Famiglie' THEN t.importo ELSE 0 END) AS importo_uscita_conto_famiglie,
    SUM(CASE WHEN tt.segno = '+' AND tc.desc_tipo_conto = 'Conto Base' THEN t.importo ELSE 0 END) AS importo_entrata_conto_base,
    SUM(CASE WHEN tt.segno = '+' AND tc.desc_tipo_conto = 'Conto Business' THEN t.importo ELSE 0 END) AS importo_entrata_conto_business,
    SUM(CASE WHEN tt.segno = '+' AND tc.desc_tipo_conto = 'Conto Privati' THEN t.importo ELSE 0 END) AS importo_entrata_conto_privati,
    SUM(CASE WHEN tt.segno = '+' AND tc.desc_tipo_conto = 'Conto Famiglie' THEN t.importo ELSE 0 END) AS importo_entrata_conto_famiglie
FROM banca.transazioni t
LEFT JOIN banca.conto co ON t.id_conto = co.id_conto
LEFT JOIN banca.tipo_conto tc ON co.id_tipo_conto = tc.id_tipo_conto
LEFT JOIN banca.tipo_transazione tt ON t.id_tipo_trans = tt.id_tipo_transazione
GROUP BY co.id_cliente;

-- unisco tutto in una tabella finale
-- nota: IFNULL necessario su ogni colonna perché i LEFT JOIN
-- possono restituire NULL per clienti senza conti o transazioni
CREATE TABLE banca.final_table AS 
SELECT 
    cl.id_cliente, nome, cognome, data_nascita, eta, numero_conti_posseduti, 
    IFNULL(conto_base, 0) AS conto_base, IFNULL(conto_business, 0) AS conto_business, 
    IFNULL(conto_privati, 0) AS conto_privati, IFNULL(conto_famiglie, 0) AS conto_famiglie,
    IFNULL(transazioni_uscita_totali, 0) AS transazioni_uscita_totali, 
    IFNULL(transazioni_entrata_totali, 0) AS transazioni_entrata_totali, 
    IFNULL(importo_uscita_totale, 0) AS importo_uscita_totale, 
    IFNULL(importo_entrata_totale, 0) AS importo_entrata_totale, 
    IFNULL(trans_uscita_conto_base, 0) AS trans_uscita_conto_base, 
    IFNULL(trans_uscita_conto_business, 0) AS trans_uscita_conto_business, 
    IFNULL(trans_uscita_conto_privati, 0) AS trans_uscita_conto_privati, 
    IFNULL(trans_uscita_conto_famiglie, 0) AS trans_uscita_conto_famiglie, 
    IFNULL(trans_entrata_conto_base, 0) AS trans_entrata_conto_base, 
    IFNULL(trans_entrata_conto_business, 0) AS trans_entrata_conto_business, 
    IFNULL(trans_entrata_conto_privati, 0) AS trans_entrata_conto_privati, 
    IFNULL(trans_entrata_conto_famiglie, 0) AS trans_entrata_conto_famiglie, 
    IFNULL(importo_uscita_conto_base, 0) AS importo_uscita_conto_base, 
    IFNULL(importo_uscita_conto_business, 0) AS importo_uscita_conto_business, 
    IFNULL(importo_uscita_conto_privati, 0) AS importo_uscita_conto_privati, 
    IFNULL(importo_uscita_conto_famiglie, 0) AS importo_uscita_conto_famiglie, 
    IFNULL(importo_entrata_conto_base, 0) AS importo_entrata_conto_base, 
    IFNULL(importo_entrata_conto_business, 0) AS importo_entrata_conto_business, 
    IFNULL(importo_entrata_conto_privati, 0) AS importo_entrata_conto_privati, 
    IFNULL(importo_entrata_conto_famiglie, 0) AS importo_entrata_conto_famiglie
FROM banca.cliente cl
LEFT JOIN banca.temp_eta_cliente tec ON cl.id_cliente = tec.id_cliente
LEFT JOIN banca.temp_numero_conti tnc ON cl.id_cliente = tnc.id_cliente
LEFT JOIN banca.temp_conti_tipologia tct ON cl.id_cliente = tct.id_cliente
LEFT JOIN banca.temp_transazioni_totali ttt ON cl.id_cliente = ttt.id_cliente
LEFT JOIN banca.temp_transazioni_tipologia tttt ON cl.id_cliente = tttt.id_cliente;