#!/bin/bash
# _output=()
_used_dbs=()
_used_views=()
_used_tables=()
_used_triggers=()
_used_functions=()
_used_procedures=()
# _test_array=(temp_sql_scripts/test_1.sql temp_sql_scripts/test_2.sql temp_sql_scripts/test_3.sql)
_test_array=( $( mysql --batch mysql -uroot -pmed123 -N -e "SELECT script_name  FROM X.scripts WHERE script_plateform='encour'" ) )
function union_of_arrays() { 
	unset _union_match
	_union_match=()
	local -n _array_one=$1
	local -n _array_two=$2
	for word in ${_array_one[@]}
	do
		if [[ (${_array_two[*]} =~ "$word") ]]; then
            _union_match+=($word)
        fi
	done
}
_output="/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;\n /*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;\n /*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;\n /*!50503 SET NAMES utf8mb4 */;\n /*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;\n /*!40103 SET TIME_ZONE='+00:00' */;\n /*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;\n /*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;\n /*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;\n /*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;\n"
for script in ${_test_array[@]}
do
	_currentScript+=($(echo $(cat $script | sed 's/[^0-9  _  a-z  A-Z]/ /g' | tr '[:upper:]' '[:lower:]')))
	
	
	_db_names=( $( mysql --batch mysql -uroot -pmed123 -N -e "show databases;" ) )
	union_of_arrays _currentScript _db_names 
	_used_dbs+=(${_union_match[@]})
	_used_dbs=($(printf "%s\n" "${_used_dbs[@]}" | sort -u | tr '\n' ' '))
	for db in ${_used_dbs[@]}
	do
		_view_names=( $( mysql --batch mysql -uroot -pmed123 -N -e "select TABLE_NAME from information_schema.tables where TABLE_TYPE='VIEW' AND TABLE_SCHEMA= '${db}';" ) )
		union_of_arrays _currentScript _view_names 
		_used_views+=("${_union_match[@]/#/$db.}")
	done
	_used_views=($(printf "%s\n" "${_used_views[@]}" | sort -u | tr '\n' ' '))
	for view in ${_used_views[@]}
	do
		current_view=(${view//./ })
		_used_tables+=( $( mysql --batch mysql -uroot -pmed123 -N -e "SELECT DISTINCT CONCAT(TABLE_SCHEMA, '.', TABLE_NAME) FROM INFORMATION_SCHEMA.VIEW_TABLE_USAGE WHERE TABLE_SCHEMA= '${current_view[0]}' AND VIEW_NAME= '${current_view[1]}';" ) )
	done
	for db in ${_used_dbs[@]}
	do
		_procedure_names=( $( mysql --batch mysql -uroot -pmed123 -N -e "SELECT SPECIFIC_NAME FROM INFORMATION_SCHEMA.ROUTINES where ROUTINE_SCHEMA='${db}' AND ROUTINE_TYPE='PROCEDURE';" ) )
		union_of_arrays _currentScript _procedure_names 
		_used_procedures+=("${_union_match[@]/#/$db.}")
	done
	_used_procedures=($(printf "%s\n" "${_used_procedures[@]}" | sort -u | tr '\n' ' '))
	_additionnal_scripts=()
	# printf '%s\n' "${_used_procedures[@]}"
	for procedure in ${_used_procedures[@]}
	do
		set -f        # disable globbing
		IFS=$'\n'     # set field separator to NL (only)
		# echo "show create procedure ${procedure};"
		procedure_creation=( $( mysql -uroot -pmed123 -N -e "show create procedure ${procedure};" ) )
		if [ ${#procedure_creation[@]} != 0 ]; then
		IFS=$'\t' read -r col1 col2 col3 col4  <<< "${procedure_creation[0]}"
		_procedure_output="${procedure} ${col3}"
		fi
		_additionnal_scripts+=($(echo $_procedure_output | sed 's/[^0-9  _  a-z  A-Z]/ /g' | tr '[:upper:]' '[:lower:]'))
		printf '%s\n' "hhhhhhhhhhhhh${_additionnal_scripts[@]}"
	done
		IFS=' '
	for db in ${_used_dbs[@]}
	do
		_function_names=( $( mysql --batch mysql -uroot -pmed123 -N -e "SELECT SPECIFIC_NAME FROM INFORMATION_SCHEMA.ROUTINES where ROUTINE_SCHEMA='${db}' AND ROUTINE_TYPE='fUNCTION';" ) )
		union_of_arrays _currentScript _function_names 
		_used_functions+=("${_union_match[@]/#/$db.}")
	done
	_used_functions=($(printf "%s\n" "${_used_functions[@]}" | sort -u | tr '\n' ' '))	
	_currentScript+=${_additionnal_scripts[@]}
	for db in ${_used_dbs[@]}
	do
		_table_names=( $( mysql --batch mysql -uroot -pmed123 -N -e "select TABLE_NAME from information_schema.tables where TABLE_TYPE='BASE TABLE' AND TABLE_SCHEMA='${db}';" ) )

		union_of_arrays _currentScript _table_names 
		_used_tables+=("${_union_match[@]/#/$db.}")
	done	
	_used_tables=($(printf "%s\n" "${_used_tables[@]}" | sort -u | tr '\n' ' '))


	echo CURRENTLY PROCESSING ${script} IT SIZE IS "${#_currentScript[@]}"
	printf '%s\n' "${_currentScript[@]}"
	_currentScript=()
done





for constraint_table in ${_used_tables[@]}
do
	current_table=(${constraint_table//./ })
	# echo was here
	_constraint_tables=( $( mysql --batch mysql -uroot -pmed123 -N -e "SELECT CONCAT(TABLE_SCHEMA, '.', REFERENCED_TABLE_NAME) FROM information_schema.KEY_COLUMN_USAGE WHERE CONSTRAINT_SCHEMA = '${current_table[0]}' AND TABLE_NAME = '${current_table[1]}' AND REFERENCED_TABLE_NAME != 'null';" ) )
	_used_tables+=(${_constraint_tables[@]})
done
_used_tables=($(printf "%s\n" "${_used_tables[@]}" | sort -u | tr '\n' ' '))
printf '%s\n' "${_constraint_tables[@]}"




for db in ${_used_dbs[@]}
do
	_output="${_output} \nCREATE DATABASE $db;"
done
for table in ${_used_tables[@]}
do
	IFS=' '
	current_table=(${table//./ })
	db_temp_name=${current_table[0]}
	set -f        # disable globbing
	IFS=$'\n'     # set field separator to NL (only)
	table_creation=( $( mysql -uroot -pmed123 -N -e "show create table ${table};" ) )
	if [ ${#table_creation[@]} != 0 ]; then	
	IFS=$'\t' read -r col1 col2   <<< "${table_creation[0]}"
	_output="${_output} \nUSE $db_temp_name;\n${col2};"
	fi
done
for view in ${_used_views[@]}
do
	IFS=' '
	current_view=(${view//./ })
	db_temp_name=${current_view[0]}
	set -f        # disable globbing
	IFS=$'\n'     # set field separator to NL (only)
	view_creation=( $( mysql -uroot -pmed123 -N -e "show create view ${view};" ) )
	if [ ${#view_creation[@]} != 0 ]; then
	IFS=$'\t' read -r col1 col2 col3   <<< "${view_creation[0]}"
	_output="${_output} \nUSE $db_temp_name;\n${col2};"
	fi
done
for procedure in ${_used_procedures[@]}
do
	IFS=' '
	current_procedure=(${procedure//./ })
	db_temp_name=${current_procedure[0]}
	set -f        # disable globbing
	IFS=$'\n'     # set field separator to NL (only)
	procedure_creation=( $( mysql -uroot -pmed123 -N -e "show create procedure ${procedure};" ) )
	if [ ${#procedure_creation[@]} != 0 ]; then
	IFS=$'\t' read -r col1 col2 col3 col4  <<< "${procedure_creation[0]}"
	_output="${_output} \nUSE $db_temp_name;\n delimiter // \n${col3}; // \n delimiter ; "
	fi
done
for function in ${_used_functions[@]}
do
	IFS=' '
	current_function=(${function//./ })
	db_temp_name=${current_function[0]}
	set -f        # disable globbing
	IFS=$'\n'     # set field separator to NL (only)
	function_creation=( $( mysql -uroot -pmed123 -N -e "show create function ${function};" ) )
	if [ ${#function_creation[@]} != 0 ]; then
	IFS=$'\t' read -r col1 col2 col3 col4  <<< "${function_creation[0]}"
	_output="${_output} \nUSE $db_temp_name; \n delimiter // \n ${col3}// \n delimiter ; "
	fi
done
touch output.sql
printf '%b\n' "${_output[@]}"> output.sql