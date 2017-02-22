#!/bin/bash
MYSQL_HOST="10.25.58.246"
MYSQL_PORT="3306"
MYSQL_USER="root"
MYSQL_PASS="123456"
MYSQLADMIN="/usr/bin/mysqladmin"
MYSQLADMIN_COMMAND="$MYSQLADMIN -i1 ext -u$MYSQL_USER -p$MYSQL_PASS "

if [ ! -x $MYSQLADMIN ];then
    echo "Command $MYSQLADMIN not found."
    exit 1
fi

show_help() {
    echo " Usage: $0 <query|thread> "
    exit 1
}

case "$1" in  
    query)
        $MYSQLADMIN_COMMAND -r 2>/dev/null |gawk -F"|" "BEGIN{ count=0; }"'{ if($2 ~ /Variable_name/ && ++count == 1){\
    print "--------|-------|--Network Traffic--|--- MySQL Command Status --|----- Innodb row operation ----|----------- Buffer Pool ----------";\
    print "--Time--|--QPS--| Received      Sent|select insert update delete|  read inserted updated deleted| r-logical  r-physical  w-logical ";\
}\
else if ($2 ~ /Queries/){queries=$3;}\
else if ($2 ~ /Bytes_sent/){bytes_sent=$3;}\
else if ($2 ~ /Bytes_received/){bytes_rec=$3;}\
else if ($2 ~ /Com_select /){com_select=$3;}\
else if ($2 ~ /Com_insert /){com_insert=$3;}\
else if ($2 ~ /Com_update /){com_update=$3;}\
else if ($2 ~ /Com_delete /){com_delete=$3;}\
else if ($2 ~ /Innodb_rows_read/){innodb_rows_read=$3;}\
else if ($2 ~ /Innodb_rows_deleted/){innodb_rows_deleted=$3;}\
else if ($2 ~ /Innodb_rows_inserted/){innodb_rows_inserted=$3;}\
else if ($2 ~ /Innodb_rows_updated/){innodb_rows_updated=$3;}\
else if ($2 ~ /Innodb_buffer_pool_read_requests/){innodb_lor=$3;}\
else if ($2 ~ /Innodb_buffer_pool_reads/){innodb_phr=$3;}\
else if ($2 ~ /Innodb_buffer_pool_write_requests/){innodb_pbw=$3;}\
else if ($2 ~ /Uptime / && count >= 2){\
printf("%s|%7d",strftime("%H:%M:%S"),queries);\
printf("|%8d %10d",bytes_rec,bytes_sent);\
printf("|%6d %6d %6d %6d",com_select,com_insert,com_update,com_delete);\
printf("|%6d %8d %7d %7d",innodb_rows_read,innodb_rows_inserted,innodb_rows_updated,innodb_rows_deleted);\
printf("|%10d %10d %10d\n",innodb_lor,innodb_phr,innodb_pbw);\
}}' ;;
    thread)
        echo ">>>>> Max Used MySQL Connections:  $($MYSQLADMIN_COMMAND -c1 2>/dev/null | awk '/Max_used_connections/ {print $4}')"
        $MYSQLADMIN_COMMAND 2>/dev/null | awk 'BEGIN { \
print "--------|------ Threads -----|------------- InnoDB Pending IO-------------|------------------- Qcache -----------------|";\
print "--Time--| Connected   Running| pending-read pending-writes pending-fsyncs |    qcache-hits   qcache-inserts hits-ratio |"} \
/Com_select/{com_select=$4} \
/Innodb_data_pending_reads/{pr=$4} \
/Innodb_data_pending_writes/{pw=$4} \
/Innodb_data_pending_fsyncs/{pf=$4} \
/Qcache_hits/{qh=$4} \
/Qcache_inserts/{qi=$4} \
/Threads_connected/{tc=$4} \
/Threads_running/ {printf "%s|%10d %8d | %12d %14d %14d | %15d %15d %f%\n",strftime("%H:%M:%S"), tc, $4, pr, pw, pf, qh, qi, 100*qh/(qh+com_select)}' ;; 
    *) show_help ;;
esac
