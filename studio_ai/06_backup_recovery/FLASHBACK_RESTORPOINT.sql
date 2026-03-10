--In Caso il rilascio fallisce come eseguire il flashback
--PRIMARIO:
 
alter pluggable database P1RISKIPHP close immediate instances=all;
 
flashback pluggable database P1RISKIPHP to restore point <nome_restore_point>;
 
alter pluggable database P1RISKIPHP open resetlogs;
 
srvctl start service -d CFRSKPEP -service RISKIPHP_PRY (-pdb P1RISKIPHP)
 
STANDBY:
 
srvctl stop database -d CFRSKSEP1
 
srvctl start database -d CFRSKSEP1

 