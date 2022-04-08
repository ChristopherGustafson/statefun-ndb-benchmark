from kafka import KafkaProducer
import os
import time
import configparser

# Config parameters
config = configparser.RawConfigParser()
config.read('config.properties')
bootstrap_servers = config.get("Config", "bootstrap.servers")
add_to_cart_topic = "add-to-cart"
checkout_topic = "checkout"
restock_topic = "restock"
time_periods = 100

dirname = os.path.dirname(__file__)
producer = KafkaProducer(bootstrap_servers=bootstrap_servers)

while True:
    for i in range(1, time_periods+1):
        print("Producing events for time period {}".format(i))
        path = os.path.join(dirname, 'data/time{}/data.txt'.format(i))
        file = open(path, 'r')
        for line in file.readlines():
            event = line.strip().split("=")
            if "userId" in event[1] and "quantity" in event[1]:
                producer.send(add_to_cart_topic, key=bytes(event[0], "utf-8"), value=bytes(event[1], "utf-8"))
            elif "userId" in event[1]:
                producer.send(checkout_topic, key=bytes(event[0], "utf-8"), value=bytes(event[1], "utf-8"))
            else:
                producer.send(restock_topic, key=bytes(event[0], "utf-8"), value=bytes(event[1], "utf-8"))
