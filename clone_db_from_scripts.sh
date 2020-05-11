#!/bin/bash
# _output=()
_used_dbs=()
_used_views=()
_used_tables=()
_used_triggers=()
_used_functions=()
_used_procedures=()
_test_array=(temp_sql_scripts/test_1.sql temp_sql_scripts/test_2.sql temp_sql_scripts/test_3.sql)
touch output.sql
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
		_table_names=( $( mysql --batch mysql -uroot -pmed123 -N -e "select TABLE_NAME from information_schema.tables where TABLE_TYPE='BASE TABLE' AND TABLE_SCHEMA='${db}';" ) )

		union_of_arrays _currentScript _table_names 
		_used_tables+=("${_union_match[@]/#/$db.}")
	done	
	_used_tables=($(printf "%s\n" "${_used_tables[@]}" | sort -u | tr '\n' ' '))
	
	currentScript=()
done


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
	IFS=$'\t' read -r col1 col2   <<< "${table_creation[0]}"
	_output="${_output} \nUSE $db_temp_name;\n${col2};"
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
	else
		echo "Oops, something went wrong..."
	fi
done
printf '%b ' "${_output[@]}"> output.sql
# echo Dbs to create:  "${_used_dbs[@]}"
# echo Tables to create:  "${_used_tables[@]}"
# echo Views to create: "${_used_views[@]}"
 #_used_tables=($(printf "%s\n" "${_used_tables[@]}" | sort -u | tr '\n' ' '))

# _used_tables=($(printf "%s\n" "${_used_tables[@]}" | sort -u | tr '\n' ' '))
		# if [[ (${_used_tables[0]} = "db2.car") ]]; then
            # echo true
       
		# else 
		# echo false
		# fi
# printf '%s\n' "${_used_tables[@]}"
#unique=($(printf _used_viewss\n" "${used_dbs[@]}" | sort -u | tr '\n' ' '))
#echo "${used_dbs[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '
#unique=($(printf "%s\n" "${used_dbs[@]}" | sort -u | tr '\n' ' '))
#echo ${used_dbs[1]}