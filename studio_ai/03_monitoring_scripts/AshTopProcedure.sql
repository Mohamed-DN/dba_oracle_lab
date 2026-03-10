SET LINESIZE 120
COL entry_package FOR a25
COL entry_procedure FOR a25
COL cur_package FOR a25
COL cur_procedure FOR a25
COL calling_code FOR a70

  SELECT COUNT (*),
         sql_id,
            procs1.object_name
         || DECODE (procs1.procedure_name, '', '', '.')
         || procs1.procedure_name
         || ' '
         || DECODE (
               procs2.object_name,
               procs1.object_name, '',
               DECODE (procs2.object_name,
                       '', '',
                       ' => ' || procs2.object_name))
         || DECODE (
               procs2.procedure_name,
               procs1.procedure_name, '',
                  DECODE (procs2.procedure_name,  '', '',  NULL, '',  '.')
               || procs2.procedure_name)
            "calling_code"
    FROM v$active_session_history ash,
         all_procedures procs1,
         all_procedures procs2
   WHERE     ash.PLSQL_ENTRY_OBJECT_ID = procs1.object_id(+)
         AND ash.PLSQL_ENTRY_SUBPROGRAM_ID = procs1.SUBPROGRAM_ID(+)
         AND ash.PLSQL_OBJECT_ID = procs2.object_id(+)
         AND ash.PLSQL_SUBPROGRAM_ID = procs2.SUBPROGRAM_ID(+)
         AND ash.sample_time > SYSDATE - &minutes / (60 * 24)
GROUP BY procs1.object_name,
         procs1.procedure_name,
         procs2.object_name,
         procs2.procedure_name,
         sql_id
ORDER BY COUNT (*)
/
