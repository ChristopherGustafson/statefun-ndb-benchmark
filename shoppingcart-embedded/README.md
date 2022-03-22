# Shopping Cart job using embedded functions
The benchmark shopping cart job using only embedded functions in StateFun.

## Deployement
Start by building the project as a fat jar:
```
mvn clean package
```
Then submit the job to a running Flink cluster using the following command from the flink build folder:
```
./bin/flink run -c org.apache.flink.statefun.flink.core.StatefulFunctionsJob <path-to-fat-jar>
```