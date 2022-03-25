#!/bin/bash

# Build output consumer
echo "Building data stream generator..."
(cd data-stream-generator/;sbt build)

# Build embedded StateFun job
echo "Building embedded StateFun job..."
(cd shoppingcart-embedded/;mvn clean package)

echo "Building output-consumer..."
(cd output-consumer/;sbt build)