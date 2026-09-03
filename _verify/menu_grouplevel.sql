select 'panjang itemid' info, length(itemid) n, count(*) jml from sysgroupleftmenu group by length(itemid)
union all
select 'grant header 62 (AKTIVA)', 0, count(*) from sysgroupleftmenu where itemid='62'
union all
select 'grant header 62 - list group', 0, count(distinct usergroup) from sysgroupleftmenu where itemid='62';
select usergroup, itemid from sysgroupleftmenu where itemid in ('62','6220','6230') order by usergroup, itemid;
