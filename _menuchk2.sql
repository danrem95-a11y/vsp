SELECT 'menu62' lbl, CAST(count(*) AS varchar(10)) n FROM sysleftmenu WHERE groupid='62'
UNION ALL SELECT 'grp60_usergroups', CAST(count(distinct usergroup) AS varchar(10)) FROM sysgroupleftmenu WHERE itemid LIKE '60%';
