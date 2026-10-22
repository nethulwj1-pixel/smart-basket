import from datetime { datetime, timedelta }
import from re { search as re_search }
import from services.userProfile { UserProfileView, getUserProfile, getMissingHabitSuggestions, recordShopping }
import from services.paymentCards { SavedPaymentCard }
import from jaclang.byllm.lib { Image }
import from base64 { b64decode }

node Grocery {
    has name: str = "";
    has base_price: float = 0.0;
    has category: str = "Pantry";
    has pack_size: float = 1.0;
    has pack_unit: str = "pack";
}
node Supermarket {
    has name: str = "";
    has address: str = "";
    has district: str = "";
    has trip_fee: float = 0.0;
}
node InventoryOffer {
    has item_name: str = "";
    has price: float = 0.0;
    has promo_price: float = 0.0;
    has promo_text: str = "";
}
node CardPromotion {
    has bank: str = "";
    has description: str = "";
    has category: str = "";
    has discount: float = 0.0;
    has min_bill: float = 0.0;
    has max_cap: float = 0.0;
    has condition: str = "";
}
node DeliveryCourier {
    has name: str = "";
    has cost: float = 0.0;
    has days: int = 1;
}
edge HasOffer: Supermarket --> InventoryOffer {}
edge OfferFor: InventoryOffer --> Grocery {}
edge HasPromotion: Supermarket --> CardPromotion {}
edge HasCourier: Supermarket --> DeliveryCourier {}

obj BasketItem {
    has name: str;
    has quantity: float = 1.0;
    has unit: str = "";
    has requested_quantity: float = 1.0;
    has requested_unit: str = "pack";
    has category: str = "Pantry";
}
obj BillLine {
    has name: str;
    has quantity: float = 1.0;
    has store: str = "";
    has base_price: float = 0.0;
    has item_discount: float = 0.0;
    has line_total: float = 0.0;
    has promo_note: str = "";
}
obj StoreDelivery {
    has store: str;
    has courier: str;
    has charge: float = 0.0;
    has address: str = "";
}

obj OfferRule {
    has store: str;
    has card: str;
    has discount_percent: float = 0.0;
    has min_bill: float = 0.0;
    has max_cap: float = 0.0;
    has conditions: str = "";
    has eligible: bool = False;
    has applied_discount: float = 0.0;
}
obj InventoryRow {
    has name: str;
    has category: str;
    has store: str;
    has price: float = 0.0;
    has promo_price: float = 0.0;
    has promo_text: str = "";
}
obj OptimizationResult {
    has items: list[BasketItem] = [];
    has ai_suggestions: list[str] = [];
    has unavailable_items: list[str] = [];
    has offer_rules: list[OfferRule] = [];
    has profile: UserProfileView | None = None;
    has mock_balance_warning: str = "";
    has location_summary: str = "";
    has lines: list[BillLine] = [];
    has deliveries: list[StoreDelivery] = [];
    has store: str = "";
    has courier: str = "";
    has card: str = "";
    has subtotal: float = 0.0;
    has item_discounts: float = 0.0;
    has basket_discount: float = 0.0;
    has delivery_charge: float = 0.0;
    has location_charge: float = 0.0;
    has total: float = 0.0;
    has savings: float = 0.0;
    has estimated_balance: float = 0.0;
    has balance_warning: str = "";
    has delivery_days: int = 1;
    has delivery_hours: int = 0;
    has delivery_date: str = "";
    has promo_note: str = "";
    has error: str = "";
}

obj ParsedList {
    has items: list[str] = [];
    has notes: str = "";
}
sem ParsedList.items = "Every grocery item legible in the photo, one entry per written line, preserving quantities like '2kg rice' exactly as written.";
sem ParsedList.notes = "Short note about lines that were unclear or unreadable; empty string if the whole list was legible.";

def _parse_handwritten(img: Image) -> ParsedList by llm(temperature=0.1, max_tokens=800);
sem _parse_handwritten = "Read a photographed handwritten grocery list and transcribe it exactly.";
sem _parse_handwritten.img = "The photo of a handwritten grocery list.";

