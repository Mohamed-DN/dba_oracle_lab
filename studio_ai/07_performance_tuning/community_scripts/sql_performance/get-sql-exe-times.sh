#!/usr/bin/env bash


banner () {
	echo
	echo '########################################################'
	echo "## $@"
	echo '########################################################'
	echo
}

: "${SQLPLUS_CONNECT:?Set SQLPLUS_CONNECT, example scott/<password>@orcl}"

for sqlid in $(grep -Eo '^[[:alnum:]]{13}' logs/sql-buffer-ratios-awr_2024-03-05_14-22-10.log)
do
	banner "SQL_ID: $sqlid"

	sqlplus -S -L "${SQLPLUS_CONNECT}" <<-EOF
		

	EOF
done


	
