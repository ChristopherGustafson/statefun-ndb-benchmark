#!/bin/bash

# Build embedded StateFun job
echo "Building embedded StateFun job..."
(cd shoppingcart-embedded/;mvn clean package)
