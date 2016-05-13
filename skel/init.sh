#!/bin/bash

########## Zookeeper ##########
#
########## Zookeeper ##########

source /opt/scripts/container_functions.lib.sh

init_vars() {

  if [[ $ENVIRONMENT_INIT && -f $ENVIRONMENT_INIT ]]; then
      source "$ENVIRONMENT_INIT"
  fi 

  if [[ ! $PARENT_HOST && $HOST ]]; then
    export PARENT_HOST="$HOST"
  fi

  export APP_NAME=${APP_NAME:-zookeeper}
  export ENVIRONMENT=${ENVIRONMENT:-local}
  export PARENT_HOST=${PARENT_HOST:-unknown}

  export ZOOKEEPER_LOG_STDOUT_LAYOUT=${ZOOKEEPER_LOG_STDOUT_LAYOUT:-standard}
  export ZOOKEEPER_LOG_DIR=${ZOOKEEPER_LOG_DIR:-/var/log/zookeeper}
  export ZOOKEEPER_LOG_FILE=${ZOOKEEPER_LOG_FILE:-zookeeper.log}
  export ZOOKEEPER_LOG_FILE_LAYOUT=${ZOOKEEPER_LOG_FILE_LAYOUT:-json}

  export SERVICE_CONSUL_TEMPLATE=${SERVICE_CONSUL_TEMPLATE:-disabled}
  export SERVICE_LOGSTASH_FORWARDER_CONF=${SERVICE_LOGSTASH_FORWARDER_CONF:-/opt/logstash-forwarder/zookeeper.conf}
  export SERVICE_REDPILL_MONITOR=${SERVICE_REDPILL_MONITOR:-zookeeper}
  export SERVICE_ZOOKEEPER_CMD=${SERVICE_ZOOKEEPER_CMD:-"/usr/share/zookeeper/bin/zkServer.sh start-foreground"}

  case "${ENVIRONMENT,,}" in
    prod|production|dev|development)
      export JAVA_OPTS=${JAVA_OPTS:-"-Xmx1000m"}
      export ZOOKEEPER_LOG_STDOUT_THRESHOLD=${ZOOKEEPER_LOG_STDOUT_THRESHOLD:-INFO}
      export ZOOKEEPER_LOG_FILE_THRESHOLD=${ZOOKEEPER_LOG_FILE_THRESHOLD:-INFO}
      export SERVICE_LOGSTASH_FORWARDER=${SERVICE_LOGSTASH_FORWARDER:-enabled}
      export SERVICE_REDPILL=${SERVICE_REDPILL:-enabled}
      ;;
    debug)
      export JAVA_OPTS=${JAVA_OPTS:-"-Xmx1000m"}
      export ZOOKEEPER_LOG_STDOUT_THRESHOLD=${ZOOKEEPER_LOG_STDOUT_THRESHOLD:-DEBUG}
      export ZOOKEEPER_LOG_FILE_THRESHOLD=${ZOOKEEPER_LOG_FILE_THRESHOLD:-DEBUG}
      export SERVICE_LOGSTASH_FORWARDER=${SERVICE_LOGSTASH_FORWARDER:-disabled}
      export SERVICE_REDPILL=${SERVICE_REDPILL:-disabled}
      if [[ "$SERVICE_CONSUL_TEMPLATE" == "enabled" ]]; then
        export SERVICE_LOGROTATE=${SERVICE_LOGROTATE:-disabled}
        export SERVICE_RSYSLOG=${SERVICE_RSYSLOG:-enabled}
      fi
      ;;
    local|*)
      export JAVA_OPTS=${JAVA_OPTS:-"-Xmx256m"}
      export ZOOKEEPER_LOG_STDOUT_THRESHOLD=${ZOOKEEPER_LOG_STDOUT_THRESHOLD:-INFO}
      export ZOOKEEPER_LOG_FILE_THRESHOLD=${ZOOKEEPER_LOG_FILE_THRESHOLD:-INFO}
      export SERVICE_LOGSTASH_FORWARDER=${SERVICE_LOGSTASH_FORWARDER:-disabled}
      export SERVICE_REDPILL=${SERVICE_REDPILL:-enabled}
      ;;
  esac

  if [[ "$SERVICE_CONSUL_TEMPLATE" == "enabled" ]]; then
    export SERVICE_LOGROTATE=${SERVICE_LOGROTATE:-enabled}
    export SERVICE_RSYSLOG=${SERVICE_RSYSLOG:-enabled}
  fi
}


