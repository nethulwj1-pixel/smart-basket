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