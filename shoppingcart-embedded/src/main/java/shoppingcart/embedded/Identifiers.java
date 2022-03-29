package shoppingcart.embedded;

import org.apache.flink.statefun.sdk.FunctionType;
import org.apache.flink.statefun.sdk.io.EgressIdentifier;
import org.apache.flink.statefun.sdk.io.IngressIdentifier;

import shoppingcart.embedded.protos.AddToCart;
import shoppingcart.embedded.protos.Checkout;
import shoppingcart.embedded.protos.Receipt;
import shoppingcart.embedded.protos.RestockItem;

public class Identifiers {

    public static final String NAMESPACE = "shoppingcart-embedded";

    /* INGRESS IDENTIFIERS */
    public static final IngressIdentifier<AddToCart> ADD_TO_CART_INGRESS =
            new IngressIdentifier<>(AddToCart.class, NAMESPACE, "add-to-cart");

    public static final IngressIdentifier<Checkout> CHECKOUT_INGRESS =
            new IngressIdentifier<>(Checkout.class, NAMESPACE, "checkout");

    public static final IngressIdentifier<RestockItem> RESTOCK_INGRESS =
            new IngressIdentifier<>(RestockItem.class, NAMESPACE, "restock");

    /* EGRESS IDENTIFIERS */
    public static final EgressIdentifier<AddToCart> ADD_CONFIRM_EGRESS =
            new EgressIdentifier<>(NAMESPACE, "add-confirm", AddToCart.class);

    public static final EgressIdentifier<Receipt> RECEIPT_EGRESS =
            new EgressIdentifier<>(NAMESPACE, "receipt", Receipt.class);


    static final FunctionType SHOPPING_CART_FUNCTION_TYPE = new FunctionType(NAMESPACE, "shopping-cart");

    static final FunctionType STOCK_FUNCTION_TYPE = new FunctionType(NAMESPACE, "stock");

}
