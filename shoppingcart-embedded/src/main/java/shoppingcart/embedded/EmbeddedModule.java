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
import shoppingcart.embedded.protos.Checkout;
import shoppingcart.embedded.protos.Receipt;
import shoppingcart.embedded.protos.RestockItem;

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
                        .withDeserializer(Serialization.AddToCartKafkaDeserializer.class)
                        .withStartupPosition(KafkaIngressStartupPosition.fromLatest())
                        .build();
        binder.bindIngress(addToCartIngress);
        // Route incoming addToCart ingress to the Shopping Cart function for the given user Id
        binder.bindIngressRouter(Identifiers.ADD_TO_CART_INGRESS, (message, downstream) ->
                downstream.forward(Identifiers.SHOPPING_CART_FUNCTION_TYPE, message.getUserId(), message));

        IngressSpec<Checkout> checkoutIngress =
                KafkaIngressBuilder.forIdentifier(Identifiers.CHECKOUT_INGRESS)
                        .withKafkaAddress("localhost:9092")
                        .withConsumerGroupId("my-group-id")
                        .withTopic("checkout")
                        .withDeserializer(Serialization.CheckoutKafkaDeserializer.class)
                        .withStartupPosition(KafkaIngressStartupPosition.fromLatest())
                        .build();
        binder.bindIngress(checkoutIngress);
        // Route incoming checkout ingress to the Shopping Cart function for the given user Id
        binder.bindIngressRouter(Identifiers.CHECKOUT_INGRESS, (message, downstream) ->
                downstream.forward(Identifiers.SHOPPING_CART_FUNCTION_TYPE, message.getUserId(), message));

        IngressSpec<RestockItem> restockIngress =
                KafkaIngressBuilder.forIdentifier(Identifiers.RESTOCK_INGRESS)
                        .withKafkaAddress("localhost:9092")
                        .withConsumerGroupId("my-group-id")
                        .withTopic("restock")
                        .withDeserializer(Serialization.RestockKafkaDeserializer.class)
                        .withStartupPosition(KafkaIngressStartupPosition.fromLatest())
                        .build();
        binder.bindIngress(restockIngress);
        // Route incoming restock ingress msgs to the Stock function for the given item id
        binder.bindIngressRouter(Identifiers.RESTOCK_INGRESS, (message, downstream) ->
                downstream.forward(Identifiers.STOCK_FUNCTION_TYPE, message.getItemId(), message));

        /* EGRESS SETUP */
        EgressSpec<AddToCart> addConfirmEgress =
                KafkaEgressBuilder.forIdentifier(Identifiers.ADD_CONFIRM_EGRESS)
                        .withKafkaAddress("localhost:9092")
                        .withSerializer(Serialization.AddToCartKafkaSerializer.class)
                        .build();
        binder.bindEgress(addConfirmEgress);

        EgressSpec<Receipt> receiptEgress =
                KafkaEgressBuilder.forIdentifier(Identifiers.RECEIPT_EGRESS)
                        .withKafkaAddress("localhost:9092")
                        .withSerializer(Serialization.ReceiptKafkaSerializer.class)
                        .build();
        binder.bindEgress(receiptEgress);

        /* FUNCTION SETUP */
        binder.bindFunctionProvider(Identifiers.SHOPPING_CART_FUNCTION_TYPE, unused -> new ShoppingCartFn());
        binder.bindFunctionProvider(Identifiers.STOCK_FUNCTION_TYPE, unused -> new StockFn());
    }


}
