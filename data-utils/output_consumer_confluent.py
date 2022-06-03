from confluent_kafka import Consumer
import os
from datetime import datetime
import json
import configparser

# Config parameters
config = configparser.RawConfigParser()
config.read('config.properties')
bootstrap_servers = config.get("Config", "bootstrap.servers")
# gcp_bucket_name = os.getenv('GCP_BUCKET_NAME', "statefun-benchmark-data")
add_confirm_topic = "add-confirm"

c = Consumer({
    'bootstrap.servers': bootstrap_servers,
    'group.id': 'my-group-id',
    'auto.offset.reset': 'earliest',
    'isolation.level': 'read_committed'
})
c.subscribe([add_confirm_topic])

# Local output consumer
# time = datetime.now().strftime("%d-%m-%Y_%H:%M:%S")
dirname = os.path.dirname(__file__)
path = os.path.join(dirname, 'output-data')
os.mkdir(path)
events_read = 0
# Produce data file
with open(path+'/data.json', 'w') as output_file:

    while True:
        msg = c.poll(1.0)
        if msg is None:
            continue
        events_read = events_read+1
        if msg.error():
            print("Consumer error: {}".format(msg.error()))
            continue
        try:
            msg_value = json.loads(msg.value())
        except:
            print(f"Exception occurred when parsing json: {msg.value()}")
            pass
        event = {
            'inputKafkaTimestamp': msg_value["publishTimestamp"],
            'outputKafkaTimestamp': msg.timestamp()[1]
        }
        json.dump(event, output_file)
        output_file.write('\n')
        if (events_read % 1000) == 0:
            print(f"Consumed {events_read} events")


