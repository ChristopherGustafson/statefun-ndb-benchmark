
import os
import random
from datetime import datetime
import string
import json
import sys

time_periods = 20
requests_per_period = 1000
dirname = os.path.dirname(__file__)
random.seed(datetime.now())

# Data generation config
unique_users = 10000
unique_items = 100

user_id_length = 6
item_id_length = 2

max_quantity = 10
max_add_to_carts = 4
restock_amount = 200

minimum_id = 10000
items = range(minimum_id, minimum_id + unique_items)
users = range(minimum_id + unique_items, minimum_id + unique_items + unique_users)

for i in range(1, time_periods+1):
    # Create time directory
    path = os.path.join(dirname, 'time{}'.format(i))
    os.mkdir(path)

    # Create text file
    file_path = os.path.join(path, "data.txt")
    file = open(file_path, "w+")

    for _ in range(requests_per_period):
        action = random.randint(0, 20)
        # Restock for 1/20 requests
        if action == 0:
            # item_id = ''.join(random.choice(string.ascii_lowercase) for _ in range(item_id_length))
            item_id = str(random.choice(items))
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S.0")
            json_obj = {
                "itemId": item_id,
                "quantity": 200,
                "publishTimestamp": timestamp
            }
            file.write(item_id + '=' + json.dumps(json_obj, separators=(',', ':')) + '\n')
        else:
            user_id = str(random.choice(users))
            # Add number of items to cart
            cart_adds = random.randint(1, max_add_to_carts)
            for _ in range(cart_adds):
                item_id = str(random.choice(items))
                quantity = random.randint(1, max_quantity)
                timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S.0")
                json_obj = {
                    "userId": user_id,
                    "quantity": quantity,
                    "itemId": item_id,
                    "publishTimestamp": timestamp
                }
                file.write(user_id + '=' + json.dumps(json_obj, separators=(',', ':')) + '\n')
            
            # Checkout
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S.0")
            json_obj = {
                "userId": user_id,
                "publishTimestamp": timestamp
            }
            file.write(user_id + '=' + json.dumps(json_obj, separators=(',', ':')) + '\n')
            










