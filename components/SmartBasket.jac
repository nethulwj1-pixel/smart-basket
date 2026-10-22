sv import from ..services.paymentCards { SavedPaymentCard, listSavedCards }
sv import from ..services.userProfile { UserProfileView, getDisplayName, getUserProfile, getMissingHabitSuggestions, recordShopping }
sv import from ..services.basketService { OptimizationResult, OfferRule, optimizeBasket }
import from "@jac/runtime" { Link, useNavigate, jacIsLoggedIn }
import from .ui.button { Button }
import from .ui.card { Card, CardContent, CardDescription, CardHeader, CardTitle }
import from .ui.badge { Badge }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { ShoppingBag01Icon, SparklesIcon, DeliveryTruck01Icon, CreditCardIcon, CheckmarkCircle02Icon }


def format_rs(amount: float) -> str {
    cents = int(round(amount * 100.0));
    whole = cents // 100;
    fraction = cents % 100;
    fraction_text = "0" + str(fraction) if fraction < 10 else str(fraction);
    return str(whole) + "." + fraction_text;
}


def:pub SmartBasket() -> JsxElement {
    has grocery_text: str = "2 Carrot (1kg), Rice (5kg), Eggs (Pack of 10)";
    has basket_items: list[str] = ["2 Carrot (1kg)", "Rice (5kg)", "Eggs (Pack of 10)"];
    has result: OptimizationResult | None = None;
    has loading: bool = False;
    has error_message: str = "";
    has checkout_message: str = "";
    has cards: list[str] = ["Commercial Bank", "Sampath Bank", "Pan Asia", "BOC", "COD"];
    has saved_cards: list[SavedPaymentCard] = [];
    has display_name: str = "";
    has profile: UserProfileView | None = None;
    has suggestions: list[str] = [];
    has selected_cards: list[str] = ["COD"];
    has stores: list[str] = ["Keells", "Arpico", "Cargills"];
    has selected_stores: list[str] = ["Keells", "Arpico", "Cargills"];
    has speed_priority: int = 45;
    has delivery_days: int = 1;
    has delivery_hours: int = 0;
    nav = useNavigate();

    async can with entry {
        if jacIsLoggedIn() {
            try {
                saved_cards = await listSavedCards();
                display_name = await getDisplayName();
                profile = await getUserProfile();
            } except Exception { saved_cards = []; }
        }
    }
    def handle_text(e: ChangeEvent) { grocery_text = e.target.value; }
    def handle_store(e: ChangeEvent) {
        store = e.target.value;
        if store in selected_stores { selected_stores = [item for item in selected_stores if item != store]; }
        else { selected_stores = selected_stores + [store]; }
    }
    def handle_speed(e: ChangeEvent) { speed_priority = int(e.target.value); }
    def handle_days(e: ChangeEvent) { delivery_days = int(e.target.value); }
    def handle_hours(e: ChangeEvent) { delivery_hours = int(e.target.value); }
    def handle_cards(e: ChangeEvent) {
        card = e.target.value;
        if card in selected_cards { selected_cards = [item for item in selected_cards if item != card]; }
        else { selected_cards = selected_cards + [card]; }
    }
    def add_habit(item: str) {
        current = [part.strip() for part in grocery_text.split(",") if len(part.strip()) > 0];
        if not (item.lower() in grocery_text.lower()) {
            grocery_text = grocery_text + ", " + item;
            basket_items = current + [item];
            suggestions = [suggestion for suggestion in suggestions if suggestion != item];
        }
    }
    def handle_add(e: MouseEvent) {
        basket_items = [item.strip() for item in grocery_text.split(",") if len(item.strip()) > 0];
        result = None;
        error_message = "";
    }
    def handle_canary(e: Event) { error_message = "canary-click-works"; }
    async def handle_optimize {
        loading = True;
        error_message = "Optimizing your basket...";
        result = None;
        next_error: str = "";
        next_result: OptimizationResult | None = None;
        offer_banks = [card for card in selected_cards if card in cards];
        for saved in saved_cards {
            saved_label = saved.nickname + " · " + saved.brand + " ending " + saved.last_four;
            if saved_label in selected_cards and not (saved.bank in offer_banks) { offer_banks = offer_banks + [saved.bank]; }
        }
        try {
            candidate: OptimizationResult = await optimizeBasket(grocery_text, offer_banks, selected_stores, speed_priority, delivery_days, delivery_hours);
            if candidate.error != "" { next_error = candidate.error; }
            else { next_result = candidate; suggestions = candidate.ai_suggestions; checkout_message = ""; }
        } except Exception as err { next_error = str(err); }
        error_message = next_error;
        result = next_result;
        loading = False;
    }
    async def handle_confirm_order {
        if not jacIsLoggedIn() { checkout_message = "Sign in to save this order and update your shopping profile."; return; }
        if result is None { checkout_message = "Run the price check before confirming a mock order."; return; }
        try {
            if result is not None {
                purchased: list[str] = [line.name for line in result.lines];
                profile = await recordShopping(result.savings, purchased);
                checkout_message = "Mock order confirmed. Your savings and shopping habits were updated.";
            }
        } except Exception { checkout_message = "Could not update your profile. No payment was processed."; }
    }
    def handle_example(e: MouseEvent) {
        grocery_text = "2 Carrot (1kg), Rice (5kg), Eggs (Pack of 10)";
        basket_items = ["2 Carrot (1kg)", "Rice (5kg)", "Eggs (Pack of 10)"];
        result = None;
        error_message = "";
    }

    return <div className="sb-app min-h-screen text-foreground">
        <header className="sticky top-0 z-20 border-b border-white/10 bg-slate-950/80 backdrop-blur-xl"><div className="mx-auto flex min-h-16 max-w-7xl flex-wrap items-center justify-between gap-3 px-4 py-2 sm:px-6"><div className="flex items-center gap-3"><div className="flex size-10 items-center justify-center rounded-xl bg-emerald-400 text-slate-950"><HugeiconsIcon icon={ShoppingBag01Icon} strokeWidth={2} className="size-5" /></div><div><p className="text-base font-semibold text-white">Smart Basket</p><p className="text-xs text-slate-400">Agentic grocery intelligence</p></div></div><div className="flex flex-wrap items-center gap-3"><Link to="/stores" className="text-xs text-cyan-200 hover:text-white">Browse inventory</Link><Link to="/account/cards" className="text-xs text-cyan-200 hover:text-white">Saved cards</Link><Link to="/login" className="text-xs text-slate-400 hover:text-white">Sign in</Link></div></div></header>
        <main className="mx-auto flex w-full max-w-7xl flex-col gap-7 px-4 py-7 sm:px-6 lg:py-10">
            {if profile is not None { <div className="grid gap-3 sm:grid-cols-3"><div className="rounded-xl border border-white/10 bg-slate-900/65 p-4"><p className="text-xs text-slate-400">Shopping profile</p><p className="mt-1 font-semibold text-white">{profile.display_name}</p><p className="text-xs text-slate-400">{profile.delivery_location}</p></div><div className="rounded-xl border border-white/10 bg-slate-900/65 p-4"><p className="text-xs text-slate-400">Total saved</p><p className="mt-1 text-xl font-semibold text-emerald-200">Rs. {format_rs(profile.total_savings)}</p></div><div className="rounded-xl border border-white/10 bg-slate-900/65 p-4"><p className="text-xs text-slate-400">Completed mock orders</p><p className="mt-1 text-xl font-semibold text-white">{str(profile.total_orders)}</p></div></div> }}
            {if profile is not None { <div className="grid gap-3 sm:grid-cols-3"><div className="rounded-xl border border-white/10 bg-slate-900/65 p-4"><p className="text-xs text-slate-400">Your profile</p><p className="mt-1 font-semibold text-white">{profile.display_name}</p><p className="text-xs text-slate-400">{profile.delivery_location}</p></div><div className="rounded-xl border border-white/10 bg-slate-900/65 p-4"><p className="text-xs text-slate-400">Cumulative savings</p><p className="mt-1 text-xl font-semibold text-emerald-200">Rs. {format_rs(profile.total_savings)}</p><p className="text-xs text-slate-500">From confirmed mock orders</p></div><div className="rounded-xl border border-white/10 bg-slate-900/65 p-4"><p className="text-xs text-slate-400">Order history</p><p className="mt-1 text-xl font-semibold text-white">{str(profile.total_orders)} confirmed</p></div></div> }}
            <div className="relative overflow-hidden rounded-3xl border border-white/10 bg-slate-900/70 px-5 py-7 sm:px-8 sm:py-9"><div className="relative flex flex-wrap items-end justify-between gap-6"><div className="flex max-w-3xl flex-col gap-3"><p className="text-xs font-semibold uppercase tracking-[0.22em] text-emerald-300"><HugeiconsIcon icon={SparklesIcon} strokeWidth={2} className="mr-2 inline size-4" />{"Welcome back, " + display_name if len(display_name) > 0 else "Smarter shopping starts here"}</p><h1 className="text-3xl font-semibold text-white sm:text-5xl">A better basket, <span className="text-emerald-300">by design.</span></h1><p className="text-sm text-slate-400 sm:text-base">Compare the supplied store inventory, qualifying bank offers, and delivery costs.</p></div><div className="rounded-2xl border border-cyan-300/15 bg-slate-950/50 px-4 py-3"><p className="font-semibold text-white">AI basket planner</p><p className="text-xs text-slate-400">Habit-aware suggestions</p></div></div></div>
            <div className="grid gap-5 lg:grid-cols-12 lg:items-start">
                <section className="grid gap-5 lg:col-span-7">
                    <Card className="sb-glass border-white/10 bg-slate-900/65"><CardHeader><CardTitle className="text-white">Build your basket</CardTitle><CardDescription className="text-slate-400">Enter items and quantities such as 2 Carrot (1kg), Rice (5kg), Eggs (Pack of 10).</CardDescription></CardHeader><CardContent className="flex flex-col gap-4"><label htmlFor="grocery-list" className="text-sm text-slate-200">Grocery list</label><textarea id="grocery-list" value={grocery_text} onChange={handle_text} rows={4} className="w-full rounded-xl border border-white/10 bg-slate-950/70 px-4 py-3 text-sm text-white" /><div className="flex justify-between"><span className="text-xs text-slate-400">{str(len(basket_items))} items</span><Button variant="outline" onClick={handle_add}>Update basket</Button></div><div className="flex flex-wrap gap-2">{for (i, item) in enumerate(basket_items) { <Badge key={str(i)} variant="secondary">{item}</Badge> }}</div>
                    {if len(suggestions) > 0 { <div className="rounded-2xl border border-cyan-300/30 bg-cyan-300/[0.07] p-4 shadow-[0_0_28px_rgba(34,211,238,.10)]"><p className="text-xs font-bold uppercase tracking-[0.18em] text-cyan-200">Agent Alert</p>{for (i, suggestion) in enumerate(suggestions) { <div key={str(i)} className="mt-2 flex flex-wrap items-center justify-between gap-2"><p className="flex-1 text-sm text-slate-200">I noticed you usually buy <strong>{suggestion}</strong> every week, but it is not on your list. Should I include it in the price check?</p><Button size="sm" onClick={lambda (e: MouseEvent) { add_habit(suggestion); }}>Add {suggestion}</Button></div> }}</div> }}
                    </CardContent></Card>
                    {if len(suggestions) > 0 { <Card className="sb-glass border-cyan-300/30 bg-cyan-300/[0.07] shadow-[0_0_28px_rgba(34,211,238,.12)]"><CardHeader><CardTitle className="text-cyan-100">Agent Alert</CardTitle><CardDescription className="text-slate-300">Based on your prior confirmed mock baskets</CardDescription></CardHeader><CardContent className="flex flex-col gap-3">{for (i, suggestion) in enumerate(suggestions) { <div key={str(i)} className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-white/10 bg-slate-950/40 p-3"><p className="flex-1 text-sm text-slate-200">I noticed you usually buy <strong>{suggestion}</strong> every week, but it is not on your list. Should I include it in the price check?</p><Button size="sm" onClick={lambda (e: MouseEvent) { add_habit(suggestion); }}>Add to list</Button></div> }}</CardContent></Card> }}
                    <Card className="sb-glass border-white/10 bg-slate-900/65"><CardHeader><CardTitle className="text-white">Payment, stores and delivery</CardTitle><CardDescription className="text-slate-400">Only your saved cards and COD are shown; offers use the issuer you saved.</CardDescription></CardHeader><CardContent className="flex flex-col gap-5"><div className="flex flex-wrap gap-2">{for bank in ["COD"] { <label key={bank} className="rounded-xl border border-white/10 bg-slate-950/40 p-3 text-sm text-slate-200"><input type="checkbox" value={bank} checked={bank in selected_cards} onChange={handle_cards} className="mr-2 accent-emerald-300" />Cash on delivery</label> }}{for saved in saved_cards { label = saved.nickname + " · " + saved.brand + " ending " + saved.last_four; <label key={label} className="rounded-xl border border-white/10 bg-slate-950/40 p-3 text-sm text-slate-200"><input type="checkbox" value={label} checked={label in selected_cards} onChange={handle_cards} className="mr-2 accent-emerald-300" />{label} · {saved.bank}</label> }}<Link to="/account/cards" className="self-center text-xs text-cyan-200">Manage saved cards</Link></div><div className="rounded-xl border border-white/10 bg-slate-950/40 p-3 text-xs leading-relaxed text-slate-400">Only your saved masked cards and COD are available here. Bank balances are never accessed; any displayed balance is a mock estimate. Offer minimums, eligible categories, and maximum caps are enforced from the supplied rules.</div><div><p className="mb-2 text-sm text-slate-200">Stores</p><div className="flex flex-wrap gap-2">{for store in stores { <label key={store} className="rounded-lg border border-white/10 px-3 py-2 text-sm text-slate-200"><input type="checkbox" value={store} checked={store in selected_stores} onChange={handle_store} className="mr-2 accent-emerald-300" />{store}</label> }}</div></div><div className="grid gap-4 sm:grid-cols-3"><label className="text-sm text-slate-200">Price ↔ Speed ({str(speed_priority)}%)<input type="range" min="0" max="100" value={str(speed_priority)} onChange={handle_speed} className="sb-range mt-3 w-full" /></label><label className="text-sm text-slate-200">Delivery days<input type="number" min="0" max="7" value={str(delivery_days)} onChange={handle_days} className="mt-2 h-10 w-full rounded-lg bg-slate-950 px-3" /></label><label className="text-sm text-slate-200">Extra hours<input type="number" min="0" max="23" value={str(delivery_hours)} onChange={handle_hours} className="mt-2 h-10 w-full rounded-lg bg-slate-950 px-3" /></label></div><Button disabled={loading} onClick={handle_canary} className="h-12 bg-emerald-300 font-semibold text-slate-950">{"Optimizing..." if loading else "Find best basket"}</Button>{if error_message != "" { <p role="alert" className="text-sm text-rose-200">{error_message}</p> }}</CardContent></Card>
                </section>
                <section className="flex flex-col gap-5 lg:col-span-5">
                    <Card className="sb-glass border-emerald-300/20 bg-slate-900/75">
                        <CardHeader><CardTitle className="text-white">Optimized bill</CardTitle><CardDescription className="text-slate-400">Store-level discounts, capped bank offers, and trip fees</CardDescription></CardHeader>
                        <CardContent className="flex flex-col gap-4">
                            {if result is None { <div className="rounded-xl border border-dashed border-white/10 p-8 text-center text-slate-400">Run a price check to see your itemized bill.</div> }
                            else {
                                <div className="flex flex-col gap-3">
                                    <div className="flex justify-between text-2xl font-semibold text-white"><span>Total</span><span>Rs. {format_rs(result.total)}</span></div>
                                    <div className="flex justify-between text-emerald-200"><span>Total savings</span><span>Rs. {format_rs(result.savings)}</span></div>
                                    <div className="border-t border-white/10 pt-3">{for (i, line) in enumerate(result.lines) { <div key={str(i)} className="border-b border-white/5 py-2 text-sm"><div className="flex justify-between text-slate-200"><span>{line.name} × {str(line.quantity)}</span><span>Rs. {format_rs(line.line_total)}</span></div><div className="text-xs text-slate-400">{line.store} · {line.promo_note} · discount Rs. {format_rs(line.item_discount)}</div></div> }}</div>
                                    <div className="flex justify-between text-sm text-slate-300"><span>Delivery and location charges</span><span>Rs. {format_rs(result.delivery_charge + result.location_charge)}</span></div>
                                    {if result.location_summary != "" { <p className="text-xs text-slate-400">Delivery locations: {result.location_summary}</p> }}
                                    <div className="text-xs text-slate-400">{for delivery in result.deliveries { <p key={delivery.store}>{delivery.store}, {delivery.address}: {delivery.courier}, delivery Rs. {format_rs(delivery.charge)}</p> }}</div>
                                    <div className="rounded-lg border border-white/10 p-3">{for (i, rule) in enumerate(result.offer_rules) { <p key={str(i)} className="text-xs text-slate-300">{rule.card} at {rule.store}: {rule.conditions}; minimum Rs. {format_rs(rule.min_bill)}, cap Rs. {format_rs(rule.max_cap)}; eligible: {str(rule.eligible)}; applied Rs. {format_rs(rule.applied_discount)}</p> }}</div>
                                    {if result.mock_balance_warning != "" { <p className="rounded-lg border border-amber-300/30 bg-amber-300/10 p-3 text-sm text-amber-100">{result.mock_balance_warning}</p> }}
                                    {if len(result.unavailable_items) > 0 { <p className="text-sm text-rose-200">Unavailable: {", ".join(result.unavailable_items)}</p> }}
                                    {if jacIsLoggedIn() { <Button onClick={lambda (e: MouseEvent) { handle_confirm_order(); }} className="bg-emerald-300 text-slate-950">Confirm mock order</Button> }}
                                    {if checkout_message != "" { <p role="status" className="text-sm text-emerald-200">{checkout_message}</p> }}
                                </div>
                            }}
                            {if profile is not None { <div className="rounded-xl border border-white/10 p-3 text-xs text-slate-400">Profile: {profile.display_name} · {str(profile.total_orders)} orders · total saved Rs. {format_rs(profile.total_savings)} · mock available balance Rs. {format_rs(profile.mock_available_balance)}</div> }}
                        </CardContent>
                    </Card>
                </section>
            </div>
        </main>
    </div>;
}
