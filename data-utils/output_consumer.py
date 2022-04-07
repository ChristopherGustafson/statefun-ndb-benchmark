from kafka import KafkaConsumer
import os
from datetime import datetime
import json


# Config parameters
bootstrap_servers = os.getenv('KAFKA_BOOTSTRAP_SERVERS', "localhost:9092")
gcp_bucket_name = os.getenv('GCP_BUCKET_NAME', "no-bucket")
add_confirm_topic = "add-confirm"
consumer = KafkaConsumer(
    add_confirm_topic,
    bootstrap_servers=bootstrap_servers,
    auto_offset_reset='earliest')

# Local output consumer
time = datetime.now().strftime("%d-%m-%Y_%H:%M:%S")
dirname = os.path.dirname(__file__)
path = os.path.join(dirname, 'output-data/{}'.format(time))
os.mkdir(path)

with open(path+'/data.json', 'w') as output_file:
    for msg in consumer:
        msg_value = json.loads(msg.value)
        event = {
            'inputKafkaTimestamp': msg_value["publishTimestamp"],
            'outputKafkaTimestamp': msg.timestamp
        }
        json.dump(event, output_file)
        output_file.write('\n')




