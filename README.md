
### ak-dash-shell.pl 
可以考虑作为监控、研发人员的login shell。

### ak-certificate-generator.sh
快速生成自签名SSL证书，以用于测试或其他目的。

### ak-mysql-realtime-status.sh 
MySQL/MariaDB的实时状态监控。

    # ak-mysql-realtime-status.sh query
    --------|-------|--Network Traffic--|--- MySQL Command Status --|----- Innodb row operation ----|----------- Buffer Pool ----------
    --Time--|--QPS--| Received      Sent|select insert update delete|  read inserted updated deleted| r-logical  r-physical  w-logical 
    15:46:22|    869|  168725    2038575|   382     14     14      0|     0        0       0       0|         0          0          0
    15:46:23|    946|  184717    2394139|   450      7     20      0|     2        1       2       0|        45          0         19
    15:46:24|    751|  149707    1887488|   329     10     13      0|     0        2       0       0|        30          0         15
    15:46:25|    973|  186031    2328225|   442     11     18      0|     0        0       0       0|         0          0          0
    15:46:26|    623|  120460    1527219|   265     12     17      1|     2        0       2       0|        33          0         13
    # ak-mysql-realtime-status.sh thread
    >>>>> Max Used MySQL Connections:  291
    --------|------ Threads -----|------------- InnoDB Pending IO-------------|------------------- Qcache -----------------|
    --Time--| Connected   Running| pending-read pending-writes pending-fsyncs |    qcache-hits   qcache-inserts hits-ratio |
    15:46:31|         7        3 |            0              0              0 |       273517066       441041854 27.968750%
    15:46:32|         8        1 |            0              0              0 |       273517164       441042012 27.968747%
    15:46:33|         6        1 |            0              0              0 |       273517240       441042167 27.968743%
    15:46:34|        10        1 |            0              0              0 |       273517360       441042334 27.968743%
    15:46:35|         7        2 |            0              0              0 |       273517466       441042562 27.968739%

### ak-mysql-pretty-slowlog.pl
MySQL慢日志对技术人员是比较有价值的，不过默认的slow log查看起来不是非常美观，经过本脚本美颜之后，就赏心悦目多了。

### ak-vsftpd-install.sh
一键部署vsftpd FTP服务器。

### ak-blackip-generator.pl
从恶意IP列表中直接生成nginx deny 规则，此规则将阻止恶意IP/24网段所有IP的访问，用于特殊情况下的应急处理。

### ak-zabbix-log-checker.pl
替代Zabbix的Log file monitoring。

### ak-nginx-log-analyzer.pl
结合了GeoIP的nginx访问日志分析，可快速掌握分辨恶意的请求或IP地址。对应的nginx日志格式：`
log_format  access '[$time_local] $status $remote_addr $request_time $body_bytes_sent $host $request $http_referer "$http_user_agent" $http_x_forwarded_for'; 
`

    --------------------------------------------------------------------------------
    | Count  | HTTP Status                    |
    --------------------------------------------------------------------------------
    | 144086 | 200                            |
    | 938    | 302                            |
    | 86     | 500                            |
    | 43     | 499                            |
    | 24     | 404                            |
    | 3      | 401                            |
    | 3      | 304                            |
    --------------------------------------------------------------------------------
    | Count  | IP ADDRESS                     | Location                                 | 
    --------------------------------------------------------------------------------
    | 1686   | 123.235.119.143                | China/Shandong/Jinan                     | 
    | 249    | 182.149.160.6                  | China/Sichuan/Chengdu                    | 
    | 229    | 223.104.188.85                 | China/Shandong/                          | 
    | 173    | 223.104.177.66                 | China/Liaoning/Dalian                    | 
    | 171    | 59.53.67.230                   | China/Jiangxi/Nanchang                   | 
    | 162    | 112.241.113.224                | China/Shandong/Jinan                     | 
    | 155    | 117.136.46.199                 | China/Jiangsu/Taicang                    | 
    | 154    | 101.226.103.63                 | China/Shanghai/Shanghai                  | 
    | 152    | 61.174.54.133                  | China/Zhejiang/Huzhou                    | 
    | 148    | 222.208.150.129                | China/Sichuan/Chengdu                    | 
    --------------------------------------------------------------------------------------
    | Count  | URL                                                                       
    --------------------------------------------------------------------------------------
    | 12616  | /                                                                          
    | 1847   | /sign.html                                                               
    | 1781   | /page/scounter?projectcode=kumBWR7X5GM8zZmGagzOg66q0wuGRuBR     
    | 1672   | /page/sdata?projectcode=kumBWR7X5GM8zZmGagzOg66q0wuGRuBR       
    | 1671   | /qr.php?projectcode=kumBWR7X5GM8zZmGagzOg66q0wuGRuBR              
    | 1478   | /page/page?projectcode=kumBWR7X5GM8zZmGagzOg66q0wuGRuBR          
    | 1297   | /login.php?sitename=weixin                                          
    | 1253   | /page/my/index                                                 
    | 1052   | /page/dodonate                                                
    | 903    | /pay/applepay/notify.php                                                

### ak-elk-log-sender.py
Elasticsearch+Logstash+Kibana架构中，在客户端本地直接完成Nginx日志中的IP来源分析、UserAgent分析等等，然后直接发送到Logstash服务端。

nginx日志格式： `log_format  access '[$time_local] | $status | $host | $request | $remote_addr | $http_user_agent';`

Logstash服务端自定义PATTERN: `NGINXACCESS \[%{HTTPDATE:timestamp}\] %{NUMBER:response} %{IPORHOST:http_host} %{WORD:verb} %{URIPATHPARAM:request} HTTP/%{NUMBER:httpversion} %{IP:clientip} \"%{DATA:os}\" \"%{DATA:mobile_device}\" \"%{DATA:browser}\" \"%{DATA:country}\" \"%{DATA:city}\"`

### securecrt_via_session.py
SecureCRT+Python. 连接到指定SecureCRT session(例如跳板机)之后，再自动连接到server.txt中的服务器列表，配合Chat Window/Command Window功能使用，完美的并发执行（建议同时操作的服务器不超过30台，否则Tab太多~~）。

服务器列表文件server.txt格式: 

```
user1:host1:sshport:password
user2:host2:sshport:password
user3:host3:sshport:password
```

适合场景：

1. 尚未使用Saltstack、ansible之类的软件。

2. 虽然有Saltstack、ansible，但所执行的命令需要一定的交互或者花费较长时间。

3. 虽然有Saltstack、ansible，但在意所执行命令的实时输出。

### securecrt_direct_conn.py
在SecureCRT中直接打开server.txt中的所有服务器。

### ak-jailkit.sh
CentOS下Jailkit自动设置。从 https://olivier.sessink.nl/jailkit/ 编译安装后，执行该脚本即可。

默认创建了用户：`goosr`，密码：`123456`。测试完毕之后，记得及时删除或修改。

### ak-ldap-tool.sh
SSH+LDAP登录，之前为了方便LDAP用户管理写的一个脚本。

