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

import org.apache.flink.statefun.sdk.java.TypeName;
import org.apache.flink.statefun.sdk.java.types.SimpleType;
import org.apache.flink.statefun.sdk.java.types.Type;

import com.google.protobuf.AbstractMessageLite;
import com.google.protobuf.util.JsonFormat;
import shoppingcart.remote.AddToCart;
import shoppingcart.remote.Checkout;
import shoppingcart.remote.ItemAvailability;
import shoppingcart.remote.Receipt;
import shoppingcart.remote.RequestItem;
import shoppingcart.remote.RestockItem;

import java.nio.charset.StandardCharsets;

final class Identifiers {

  public static final String NAMESPACE = "shoppingcart-remote";

  private Identifiers() {}

  static final TypeName ADD_CONFIRM_EGRESS = TypeName.typeNameOf(NAMESPACE, "add-confirm");
  static final TypeName RECEIPT_EGRESS = TypeName.typeNameOf(NAMESPACE, "receipt");
  static final String RECEIPT_TOPIC = "receipt";
  static final String ADD_CONFIRM_TOPIC = "add-confirm";

  public static final Type<AddToCart> ADD_TO_CART_TYPE =
          SimpleType.simpleImmutableTypeFrom(
                  TypeName.typeNameOf(NAMESPACE, AddToCart.class.getName()),
                  msg -> JsonFormat.printer().print(msg).getBytes(),
                  AddToCart::parseFrom);

  public static final Type<Checkout> CHECKOUT_TYPE =
          SimpleType.simpleImmutableTypeFrom(
                  TypeName.typeNameOf(NAMESPACE, Checkout.class.getName()),
                  AbstractMessageLite::toByteArray,
                  Checkout::parseFrom);

  public static final Type<RestockItem> RESTOCK_ITEM_TYPE =
          SimpleType.simpleImmutableTypeFrom(
                  TypeName.typeNameOf(NAMESPACE, RestockItem.class.getName()),
                  AbstractMessageLite::toByteArray,
                  RestockItem::parseFrom);

  public static final Type<Receipt> RECEIPT_TYPE =
          SimpleType.simpleImmutableTypeFrom(
                  TypeName.typeNameOf(NAMESPACE, Receipt.class.getName()),
                  msg -> JsonFormat.printer().print(msg).getBytes(),
                  Receipt::parseFrom);

  public static final Type<RequestItem> REQUEST_ITEM_TYPE =
          SimpleType.simpleImmutableTypeFrom(
                  TypeName.typeNameOf(NAMESPACE, RequestItem.class.getName()),
                  AbstractMessageLite::toByteArray,
                  RequestItem::parseFrom);

  public static final Type<ItemAvailability> ITEM_AVAILABILITY_TYPE =
          SimpleType.simpleImmutableTypeFrom(
                  TypeName.typeNameOf(NAMESPACE, ItemAvailability.class.getName()),
                  AbstractMessageLite::toByteArray,
                  ItemAvailability::parseFrom);

}
