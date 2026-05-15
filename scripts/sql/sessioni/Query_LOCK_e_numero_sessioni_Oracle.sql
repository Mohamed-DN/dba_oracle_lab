-- Source: https://www.scriptdba.com/query-per-trovere-quale-sessione-sta-determinando-il-blocco-del-database-in-breve-tempo/
-- Title: Query LOCK e numero sessioni Oracle

SELECT bs.sid BSID, count(ws.sid) as NumWait 
FROM v$lock hk, v$session bs, v$lock wk, v$session ws 
WHERE hk.BLOCK = 1 AND wk.TYPE(+) = hk.TYPE AND wk.id1(+) = hk.id1 
AND wk.id2(+) = hk.id2 AND hk.sid = bs.sid(+) 
AND wk.sid = ws.sid(+) AND bs.sid != ws.sid group by bs.sid 
order by 2 desc;

SELECT bs.sid BSID, count(ws.sid) as NumWait 
FROM v$lock hk, v$session bs, v$lock wk, v$session ws 
WHERE hk.BLOCK = 1 AND wk.TYPE(+) = hk.TYPE AND wk.id1(+) = hk.id1 
AND wk.id2(+) = hk.id2 AND hk.sid = bs.sid(+) 
AND wk.sid = ws.sid(+) AND bs.sid != ws.sid group by bs.sid 
order by 2 desc;

SELECT bs.inst_id, bs.sid BSID, count(ws.sid) as NumWait 
FROM gv$lock hk, gv$session bs, gv$lock wk, gv$session ws 
WHERE hk.BLOCK = 1 AND wk.TYPE(+) = hk.TYPE AND wk.id1(+) = hk.id1 
AND wk.id2(+) = hk.id2 AND hk.sid = bs.sid(+) 
AND wk.sid = ws.sid(+) AND bs.sid != ws.sid group by bs.inst_id, bs.sid
order by 2 desc;

SELECT bs.inst_id, bs.sid BSID, count(ws.sid) as NumWait 
FROM gv$lock hk, gv$session bs, gv$lock wk, gv$session ws 
WHERE hk.BLOCK = 1 AND wk.TYPE(+) = hk.TYPE AND wk.id1(+) = hk.id1 
AND wk.id2(+) = hk.id2 AND hk.sid = bs.sid(+) 
AND wk.sid = ws.sid(+) AND bs.sid != ws.sid group by bs.inst_id, bs.sid
order by 2 desc;

