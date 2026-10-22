import from asyncio { run }

test "plain rice maps to regular rice, not basmati" {
    r = run(optimizeBasket("rice", [], [], 45, 1, 0));
    assert r.error == "", r.error;
    assert len(r.lines) == 1;
    assert r.lines[0].name == "Rice (5kg)", r.lines[0].name;
}

test "basmati request still maps to basmati" {
    r = run(optimizeBasket("basmati rice", [], [], 45, 1, 0));
    assert r.error == "", r.error;
    assert r.lines[0].name == "Basmati Rice (5kg)", r.lines[0].name;
}

test "10kg rice becomes 2 packs of 5kg" {
    r = run(optimizeBasket("10kg rice", [], [], 45, 1, 0));
    assert r.error == "", r.error;
    assert r.lines[0].name == "Rice (5kg)", r.lines[0].name;
    assert r.lines[0].quantity == 2.0, str(r.lines[0].quantity);
}

test "2 packs of eggs maps quantity 2" {
    r = run(optimizeBasket("2 eggs", [], [], 45, 1, 0));
    assert r.error == "", r.error;
    assert r.lines[0].name == "Eggs (Pack of 10)", r.lines[0].name;
    assert r.lines[0].quantity == 2.0, str(r.lines[0].quantity);
}

test "3l milk maps to 3 one-litre packs" {
    r = run(optimizeBasket("3l milk", [], [], 45, 1, 0));
    assert r.error == "", r.error;
    assert r.lines[0].name == "Milk (1L)", r.lines[0].name;
    assert r.lines[0].quantity == 3.0, str(r.lines[0].quantity);
}

test "spelling typo still matches the right product" {
    r = run(optimizeBasket("tamato 2kg", [], [], 45, 1, 0));
    assert r.error == "", r.error;
    assert r.lines[0].name == "Tomato (1kg)", r.lines[0].name;
    assert r.lines[0].quantity == 2.0, str(r.lines[0].quantity);
}