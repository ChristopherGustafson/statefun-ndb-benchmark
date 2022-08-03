package harness;

import harness.protos.Msg;
import org.apache.flink.statefun.sdk.io.Router;

public class IngressRouter implements Router<Msg> {
    @Override
    public void route(Msg inputMsg, Downstream<Msg> downstream) {
        downstream.forward(Identifiers.FUNCTION_TYPE, inputMsg.getUserId(), inputMsg);
    }
}