async def:pub readHandwrittenList(image_data: str) -> ParsedList {
    if len(image_data.strip()) == 0 { return ParsedList(notes="No image was provided."); }
    payload = image_data.split(",", 1)[1] if "," in image_data else image_data;
    try {
        img = Image(b64decode(payload) as any);
    } except Exception as err {
        return ParsedList(notes="That file could not be read as an image.");
    }
    try {
        return _parse_handwritten(img);
    } except Exception as err {
        return ParsedList(notes="The handwriting could not be read right now. Please type the items instead.");
    }
}
obj ItemClassification { has name: str; has category: str; }
obj ClassificationResult { has items: list[ItemClassification] = []; }
sem ItemClassification.name = "The normalized grocery item name, preserving quantity if useful.";
sem ItemClassification.category = "Exactly Perishable or Pantry. Fresh produce, dairy, meat and bread are Perishable. Dry goods and household staples are Pantry.";
sem ClassificationResult.items = "One classification for each comma-separated grocery item supplied.";
def classify_groceries(grocery_text: str) -> ClassificationResult by llm(temperature=0.1, max_tokens=500);
sem classify_groceries = "Categorize every grocery list entry for delivery planning. Return Perishable for food that should arrive promptly, otherwise Pantry. Do not omit entries.";
sem classify_groceries.grocery_text = "User's comma-separated grocery list, including quantities.";


