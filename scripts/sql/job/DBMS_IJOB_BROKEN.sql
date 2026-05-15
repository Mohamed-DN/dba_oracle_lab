-- Source: https://www.scriptdba.com/statement-per-impostare-i-job-in-broken/
-- Title: DBMS_IJOB BROKEN

alter systems set job_queue_processes=0 scope=both;

alter systems set job_queue_processes=0 scope=both;

exec dbms_ijob.broken (&JOB,TRUE);

exec dbms_ijob.broken (&JOB,TRUE);

