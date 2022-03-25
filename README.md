# Statefun NDB Benchmark
Benchmark for my Thesis *Highly Available Stateful Serverless Functions in Apache Flink*.

This benchmark is based on [OSPBench](https://github.com/Klarrio/open-stream-processing-benchmark), 
and adapted to fit Stateful Serverless functions.

## Deployment
Deployment scripts can be found in [``deployment``](/deployment).

### Local Deployment
For local deployment, first copy your Flink build into the folder [``deployment/flink``](/deployment/flink), and name the folder `build`.

Then run the following command

```shell
./deployment/local/run.sh
```