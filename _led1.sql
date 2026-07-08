  SELECT 	
case when gl_journal.modul_id = 'AS' then F_DIFF_CONS_OUT(isnull(gl_journal.doc_reff,'')) else 0 end as diff_cons,
isnull(gl_journal.doc_reff,'') as doc_reff,
isnull(gl_journal.modul_id,'') as modul_id,
gl_journal.voucher,   
gl_acc.accountdes,
				max(gl_journal.urut) as urut,   
				gl_journal.tgl,   
				gl_journal.account_id,   
sum(isnull(gl_journal.debet,0)) as debet,   
sum(isnull(gl_journal.kredit,0)) as kredit,  
gl_journal.modul_id, 
gl_journal.ket as ketxx,
case gl_journal.modul_id
when 'SO' then jual.ket
when 'PO' then beli.ket
when 'EX' then ex.ket
when 'CO' then '['+gl_journal.account_id+'  '+replace(gl_journal.ket,gl_acc.accountdes,'')+'] '
when 'CI' then '['+gl_journal.account_id+'  '+replace(gl_journal.ket,gl_acc.accountdes,'')+'] '
when 'AS' then case when isnull(cons.ket,'') = '' then jual.ket else cons.ket end
else  case when gl_journal.account_id = '228-003' then replace(gl_journal.ket,'DP','JPB') else gl_journal.ket end
end as ket,
isnull(jual.bukti_id,'')+isnull(beli.bukti_id,'')+isnull(ex.bukti_id,'')+isnull(gl_journal.doc_reff,'')+isnull(gl_journal.order_reff,'')+
dateformat(gl_journal.tgl,'yyyymmdd') as urut1,
dateformat(gl_journal.tgl,'yyyymmdd')+gl_journal.account_id+gl_journal.voucher_manual+str(gl_journal.urut) as urut2,
isnull(jual.ket,'') as ket_jual,
isnull(beli.ket,'') as ket_beli,
gl_acc.AccountDes,
cast(:arg_saldo as decimal(14,2) ) as sowal,
gl_journal.voucher_manual,gl_journal.voucher_manual+' '+isnull(gl_journal.ket,'') as is_find
FROM 		gl_journal,   
         			gl_acc ,
(
select a.order_client as bukti_id,a.bukti_reff,b.cust_name,
bukti_reff+'   ['+b.cust_name+']' as ket
from tsales1 a,mcust b
where a.cust_id = b.cust_id
)jual,
(
select a.order_client as bukti_id,bukti_reff,b.nama,
bukti_reff+'   ['+b.nama+']' as ket
from ap_trans a,mcstsupp b
where a.vendor_id = b.vendor_id
)beli,
(
select a.order_client as bukti_id,bukti_reff,b.nama,
isnull(a.bukti_reff,'')+'   ['+isnull(a.keterangan,'')+']' as ket
from ap_trans a,mcstsupp b
where a.vendor_id = b.vendor_id
)ex,
(
select a.order_client as bukti_id, list(isnull(b.description,'')) as ket
from tstok1 a,tstok2 b
where a.bukti_id = b.bukti_id
group by a.order_client
)cons,
(
select voucher,list(isnull(ket,'')) as ket from gl_journal 
where urut = 1
group by voucher
) ket_bayar
   WHERE 	
(gl_journal.site_id = gl_acc.site_id ) and
(gl_journal.account_id = gl_acc.AccountCode ) AND
gl_journal.tgl between :arg_tgl1 and :arg_tgl2 and
( gl_journal.account_id like :arg_acc ) AND
(isnull(gl_journal.debet,0) <>0 or isnull(gl_journal.kredit,0)<>0) and
( gl_journal.site_id = :arg_site ) and
gl_journal.voucher *= ket_bayar.voucher and
isnull(gl_journal.doc_reff,'') *= jual.bukti_id and
isnull(gl_journal.doc_reff,'') *= beli.bukti_id and
isnull(gl_journal.doc_reff,'') *= ex.bukti_id and
isnull(gl_journal.doc_reff,'') *= cons.bukti_id
group by
gl_journal.voucher, 
gl_journal.urut,
gl_journal.modul_id,
order_reff,
gl_journal.tgl,   
gl_journal.account_id,
gl_journal.ket,   
gl_acc.AccountDes,
ket_bayar.ket,
voucher_manual,
jual.ket,
beli.ket,
ex.ket,
isnull(gl_journal.doc_reff,''),
jual.bukti_id,
beli.bukti_id,
ex.bukti_id,
cons.bukti_id,cons.ket		
