package shoppingcart.embedded;

import org.apache.flink.statefun.sdk.kafka.KafkaEgressSerializer;
import org.apache.flink.statefun.sdk.kafka.KafkaIngressDeserializer;

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

public class Serialization {

    public static class AddToCartKafkaDeserializer implements KafkaIngressDeserializer<AddToCart> {

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

    public static class CheckoutKafkaDeserializer implements KafkaIngressDeserializer<Checkout> {

        @Override
        public Checkout deserialize(ConsumerRecord<byte[], byte[]> input) {
            try{
                Message.Builder msgBuilder = Checkout.newBuilder();
                String inputString = new String(input.value(), StandardCharsets.UTF_8);
                JsonFormat.parser().merge(inputString, msgBuilder);
                Checkout.Builder checkoutBuilder = (Checkout.Builder) msgBuilder;
                Checkout msg = checkoutBuilder.setPublishTimestamp(Long.toString(input.timestamp())).build();
                return msg;
            } catch(IOException e){
                e.printStackTrace();
                return null;
            }
        }
    }

    public static class RestockKafkaDeserializer implements KafkaIngressDeserializer<RestockItem> {

        @Override
        public RestockItem deserialize(ConsumerRecord<byte[], byte[]> input) {
            try{
                Message.Builder msgBuilder = RestockItem.newBuilder();
                String inputString = new String(input.value(), StandardCharsets.UTF_8);
                JsonFormat.parser().merge(inputString, msgBuilder);
                RestockItem.Builder restockBuilder = (RestockItem.Builder) msgBuilder;
                RestockItem msg = restockBuilder.setPublishTimestamp(Long.toString(input.timestamp())).build();
                return msg;
            } catch(IOException e){
                e.printStackTrace();
                return null;
            }
        }
    }

    public static class AddToCartKafkaSerializer implements KafkaEgressSerializer<AddToCart> {

        private static final String TOPIC = "add-confirm";

        private final ObjectMapper mapper = new ObjectMapper();

        @Override
        public ProducerRecord<byte[], byte[]> serialize(AddToCart addToCart) {
            try {
                byte[] key = addToCart.getUserId().getBytes();
                byte[] value = JsonFormat.printer().print(addToCart).getBytes();
                return new ProducerRecord<>(TOPIC, key, value);
            } catch (InvalidProtocolBufferException e) {
                e.printStackTrace();
                return null;
            }
        }
    }

    public static class ReceiptKafkaSerializer implements KafkaEgressSerializer<Receipt> {

        private static final String TOPIC = "receipt";

        private final ObjectMapper mapper = new ObjectMapper();

        @Override
        public ProducerRecord<byte[], byte[]> serialize(Receipt receipt) {
            try {
                byte[] key = receipt.getUserId().getBytes();
                byte[] value = JsonFormat.printer().print(receipt).getBytes();
                return new ProducerRecord<>(TOPIC, key, value);
            } catch (InvalidProtocolBufferException e) {
                e.printStackTrace();
                return null;
            }
        }
    }
}