config_zookeeper() {
  #logging settings for log4j and default JAVA_OPTS
  local log_stdout_layout=""
  local log_file_layout=""

  case "${ZOOKEEPER_LOG_STDOUT_LAYOUT,,}" in
    json)
      log_stdout_layout="net.logstash.log4j.JSONEventLayoutV1"
      ;;
    standard|*)
      log_stdout_layout="org.apache.log4j.PatternLayout"
      ;;
  esac

  case "${ZOOKEEPER_LOG_FILE_LAYOUT,,}" in
    json)
      log_file_layout="net.logstash.log4j.JSONEventLayoutV1"
      ;;
    standard|*)
      log_file_layout="org.apache.log4j.PatternLayout"
      ;;
  esac

  #set zookeeper defaults
  #FYI-ZOOKEEPER_DATADIR will ALWAYS be SED'ed into the config
  export ZOOKEEPER_MYID=${ZOOKEEPER_MYID:-1}
  export ZOOKEEPER_DATADIR=${ZOOKEEPER_DATADIR:-/var/lib/zookeeper}

  echo "$ZOOKEEPER_MYID" > "$ZOOKEEPER_DATADIR/myid"

  jvm_opts=( "-Dlog4j.configuration=file:/etc/zookeeper/conf/log4j.properties"
             "-Dlog.stdout.layout=$log_stdout_layout"
             "-Dlog.stdout.threshold=$ZOOKEEPER_LOG_STDOUT_THRESHOLD"
             "-Dlog.file.layout=$log_file_layout"
             "-Dlog.file.threshold=$ZOOKEEPER_LOG_FILE_THRESHOLD"
             "-Dlog.file.dir=$ZOOKEEPER_LOG_DIR"
             "-Dlog.file.name=$ZOOKEEPER_LOG_FILE")

  for j_opt in $JAVA_OPTS; do
    jvm_opts+=( ${j_opt} )
  done

  #the zookeeper start script (zkServer) looks to see if SERVER_JVMFLAGS is set and appends it to the java start command.
  export SERVER_JVMFLAGS="${jvm_opts[*]}"

  
  sed -e "s|^dataDir=.*|dataDir=$ZOOKEEPER_DATADIR|g" -i /etc/zookeeper/conf/zoo.cfg

  # If any there are any ZOOKEEPER_SERVER_* ENV variables definied (should be a zk server address)
  # Either add or replace them in zoo.cfg

  for i in $(compgen -A variable | grep -E "ZOOKEEPER_SERVER_[0-9]{1,3}"); do
    server_id=$(echo "$i" | grep -P -o '(?<=ZOOKEEPER_SERVER_)[0-9]{1,3}')
    server_address="${!i}"
    echo "[$(date)][Zookeeper][server.$server_id] $server_address"
    if [[ $(grep -ci "^server.$server_id" /etc/zookeeper/conf/zoo.cfg) -eq 1 ]]; then
        sed -e "s/server.$server_id=.*/server.$server_id=$server_address/" -i /etc/zookeeper/conf/zoo.cfg
    else     
        echo "server.$server_id=$server_address" >> /etc/zookeeper/conf/zoo.cfg
    fi
  done

}


main() {

  init_vars

  echo "[$(date)][App-name] $APP_NAME"
  echo "[$(date)][Environment] $ENVIRONMENT"

  __config_service_consul_template
  __config_service_logrotate
  __config_service_logstash_forwarder
  __config_service_redpill
  __config_service_rsyslog

  config_zookeeper

  echo "[$(date)][Zookeeper][Myid] $ZOOKEEPER_MYID"
  echo "[$(date)][Zookeeper][Start-Command] $SERVICE_ZOOKEEPER_CMD"

  exec supervisord -n -c /etc/supervisor/supervisord.conf

}

main "$@"
