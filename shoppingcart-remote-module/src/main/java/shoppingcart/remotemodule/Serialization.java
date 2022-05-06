package shoppingcart.remotemodule;

import org.apache.flink.statefun.sdk.kafka.KafkaEgressSerializer;
import org.apache.flink.statefun.sdk.kafka.KafkaIngressDeserializer;
import org.apache.flink.statefun.sdk.reqreply.generated.TypedValue;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.google.protobuf.InvalidProtocolBufferException;
import com.google.protobuf.Message;
import com.google.protobuf.util.JsonFormat;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.producer.ProducerRecord;
import shoppingcart.remote.AddToCart;
import shoppingcart.remote.Checkout;
import shoppingcart.remote.Receipt;
import shoppingcart.remote.RestockItem;

import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.FileAlreadyExistsException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

public class Serialization {

    public static class AddToCartKafkaDeserializer implements KafkaIngressDeserializer<TypedValue> {

        @Override
        public TypedValue deserialize(ConsumerRecord<byte[], byte[]> input) {
            try{
                Message.Builder msgBuilder = AddToCart.newBuilder();
                String inputString = new String(input.value(), StandardCharsets.UTF_8);
                JsonFormat.parser().merge(inputString, msgBuilder);
                AddToCart.Builder addBuilder = (AddToCart.Builder) msgBuilder;
                AddToCart msg = addBuilder.setPublishTimestamp(Long.toString(input.timestamp())).build();
                // Cause failure if quantity < 0
                if(msg.getQuantity() < 0){
                    // Start by deleting file indicating that we have caused crash
                    File crashFile = new File("crashed.txt");
                    if (crashFile.delete()) {
                        System.out.println("Crash file deleted: " + crashFile.getName());
                        throw new RuntimeException("KABOOM!");
                    } else {
                        System.out.println("Crash file already deleted, moving on");
                    }
                }

                return pack(msg);
            } catch(IOException e){
                e.printStackTrace();
                return null;
            }
        }
    }

    public static class CheckoutKafkaDeserializer implements KafkaIngressDeserializer<TypedValue> {

        @Override
        public TypedValue deserialize(ConsumerRecord<byte[], byte[]> input) {
            try{
                Message.Builder msgBuilder = Checkout.newBuilder();
                String inputString = new String(input.value(), StandardCharsets.UTF_8);
                JsonFormat.parser().merge(inputString, msgBuilder);
                Checkout.Builder checkoutBuilder = (Checkout.Builder) msgBuilder;
                Checkout msg = checkoutBuilder.setPublishTimestamp(Long.toString(input.timestamp())).build();
                return pack(msg);
            } catch(IOException e){
                e.printStackTrace();
                return null;
            }
        }
    }

    public static class RestockKafkaDeserializer implements KafkaIngressDeserializer<TypedValue> {

        @Override
        public TypedValue deserialize(ConsumerRecord<byte[], byte[]> input) {
            try{
                Message.Builder msgBuilder = RestockItem.newBuilder();
                String inputString = new String(input.value(), StandardCharsets.UTF_8);
                JsonFormat.parser().merge(inputString, msgBuilder);
                RestockItem.Builder restockBuilder = (RestockItem.Builder) msgBuilder;
                RestockItem msg = restockBuilder.setPublishTimestamp(Long.toString(input.timestamp())).build();
                return pack(msg);
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

    public static <M extends Message> TypedValue pack(M message) {
        return TypedValue.newBuilder()
                .setTypename(Identifiers.NAMESPACE + "/" + message.getDescriptorForType().getFullName())
                .setHasValue(true)
                .setValue(message.toByteString())
                .build();
    }

}
