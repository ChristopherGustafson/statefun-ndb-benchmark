package shoppingcart.remotemodule;

import org.apache.flink.statefun.sdk.io.EgressSpec;
import org.apache.flink.statefun.sdk.io.IngressSpec;
import org.apache.flink.statefun.sdk.kafka.KafkaEgressBuilder;
import org.apache.flink.statefun.sdk.kafka.KafkaIngressBuilder;
import org.apache.flink.statefun.sdk.kafka.KafkaIngressStartupPosition;
import org.apache.flink.statefun.sdk.reqreply.generated.TypedValue;
import org.apache.flink.statefun.sdk.spi.StatefulFunctionModule;

import com.google.auto.service.AutoService;
import com.google.protobuf.InvalidProtocolBufferException;
import shoppingcart.remote.AddToCart;
import shoppingcart.remote.Checkout;
import shoppingcart.remote.Receipt;
import shoppingcart.remote.RestockItem;

import java.io.InputStream;
import java.util.Map;
import java.util.Properties;

@AutoService(StatefulFunctionModule.class)
public class EmbeddedModule implements StatefulFunctionModule {

    @Override
    public void configure(Map<String, String> globalConfiguration, Binder binder) {

        Properties prop = new Properties();
        try (InputStream inputStream = getClass().getClassLoader().getResourceAsStream("config.properties")){
            prop.load(inputStream);
        } catch(Exception e) {
            e.printStackTrace();
            return;
        }
        String kafkaAddress = prop.getProperty("bootstrap.servers");

        /* INGRESS SETUP */
        IngressSpec<TypedValue> addToCartIngress =
                KafkaIngressBuilder.forIdentifier(Identifiers.ADD_TO_CART_INGRESS)
                        .withKafkaAddress(kafkaAddress)
                        .withConsumerGroupId("my-group-id")
                        .withTopic("add-to-cart")
                        .withDeserializer(Serialization.AddToCartKafkaDeserializer.class)
                        .withStartupPosition(KafkaIngressStartupPosition.fromLatest())
                        .build();
        binder.bindIngress(addToCartIngress);
        // Route incoming addToCart ingress to the Shopping Cart function for the given user Id
        binder.bindIngressRouter(Identifiers.ADD_TO_CART_INGRESS, (message, downstream) ->
        {
            try {
                downstream.forward(Identifiers.SHOPPING_CART_FUNCTION_TYPE, AddToCart.parseFrom(message.getValue()).getUserId(), message);
            } catch (InvalidProtocolBufferException e) {
                throw new RuntimeException(e);
            }
        });

        IngressSpec<TypedValue> checkoutIngress =
                KafkaIngressBuilder.forIdentifier(Identifiers.CHECKOUT_INGRESS)
                        .withKafkaAddress(kafkaAddress)
                        .withConsumerGroupId("my-group-id")
                        .withTopic("checkout")
                        .withDeserializer(Serialization.CheckoutKafkaDeserializer.class)
                        .withStartupPosition(KafkaIngressStartupPosition.fromLatest())
                        .build();
        binder.bindIngress(checkoutIngress);
        // Route incoming checkout ingress to the Shopping Cart function for the given user Id
        binder.bindIngressRouter(Identifiers.CHECKOUT_INGRESS, (message, downstream) ->
        {
            try {
                downstream.forward(Identifiers.SHOPPING_CART_FUNCTION_TYPE, Checkout.parseFrom(message.getValue()).getUserId(), message);
            } catch (InvalidProtocolBufferException e) {
                throw new RuntimeException(e);
            }
        });

        IngressSpec<TypedValue> restockIngress =
                KafkaIngressBuilder.forIdentifier(Identifiers.RESTOCK_INGRESS)
                        .withKafkaAddress(kafkaAddress)
                        .withConsumerGroupId("my-group-id")
                        .withTopic("restock")
                        .withDeserializer(Serialization.RestockKafkaDeserializer.class)
                        .withStartupPosition(KafkaIngressStartupPosition.fromLatest())
                        .build();
        binder.bindIngress(restockIngress);
        // Route incoming restock ingress msgs to the Stock function for the given item id
        binder.bindIngressRouter(Identifiers.RESTOCK_INGRESS, (message, downstream) ->
        {
            try {
                downstream.forward(Identifiers.STOCK_FUNCTION_TYPE, RestockItem.parseFrom(message.getValue()).getItemId(), message);
            } catch (InvalidProtocolBufferException e) {
                throw new RuntimeException(e);
            }
        });

    }


}
