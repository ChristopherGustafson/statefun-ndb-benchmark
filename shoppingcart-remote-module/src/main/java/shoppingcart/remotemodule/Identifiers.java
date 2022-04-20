package shoppingcart.remotemodule;

import org.apache.flink.statefun.sdk.FunctionType;
import org.apache.flink.statefun.sdk.io.EgressIdentifier;
import org.apache.flink.statefun.sdk.io.IngressIdentifier;
import org.apache.flink.statefun.sdk.reqreply.generated.TypedValue;

import shoppingcart.remote.AddToCart;
import shoppingcart.remote.Checkout;
import shoppingcart.remote.Receipt;
import shoppingcart.remote.RestockItem;

public class Identifiers {

    public static final String NAMESPACE = "shoppingcart-remote";

    /* INGRESS IDENTIFIERS */
    public static final IngressIdentifier<TypedValue> ADD_TO_CART_INGRESS =
            new IngressIdentifier<>(TypedValue.class, NAMESPACE, "add-to-cart");

    public static final IngressIdentifier<TypedValue> CHECKOUT_INGRESS =
            new IngressIdentifier<>(TypedValue.class, NAMESPACE, "checkout");

    public static final IngressIdentifier<TypedValue> RESTOCK_INGRESS =
            new IngressIdentifier<>(TypedValue.class, NAMESPACE, "restock");

    /* EGRESS IDENTIFIERS */
    public static final EgressIdentifier<AddToCart> ADD_CONFIRM_EGRESS =
            new EgressIdentifier<>(NAMESPACE, "add-confirm", AddToCart.class);

    public static final EgressIdentifier<Receipt> RECEIPT_EGRESS =
            new EgressIdentifier<>(NAMESPACE, "receipt", Receipt.class);


    static final FunctionType SHOPPING_CART_FUNCTION_TYPE = new FunctionType(NAMESPACE, "shopping-cart");

    static final FunctionType STOCK_FUNCTION_TYPE = new FunctionType(NAMESPACE, "stock");

}
