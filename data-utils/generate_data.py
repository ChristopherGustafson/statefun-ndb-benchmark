
import os
import random
from datetime import datetime
import json
import numpy as np
import math
import string


time_periods = 300
requests_per_period = 30000
dirname = os.path.dirname(__file__)
random.seed(datetime.now())

# Data generation config
unique_users = 2000000
unique_items = 10000

user_id_length = 20
item_id_length = 16

max_quantity = 9
max_add_to_carts = 10
restock_amount = 200

# Generating random id as string
# item_id = ''.join(random.choice(string.ascii_lowercase) for _ in range(item_id_length))

minimum_id = 10000
# items = range(minimum_id, minimum_id + unique_items)
# users = range(minimum_id + unique_items, minimum_id + unique_items + unique_users)
items = [''.join(random.choice(string.ascii_lowercase) for _ in range(item_id_length)) for _ in range(unique_items)]
users = [''.join(random.choice(string.ascii_lowercase) for _ in range(user_id_length)) for _ in range(unique_users)]
used_users = {}
count = 0

# Distribution parameters
power_law_a = 3

item_counts = {}


def get_random_user():
    random_user = np.random.randint(0, unique_users)
    #power_l_r = np.random.power(power_law_a)
    #random_user = int(power_l_r * unique_users)
    if random_user not in used_users:
        used_users[random_user] = True
        global count
        count = count + 1
    return str(users[random_user])


def get_random_item():
    power_l_r = np.random.power(power_law_a)
    random_item = int(power_l_r * unique_items)
    if item_counts.get(random_item):
        item_counts[random_item] = item_counts[random_item] + 1
    else:
        item_counts[random_item] = 1
    return str(items[random_item])


def send_add_to_cart(u_id):
    item_id = get_random_item()
    quantity = random.randint(1, max_quantity)
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S.0")
    json_obj = {
        "userId": u_id,
        "quantity": quantity,
        "itemId": item_id,
        "publishTimestamp": timestamp
    }
    file.write(u_id + '=' + json.dumps(json_obj, separators=(',', ':')) + '\n')


def send_checkout(u_id):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S.0")
    json_obj = {
        "userId": u_id,
        "publishTimestamp": timestamp
    }
    file.write(u_id + '=' + json.dumps(json_obj, separators=(',', ':')) + '\n')


def send_restock():
    item_id = get_random_item()
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S.0")
    json_obj = {
        "itemId": item_id,
        "quantity": 300,
        "publishTimestamp": timestamp
    }
    file.write(item_id + '=' + json.dumps(json_obj, separators=(',', ':')) + '\n')


user_requests = {}


for i in range(1, time_periods+1):
    # Create time directory
    path = os.path.join(dirname, 'data/time{}'.format(i))
    os.mkdir(path)

    # Create text file
    file_path = os.path.join(path, "data.txt")
    file = open(file_path, "w+")
    if i == 240:
        print("At period 240 we have used " + str(count))

    for _ in range(requests_per_period):
        action = random.randint(0, 20)
        # Restock for 1/20 requests
        if action == 0:
            send_restock()
        else:
            # Select random user
            user_id = get_random_user()
            # Check if user send request before, and how many adds are left
            requests_before_checkout = user_requests.get(user_id)
            # If it has not sent before, randomize how many adds before checkout and send add
            if requests_before_checkout is None:
                cart_adds = random.randint(1, max_add_to_carts-1)
                user_requests[user_id] = cart_adds
                send_add_to_cart(user_id)
            # If no requests left send checkout
            elif requests_before_checkout == 0:
                del user_requests[user_id]
                send_checkout(user_id)
            # Else send add and reduce number of adds left before checkout
            else:
                user_requests[user_id] = requests_before_checkout-1
                send_add_to_cart(user_id)




