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
import org.apache.flink.statefun.sdk.java.message.Message;
import org.apache.flink.statefun.sdk.java.message.MessageBuilder;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import shoppingcart.remote.ItemAvailability;
import shoppingcart.remote.RequestItem;
import shoppingcart.remote.RestockItem;

import java.util.concurrent.CompletableFuture;

import static shoppingcart.remote.Identifiers.ITEM_AVAILABILITY_TYPE;
import static shoppingcart.remote.Identifiers.REQUEST_ITEM_TYPE;
import static shoppingcart.remote.Identifiers.RESTOCK_ITEM_TYPE;

final class StockFn implements StatefulFunction {

  private static final Logger LOG = LoggerFactory.getLogger(ShoppingCartFn.class);

  static final TypeName TYPE = TypeName.typeNameOf(Identifiers.NAMESPACE, "stock");
  static final ValueSpec<Integer> STOCK = ValueSpec.named("stock").withIntType();

  @Override
  public CompletableFuture<Void> apply(Context context, Message message) {
    AddressScopedStorage storage = context.storage();
    final int quantity = storage.get(STOCK).orElse(100000);
    if (message.is(RESTOCK_ITEM_TYPE)) {
      RestockItem restock;
      restock = message.as(RESTOCK_ITEM_TYPE);

      final int newQuantity = quantity + restock.getQuantity();
      storage.set(STOCK, newQuantity);

//      System.out.println("---");
//      System.out.println("Received Restock for itemId " + context.self().id());
//      System.out.println("---");
      return context.done();
    }
    else if (message.is(REQUEST_ITEM_TYPE)) {
      RequestItem request = message.as(REQUEST_ITEM_TYPE);
      final int requestQuantity = request.getQuantity();

      ItemAvailability.Builder builder = ItemAvailability.newBuilder()
              .setQuantity(requestQuantity)
              .setPublishTimestamp(request.getPublishTimestamp());

      if (quantity >= requestQuantity) {
        storage.set(STOCK, quantity - requestQuantity);
        builder.setStatus(ItemAvailability.Status.INSTOCK);
      } else {
        builder.setStatus(ItemAvailability.Status.OUTOFSTOCK);
      }
      ItemAvailability itemAvailability = builder.build();

//      System.out.println("---");
//      System.out.println("Received ItemRequest from userId " + context.caller().get().id() + " and quantity " + requestQuantity);
//      System.out.println("---");
      context.send(
          MessageBuilder.forAddress(context.caller().get())
              .withCustomType(ITEM_AVAILABILITY_TYPE, itemAvailability)
              .build());
          }
    return context.done();
  }
}
