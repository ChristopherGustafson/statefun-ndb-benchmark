package harness;

import harness.protos.Msg;
import org.apache.flink.statefun.flink.harness.Harness;
import org.apache.flink.statefun.flink.harness.io.SerializableSupplier;
import org.apache.flink.util.StringUtils;

import java.io.InputStream;
import java.util.Properties;
import java.util.concurrent.ThreadLocalRandom;

public class Main {

    public static void main(String[] args) {

        Properties prop = new Properties();
        try (InputStream inputStream = Main.class.getClassLoader().getResourceAsStream("config.properties")){
            prop.load(inputStream);
        } catch(Exception e) {
            e.printStackTrace();
            return;
        }
        String backend = prop.getProperty("backend");
        int eventsBeforeCrash = Integer.parseInt(prop.getProperty("events"));
        String connectionString = prop.getProperty("ndb.connectionstring");
        String bucketName = prop.getProperty("gcp.bucket.name");
        String recoveryMethod = prop.getProperty("recovery");

        Harness harness = new Harness();
        // Set Common Flink Configs
        harness.withConfiguration("state.checkpoints.dir", bucketName+"/checkpoints");
        harness.withConfiguration("state.savepoints.dir", bucketName+"/savepoints");
        harness.withConfiguration("execution.checkpointing.interval", "10sec");
        harness.withConfiguration("execution.checkpointing.min-pause", "5sec");
        harness.withConfiguration("execution.checkpointing.mode", "EXACTLY_ONCE");

        harness.withConfiguration("taskmanager.memory.managed.size", "32GB");

        // State Backend Config
        harness.withConfiguration("state.backend", backend);
        // NDB config
        if(backend.equals("ndb")){
            harness.withConfiguration("state.backend.ndb.connectionstring", connectionString);
            harness.withConfiguration("state.backend.ndb.dbname", "flinkndb");
            harness.withConfiguration("state.backend.ndb.truncatetableonstart", "false");
            if(recoveryMethod.equals("lazy")){
                harness.withConfiguration("state.backend.ndb.lazyrecovery", "true");
            }
        }
        else if(backend.equals("rocksdb")){
            harness.withConfiguration("state.backend.incremental", "true");
        }

        // Config required by StateFun
        harness.withConfiguration(
                "classloader.parent-first-patterns.additional",
                "org.apache.flink.statefun;org.apache.kafka;com.google.protobuf;org.apache.flink.flink-gs-fs-hadoop");
        harness.withKryoMessageSerializer();

        InputGenerator generator = new InputGenerator();
        generator.crash = eventsBeforeCrash;
        harness.withSupplyingIngress(Identifiers.MESSAGE_INGRESS, generator);
        harness.withPrintingEgress(Identifiers.MESSAGE_EGRESS);

        try {
            harness.start();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private static final class InputGenerator implements SerializableSupplier<Msg> {

        static int count = 0;
        static int crash = 1000000;

        @Override
        public Msg get() {

            try {
                Thread.sleep(1);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
            if(count++ == crash) return getFaultyMessage();
            if(count % 100000 == 0) System.out.println(count + " events produced.");
            return getRandomMessage();
        }

        private Msg getRandomMessage(){
            final ThreadLocalRandom r = ThreadLocalRandom.current();
            final String userId = StringUtils.generateRandomAlphanumericString(r, 20);
            final String msg = StringUtils.generateRandomAlphanumericString(r, 250);
            return Msg.newBuilder().setUserId(userId).setMessage(msg).build();
        }

        private Msg getFaultyMessage(){
            final ThreadLocalRandom r = ThreadLocalRandom.current();
            final String userId = StringUtils.generateRandomAlphanumericString(r, 20);
            return Msg.newBuilder().setUserId(userId).setMessage("").build();
        }
    }
}
