-- Source: https://www.scriptdba.com/query-per-vedere-i-numeri-di-sessioni-processi-transazioni-e-cursori/
-- Title: Query sessioni processi transazioni cursori Oracle

TAG   PARAMETER                                                        CURRENT MAXIMUM USAGE%
----- ---------------------------------------------------------------- ------- ------- ------
PSTAT open_cursors                                                          33     300     11
PSTAT processes                                                             52     300     17
PSTAT sessions                                                              33     472      6
PSTAT transactions                                                           0     519      0

TAG   PARAMETER                                                        CURRENT MAXIMUM USAGE%
----- ---------------------------------------------------------------- ------- ------- ------
PSTAT open_cursors                                                          33     300     11
PSTAT processes                                                             52     300     17
PSTAT sessions                                                              33     472      6
PSTAT transactions                                                           0     519      0

set verify off
set termout off
set feedback off
set echo off
set serveroutput on size 999999
set linesize 132
set termout on
declare
MISSING_PARAMETER exception;
MISSING_STAT_OPENCURS exception;
--
MaxIdxParameter integer;
type parameter_name is record (
name varchar2(64),
value integer);
type parameter_list_array is table of parameter_name index by binary_integer;
parameter_lst parameter_list_array;
type parameter_type is record (
current_value integer);
type parameter_array is table of parameter_type index by binary_integer;
parameter_stat parameter_array;
--
function LoadParameterList return number is
cursor parameter_list is
select 1 parameter_id, name, to_number(value) value from v$parameter where name = 'open_cursors'
union all
select 2, name, to_number(value) from v$parameter where name = 'processes'
union all
select 3, name, to_number(value) from v$parameter where name = 'sessions'
union all
select 4, name, to_number(value) from v$parameter where name = 'transactions';
begin
MaxIdxParameter := 1;
for rec_parameter_list in parameter_list loop
if rec_parameter_list.parameter_id = MaxIdxParameter then
parameter_lst(MaxIdxParameter).name := rec_parameter_list.name;
parameter_lst(MaxIdxParameter).value := rec_parameter_list.value;
MaxIdxParameter := MaxIdxParameter + 1;
else
return MaxIdxParameter;
end if;
end loop;
MaxIdxParameter := MaxIdxParameter - 1;
return 0;
end LoadParameterList;
--
procedure LoadParameterStat is
stat_id number;
cursor parameter_list (p_stat in number) is
select 1 parameter_id, max(count(*)) current_value from v$open_cursor group by sid
union all
select 2, count(*) current_value from v$process
union all
select 3, count(*) current_value from v$session
union all
select 4, count(*) current_value from v$transaction;
begin
begin select statistic# into stat_id from v$statname where name = 'opened cursors current';
exception when no_data_found then raise MISSING_STAT_OPENCURS;
end;
for rec_parameter_list in parameter_list(stat_id) loop
parameter_stat(rec_parameter_list.parameter_id).current_value := rec_parameter_list.current_value;
end loop;
end LoadParameterStat;
--
procedure OutputStats is
ParameterId integer;
PctUsage number;
begin
dbms_output.put(rpad('TAG',5));
dbms_output.put(' '||rpad('PARAMETER',64));
dbms_output.put(' '||rpad('CURRENT',7));
dbms_output.put(' '||rpad('MAXIMUM',7));
dbms_output.put(' '||rpad('USAGE%',6));
dbms_output.new_line;
dbms_output.put(rpad('-',5,'-'));
dbms_output.put(' '||rpad('-',64,'-'));
dbms_output.put(' '||rpad('-',7,'-'));
dbms_output.put(' '||rpad('-',7,'-'));
dbms_output.put(' '||rpad('-',6,'-'));
dbms_output.new_line;
for ParameterId in 1..MaxIdxParameter loop
dbms_output.put(rpad('PSTAT',5));
dbms_output.put(' '||rpad(parameter_lst(ParameterId).name,64));
PctUsage := trunc(100*parameter_stat(ParameterId).current_value/parameter_lst(ParameterId).value);
dbms_output.put(' '||lpad(parameter_stat(ParameterId).current_value,7));
dbms_output.put(' '||lpad(parameter_lst(ParameterId).value,7));
dbms_output.put(' '||lpad(PctUsage,6));
dbms_output.new_line;
end loop;
end OutputStats;
begin
-----------------------------------------------------
-- catalogazione parametri sistema
-----------------------------------------------------
if LoadParameterList != 0 then raise MISSING_PARAMETER;
end if;
LoadParameterStat;
-----------------------------------------------------
-- output statistiche
-----------------------------------------------------
OutputStats;
exception
when MISSING_PARAMETER then raise_application_error(-20000,'missing parameter id='||MaxIdxParameter);
when MISSING_STAT_OPENCURS then raise_application_error(-20001,'missing statistic: "opened cursors current"');
end;
/

