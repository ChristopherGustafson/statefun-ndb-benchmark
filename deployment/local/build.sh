#!/bin/bash

# Build embedded StateFun job
echo "Building embedded StateFun job..."
(cd shoppingcart-embedded/;mvn clean package)

echo "Building remote StateFun Module..."
(cd shoppingcart-remote-module/;mvn clean package)

echo "Building remote StateFun Functions..."
(cd shoppingcart-remote/;mvn clean package)
