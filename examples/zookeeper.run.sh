#!/bin/bash
docker run -d \
-e ENVIRONMENT=production \
-e PARENT_HOST=$(hostname) \
-e LOG_STDOUT_THRESHOLD=WARN \
-e ZOOCFG_MYID=1 \
-e ZOOCFG_SERVER_1=10.10.0.11:2888:3888 \
-e ZOOCFG_SERVER_2=10.10.0.12:2888:3888 \
-e ZOOCFG_SERVER_3=10.10.0.13:2888:3888 \
-p 2181:2181 \
-p 2888:2888 \
-p 3888:3888 \
-v /data/zookeeper:/var/lib/zookeeper:rw \
zookeeper
