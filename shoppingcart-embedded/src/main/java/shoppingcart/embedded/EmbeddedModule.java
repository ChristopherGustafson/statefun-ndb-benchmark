package shoppingcart.embedded;

import org.apache.flink.statefun.sdk.io.EgressSpec;
import org.apache.flink.statefun.sdk.io.IngressSpec;
import org.apache.flink.statefun.sdk.io.Router;
import org.apache.flink.statefun.sdk.kafka.KafkaEgressBuilder;
import org.apache.flink.statefun.sdk.kafka.KafkaEgressSerializer;
import org.apache.flink.statefun.sdk.kafka.KafkaIngressBuilder;
import org.apache.flink.statefun.sdk.kafka.KafkaIngressDeserializer;
import org.apache.flink.statefun.sdk.kafka.KafkaIngressStartupPosition;
import org.apache.flink.statefun.sdk.spi.StatefulFunctionModule;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.google.protobuf.InvalidProtocolBufferException;
import com.google.protobuf.Message;
import com.google.protobuf.util.JsonFormat;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import shoppingcart.embedded.protos.AddToCart;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.Map;

public class EmbeddedModule implements StatefulFunctionModule {

    @Override
    public void configure(Map<String, String> globalConfiguration, Binder binder) {

        /* INGRESS SETUP */
        IngressSpec<AddToCart> addToCartIngress =
                KafkaIngressBuilder.forIdentifier(Identifiers.ADD_TO_CART_INGRESS)
                        .withKafkaAddress("localhost:9092")
                        .withConsumerGroupId("my-group-id")
                        .withTopic("add-to-cart")
                        .withDeserializer(KafkaDeserializer.class)
                        .withStartupPosition(KafkaIngressStartupPosition.fromLatest())
                        .build();
        binder.bindIngress(addToCartIngress);
        // Route incoming addToCart ingress to the Shopping Cart function for the given user Id
        binder.bindIngressRouter(Identifiers.ADD_TO_CART_INGRESS, (message, downstream) ->
                downstream.forward(Identifiers.SHOPPING_CART_FUNCTION_TYPE, message.getUserId(), message));

        /* EGRESS SETUP */
        EgressSpec<AddToCart> addConfirmEgress =
                KafkaEgressBuilder.forIdentifier(Identifiers.ADD_CONFIRM_EGRESS)
                        .withKafkaAddress("localhost:9092")
                        .withSerializer(KafkaSerializer.class)
                        .build();
         binder.bindEgress(addConfirmEgress);

        /* FUNCTION SETUP */
        binder.bindFunctionProvider(Identifiers.SHOPPING_CART_FUNCTION_TYPE, unused -> new ShoppingCartFn());
        binder.bindFunctionProvider(Identifiers.STOCK_FUNCTION_TYPE, unused -> new StockFn());
    }

    private static class KafkaDeserializer implements KafkaIngressDeserializer<AddToCart> {

        @Override
        public AddToCart deserialize(ConsumerRecord<byte[], byte[]> input) {
            try{
                Message.Builder msgBuilder = AddToCart.newBuilder();
                String inputString = new String(input.value(), StandardCharsets.UTF_8);
                JsonFormat.parser().merge(inputString, msgBuilder);
                AddToCart.Builder addBuilder = (AddToCart.Builder) msgBuilder;
                AddToCart msg = addBuilder.setPublishTimestamp(Long.toString(input.timestamp())).build();
                return msg;
            } catch(IOException e){
                e.printStackTrace();
                return null;
            }
        }
    }

    private static class KafkaSerializer implements KafkaEgressSerializer<AddToCart> {

        private static final Logger LOG = LoggerFactory.getLogger(KafkaSerializer.class);

        private static final String TOPIC = "add-confirm";

        private final ObjectMapper mapper = new ObjectMapper();

        @Override
        public ProducerRecord<byte[], byte[]> serialize(AddToCart addToCart) {
            try {
                byte[] key = addToCart.getUserId().getBytes();
                LOG.info("Serialized key: " + key);
                byte[] value = JsonFormat.printer().print(addToCart).getBytes();
                LOG.info("Serialized value: " + value);
                return new ProducerRecord<>(TOPIC, key, value);
            } catch (InvalidProtocolBufferException e) {
                e.printStackTrace();
                return null;
            }
        }
    }
}
