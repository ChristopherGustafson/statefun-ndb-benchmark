#!/bin/bash

./build/bin/flink run -c org.apache.flink.statefun.flink.core.StatefulFunctionsJob shoppingcart-embedded-1.0-SNAPSHOT-jar-with-dependencies.jar
