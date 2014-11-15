Zabbix Puppet Dashboard
========

This template allows to monitor Puppet reports via [Puppet Dashboard](https://github.com/sodabrew/puppet-dashboard).

Items
-----

  * Aggregated node count per status
  * Per node item: (status, last report time)

Triggers
--------

  * Last report older than 1 day 
  * Node status failed

Installation
------------

1. On your agent add `userparameter_puppetdashboard.conf` file into your `zabbix_agentd.conf.d ` directory. Modify the URL for Puppetdashboard if needed.
2. Make sure that your `zabbix_agentd.conf` include `zabbix_agentd.conf.d` directory.
3. Copy script `puppetdashboard.rb` to `/etc/zabbix/scripts´ and make it executable
4. Start or restart Zabbix Agent

#### Variant A: Trapper tests (more scalable)

5. Set up a cronjob for reporting values (on agent):
```
*/5 * * * * /etc/zabbix/scripts/puppetdashboard.rb -u http://127.0.0.1/puppetdasboard -c zabbix_sender | zabbix_sender -s admin1.dmz.former03.de -z 172.30.255.241 -i - -T  > /dev/null
```
6. Import **zabbix-puppetdashboard_trapper.xml** file into Zabbix.
7. Associate **Puppet Dashboard Trapper** template to the host.

#### Variant B: Agent tests

5. Import **zabbix-puppetdashboard_agent.xml** file into Zabbix.
6. Associate **Puppet Dashboard Agent** template to the host.

### Requirements

This template requires at least Zabbix 2.0 (Low Level Discovery).


`puppetdashboard.rb`
--------------------

```
Usage: puppetdashboard.rb [options] -c [discovery|zabbix_sender|status|created_at|reported_at|updated_at|nodes_unchanged|nodes_failed|nodes_changed|nodes_unresponsive|nodes_pending|nodes_unreported|nodes_all]
    -c, --command CMD                Command to execute
    -v, --[no-]verbose               Run verbosely
    -S, --no-ssl-verify              Disable ssl verify
    -n, --nodename NAME              Give node hostname for cmds [status|created_at|reported_at|updated_at]
    -u, --url URL                    Give dashboard base url
    -h, --help                       Show this help
```

Example graph
-------------

![Demo graphics](/demo-chart.png)


License
-------

This template is distributed under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the  License, or (at your option) any later version.

### Authors

  Christian Simon (simon@swine.de)
