package shoppingcart.embedded;

import org.apache.flink.statefun.sdk.Context;
import org.apache.flink.statefun.sdk.StatefulFunction;
import org.apache.flink.statefun.sdk.annotations.Persisted;
import org.apache.flink.statefun.sdk.state.PersistedTable;
import org.apache.flink.statefun.sdk.state.PersistedValue;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import shoppingcart.embedded.protos.AddToCart;
import shoppingcart.embedded.protos.Checkout;
import shoppingcart.embedded.protos.ItemAvailability;
import shoppingcart.embedded.protos.Receipt;
import shoppingcart.embedded.protos.RequestItem;

import java.io.File;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;

public class ShoppingCartFn implements StatefulFunction {

    private static final Logger LOG = LoggerFactory.getLogger(ShoppingCartFn.class);

    @Persisted
    private final PersistedValue<String> S1 = PersistedValue.of("first", String.class);

    @Persisted
    private final PersistedValue<String> S2 = PersistedValue.of("second", String.class);

    @Persisted
    private final PersistedValue<String> S3 = PersistedValue.of("third", String.class);

    @Persisted
    private final PersistedValue<String> S4 = PersistedValue.of("fourth", String.class);

    @Persisted
    private final PersistedValue<String> S5 = PersistedValue.of("fifth", String.class);

    @Persisted
    private final PersistedValue<String> S6 = PersistedValue.of("sixth", String.class);

    @Persisted
    private final PersistedValue<String> S7 = PersistedValue.of("seventh", String.class);

    @Persisted
    private final PersistedValue<String> S8 = PersistedValue.of("eighth", String.class);

    @Override
    public void invoke(Context context, Object input) {

        // Invoked by AddToCart ingress
        if (input instanceof AddToCart) {

            AddToCart addToCartMsg = (AddToCart) input;

            // Cause failure if quantity < 0
            if (addToCartMsg.getQuantity() < 0) {
                // Start by deleting file indicating that we have caused crash
                File crashFile = new File("crashed.txt");
                if (crashFile.delete()) {
                    System.out.println("Crash file deleted: " + crashFile.getName());
                    throw new RuntimeException("KABOOM!");
                } else {
                    System.out.println("Crash file already deleted, moving on");
                }
            }

            String s1;
            String s2;
            String s3;
            String s4;
            String s5;
            String s6;
            String s7;
            String s8;
            try{
                s1 = S1.get();
                if(s1 == null){
                    S1.set(new String(new byte[500]).replace('\0', 'a'));
                }
                s2 = S2.get();
                if(s2 == null){
                    S2.set(new String(new byte[500]).replace('\0', 'a'));
                }
                s3 = S3.get();
                if(s3 == null){
                    S3.set(new String(new byte[500]).replace('\0', 'a'));
                }
                s4 = S4.get();
                if(s4 == null){
                    S4.set(new String(new byte[500]).replace('\0', 'a'));
                }
                s5 = S5.get();
                if(s5 == null){
                    S5.set(new String(new byte[500]).replace('\0', 'a'));
                }
                s6 = S6.get();
                if(s6 == null){
                    S6.set(new String(new byte[500]).replace('\0', 'a'));
                }
                s7 = S7.get();
                if(s7 == null){
                    S7.set(new String(new byte[500]).replace('\0', 'a'));
                }
                s8 = S8.get();
                if(s8 == null){
                    S8.set(new String(new byte[500]).replace('\0', 'a'));
                }
            } catch (Exception e) {
                System.out.println("Exception during state operation: " + e);
            }
            AddToCart addConfirm = AddToCart.newBuilder()
                    .setUserId(addToCartMsg.getUserId())
                    .setItemId(addToCartMsg.getItemId())
                    .setQuantity(addToCartMsg.getQuantity())
                    .setPublishTimestamp(addToCartMsg.getPublishTimestamp())
                    .build();
            context.send(Identifiers.ADD_CONFIRM_EGRESS, addConfirm);

        } else if (input instanceof Checkout) {
        }
    }
}