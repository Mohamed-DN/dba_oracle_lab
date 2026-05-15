-- Source: https://www.scriptdba.com/sql-server-cambio-path-database-di-sistema/
-- Title: SQL Server cambio path database di sistema

USE master

Go

ALTER DATABASE model MODIFY FILE ( NAME = 'modeldev' , FILENAME = 'S:\XXXX_Dati_01\Data\model.mdf' );

Go

ALTER DATABASE model MODIFY FILE ( NAME = 'modellog' , FILENAME = 'S:\XXXX_Log_01\TLog\modellog.ldf' );

Go

ALTER DATABASE msdb MODIFY FILE ( NAME = 'MSDBData' , FILENAME = 'S:\XXXX_Dati_01\Data\MSDBData.mdf' );

Go

ALTER DATABASE msdb MODIFY FILE ( NAME = 'MSDBLog' , FILENAME = 'S:\XXXX_Log_01\TLog\MSDBLog.ldf' );

Go

USE master

Go

ALTER DATABASE model MODIFY FILE ( NAME = 'modeldev' , FILENAME = 'S:\XXXX_Dati_01\Data\model.mdf' );

Go

ALTER DATABASE model MODIFY FILE ( NAME = 'modellog' , FILENAME = 'S:\XXXX_Log_01\TLog\modellog.ldf' );

Go

ALTER DATABASE msdb MODIFY FILE ( NAME = 'MSDBData' , FILENAME = 'S:\XXXX_Dati_01\Data\MSDBData.mdf' );

Go

ALTER DATABASE msdb MODIFY FILE ( NAME = 'MSDBLog' , FILENAME = 'S:\XXXX_Log_01\TLog\MSDBLog.ldf' );

Go

net stop mssqlserver

net stop mssqlserver

net start mssqlserver

net start mssqlserver

net stop mssqlserver

net stop mssqlserver

net start mssqlserver

net start mssqlserver

