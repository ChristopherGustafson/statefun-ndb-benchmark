package shoppingcart.embedded;

import org.apache.flink.statefun.sdk.Context;
import org.apache.flink.statefun.sdk.StatefulFunction;
import org.apache.flink.statefun.sdk.annotations.Persisted;
import org.apache.flink.statefun.sdk.state.PersistedValue;

import com.google.protobuf.Message;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import shoppingcart.embedded.protos.AddToCart;
import shoppingcart.embedded.protos.Checkout;
import shoppingcart.embedded.protos.ItemAvailability;
import shoppingcart.embedded.protos.RequestItem;

public class ShoppingCartFn implements StatefulFunction {

    private static final Logger LOG = LoggerFactory.getLogger(ShoppingCartFn.class);

    @Persisted
    private final PersistedValue<Integer> BASKET_COUNT = PersistedValue.of("basket", Integer.class);

    @Override
    public void invoke(Context context, Object input) {

        // Invoked by AddToCart ingress
        if (input instanceof AddToCart) {
            AddToCart addToCartMsg = (AddToCart) input;
            RequestItem requestMsg = RequestItem.newBuilder()
                    .setQuantity(addToCartMsg.getQuantity())
                    .setPublishTimestamp(addToCartMsg.getPublishTimestamp())
                    .build();

            LOG.info("---");
            LOG.info("Received AddToCart for itemId " + addToCartMsg.getItemId() + " and quantity " + addToCartMsg.getQuantity());
            LOG.info("---");

            context.send(Identifiers.STOCK_FUNCTION_TYPE, addToCartMsg.getItemId(), requestMsg);
        }
        else if(input instanceof ItemAvailability){
            ItemAvailability availability = (ItemAvailability) input;

            if(availability.getStatus().equals(ItemAvailability.Status.INSTOCK)){
                int currentBasket = BASKET_COUNT.getOrDefault(0);
                BASKET_COUNT.set(currentBasket + availability.getQuantity());
            }

            AddToCart addConfirm = AddToCart.newBuilder()
                    .setUserId(context.self().id())
                    .setItemId(context.caller().id())
                    .setQuantity(availability.getQuantity())
                    .setPublishTimestamp(availability.getPublishTimestamp())
                    .build();

            LOG.info("---");
            LOG.info("Received AddConfirm for itemId " + addConfirm.getItemId() + " and quantity " + addConfirm.getQuantity());
            LOG.info("---");

            context.send(Identifiers.ADD_CONFIRM_EGRESS, addConfirm);
        }
        else if(input instanceof Checkout){
            System.out.println("Shopping cart: received Checkout request from ingress");
        }
    }

//    public static <M extends Message> TypedValue pack(M message) {
//        return TypedValue.newBuilder()
//                .setTypename(MyConstants.NAMESPACE + "/" + InternalMsg.class.getName())
//                .setHasValue(true)
//                .setValue(message.toByteString())
//                .build();
//      }
}
