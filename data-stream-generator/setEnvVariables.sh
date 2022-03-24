export S3_ACCESS_KEY=placeholder-access-key # S3 access key of data input
export S3_SECRET_KEY=placeholder-secret-key # S3 secret key of data input
export INPUT_DATA_PATH=placeholder-data-path # S3 data path
export KAFKA_BOOTSTRAP_SERVERS=$(hostname -I | head -n1 | awk '{print $1;}'):9092  # list of Kafka brokers in the form of "host1:port1,host2:port2"
export DATA_VOLUME=0 # inflation factor for the data
export MODE=constant-rate # data characteristics of the input stream (explained further)
export FLOWTOPIC=ndwflow # Kafka topic name for flow data
export SPEEDTOPIC=ndwspeed # Kafka topic name for speed data
export RUNS_LOCAL=true # whether we run locally or on a platform
export LAST_STAGE=4
export PUBLISHER_NB=1

export TERM=xterm-color # Added to prevent sbt bug with TERM color 