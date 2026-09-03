-- Provisioning tabel audit untuk COSTING GATE (non-WIP: jual'22'/mutasi'19'/adjustment'4c')
-- Pola identik wip_out_gate_result/detail yang sudah terbukti jalan di prod.
-- Jalankan SEKALI di dbisql sebelum build/deploy fix hardening n_cst_closing_stock.sru.

IF NOT EXISTS (SELECT 1 FROM SYSTABLE WHERE table_name = 'costing_gate_result') THEN
CREATE TABLE costing_gate_result (
  gate_id        INTEGER IDENTITY PRIMARY KEY,
  periode_from   datetime,
  periode_to     datetime,
  sumber         varchar(10),
  n_pelanggaran  integer,
  status         varchar(12),
  tgl_cek        datetime DEFAULT current timestamp
);
END IF;

IF NOT EXISTS (SELECT 1 FROM SYSTABLE WHERE table_name = 'costing_gate_detail') THEN
CREATE TABLE costing_gate_detail (
  detail_id           INTEGER IDENTITY PRIMARY KEY,
  periode_from        datetime,
  periode_to          datetime,
  sumber              varchar(12),
  bukti_id            varchar(20),
  stok_id             varchar(20),
  tipe_trans          varchar(5),
  qty                 numeric(18,2),
  hpp                 numeric(18,4),
  nilai               numeric(18,2),
  opening_qty         numeric(18,2),
  opening_nilai       numeric(18,2),
  beli_qty_periode    numeric(18,2),
  beli_nilai_periode  numeric(18,2),
  tgl_log             datetime DEFAULT current timestamp
);
END IF;

-- Tabel bantu PERFORMA: menyimpan hasil hitung "opening + beli bulan berjalan" per stok_id, dihitung
-- SEKALI per of_run() (bukan berulang 6x di 3 blok fix + 3 blok gate) -- ini penyebab closing lambat
-- sebelum dioptimasi. Dikosongkan & diisi ulang setiap kali of_run() dipanggil (delete-then-insert,
-- scope penuh per-run, tidak perlu index tambahan selain PK stok_id karena tabelnya kecil per-refresh).
IF NOT EXISTS (SELECT 1 FROM SYSTABLE WHERE table_name = 'costing_helper_movavg') THEN
CREATE TABLE costing_helper_movavg (
  stok_id        varchar(20) PRIMARY KEY,
  opening_qty    numeric(18,4),
  opening_nilai  numeric(18,2),
  beli_qty       numeric(18,4),
  beli_nilai     numeric(18,2),
  closing_avg    numeric(18,4)
);
END IF;
