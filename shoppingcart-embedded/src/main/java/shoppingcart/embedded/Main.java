package shoppingcart.embedded;

import org.apache.flink.statefun.flink.harness.Harness;

public class Main {

    public static void main(String[] args) throws Exception {
        Harness harness = new Harness();

        harness.withConfiguration("state.backend", "ndb");
        harness.withConfiguration("state.backend.ndb.connectionstring", "127.0.0.1");
        harness.withConfiguration("state.backend.ndb.dbname", "flinkndb");
        harness.withConfiguration("state.backend.ndb.truncatetableonstart", "false");

        harness.withConfiguration("state.checkpoints.dir", "file:///tmp/checkpoints");
        harness.withConfiguration("state.savepoints.dir", "file:///tmp/savepoints");

        harness.withConfiguration("execution.checkpointing.interval", "15sec");
        harness.withConfiguration("execution.checkpointing.mode", "EXACTLY_ONCE");

        harness.withConfiguration("parallelism.default", "1");
        harness.withConfiguration("taskmanager.numberOfTaskSlots", "1");

        harness.withConfiguration(
                "classloader.parent-first-patterns.additional",
                "org.apache.flink.statefun;org.apache.kafka;com.google.protobuf");
        harness.withPrintingEgress(Identifiers.RECEIPT_EGRESS);
        harness.withPrintingEgress(Identifiers.ADD_CONFIRM_EGRESS);

        harness.start();
    }
}
