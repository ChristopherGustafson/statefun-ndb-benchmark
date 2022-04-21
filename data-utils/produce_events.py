from kafka import KafkaProducer
import os
import time
import configparser

# Config parameters
config = configparser.RawConfigParser()
config.read('config.properties')
bootstrap_servers = config.get("Config", "bootstrap.servers")
events_per_sec = int(config.get("Config", "events_per_sec"))
add_to_cart_topic = "add-to-cart"
checkout_topic = "checkout"
restock_topic = "restock"
# How many time periods of data that exist
time_periods = 100
# Size of every event micro batch, the program will wait a certain time between every micro batch of events
# to produce the correct number of events per second 
micro_batch_size = 100
wait_time = (micro_batch_size/events_per_sec)
events_produced = 0

dirname = os.path.dirname(__file__)
producer = KafkaProducer(bootstrap_servers=bootstrap_servers)


while True:
    for i in range(1, time_periods+1):
        print("Producing events for time period {}".format(i))
        path = os.path.join(dirname, 'data/time{}/data.txt'.format(i))
        file = open(path, 'r')
        for line in file.readlines():
            batch_start = time.time_ns()
            # Micro batches, 
            for _ in range(micro_batch_size):
                events_produced = events_produced+1
                event = line.strip().split("=")
                if "userId" in event[1] and "quantity" in event[1]:
                    producer.send(add_to_cart_topic, key=bytes(event[0], "utf-8"), value=bytes(event[1], "utf-8"))
                elif "userId" in event[1]:
                    producer.send(checkout_topic, key=bytes(event[0], "utf-8"), value=bytes(event[1], "utf-8"))
                else:
                    producer.send(restock_topic, key=bytes(event[0], "utf-8"), value=bytes(event[1], "utf-8"))
                if (events_produced % events_per_sec) == 0:
                    print(f"Produced {events_produced} events")
            batch_duration = (time.time_ns() - batch_start)/1000000000
            if batch_duration < wait_time:
                time.sleep(wait_time - batch_duration)
