package shoppingcart.embedded;

import org.apache.flink.statefun.sdk.io.EgressSpec;
import org.apache.flink.statefun.sdk.io.IngressSpec;
import org.apache.flink.statefun.sdk.kafka.KafkaEgressBuilder;
import org.apache.flink.statefun.sdk.kafka.KafkaIngressBuilder;
import org.apache.flink.statefun.sdk.kafka.KafkaIngressStartupPosition;
import org.apache.flink.statefun.sdk.spi.StatefulFunctionModule;

import shoppingcart.embedded.protos.AddToCart;
import shoppingcart.embedded.protos.Checkout;
import shoppingcart.embedded.protos.Receipt;
import shoppingcart.embedded.protos.RestockItem;

import java.io.InputStream;
import java.util.Map;
import java.util.Properties;

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
//        String saslMechanism = prop.getProperty("sasl.mechanism");
//        String saslConfig = prop.getProperty("sasl.jaas.config");
        /* INGRESS SETUP */
        IngressSpec<AddToCart> addToCartIngress =
                KafkaIngressBuilder.forIdentifier(Identifiers.ADD_TO_CART_INGRESS)
                        .withKafkaAddress(kafkaAddress)
//                        .withProperty("sasl.mechanism", saslMechanism)
//                        .withProperty("sasl.jaas.config", saslConfig)
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
                        .withKafkaAddress(kafkaAddress)
//                        .withProperty("sasl.mechanism", saslMechanism)
//                        .withProperty("sasl.jaas.config", saslConfig)
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
                        .withKafkaAddress(kafkaAddress)
//                        .withProperty("sasl.mechanism", saslMechanism)
//                        .withProperty("sasl.jaas.config", saslConfig)
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
                        .withKafkaAddress(kafkaAddress)
//                        .withProperty("sasl.mechanism", saslMechanism)
//                        .withProperty("sasl.jaas.config", saslConfig)
                        .withSerializer(Serialization.AddToCartKafkaSerializer.class)
                        .build();
        binder.bindEgress(addConfirmEgress);

        EgressSpec<Receipt> receiptEgress =
                KafkaEgressBuilder.forIdentifier(Identifiers.RECEIPT_EGRESS)
                        .withKafkaAddress(kafkaAddress)
//                        .withProperty("sasl.mechanism", saslMechanism)
//                        .withProperty("sasl.jaas.config", saslConfig)
                        .withSerializer(Serialization.ReceiptKafkaSerializer.class)
                        .build();
        binder.bindEgress(receiptEgress);

        /* FUNCTION SETUP */
        binder.bindFunctionProvider(Identifiers.SHOPPING_CART_FUNCTION_TYPE, unused -> new ShoppingCartFn());
        binder.bindFunctionProvider(Identifiers.STOCK_FUNCTION_TYPE, unused -> new StockFn());
    }


}
