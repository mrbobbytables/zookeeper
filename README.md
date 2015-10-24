# - Zookeeper -

An Ubuntu based Zookeeper container, with the capability of logging to both standard and json format. It comes packaged with Logstash-Forwarder and is managed via Supervisord.


##### Version Information:

* **Container Release:** 1.1.0
* **Mesos:** 0.24.1-0.2.35.ubuntu1404
* **Zookeeper:** 3.4.5+dfsg-1


##### Services Include:
* **[Zookeeper](#zookeeper)** - A distributed and highly available configuration service. The 'heart' of what powers Mesos.
* **[Logstash-Forwarder](#logstash-forwarder)** - A lightweight log collector and shipper for use with [Logstash](https://www.elastic.co/products/logstash).
* **[Redpill](#redpill)** - A bash script and healthcheck for supervisord managed services. It is capable of running cleanup scripts that should be executed upon container termination.


---
---
### Index

* [Usage](#usage)
 * [Example Run Command](#example-run-command)
* [Modification and Anatomy of the Project](#modification-and-anatomy-of-the-project)
* [Important Environment Variables](#important-environment-variables)
* [Service Configuration](#service-configuration)
 * [Zookeeper](#zookeeper)
 * [Logstash-Forwarder](#logstash-forwarder)
 * [Redpill](#redpill)
* [Troubleshooting](#troubleshooting)

---
---

### Usage
The Zookeeper container does not offer as much versatility as some of the others in terms of passing the configuration via variables at runtime. However, the settings that have been predefined in the Zookeeper config should be adequate to get going for most environments. Those that need further custom configuration should update the zookeeper config (`/etc/zookeeper/conf/zoo.cfg`) manually.

For local use (`ENVIRONMENT` set to `local`), no environment variables need to be defined. The default configuration that comes with zookeeper will be made active.


For production or development (`ENVIRONMENT` set to `production` or `development`) use; where you intend on having more than one server. There are two important environment variables:`ZOOKEEPER_MYID` and `ZOOKEEPER_SERVER_###`.

* `ZOOKEEPER_MYID` - The unique ID of the server that will be placed in the myid file. Valid values are 1-255.

* `ZOOKEEPER_SERVER_###` - The zookeeper cluster peers. These represent the server.id in the zookeeper configuration file. The format should be the same as you would provide in the zookeeper config manually - **ip:port:port**


Other useful, but not critical environment variables include `JAVA_OPTS`, `ZOOKEEPER_LOG_STDOUT_LAYOUT`, `ZOOKEEPER_LOG_STDOUT_THRESHOLD`, `ZOOKEEPER_LOG_FILE_LAYOUT`, and `ZOOKEEPER_LOG_STDFILE_THRESHOLD`.

* `JAVA_OPTS` - The java configuration that will be passed to zookeeper at runtime. Main option to adjust is the max java memory (`-Xmx`).

* `ZOOKEEPER_LOG_STDOUT_LAYOUT` - The log format used for stdout logging (standard or json).

* `ZOOKEEPER_LOG_STDOUT_THRESHOLD` - The logging level of the events being sent to the console of the container.

* `ZOOKEEPER_LOG_FILE_LAYOUT` - The log format used for logging to the log file (standard or json).

* `ZOOKEEPER_LOG_FILE_THRESHOLD` - The logging level of the events being sent to the zookeeper log file.

For more information regarding configuring Zookeper, please use the [Zookeeper Admin Guide](http://zookeeper.apache.org/doc/trunk/zookeeperAdmin.html)


---

### Example Run Command
```
docker run -d \
-e ENVIRONMENT=production \
-e PARENT_HOST=$(hostname) \
-e ZOOKEEPER_LOG_STDOUT_THRESHOLD=WARN \
-e ZOOKEEPER_MYID=1 \
-e ZOOKEEPER_SERVER_1=10.10.0.11:2888:3888 \
-e ZOOKEEPER_SERVER_2=10.10.0.12:2888:3888 \
-e ZOOKEEPER_SERVER_3=10.10.0.13:2888:3888 \
-p 2181:2181 \
-p 2888:2888 \
-p 3888:3888 \
-v /data/zookeeper:/var/lib/zookeeper:rw \
zookeeper
```

---
---

### Modification and Anatomy of the Project

**File Structure**
The directory `skel` in the project root maps to the root of the file system once the container is built. Files and folders placed there will map to their corresponding location within the container.

**Init**
The init script (`./init.sh`) found at the root of the directory is the entry process for the container. It's role is to simply set specific environment variables and modify any subsequently required configuration files.

**Zookeeper**
All Zookeeper configuration files can be found at `/etc/zookeeper/conf/` with example configurations found in `/etc/zookeeper/conf_example/`. Logging is controlled through a combination of environment variable definitions and the `log4j.properties` file in the zookeeper conf directory. See the [zookeeper service](#zookeeper) section for more information.


**Supervisord**
All supervisord configs can be found in `/etc/supervisor/conf.d/`. Services by default will redirect their stdout to `/dev/fd/1` and stderr to `/dev/fd/2` allowing for service's console output to be displayed. Most applications can log to both stdout and their respectively specified log file.

In some cases (such as with zookeeper), it is possible to specify different logging levels and formats for each location.

**Logstash-Forwarder**
The Logstash-Forwarder binary and default configuration file can be found in `/skel/opt/logstash-forwarder`. It is ideal to bake the Logstash Server certificate into the base container at this location. If the certificate is called `logstash-forwarder.crt`, the default supplied Logstash-Forwarder config should not need to be modified, and the server setting may be passed through the `SERVICE_LOGSTASH_FORWARDER_ADDRESS` environment variable.

In practice, the supplied Logstash-Forwarder config should be used as an example to produce one tailored to each deployment.

---
---

### Important Environment Variables

#### Defaults

| **Variable**                      | **Default**                                             |
|-----------------------------------|---------------------------------------------------------|
| `ENVIRONMENT_INIT`                |                                                         |
| `APP_NAME`                        | `zookeeper`                                             |
| `ENVIRONMENT`                     | `local`                                                 |
| `PARENT_HOST`                     | `unknown`                                               |
| `JAVA_OPTS`                       |                                                         |
| `ZOOKEEPER_LOG_DIR`               | `/var/log/zookeeper`                                    |
| `ZOOKEEPER_LOG_FILE`              | `zookeeper.log`                                         |
| `ZOOKEEPER_LOG_FILE_LAYOUT`       | `json`                                                  |
| `ZOOKEEPER_LOG_FILE_THRESHOLD`    |                                                         |
| `ZOOKEEPER_LOG_STDOUT_LAYOUT`     | `standard`                                              |
| `ZOOKEEPER_LOG_STDOUT_THRESHOLD`  |                                                         |
| `SERVICE_LOGSTASH_FORWARDER`      |                                                         |
| `SERVICE_LOGSTASH_FORWARDER_CONF` | `/opt/logstash-forwarder/zookeeper.conf`                |
| `SERVICE_REDPILL`                 |                                                         |
| `SERVICE_REDPILL_MONITOR`         | `zookeeper`                                             |


##### Description

* `ENVIRONMENT_INIT` - If set, and the file path is valid. This will be sourced and executed before **ANYTHING** else. Useful if supplying an environment file or need to query a service such as consul to populate other variables.

* `APP_NAME` - A brief description of the container. If Logstash-Forwarder is enabled, this will populate the `app_name` field in the Logstash-Forwarder configuration file.

* `ENVIRONMENT` - Sets defaults for several other variables based on the current running environment. Please see the [environment](#environment) section for further information. If logstash-forwarder is enabled, this value will populate the `environment` field in the logstash-forwarder configuration file.

* `PARENT_HOST` - The name of the parent host. If Logstash-Forwarder is enabled, this will populate the `parent_host` field in the Logstash-Forwarder configuration file.

* `JAVA_OPTS` - The Java environment variables that will be passed to Zookeeper at runtime. Generally used for adjusting memory allocation (`-Xms` and `-Xmx`).

* `ZOOKEEPER_LOG_DIR` - The directory in which the Zookeeper log files will be stored.

* `ZOOKEEPER_LOG_FILE` - The name of the Zookeeper log file.

* `ZOOKEEPER_LOG_FILE_LAYOUT` - The log format or layout to be used for the file logger. There are two available formats, `standard` and `json`. The `standard` format is more humanly readable and is the Zookeeper default. The `json` format is easier for log processing by applications such as logstash. (**Options:** `standard` or `json`).

* `ZOOKEEPER_LOG_FILE_THRESHOLD` - The log level to be used for the file logger. (**Options:** `FATAL`, `ERROR`, `WARN`, `INFO`, `DEBUG`, `TRACE`, and `ALL`)

* `ZOOKEEPER_LOG_STDOUT_LAYOUT` - The log format or layout to be used for console output. There are two available formats, `standard` and `json`. The `standard` format is more humanly readable and is the Zookeeper default. The `json` format is easier for log processing by applications such as logstash. (**Options:** `standard` or `json`).

* `ZOOKEEPER_LOG_STDOUT_THRESHOLD`  The log level to be used for console output. (**Options:** `FATAL`, `ERROR`, `WARN`, `INFO`, `DEBUG`, `TRACE`, and `ALL`)

* `SERVICE_LOGSTASH_FORWARDER` - Enables or disables the Logstash-Forwarder service. Set automatically depending on the `ENVIRONMENT`. See the Environment section below.  (**Options:** `enabled` or `disabled`)

* `SERVICE_LOGSTASH_FORWARDER_CONF` - The path to the logstash-forwarder configuration.

* `SERVICE_REDPILL` - Enables or disables the Redpill service. Set automatically depending on the `ENVIRONMENT`. See the Environment section below.  (**Options:** `enabled` or `disabled`)

* `SERVICE_REDPILL_MONITOR` - The name of the supervisord service(s) that the Redpill service check script should monitor.


---

##### Environment

* `local` (default)

| **Variable**                     | **Default** |
|----------------------------------|-------------|
| `JAVA_OPTS`                      | `-Xmx256m`  |
| `ZOOKEEPER_LOG_FILE_THRESHOLD`   | `INFO`      |
| `ZOOKEEPER_LOG_STDOUT_THRESHOLD` | `INFO`      |
| `SERVICE_LOGSTASH_FORWARDER`     | `disabled`  |
| `SERVICE_REDPILL`                | `enabled`   |


* `prod`|`production`|`dev`|`development`

| **Variable**                     | **Default** |
|----------------------------------|-------------|
| `JAVA_OPTS`                      | `-Xmx1000m` |
| `ZOOKEEPER_LOG_FILE_THRESHOLD`   | `INFO`      |
| `ZOOKEEPER_LOG_STDOUT_THRESHOLD` | `INFO`      |
| `SERVICE_LOGSTASH_FORWARDER`     | `enabled`   |
| `SERVICE_REDPILL`                | `enabled`   |


* `debug`

| **Variable**                     | **Default** |
|----------------------------------|-------------|
| `JAVA_OPTS`                      | -Xmx1000m   |
| `ZOOKEEPER_LOG_FILE_LEVEL`       | DEBUG       |
| `ZOOKEEPER_LOG_STDOUT_THRESHOLD` | DEBUG       |
| `SERVICE_LOGSTASH_FORWARDER`     | disabled    |
| `SERVICE_REDPILL`                | disabled    |


---
---

### Service Configuration

---

#### Zookeeper

Zookeeper is a highly-available distributed configuration registry. Within the scope of theGrid project, it proves the back-end for a Mesos, and a multitude of Mesos Frameworks. For more information, please see the official [Zookeeper Wiki](https://cwiki.apache.org/confluence/display/ZOOKEEPER/Index).

#### Zookeeper Environment Variables

##### Defaults

| **Variable**                     | **Default**                                             |
|----------------------------------|---------------------------------------------------------|
| `ZOOKEEPER_LOG_DIR`              | `/var/log/zookeeper`                                    |
| `ZOOKEEPER_LOG_FILE`             | `zookeeper.log`                                         |
| `ZOOKEEPER_LOG_STDOUT_LAYOUT`    | `standard`                                              |
| `ZOOKEEPER_LOG_STDOUT_THRESHOLD` | `INFO`                                                  |
| `ZOOKEEPER_LOG_FILE_LAYOUT`      | `json`                                                  |
| `ZOOKEEPER_LOG_FILE_THRESHOLD`   | `INFO`                                                  |
| `ZOOKEEPER_MYID`                 | `1`                                                     |
| `ZOOKEEPER_DATADIR`              | `/var/lib/zookeeper`                                    |
| `SERVICE_ZOOKEEPER_CMD`          | `/usr/share/zookeeper/bin/zkServer.sh start-foreground` |

##### Description

* `ZOOKEEPER_LOG_DIR` - The path to the log directory.

* `ZOOKEEPER_LOG_FILE` - The name of the log file.

* `ZOOKEEPER_LOG_STDOUT_LAYOUT` - The log format used for stdout logging (standard or json).

* `ZOOKEEPER_LOG_STDOUT_THRESHOLD` - The logging threshold for stdout logging (`FATAL`, `ERROR`, `WARN`, `INFO`, `DEBUG`, `TRACE`, and `ALL`)

* `ZOOKEEPER_LOG_FILE_LAYOUT` - The log format used for logging to the log file (`standard` or `json`).

* `ZOOKEEPER_LOG_FILE_THRESHOLD` - The logging threshold for the log file (`FATAL`, `ERROR`, `WARN`, `INFO`, `DEBUG`, `TRACE`, and `ALL`)

* `ZOOKEEPER_MYID` - A number between 1-255 that acts as the unique identifier for the server in the cluster.

* `ZOOKEEPER_DATADIR` - The path to the zookeeper data directory.

* `SERVICE_ZOOKEEPER_CMD` - The command that is passed to supervisor. If overriding, must be an escaped python string expression. Please see the [Supervisord Command Documentation](http://supervisord.org/configuration.html#program-x-section-settings) for further information.

---


### Logstash-Forwarder

Logstash-Forwarder is a lightweight application that collects and forwards logs to a logstash server endpoint for further processing. For more information see the [Logstash-Forwarder](https://github.com/elastic/logstash-forwarder) project.


#### Logstash-Forwarder Environment Variables

##### Defaults

| **Variable**                         | **Default**                                                                            |
|--------------------------------------|----------------------------------------------------------------------------------------|
| `SERVICE_LOGSTASH_FORWARDER`         |                                                                                        |
| `SERVICE_LOGSTASH_FORWARDER_CONF`    | `/opt/logstash-forwarder/zookeeper.conf`                                               |
| `SERVICE_LOGSTASH_FORWARDER_ADDRESS` |                                                                                        |
| `SERVICE_LOGSTASH_FORWARDER_CERT`    |                                                                                        |
| `SERVICE_LOGSTASH_FORWARDER_CMD`     | `/opt/logstash-forwarder/logstash-fowarder -cofig="${SERVICE_LOGSTASH_FOWARDER_CONF}"` |


##### Description

* `SERVICE_LOGSTASH_FORWARDER` - Enables or disables the Logstash-Forwarder service. Set automatically depending on the `ENVIRONMENT`. See the Environment section.  (**Options:** `enabled` or `disabled`)

* `SERVICE_LOGSTASH_FORWARDER_CONF` - The path to the logstash-forwarder configuration.

* `SERVICE_LOGSTASH_FORWARDER_ADDRESS` - The address of the Logstash server.

* `SERVICE_LOGSTASH_FORWARDER_CERT` - The path to the Logstash-Forwarder server certificate.

* `SERVICE_LOGSTASH_FORWARDER_CMD` - The command that is passed to supervisor. If overriding, must be an escaped python string expression. Please see the [Supervisord Command Documentation](http://supervisord.org/configuration.html#program-x-section-settings) for further information.

---


### Redpill

Redpill is a small script that performs status checks on services managed through supervisor. In the event of a failed service (FATAL) Redpill optionally runs a cleanup script and then terminates the parent supervisor process.

#### Redpill Environment Variables

##### Defaults

| **Variable**               | **Default** |
|----------------------------|-------------|
| `SERVICE_REDPILL`          |             |
| `SERVICE_REDPILL_MONITOR`  | `zookeeper` |
| `SERVICE_REDPILL_INTERVAL` |             |
| `SERVICE_REDPILL_CLEANUP`  |             |
| `SERVICE_REDPILL_CMD`      |             |


##### Description

* `SERVICE_REDPILL` - Enables or disables the Redpill service. Set automatically depending on the `ENVIRONMENT`. See the Environment section.  (**Options:** `enabled` or `disabled`)

* `SERVICE_REDPILL_MONITOR` - The name of the supervisord service(s) that the Redpill service check script should monitor. 

* `SERVICE_REDPILL_INTERVAL` - The interval in which Redpill polls supervisor for status checks. (Default for the script is 30 seconds)

* `SERVICE_REDPILL_CLEANUP` - The path to the script that will be executed upon container termination.

* `SERVICE_REDPILL_CMD` - The command that is passed to supervisor. It is dynamically built from the other redpill variables. If overriding, must be an escaped python string expression. Please see the [Supervisord Command Documentation](http://supervisord.org/configuration.html#program-x-section-settings) for further information.


##### Redpill Script Help Text

```
root@c90c98ae31e1:/# /opt/scripts/redpill.sh --help
Redpill - Supervisor status monitor. Terminates the supervisor process if any specified service enters a FATAL state.

-c | --cleanup    Optional path to cleanup script that should be executed upon exit.
-h | --help       This help text.
-i | --interval   Optional interval at which the service check is performed in seconds. (Default: 30)
-s | --service    A comma delimited list of the supervisor service names that should be monitored.
```

---
---

### Troubleshooting

In the event of an issue, the `ENVIRONMENT` variable can be set to `debug`.  This will stop the container from shipping logs and prevent it from terminating if one of the services enters a failed state. It will also default the logging level for both stdout and the file to `DEBUG`.

If the zookeeper registry needs to be explored directly, you can use the Zookeeper Cli (zkCli) located at `/usr/share/zookeeper/bin/zkCli.sh`. For more information on how to use the zkCli, please see the Zookeeper [Getting Started Guide](http://zookeeper.apache.org/doc/trunk/zookeeperStarted.html).



