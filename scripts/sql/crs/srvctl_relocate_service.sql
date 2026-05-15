-- Source: https://www.scriptdba.com/srvctl-relocate-service/
-- Title: srvctl relocate service

crsctl status res -t

crsctl status res -t

srvctl relocate service -d <database> -s <service> -i <nome_istanza_provenienza> -t <nome_istanza_destinazione>

srvctl relocate service -d <database> -s <service> -i <nome_istanza_provenienza> -t <nome_istanza_destinazione>

srvctl relocate service -d DBTESTp -s DB_TEST_SERVICE -i DBTESTp1 -t DBTESTp2

srvctl relocate service -d DBTESTp -s DB_TEST_SERVICE -i DBTESTp1 -t DBTESTp2

crsctl status res -t

crsctl status res -t