set verify off
set termout off
set feedback off
set echo off
set serveroutput on size 999999
set linesize 132
set termout on
declare
MISSING_PARAMETER exception;
MISSING_STAT_OPENCURS exception;
--
MaxIdxParameter integer;
type parameter_name is record (
name varchar2(64),
value integer);
type parameter_list_array is table of parameter_name index by binary_integer;
parameter_lst parameter_list_array;
type parameter_type is record (
current_value integer);
type parameter_array is table of parameter_type index by binary_integer;
parameter_stat parameter_array;
--
function LoadParameterList return number is
cursor parameter_list is
select 1 parameter_id, name, to_number(value) value from v$parameter where name = 'open_cursors'
union all
select 2, name, to_number(value) from v$parameter where name = 'processes'
union all
select 3, name, to_number(value) from v$parameter where name = 'sessions'
union all
select 4, name, to_number(value) from v$parameter where name = 'transactions';
begin
MaxIdxParameter := 1;
for rec_parameter_list in parameter_list loop
if rec_parameter_list.parameter_id = MaxIdxParameter then
parameter_lst(MaxIdxParameter).name := rec_parameter_list.name;
parameter_lst(MaxIdxParameter).value := rec_parameter_list.value;
MaxIdxParameter := MaxIdxParameter + 1;
else
return MaxIdxParameter;
end if;
end loop;
MaxIdxParameter := MaxIdxParameter - 1;
return 0;
end LoadParameterList;
--
procedure LoadParameterStat is
stat_id number;
cursor parameter_list (p_stat in number) is
select 1 parameter_id, max(count(*)) current_value from v$open_cursor group by sid
union all
select 2, count(*) current_value from v$process
union all
select 3, count(*) current_value from v$session
union all
select 4, count(*) current_value from v$transaction;
begin
begin select statistic# into stat_id from v$statname where name = 'opened cursors current';
exception when no_data_found then raise MISSING_STAT_OPENCURS;
end;
for rec_parameter_list in parameter_list(stat_id) loop
parameter_stat(rec_parameter_list.parameter_id).current_value := rec_parameter_list.current_value;
end loop;
end LoadParameterStat;
--
procedure OutputStats is
ParameterId integer;
PctUsage number;
begin
dbms_output.put(rpad('TAG',5));
dbms_output.put(' '||rpad('PARAMETER',64));
dbms_output.put(' '||rpad('CURRENT',7));
dbms_output.put(' '||rpad('MAXIMUM',7));
dbms_output.put(' '||rpad('USAGE%',6));
dbms_output.new_line;
dbms_output.put(rpad('-',5,'-'));
dbms_output.put(' '||rpad('-',64,'-'));
dbms_output.put(' '||rpad('-',7,'-'));
dbms_output.put(' '||rpad('-',7,'-'));
dbms_output.put(' '||rpad('-',6,'-'));
dbms_output.new_line;
for ParameterId in 1..MaxIdxParameter loop
dbms_output.put(rpad('PSTAT',5));
dbms_output.put(' '||rpad(parameter_lst(ParameterId).name,64));
PctUsage := trunc(100*parameter_stat(ParameterId).current_value/parameter_lst(ParameterId).value);
dbms_output.put(' '||lpad(parameter_stat(ParameterId).current_value,7));
dbms_output.put(' '||lpad(parameter_lst(ParameterId).value,7));
dbms_output.put(' '||lpad(PctUsage,6));
dbms_output.new_line;
end loop;
end OutputStats;
begin
-----------------------------------------------------
-- catalogazione parametri sistema
-----------------------------------------------------
if LoadParameterList != 0 then raise MISSING_PARAMETER;
end if;
LoadParameterStat;
-----------------------------------------------------
-- output statistiche
-----------------------------------------------------
OutputStats;
exception
when MISSING_PARAMETER then raise_application_error(-20000,'missing parameter id='||MaxIdxParameter);
when MISSING_STAT_OPENCURS then raise_application_error(-20001,'missing statistic: "opened cursors current"');
end;
/

