/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package shoppingcart.remote;

import org.apache.flink.statefun.sdk.java.Address;
import org.apache.flink.statefun.sdk.java.AddressScopedStorage;
import org.apache.flink.statefun.sdk.java.Context;
import org.apache.flink.statefun.sdk.java.StatefulFunction;
import org.apache.flink.statefun.sdk.java.TypeName;
import org.apache.flink.statefun.sdk.java.ValueSpec;
import org.apache.flink.statefun.sdk.java.io.KafkaEgressMessage;
import org.apache.flink.statefun.sdk.java.message.EgressMessage;
import org.apache.flink.statefun.sdk.java.message.Message;
import org.apache.flink.statefun.sdk.java.message.MessageBuilder;
import org.apache.flink.statefun.sdk.java.types.SimpleType;
import org.apache.flink.statefun.sdk.java.types.Type;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import shoppingcart.remote.AddToCart;
import shoppingcart.remote.Checkout;
import shoppingcart.remote.ItemAvailability;
import shoppingcart.remote.Receipt;
import shoppingcart.remote.RequestItem;

import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.concurrent.CompletableFuture;
import java.util.stream.Collectors;

import static shoppingcart.remote.Identifiers.ADD_CONFIRM_EGRESS;
import static shoppingcart.remote.Identifiers.ADD_TO_CART_TYPE;
import static shoppingcart.remote.Identifiers.CHECKOUT_TYPE;
import static shoppingcart.remote.Identifiers.ITEM_AVAILABILITY_TYPE;
import static shoppingcart.remote.Identifiers.RECEIPT_TYPE;
import static shoppingcart.remote.Identifiers.REQUEST_ITEM_TYPE;

final class ShoppingCartFn implements StatefulFunction {

  private static final Logger LOG = LoggerFactory.getLogger(ShoppingCartFn.class);

  static final TypeName TYPE = TypeName.typeNameOf(Identifiers.NAMESPACE, "shopping-cart");
  static final ValueSpec<Basket> BASKET = ValueSpec.named("basket").withCustomType(Basket.TYPE);


  @Override
  public CompletableFuture<Void> apply(Context context, Message message) {
    if (message.is(ADD_TO_CART_TYPE)) {
      AddToCart addToCartMsg = message.as(ADD_TO_CART_TYPE);
      RequestItem requestMsg = RequestItem.newBuilder()
              .setQuantity(addToCartMsg.getQuantity())
              .setPublishTimestamp(addToCartMsg.getPublishTimestamp())
              .build();

      System.out.println("---");
      System.out.println("Received AddToCart for itemId " + addToCartMsg.getItemId() + " and quantity " + addToCartMsg.getQuantity());
      System.out.println("---");

      final Message request =
          MessageBuilder.forAddress(StockFn.TYPE, addToCartMsg.getItemId())
              .withCustomType(REQUEST_ITEM_TYPE, requestMsg)
              .build();
      context.send(request);

      return context.done();
    }

    if (message.is(ITEM_AVAILABILITY_TYPE)) {
      ItemAvailability availability = message.as(ITEM_AVAILABILITY_TYPE);

      if (ItemAvailability.Status.INSTOCK.equals(availability.getStatus())) {
        final AddressScopedStorage storage = context.storage();
        final Basket basket = storage.get(BASKET).orElse(Basket.initEmpty());

        // ItemAvailability event comes from the Stock function and contains the itemId as the
        // caller id
        final Optional<Address> caller = context.caller();
        if (caller.isPresent()) {
          basket.add(caller.get().id(), availability.getQuantity());
        } else {
          throw new IllegalStateException("There should always be a caller in this example");
        }
        storage.set(BASKET, basket);
      }

      AddToCart addConfirm = AddToCart.newBuilder()
              .setUserId(context.self().id())
              .setItemId(context.caller().get().id())
              .setQuantity(availability.getQuantity())
              .setPublishTimestamp(availability.getPublishTimestamp())
              .build();
      final EgressMessage egressMessage =
              KafkaEgressMessage.forEgress(ADD_CONFIRM_EGRESS)
                      .withTopic(Identifiers.ADD_CONFIRM_TOPIC)
                      .withUtf8Key(context.self().id())
                      .withValue(ADD_TO_CART_TYPE, addConfirm)
                      .build();

      System.out.println("---");
      System.out.println("Received AddConfirm for itemId " + addConfirm.getItemId() + " and quantity " + addConfirm.getQuantity());
      System.out.println("---");
      context.send(egressMessage);
      return context.done();
    }

    if (message.is(CHECKOUT_TYPE)) {

      final Checkout checkout = message.as(CHECKOUT_TYPE);
      final AddressScopedStorage storage = context.storage();

      final Optional<String> itemsOption =
          storage
              .get(BASKET)
              .map(
                  basket ->
                      basket.getEntries().stream()
                          .map(entry -> entry.getKey() + ": " + entry.getValue())
                          .collect(Collectors.joining("\n")));

      itemsOption.ifPresent(
          items -> {
            Receipt receipt = Receipt.newBuilder()
                    .setUserId(context.self().id())
                    .setReceipt(items)
                    .setPublishTimestamp(checkout.getPublishTimestamp())
                    .build();
            final EgressMessage egressMessage =
                KafkaEgressMessage.forEgress(Identifiers.RECEIPT_EGRESS)
                    .withTopic(Identifiers.RECEIPT_TOPIC)
                    .withUtf8Key(context.self().id())
                    .withValue(RECEIPT_TYPE, receipt)
                    .build();
            context.send(egressMessage);

            System.out.println("---");
            System.out.println("Received checkout for basket:\n" + items);
            System.out.println("---");
          });
    }
    return context.done();
  }

  private static class Basket {

    private static final ObjectMapper mapper = new ObjectMapper();

    public static final Type<Basket> TYPE =
        SimpleType.simpleImmutableTypeFrom(
            TypeName.typeNameOf(Identifiers.NAMESPACE, "Basket"),
            mapper::writeValueAsBytes,
            bytes -> mapper.readValue(bytes, Basket.class));

    @JsonProperty("basket")
    private final Map<String, Integer> basket;

    public static Basket initEmpty() {
      return new Basket(new HashMap<>());
    }

    @JsonCreator
    public Basket(@JsonProperty("basket") Map<String, Integer> basket) {
      this.basket = basket;
    }

    public void add(String itemId, int quantity) {
      basket.put(itemId, basket.getOrDefault(itemId, 0) + quantity);
    }

    public void remove(String itemId, int quantity) {
      int remainder = basket.getOrDefault(itemId, 0) - quantity;
      if (remainder > 0) {
        basket.put(itemId, remainder);
      } else {
        basket.remove(itemId);
      }
    }

    @JsonIgnore
    public Set<Map.Entry<String, Integer>> getEntries() {
      return basket.entrySet();
    }

    @JsonProperty("basket")
    public Map<String, Integer> getBasketContent() {
      return basket;
    };

    public void clear() {
      basket.clear();
    }

    @Override
    public String toString() {
      return "Basket{" + "basket=" + basket + '}';
    }
  }
}
