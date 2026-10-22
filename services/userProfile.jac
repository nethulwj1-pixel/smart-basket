import from re { search as re_search }

node UserProfileNode {
    has display_name: str = "";
    has weekly_habits: list[str] = ["Rice (5kg)", "Eggs (Pack of 10)", "Milk (1L)"];
    has total_savings: float = 0.0;
    has total_orders: int = 0;
    has delivery_location: str = "Colombo 03";
    has mock_available_balance: float = 12000.0;
}
obj UserProfileView {
    has display_name: str = "";
    has weekly_habits: list[str] = [];
    has total_savings: float = 0.0;
    has total_orders: int = 0;
    has delivery_location: str = "Colombo 03";
    has mock_available_balance: float = 0.0;
}

def:protect saveDisplayName(display_name: str) -> str {
    clean = display_name.strip();
    if len(clean) == 0 or len(clean) > 40 { return "Choose a username between 1 and 40 characters."; }
    profiles = [root -->][?:UserProfileNode];
    if len(profiles) > 0 { profiles[0].display_name = clean; }
    else { root ++> UserProfileNode(display_name=clean); }
    return clean;
}

def:protect getDisplayName() -> str {
    profiles = [root -->][?:UserProfileNode];
    if len(profiles) > 0 { return profiles[0].display_name; }
    return "";
}

def:protect getUserProfile() -> UserProfileView {
    profiles = [root -->][?:UserProfileNode];
    if len(profiles) == 0 { return UserProfileView(); }
    profile = profiles[0];
    return UserProfileView(display_name=profile.display_name, weekly_habits=profile.weekly_habits, total_savings=profile.total_savings, total_orders=profile.total_orders, delivery_location=profile.delivery_location, mock_available_balance=profile.mock_available_balance);
}

def:protect getMissingHabitSuggestions(grocery_text: str) -> list[str] {
    profiles = [root -->][?:UserProfileNode];
    if len(profiles) == 0 { return []; }
    entry_bases: list[str] = [];
    for entry in grocery_text.split(",") {
        raw_entry = entry.strip().lower();
        if len(raw_entry) == 0 { continue; }
        match_result = re_search(r"^(\d+(?:\.\d+)?)\s*(kg|kgs|g|gm|gram|grams|l|liter|litre|packs?|pcs|pieces?)?\b[\s,:;-]*", raw_entry);
        needle = raw_entry;
        if match_result is not None and len(raw_entry[match_result.end():].strip()) > 0 { needle = raw_entry[match_result.end():].strip(); }
        entry_bases = entry_bases + [needle.split(" (")[0]];
    }
    missing: list[str] = [];
    for habit in profiles[0].weekly_habits {
        habit_base = habit.lower().split(" (")[0];
        covered = False;
        for base in entry_bases {
            if base == habit_base or habit_base.startswith(base) or base.startswith(habit_base) { covered = True; }
        }
        if not covered { missing = missing + [habit]; }
    }
    return missing;
}

def:protect recordShopping(savings: float, purchased_items: list[str]) -> UserProfileView {
    profiles = [root -->][?:UserProfileNode];
    profile: UserProfileNode;
    if len(profiles) == 0 { profile = root ++> UserProfileNode(); }
    else { profile = profiles[0]; }
    profile.total_savings += savings;
    profile.total_orders += 1;
    for item in purchased_items {
        found = False;
        for habit in profile.weekly_habits { if habit.lower() == item.lower() { found = True; } }
        if not found { profile.weekly_habits = profile.weekly_habits + [item]; }
    }
    return UserProfileView(display_name=profile.display_name, weekly_habits=profile.weekly_habits, total_savings=profile.total_savings, total_orders=profile.total_orders, delivery_location=profile.delivery_location, mock_available_balance=profile.mock_available_balance);
}
