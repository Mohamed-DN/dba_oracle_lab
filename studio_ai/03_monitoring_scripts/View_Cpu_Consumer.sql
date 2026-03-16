SET LINES 300
SET PAGES 300
COL USERNAME FOR A18
COL OSUSER FOR A18
COL MACHINE FOR A25
COL COMMAND FOR A10

SELECT   s.sid sid,
         s.username username,
         UPPER (
            DECODE (
               command,
               1, 'Create Table',
               2, 'Insert',
               3, 'Select',
               4, 'Create Cluster',
               5, 'Alter Cluster',
               6, 'Update',
               7, 'Delete',
               8, 'Drop Cluster',
               9, 'Create Index',
               10, 'Drop Index',
               11, 'Alter Index',
               12, 'Drop Table',
               13, 'Create Sequencfe',
               14, 'Alter Sequence',
               15, 'Alter Table',
               16, 'Drop Sequence',
               17, 'Grant',
               18, 'Revoke',
               19, 'Create Synonym',
               20, 'Drop Synonym',
               21, 'Create View',
               22, 'Drop View',
               23, 'Validate Index',
               24, 'Create Procedure',
               25, 'Alter Procedure',
               26, 'Lock Table',
27, 'No Operation',
               28, 'Rename',
               29, 'Comment',
               30, 'Audit',
               31, 'NoAudit',
               32, 'Create Database Link',
               33, 'Drop Database Link',
               34, 'Create Database',
               35, 'Alter Database',
               36, 'Create Rollback Segment',
               37, 'Alter Rollback Segment',
               38, 'Drop Rollback Segment',
               39, 'Create Tablespace',
               40, 'Alter Tablespace',
               41, 'Drop Tablespace',
               42, 'Alter Sessions',
               43, 'Alter User',
               44, 'Commit',
               45, 'Rollback',
               46, 'Savepoint',
               47, 'PL/SQL Execute',
               48, 'Set Transaction',
               49, 'Alter System Switch Log',
               50, 'Explain Plan',
               51, 'Create User',
               52, 'Create Role',
               53, 'Drop User',
               54, 'Drop Role',
               55, 'Set Role',
               56, 'Create Schema',
               57, 'Create Control File',
               58, 'Alter Tracing',
               59, 'Create Trigger',
               60, 'Alter Trigger',
               61, 'Drop Trigger',
               62, 'Analyze Table',
               63, 'Analyze Index',
               64, 'Analyze Cluster',
               65, 'Create Profile',
               66, 'Drop Profile',
               67, 'Alter Profile',
               68, 'Drop Procedure',
               69, 'Drop Procedure',
               70, 'Alter Resource Cost',
               71, 'Create Snapshot Log',
               72, 'Alter Snapshot Log',
               73, 'Drop Snapshot Log',
               74, 'Create Snapshot',
               75, 'Alter Snapshot',
               76, 'Drop Snapshot',
               79, 'Alter Role',
               85, 'Truncate Table',
               86, 'Truncate Cluster',
               88, 'Alter View',
               91, 'Create Function',
               92, 'Alter Function',
               93, 'Drop Function',
               94, 'Create Package',
               95, 'Alter Package',
               96, 'Drop Package',
               97, 'Create Package Body',
               98, 'Alter Package Body',
               99, 'Drop Package Body'
            )
         ) command,
         s.osuser osuser,
         s.machine machine,
         s.process process,
         t.VALUE value
FROM     v$session s, v$sesstat t, v$statname n
WHERE    s.sid = t.sid
AND      t.statistic# = n.statistic#
AND      n.name = 'CPU used by this session'
AND      t.VALUE > 0
AND      audsid > 0
ORDER BY t.VALUE DESC;

       SID USERNAME           COMMAND    OSUSER             MACHINE                   PROCESS           VALUE
---------- ------------------ ---------- ------------------ ------------------------- ------------ ----------
        26 GBC_LOCALenrico.landi WORKGROUP\HHUB7060CY5 4492:5932 93792
        75 GBC_RO                        rainbow            h3fas092                  602               32692
        37 GBC_LOCALuser WORKGROUP\GHOST-DX5150 3456:3032 4258
        35 TPSYSADM                      oracle             h3mih111                  26047              2460
        62 TPSYSADM                      oracle             h3mih111                  26330              1717
        99 TPSYSADM                      oracle             h3mih111                  29006              1610
        72 FRIGOA                        e-ChaffeeT         H3G\T-CHAFFEE             708:1628           1313
        20 TPSYSADM                      tibco2             h3mih111                  24800               995
       100 TPSYSADM                      oracle             h3mih111                  12781               931
        34 TPSYSADM                      oracle             h3mih111                  17041               791
        41 GBC_LOCAL                     nuovo              MSHOME\NEW-OK             3632:2096           706