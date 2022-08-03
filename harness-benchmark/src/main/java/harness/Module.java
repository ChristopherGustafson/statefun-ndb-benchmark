package harness;

import com.google.auto.service.AutoService;

import org.apache.flink.statefun.sdk.spi.StatefulFunctionModule;

import java.util.Map;

@AutoService(StatefulFunctionModule.class)
public class Module implements StatefulFunctionModule {

    @Override
    public void configure(Map<String, String> config, Binder binder) {
        binder.bindIngressRouter(Identifiers.MESSAGE_INGRESS, new IngressRouter());
        binder.bindFunctionProvider(Identifiers.FUNCTION_TYPE, unused -> new Function());
    }
}
