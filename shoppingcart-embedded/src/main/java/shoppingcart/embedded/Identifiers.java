package shoppingcart.embedded;

import org.apache.flink.statefun.sdk.FunctionType;
import org.apache.flink.statefun.sdk.io.EgressIdentifier;
import org.apache.flink.statefun.sdk.io.IngressIdentifier;

import shoppingcart.embedded.protos.AddToCart;

public class Identifiers {

    public static final String NAMESPACE = "shoppingcart-embedded";

    public static final IngressIdentifier<AddToCart> ADD_TO_CART_INGRESS =
            new IngressIdentifier<>(AddToCart.class, NAMESPACE, "add-to-cart");

    public static final EgressIdentifier<AddToCart> ADD_CONFIRM_EGRESS =
            new EgressIdentifier<>(NAMESPACE, "add-confirm", AddToCart.class);

    static final FunctionType SHOPPING_CART_FUNCTION_TYPE = new FunctionType(NAMESPACE, "shopping-cart");

    static final FunctionType STOCK_FUNCTION_TYPE = new FunctionType(NAMESPACE, "stock");

}
