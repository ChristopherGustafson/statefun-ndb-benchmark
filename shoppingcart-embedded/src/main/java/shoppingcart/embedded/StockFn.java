package shoppingcart.embedded;

import org.apache.flink.statefun.sdk.Context;
import org.apache.flink.statefun.sdk.StatefulFunction;
import org.apache.flink.statefun.sdk.annotations.Persisted;
import org.apache.flink.statefun.sdk.state.PersistedValue;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import shoppingcart.embedded.protos.ItemAvailability;
import shoppingcart.embedded.protos.RequestItem;
import shoppingcart.embedded.protos.RestockItem;

public class StockFn implements StatefulFunction {
    
    private static final Logger LOG = LoggerFactory.getLogger(StockFn.class);

    @Persisted
    private final PersistedValue<Integer> STOCK = PersistedValue.of("stock", Integer.class);

    @Override
    public void invoke(Context context, Object input) {
        int currentStock = STOCK.getOrDefault(100000);
        if(input instanceof RequestItem){
            RequestItem request = (RequestItem) input;
            final int requestQuantity = request.getQuantity();

            ItemAvailability.Builder builder = ItemAvailability.newBuilder()
                    .setQuantity(requestQuantity)
                    .setPublishTimestamp(request.getPublishTimestamp());
            if(currentStock >= requestQuantity) {
                STOCK.set(currentStock - requestQuantity);
                builder.setStatus(ItemAvailability.Status.INSTOCK);
            }
            else {
                builder.setStatus(ItemAvailability.Status.OUTOFSTOCK);
            }
            ItemAvailability itemAvailabilityResponse = builder.build();

            LOG.info("---");
            LOG.info("Received ItemRequest from userId " + context.caller().id() + " and quantity " + requestQuantity);
            LOG.info("---");

            context.send(Identifiers.SHOPPING_CART_FUNCTION_TYPE, context.caller().id(), itemAvailabilityResponse);
        }
        else if(input instanceof RestockItem){
            System.out.println("Stock Function: Received restock for item");
        }

    }
}
