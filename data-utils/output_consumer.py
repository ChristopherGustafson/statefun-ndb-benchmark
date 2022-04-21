from kafka import KafkaConsumer
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
consumer = KafkaConsumer(
    add_confirm_topic,
    bootstrap_servers=bootstrap_servers,
    auto_offset_reset='earliest')

# Local output consumer
# time = datetime.now().strftime("%d-%m-%Y_%H:%M:%S")
dirname = os.path.dirname(__file__)
path = os.path.join(dirname, 'output-data')
os.mkdir(path)
events_read = 0
# Produce data file
with open(path+'/data.json', 'w') as output_file:
    for msg in consumer:
        events_read = events_read+1
        try:
            msg_value = json.loads(msg.value)
        except:
            print(f"Exception occurred when parsing json: {msg.value}")
            pass
        event = {
            'inputKafkaTimestamp': msg_value["publishTimestamp"],
            'outputKafkaTimestamp': msg.timestamp
        }
        json.dump(event, output_file)
        output_file.write('\n')


