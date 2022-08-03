package harness;

import harness.protos.Msg;
import org.apache.flink.statefun.sdk.FunctionType;
import org.apache.flink.statefun.sdk.io.EgressIdentifier;
import org.apache.flink.statefun.sdk.io.IngressIdentifier;

public class Identifiers {

    public static final String NAMESPACE = "harness";

    public static final IngressIdentifier<Msg> MESSAGE_INGRESS = new IngressIdentifier<>(Msg.class, NAMESPACE, "ingress");

    public static final EgressIdentifier<Msg> MESSAGE_EGRESS = new EgressIdentifier<>(NAMESPACE, "egress", Msg.class);

    static final FunctionType FUNCTION_TYPE = new FunctionType(NAMESPACE, "my-function");

}
