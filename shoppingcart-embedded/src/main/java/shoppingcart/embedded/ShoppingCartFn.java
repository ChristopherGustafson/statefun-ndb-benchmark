package shoppingcart.embedded;

import org.apache.flink.statefun.sdk.Context;
import org.apache.flink.statefun.sdk.StatefulFunction;
import org.apache.flink.statefun.sdk.annotations.Persisted;
import org.apache.flink.statefun.sdk.state.PersistedTable;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import shoppingcart.embedded.protos.AddToCart;
import shoppingcart.embedded.protos.Checkout;
import shoppingcart.embedded.protos.ItemAvailability;
import shoppingcart.embedded.protos.Receipt;
import shoppingcart.embedded.protos.RequestItem;

import java.util.Map;

public class ShoppingCartFn implements StatefulFunction {

    private static final Logger LOG = LoggerFactory.getLogger(ShoppingCartFn.class);

//    @Persisted
//    private final PersistedValue<Basket> BASKET = PersistedValue.of("basket", Basket.class);

    @Persisted
    private final PersistedTable<String, Integer> BASKET = PersistedTable.of("basket", String.class, Integer.class);

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
            String itemId = context.caller().id();
            int requestedQuantity = availability.getQuantity();

            if(availability.getStatus().equals(ItemAvailability.Status.INSTOCK)){
                Integer quantity = BASKET.get(itemId);
                quantity = quantity == null ? requestedQuantity : quantity + requestedQuantity;
                BASKET.set(itemId, quantity);
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
            Checkout checkout = (Checkout) input;

            if(BASKET.entries().iterator().hasNext()){
                String receipt = "User " + context.self().id() + " receipt: \n";
                for(Map.Entry<String, Integer> entry : BASKET.entries()){
                    receipt += "Item: " + entry.getKey() + ", Quantity: " + entry.getValue() + "\n";
                }
                BASKET.clear();

                LOG.info("---");
                LOG.info("Received checkout for basket:\n{}", receipt);
                LOG.info("---");

                Receipt receiptMessage = Receipt.newBuilder()
                        .setUserId(context.self().id())
                        .setReceipt(receipt)
                        .setPublishTimestamp(checkout.getPublishTimestamp())
                        .build();
                context.send(Identifiers.RECEIPT_EGRESS, receiptMessage);
            }
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