def:pub initializeBasket() -> bool {
    groceries: list[Grocery] = [
        Grocery(name="Carrot (1kg)", base_price=420.0, category="Fresh Produce"),
        Grocery(name="Leeks (1kg)", base_price=380.0, category="Fresh Produce"),
        Grocery(name="Potato (1kg)", base_price=340.0, category="Fresh Produce"),
        Grocery(name="Onion (1kg)", base_price=520.0, category="Fresh Produce"),
        Grocery(name="Tomato (1kg)", base_price=310.0, category="Fresh Produce"),
        Grocery(name="Green Chilli (250g)", base_price=180.0, category="Fresh Produce"),
        Grocery(name="Banana (1kg)", base_price=360.0, category="Fresh Produce"),
        Grocery(name="Papaya (1kg)", base_price=260.0, category="Fresh Produce"),
        Grocery(name="Fish (500g)", base_price=1650.0, category="Meat & Fish"),
        Grocery(name="Chicken (1kg)", base_price=1250.0, category="Meat & Fish"),
        Grocery(name="Sausages (500g)", base_price=820.0, category="Meat & Fish"),
        Grocery(name="Eggs (Pack of 10)", base_price=460.0, category="Dairy & Eggs"),
        Grocery(name="Milk (1L)", base_price=490.0, category="Dairy & Eggs"),
        Grocery(name="Butter (200g)", base_price=780.0, category="Dairy & Eggs"),
        Grocery(name="Cheese (200g)", base_price=920.0, category="Dairy & Eggs"),
        Grocery(name="Yoghurt (Pack of 4)", base_price=320.0, category="Dairy & Eggs"),
        Grocery(name="Rice (5kg)", base_price=1420.0, category="Pantry"),
        Grocery(name="Basmati Rice (5kg)", base_price=2850.0, category="Pantry"),
        Grocery(name="Dhal (1kg)", base_price=340.0, category="Pantry"),
        Grocery(name="Sugar (1kg)", base_price=265.0, category="Pantry"),
        Grocery(name="Coconut Oil (1L)", base_price=1150.0, category="Pantry"),
        Grocery(name="Tea (400g)", base_price=680.0, category="Pantry"),
        Grocery(name="Biscuits (Large pack)", base_price=390.0, category="Snacks"),
        Grocery(name="Washing Powder (1kg)", base_price=540.0, category="Household"),
        Grocery(name="Soap (Pack of 4)", base_price=480.0, category="Household")
    ];
    for grocery in groceries {
        lower_product_name = grocery.name.lower();
        if "5kg" in lower_product_name { grocery.pack_size = 5.0; grocery.pack_unit = "kg"; }
        elif "1kg" in lower_product_name { grocery.pack_size = 1.0; grocery.pack_unit = "kg"; }
        elif "250g" in lower_product_name { grocery.pack_size = 250.0; grocery.pack_unit = "g"; }
        elif "500g" in lower_product_name or "400g" in lower_product_name or "200g" in lower_product_name { grocery.pack_size = 500.0 if "500g" in lower_product_name else (400.0 if "400g" in lower_product_name else 200.0); grocery.pack_unit = "g"; }
        elif "1l" in lower_product_name { grocery.pack_size = 1.0; grocery.pack_unit = "L"; }
        exists = False;
        for current in [root -->][?:Grocery] { if current.name == grocery.name { exists = True; } }
        if not exists { root ++> grocery; }
    }
    store_names: list[str] = ["Keells", "Arpico", "Cargills"];
    stores: list[Supermarket] = [];
    for name in store_names {
        found: Supermarket | None = None;
        for existing in [root -->][?:Supermarket] { if existing.name == name { found = existing; } }
        store_address = "No. 15 Galle Road, Colombo 03" if name == "Keells" else ("No. 8 Duplication Road, Colombo 04" if name == "Arpico" else "No. 22 Main Street, Colombo 01");
        store_trip_fee = 180.0 if name == "Keells" else (240.0 if name == "Arpico" else 210.0);
        if found is None { stores = stores + [root ++> Supermarket(name=name, address=store_address, district="Colombo", trip_fee=store_trip_fee)]; }
        else {
            existing_store = found as Supermarket;
            existing_store.address = store_address;
            existing_store.district = "Colombo";
            existing_store.trip_fee = store_trip_fee;
            stores = stores + [existing_store];
        }
    }
    prices: list[list[float]] = [
        [420.0,380.0,340.0,520.0,310.0,180.0,360.0,260.0,1650.0,1250.0,820.0,460.0,490.0,780.0,920.0,320.0,1420.0,2850.0,340.0,265.0,1150.0,680.0,390.0,540.0,480.0],
        [390.0,360.0,330.0,510.0,290.0,170.0,380.0,240.0,1700.0,1220.0,850.0,450.0,480.0,760.0,890.0,320.0,1390.0,2790.0,330.0,260.0,1120.0,660.0,380.0,520.0,470.0],
        [410.0,390.0,350.0,540.0,320.0,190.0,350.0,250.0,1680.0,1240.0,830.0,470.0,490.0,790.0,930.0,310.0,1420.0,2890.0,340.0,265.0,1180.0,690.0,390.0,550.0,490.0]
    ];
    promo_prices: list[list[float]] = [
        [340.0,0.0,0.0,450.0,250.0,0.0,0.0,200.0,0.0,1100.0,0.0,0.0,0.0,680.0,0.0,0.0,0.0,2450.0,290.0,0.0,0.0,0.0,330.0,0.0,420.0],
        [0.0,300.0,0.0,440.0,0.0,130.0,310.0,0.0,0.0,1080.0,0.0,390.0,0.0,0.0,800.0,0.0,1280.0,0.0,0.0,0.0,980.0,570.0,0.0,430.0,0.0],
        [0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,270.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0]
    ];
    promos: list[list[str]] = [
        ["Keells 20% off fresh veg","","","Keells & Arpico seasonal deal","Keells fresh deal","","","Keells daily pick","","Keells & Arpico meat markdown","","","","Keells breakfast offer","","","","Keells premium rice deal","Keells bulk markdown","","","","Keells tea-time combo","","Keells hygiene pack offer"],
        ["","Arpico weekly harvest drop","","Keells & Arpico seasonal deal","","Arpico flash discount","Arpico fruit saver","","","Keells & Arpico meat markdown","","Arpico weekend price drop","","","Arpico dairy special","","Arpico staple grains discount","","","","Arpico cooking oil special","Arpico beverage deal","","Arpico home care discount",""],
        ["","","","","","","","","","","","","","","","Cargills dairy promo","","","","","","","","",""]
    ];
    rule_rows: list[list[str | float]] = [
        ["Keells", "Commercial Bank", 25.0, 4000.0, 1500.0, "Fresh Produce, Meat & Fish"],
        ["Keells", "Sampath Bank", 10.0, 6000.0, 1000.0, "Total bill"],
        ["Arpico", "Pan Asia", 20.0, 5000.0, 2000.0, "Total bill"],
        ["Arpico", "BOC", 15.0, 7500.0, 2500.0, "Pantry, Household"],
        ["Cargills", "Sampath Bank", 20.0, 3500.0, 1200.0, "Dairy & Eggs, Fresh Produce"]
    ];
    for rule_row in rule_rows {
        rule_shop_name = rule_row[0] as str;
        rule_bank = rule_row[1] as str;
        rule_exists = False;
        for current_rule in [root -->][?:CardPromotion] { if current_rule.bank == rule_bank and current_rule.description == rule_shop_name { rule_exists = True; } }
        if not rule_exists {
            category_filter = "All" if (rule_row[5] as str) == "Total bill" else (rule_row[5] as str);
            root ++> CardPromotion(bank=rule_bank, description=rule_shop_name, category=category_filter, discount=(rule_row[2] as float) / 100.0, min_bill=rule_row[3] as float, max_cap=rule_row[4] as float, condition=rule_row[5] as str);
        }
    }
    for (store_index, shop) in enumerate(stores) {
        for (item_index, grocery) in enumerate(groceries) {
            existing_offer: InventoryOffer | None = None;
            for offer_node in [shop ->:HasOffer:->][?:InventoryOffer] { if offer_node.item_name == grocery.name { existing_offer = offer_node; } }
            if existing_offer is None {
                new_offer = InventoryOffer(item_name=grocery.name, price=prices[store_index][item_index], promo_price=promo_prices[store_index][item_index], promo_text=promos[store_index][item_index]);
                shop +>:HasOffer:+> new_offer;
                new_offer +>:OfferFor:+> grocery;
            } else {
                updated_offer = existing_offer as InventoryOffer;
                updated_offer.price = prices[store_index][item_index];
                updated_offer.promo_price = promo_prices[store_index][item_index];
                updated_offer.promo_text = promos[store_index][item_index];
            }
        }
        for courier in [root -->][?:DeliveryCourier] {
            already_linked = False;
            for linked_courier in [shop ->:HasCourier:->][?:DeliveryCourier] { if linked_courier.name == courier.name { already_linked = True; } }
            if not already_linked { shop +>:HasCourier:+> courier; }
        }
        shop_location = "No. 15 Galle Road, Colombo 03" if shop.name == "Keells" else ("No. 8 Duplication Road, Colombo 04" if shop.name == "Arpico" else "No. 22 Main Street, Colombo 01");
        shop.address = shop_location;
    }
    market_rules: list[CardPromotion] = [
        CardPromotion(bank="Commercial Bank", description="Keells", category="Fresh Produce, Meat & Fish", discount=0.25, min_bill=4000.0, max_cap=1500.0, condition="25% off qualifying vegetables, fruits, fish and meat; minimum bill Rs. 4,000; cap Rs. 1,500"),
        CardPromotion(bank="Sampath Bank", description="Keells", category="All", discount=0.10, min_bill=6000.0, max_cap=1000.0, condition="10% off total bill; minimum bill Rs. 6,000; cap Rs. 1,000"),
        CardPromotion(bank="Pan Asia", description="Arpico", category="All", discount=0.20, min_bill=5000.0, max_cap=2000.0, condition="20% off total bill; minimum bill Rs. 5,000; cap Rs. 2,000"),
        CardPromotion(bank="BOC", description="Arpico", category="Pantry, Household", discount=0.15, min_bill=7500.0, max_cap=2500.0, condition="15% off pantry and household items; minimum bill Rs. 7,500; cap Rs. 2,500"),
        CardPromotion(bank="Sampath Bank", description="Cargills", category="Dairy & Eggs, Fresh Produce", discount=0.20, min_bill=3500.0, max_cap=1200.0, condition="20% off dairy, eggs and fresh produce; minimum bill Rs. 3,500; cap Rs. 1,200")
    ];
    for rule in market_rules {
        duplicate = False;
        for existing in [root -->][?:CardPromotion] { if existing.bank == rule.bank and existing.description == rule.description { duplicate = True; } }
        if not duplicate { root ++> rule; }
    }
    return True;
}

