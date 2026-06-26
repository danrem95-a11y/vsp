SELECT itemid, itemdesc, windowobject FROM sysleftmenu WHERE groupid='62' ORDER BY itemid;
SELECT COUNT(DISTINCT usergroup) usergroups_granted FROM sysgroupleftmenu WHERE itemid LIKE '62%';
