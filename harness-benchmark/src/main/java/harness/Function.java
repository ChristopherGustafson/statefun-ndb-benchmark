package harness;

import harness.protos.Msg;
import org.apache.flink.statefun.sdk.Context;
import org.apache.flink.statefun.sdk.StatefulFunction;
import org.apache.flink.statefun.sdk.annotations.Persisted;
import org.apache.flink.statefun.sdk.state.PersistedValue;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Arrays;

public class Function implements StatefulFunction {

    private static final Logger LOG = LoggerFactory.getLogger(Function.class);

    @Persisted
    private final PersistedValue<String> receivedMessage1 = PersistedValue.of("message1", String.class);

    @Persisted
    private final PersistedValue<String> receivedMessage2 = PersistedValue.of("message2", String.class);

    @Override
    public void invoke(Context context, Object input) {

        if(!(input instanceof Msg)){
            throw new IllegalArgumentException("Unexpected message type: " + input);
        }
        Msg inputMsg = (Msg) input;
        if(inputMsg.getMessage().equals("")){
            LOG.error("Crashing!");
            throw new RuntimeException("KABOOM!");
        }

        receivedMessage1.set(inputMsg.getMessage());
        receivedMessage2.set(inputMsg.getMessage());
    }

}