def editDistance(left: str, right: str) -> int {
    a = left.lower();
    b = right.lower();
    previous: list[int] = [];
    for index in range(len(b) + 1) { previous = previous + [index]; }
    for i in range(len(a)) {
        current: list[int] = [i + 1];
        for j in range(len(b)) {
            insert_cost = current[j] + 1;
            delete_cost = previous[j + 1] + 1;
            replace_cost = previous[j] + (0 if a[i] == b[j] else 1);
            current = current + [min([insert_cost, delete_cost, replace_cost])];
        }
        previous = current;
    }
    return previous[len(b)];
}

def:pub listStoreInventory(store_name: str) -> list[InventoryRow] {
    _ = initializeBasket();
    rows: list[InventoryRow] = [];
    for shop in [root -->][?:Supermarket] {
        if store_name == "All stores" or shop.name == store_name {
            for offer in [shop ->:HasOffer:->][?:InventoryOffer] {
                category = "";
                for item in [root -->][?:Grocery] { if item.name == offer.item_name { category = item.category; } }
                rows = rows + [InventoryRow(name=offer.item_name, category=category, store=shop.name, price=offer.price, promo_price=offer.promo_price, promo_text=offer.promo_text)];
            }
        }
    }
    return rows;
}

async def:pub optimizeBasket(grocery_text: str, selected_cards: list[str], preferred_stores: list[str], speed_priority: int, delivery_days: int, delivery_hours: int) -> OptimizationResult {
    if len(grocery_text.strip()) == 0 { return OptimizationResult(error="Add at least one grocery item to build your basket."); }
    _ = initializeBasket();
    suggestions = getMissingHabitSuggestions(grocery_text);
    products: list[BasketItem] = [];
    unavailable: list[str] = [];
    for entry in grocery_text.split(",") {
        raw_entry = entry.strip().lower();
        if len(raw_entry) == 0 { continue; }
        quantity: float = 1.0;
        requested_unit = "pack";
        requested_amount: float = 1.0;
        needle: str = raw_entry;
        match_result = re_search(r"^(\d+(?:\.\d+)?)\s*(kg|kgs|g|gm|gram|grams|l|liter|litre|packs?|pcs|pieces?)?\b[\s,:;-]*", raw_entry);
        if match_result is not None and len(raw_entry[match_result.end():].strip()) > 0 {
            amount_text = match_result.group(1);
            unit_text = match_result.group(2);
            requested_amount = float(amount_text);
            needle = raw_entry[match_result.end():].strip();
            if unit_text is None { requested_unit = "pack"; }
            elif unit_text in ["kg", "kgs"] { requested_unit = "kg"; }
            elif unit_text in ["g", "gm", "gram", "grams"] { requested_unit = "g"; }
            elif unit_text in ["l", "liter", "litre"] { requested_unit = "L"; }
            else { requested_unit = "pack"; }
            quantity = requested_amount;
        } else {
            trailing = re_search(r"\s+(\d+(?:\.\d+)?)\s*(kg|kgs|g|gm|gram|grams|l|liter|litre|packs?|pcs|pieces?)?\s*$", raw_entry);
            if trailing is not None and len(raw_entry[:trailing.start()].strip()) > 0 and not raw_entry[:trailing.start()].strip().endswith("(") {
                unit_text = trailing.group(2);
                requested_amount = float(trailing.group(1));
                needle = raw_entry[:trailing.start()].strip();
                if unit_text is None { requested_unit = "pack"; }
                elif unit_text in ["kg", "kgs"] { requested_unit = "kg"; }
                elif unit_text in ["g", "gm", "gram", "grams"] { requested_unit = "g"; }
                elif unit_text in ["l", "liter", "litre"] { requested_unit = "L"; }
                else { requested_unit = "pack"; }
                quantity = requested_amount;
            }
        }
        matched: Grocery | None = None;
        nearest: Grocery | None = None;
        nearest_distance: int = 999;
        requested_base = needle.split(" (")[0];
        for item in [root -->][?:Grocery] {
            normalized_name = item.name.lower();
            short_name = normalized_name.split(" (")[0];
            if normalized_name == needle or short_name == needle or short_name.startswith(requested_base) { matched = item; }
            distance = editDistance(requested_base, short_name);
            if distance < nearest_distance { nearest_distance = distance; nearest = item; }
        }
        if matched is None and nearest is not None and nearest_distance <= 2 and len(requested_base) >= 3 { matched = nearest as Grocery; }
        if matched is not None {
            product = matched as Grocery;
            if requested_unit == "kg" {
                if product.pack_unit == "kg" { quantity = requested_amount / product.pack_size; }
                elif product.pack_unit == "g" { quantity = requested_amount * 1000.0 / product.pack_size; }
                else { quantity = requested_amount; }
            } elif requested_unit == "g" {
                if product.pack_unit == "g" { quantity = requested_amount / product.pack_size; }
                elif product.pack_unit == "kg" { quantity = requested_amount / (product.pack_size * 1000.0); }
                else { quantity = requested_amount; }
            } elif requested_unit == "L" {
                if product.pack_unit == "L" { quantity = requested_amount / product.pack_size; }
                else { quantity = requested_amount; }
            } else { quantity = requested_amount; }
            products = products + [BasketItem(name=product.name, quantity=quantity, unit=product.pack_unit, requested_quantity=requested_amount, requested_unit=requested_unit, category=product.category)];
        } else { unavailable = unavailable + [entry.strip()]; }
    }
    if len(products) == 0 { return OptimizationResult(error="None of these items exist in the mock catalog: " + ", ".join(unavailable)); }
    eligible_banks: list[str] = [];
    for bank in ["Commercial Bank", "HNB", "Sampath Bank", "Pan Asia", "BOC"] { if bank in selected_cards { eligible_banks = eligible_banks + [bank]; } }
    for saved_card in [root -->][?:SavedPaymentCard] {
        saved_label = saved_card.nickname + " · " + saved_card.brand + " ending " + saved_card.last_four;
        if saved_label in selected_cards and not (saved_card.bank in eligible_banks) { eligible_banks = eligible_banks + [saved_card.bank]; }
    }
    candidates: list[Supermarket] = [];
    for shop in [root -->][?:Supermarket] { if len(preferred_stores) == 0 or shop.name in preferred_stores { candidates = candidates + [shop]; } }
    lines: list[BillLine] = [];
    subtotal: float = 0.0;
    item_savings: float = 0.0;
    for product in products {
        has_availability = False;
        for shop in candidates { for offer in [shop ->:HasOffer:->][?:InventoryOffer] { if offer.item_name == product.name and offer.price > 0.0 { has_availability = True; } } }
        if not has_availability { unavailable = unavailable + [product.name]; }
        lowest_cost: float = 999999999.0;
        winning_line: BillLine | None = None;
        for shop in candidates {
            regular: float = 0.0;
            sale: float = 0.0;
            description: str = "Regular price";
            for offer in [shop ->:HasOffer:->][?:InventoryOffer] {
                if offer.item_name == product.name {
                    regular = offer.price;
                    sale = offer.promo_price;
                    description = offer.promo_text;
                }
            }
            payable_price = sale if sale > 0.0 else regular;
            discount = regular * product.quantity - payable_price * product.quantity;
            delivery_estimate: float = 380.0 / (len(products) as float);
            if payable_price * product.quantity + delivery_estimate < lowest_cost {
                lowest_cost = payable_price * product.quantity + delivery_estimate;
                winning_line = BillLine(name=product.name, quantity=product.quantity, store=shop.name, base_price=regular * product.quantity, item_discount=discount, line_total=payable_price * product.quantity, promo_note=description);
            }
        }
        if winning_line is not None {
            final_line = winning_line as BillLine;
            lines = lines + [final_line];
            subtotal += final_line.base_price;
            item_savings += final_line.item_discount;
        }
    }
    store_names: list[str] = [];
    for line in lines { if not (line.store in store_names) { store_names = store_names + [line.store]; } }
    deliveries: list[StoreDelivery] = [];
    delivery_total: float = 0.0;
    location_total: float = 0.0;
    courier_label: str = "";
    location_names: list[str] = [];
    for shop in candidates { if shop.name in store_names { location_names = location_names + [shop.name + " — " + shop.address]; location_total += shop.trip_fee; } }
    for shop in candidates {
        if shop.name in store_names {
            selected_courier: str = "PickMe Flash";
            fee: float = 380.0;
            for courier in [shop ->:HasCourier:->][?:DeliveryCourier] { if courier.cost < fee { selected_courier = courier.name; fee = courier.cost; } }
            deliveries = deliveries + [StoreDelivery(store=shop.name, courier=selected_courier, charge=fee + shop.trip_fee, address=shop.address)];
            delivery_total += fee;
            if courier_label == "" { courier_label = selected_courier; }
        }
    }
    total_discount: float = 0.0;
    applied_rules: list[OfferRule] = [];
    for rule in [root -->][?:CardPromotion] {
        if rule.description in store_names and rule.bank in eligible_banks {
            qualifying_bill: float = 0.0;
            for line in lines {
                category: str = "";
                for grocery in [root -->][?:Grocery] { if grocery.name == line.name { category = grocery.category; } }
                category_matches = rule.category == "All" or category in rule.category;
                if line.store == rule.description and category_matches { qualifying_bill += line.line_total; }
            }
            applied: float = 0.0;
            if qualifying_bill >= rule.min_bill {
                applied = min([qualifying_bill * rule.discount, rule.max_cap]);
                total_discount += applied;
            }
            applied_rules = applied_rules + [OfferRule(store=rule.description, card=rule.bank, discount_percent=rule.discount * 100.0, min_bill=rule.min_bill, max_cap=rule.max_cap, conditions=rule.condition, eligible=applied > 0.0, applied_discount=applied)];
        }
    }
    location_total = sum([shop.trip_fee for shop in candidates if shop.name in store_names]);
    total = subtotal - item_savings - total_discount + delivery_total + location_total;
    user_profile: UserProfileView = getUserProfile();
    remaining_balance: float = user_profile.mock_available_balance - total;
    mock_balance_warning: str = "";
    if len(eligible_banks) > 0 and remaining_balance < 0.0 { mock_balance_warning = "Estimated total exceeds the demo mock balance; COD is still available. No bank balance is accessed."; }
    eta = (datetime.now() + timedelta(days=delivery_days) + timedelta(seconds=delivery_hours * 3600)).strftime("%A, %d %B at %H:%M");
    suggestions: list[str] = getMissingHabitSuggestions(grocery_text);
    applied_savings = item_savings + total_discount;
    location_summary = "; ".join(location_names);
    return OptimizationResult(items=products, ai_suggestions=suggestions, unavailable_items=unavailable, offer_rules=applied_rules, profile=user_profile, mock_balance_warning=mock_balance_warning, location_summary=location_summary, lines=lines, deliveries=deliveries, store=", ".join(store_names), courier=courier_label, card=", ".join(eligible_banks), subtotal=subtotal, item_discounts=item_savings, basket_discount=total_discount, delivery_charge=delivery_total, location_charge=location_total, total=total, savings=applied_savings, estimated_balance=remaining_balance, delivery_days=delivery_days, delivery_hours=delivery_hours, delivery_date=eta, promo_note="Store markdowns and eligible capped bank offers applied");
}
