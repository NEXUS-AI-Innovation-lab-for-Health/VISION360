"""
Tests du module checkout (assistance au passage en caisse).

Les appels Gemini/Groq sont mockés : on teste la logique de session,
le parsing des réponses LLM et la construction des messages vocaux.
"""

import json

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app import checkout

client = TestClient(app)

FAKE_IMG = "data:image/jpeg;base64,/9j/fake"


@pytest.fixture(autouse=True)
def clear_sessions():
    checkout._SESSIONS.clear()
    yield
    checkout._SESSIONS.clear()


def _mock_gemini(monkeypatch, response: dict | str):
    async def fake(parts, timeout=60):
        return json.dumps(response) if isinstance(response, dict) else response
    monkeypatch.setattr(checkout, "_call_gemini", fake)


def _mock_groq(monkeypatch, response: dict | str):
    async def fake(system_prompt, user_prompt, timeout=60):
        return json.dumps(response) if isinstance(response, dict) else response
    monkeypatch.setattr(checkout, "_call_groq", fake)


def _start() -> str:
    r = client.post("/api/checkout/start")
    assert r.status_code == 200
    return r.json()["session_id"]


# ============================================================================
# Session
# ============================================================================

def test_start_session():
    r = client.post("/api/checkout/start")
    assert r.status_code == 200
    data = r.json()
    assert data["session_id"]
    assert "voice_message" in data


def test_unknown_session_404():
    r = client.post(
        "/api/checkout/belt/scan",
        json={"session_id": "inexistant", "image_b64": FAKE_IMG},
    )
    assert r.status_code == 404


def test_end_session():
    sid = _start()
    r = client.delete(f"/api/checkout/session/{sid}")
    assert r.status_code == 200
    assert sid not in checkout._SESSIONS


# ============================================================================
# F1 : scan du tapis
# ============================================================================

def test_belt_scan_detects_items(monkeypatch):
    _mock_gemini(monkeypatch, {
        "empty": False,
        "items": [
            {"name": "yaourt nature", "quantity": 2, "confidence": "high"},
            {"name": "brique de lait", "quantity": 1, "confidence": "low"},
        ],
    })
    sid = _start()
    r = client.post("/api/checkout/belt/scan", json={"session_id": sid, "image_b64": FAKE_IMG})
    assert r.status_code == 200
    data = r.json()
    assert data["empty"] is False
    assert len(data["items"]) == 2
    # L'article incertain doit être signalé dans le message vocal
    assert "brique de lait" in data["voice_message"]
    assert "certitude" in data["voice_message"] or "Vérifiez" in data["voice_message"]
    # La liste de référence de la session est initialisée
    assert checkout._SESSIONS[sid]["belt_initial"]


def test_belt_scan_empty(monkeypatch):
    _mock_gemini(monkeypatch, {"empty": True, "items": []})
    sid = _start()
    r = client.post("/api/checkout/belt/scan", json={"session_id": sid, "image_b64": FAKE_IMG})
    assert r.status_code == 200
    data = r.json()
    assert data["empty"] is True
    assert "vide" in data["voice_message"].lower()


def test_belt_scan_handles_markdown_fences(monkeypatch):
    raw = '```json\n{"empty": false, "items": [{"name": "pain", "quantity": 1, "confidence": "high"}]}\n```'
    _mock_gemini(monkeypatch, raw)
    sid = _start()
    r = client.post("/api/checkout/belt/scan", json={"session_id": sid, "image_b64": FAKE_IMG})
    assert r.status_code == 200
    assert r.json()["items"][0]["name"] == "pain"


# ============================================================================
# F2 : transfert tapis -> caddie
# ============================================================================

def test_transfer_requires_initial_scan(monkeypatch):
    sid = _start()
    r = client.post("/api/checkout/belt/transfer", json={"session_id": sid, "image_b64": FAKE_IMG})
    assert r.status_code == 409


def test_transfer_updates_cart(monkeypatch):
    _mock_gemini(monkeypatch, {
        "empty": False,
        "items": [{"name": "pain", "quantity": 1, "confidence": "high"}],
    })
    _mock_groq(monkeypatch, {
        "transferred": [{"name": "yaourt nature", "quantity": 2}],
        "still_on_belt": [{"name": "pain", "quantity": 1}],
        "uncertain": [],
    })
    sid = _start()
    # Scan initial avec yaourts + pain
    checkout._SESSIONS[sid]["belt_initial"] = [
        {"name": "yaourt nature", "quantity": 2},
        {"name": "pain", "quantity": 1},
    ]
    checkout._SESSIONS[sid]["belt_current"] = checkout._SESSIONS[sid]["belt_initial"]

    r = client.post("/api/checkout/belt/transfer", json={"session_id": sid, "image_b64": FAKE_IMG})
    assert r.status_code == 200
    data = r.json()
    assert data["transferred"][0]["name"] == "yaourt nature"
    assert data["belt_empty"] is False
    assert checkout._SESSIONS[sid]["cart_items"][0]["name"] == "yaourt nature"
    assert "yaourt" in data["voice_message"]


def test_transfer_uncertain_alert(monkeypatch):
    _mock_gemini(monkeypatch, {"empty": True, "items": []})
    _mock_groq(monkeypatch, {
        "transferred": [],
        "still_on_belt": [],
        "uncertain": ["paquet de chips"],
    })
    sid = _start()
    checkout._SESSIONS[sid]["belt_initial"] = [{"name": "paquet de chips", "quantity": 1}]
    checkout._SESSIONS[sid]["belt_current"] = checkout._SESSIONS[sid]["belt_initial"]

    r = client.post("/api/checkout/belt/transfer", json={"session_id": sid, "image_b64": FAKE_IMG})
    data = r.json()
    assert data["belt_empty"] is True
    assert "peut-être quitté le tapis" in data["voice_message"]


# ============================================================================
# F3 : détection des oublis
# ============================================================================

def test_forgotten_alert(monkeypatch):
    _mock_groq(monkeypatch, {
        "forgotten": [{"name": "yaourt nature", "quantity": 2}],
        "doubtful": [],
        "all_transferred": False,
        "voice_message": "Attention, il semble que les deux yaourts n'aient pas été transférés dans votre caddie.",
    })
    sid = _start()
    checkout._SESSIONS[sid]["belt_initial"] = [{"name": "yaourt nature", "quantity": 2}]

    r = client.post("/api/checkout/forgotten", json={"session_id": sid})
    assert r.status_code == 200
    data = r.json()
    assert data["all_transferred"] is False
    assert data["forgotten"][0]["name"] == "yaourt nature"
    assert "yaourts" in data["voice_message"]


def test_forgotten_with_cart_photo(monkeypatch):
    _mock_gemini(monkeypatch, "yaourt nature\npain")
    _mock_groq(monkeypatch, {
        "forgotten": [],
        "doubtful": [],
        "all_transferred": True,
        "voice_message": "Tous les articles sont dans votre caddie.",
    })
    sid = _start()
    checkout._SESSIONS[sid]["belt_initial"] = [{"name": "yaourt nature", "quantity": 2}]

    r = client.post(
        "/api/checkout/forgotten",
        json={"session_id": sid, "cart_image_b64": FAKE_IMG},
    )
    data = r.json()
    assert data["all_transferred"] is True
    assert data["cart_scan_used"] is True


def test_forgotten_requires_initial_scan():
    sid = _start()
    r = client.post("/api/checkout/forgotten", json={"session_id": sid})
    assert r.status_code == 409


# ============================================================================
# F4 : scan du ticket
# ============================================================================

def test_ticket_scan(monkeypatch):
    _mock_gemini(monkeypatch, {
        "readable": True,
        "items": [
            {"name": "YAOURT NAT X2", "quantity": 2, "unit_price": 1.5, "line_total": 3.0},
            {"name": "PAIN COMPLET", "quantity": 1, "unit_price": 2.1, "line_total": 2.1},
        ],
        "total": 5.1,
        "currency": "EUR",
    })
    sid = _start()
    r = client.post("/api/checkout/ticket/scan", json={"session_id": sid, "image_b64": FAKE_IMG})
    assert r.status_code == 200
    data = r.json()
    assert data["readable"] is True
    assert data["total"] == 5.1
    assert "3 article" in data["voice_message"]
    assert "5.1" in data["voice_message"]
    assert checkout._SESSIONS[sid]["ticket"]["total"] == 5.1


def test_ticket_unreadable(monkeypatch):
    _mock_gemini(monkeypatch, {"readable": False, "items": [], "total": 0, "currency": "EUR"})
    sid = _start()
    r = client.post("/api/checkout/ticket/scan", json={"session_id": sid, "image_b64": FAKE_IMG})
    data = r.json()
    assert data["readable"] is False
    assert "n'a pas pu être lu" in data["voice_message"]


# ============================================================================
# F5 : rapprochement ticket / caddie
# ============================================================================

def test_reconcile_requires_ticket():
    sid = _start()
    r = client.post("/api/checkout/reconcile", json={"session_id": sid})
    assert r.status_code == 409


def test_reconcile_match(monkeypatch):
    _mock_groq(monkeypatch, {
        "match": True,
        "billed_not_in_cart": [],
        "in_cart_not_billed": [],
        "voice_message": "Tout correspond, les 3 articles facturés sont bien dans votre caddie.",
    })
    sid = _start()
    checkout._SESSIONS[sid]["ticket"] = {
        "items": [{"name": "YAOURT NAT X2", "quantity": 2}],
        "total": 3.0,
        "currency": "EUR",
    }
    checkout._SESSIONS[sid]["cart_items"] = [{"name": "yaourt nature", "quantity": 2}]

    r = client.post("/api/checkout/reconcile", json={"session_id": sid})
    assert r.status_code == 200
    data = r.json()
    assert data["match"] is True
    assert "correspond" in data["voice_message"]


def test_reconcile_mismatch(monkeypatch):
    _mock_groq(monkeypatch, {
        "match": False,
        "billed_not_in_cart": [{"name": "brique de lait", "quantity": 1}],
        "in_cart_not_billed": [],
        "voice_message": "Un article facturé ne semble pas être dans votre caddie : 1 brique de lait.",
    })
    sid = _start()
    checkout._SESSIONS[sid]["ticket"] = {
        "items": [{"name": "LAIT 1L", "quantity": 1}],
        "total": 1.2,
        "currency": "EUR",
    }
    checkout._SESSIONS[sid]["cart_items"] = [{"name": "pain", "quantity": 1}]

    r = client.post("/api/checkout/reconcile", json={"session_id": sid})
    data = r.json()
    assert data["match"] is False
    assert data["billed_not_in_cart"][0]["name"] == "brique de lait"


# ============================================================================
# Helpers
# ============================================================================

def test_belt_scan_tolerates_malformed_quantities(monkeypatch):
    # Le LLM peut renvoyer des quantités en string, float ou null :
    # l'endpoint ne doit jamais renvoyer une erreur 500 pour autant.
    _mock_gemini(monkeypatch, {
        "empty": False,
        "items": [
            {"name": "yaourt", "quantity": "2", "confidence": "high"},
            {"name": "pain", "quantity": None, "confidence": "high"},
            {"name": "lait", "quantity": 1.0, "confidence": "low"},
        ],
    })
    sid = _start()
    r = client.post("/api/checkout/belt/scan", json={"session_id": sid, "image_b64": FAKE_IMG})
    assert r.status_code == 200
    assert "yaourt" in r.json()["voice_message"]


def test_ticket_scan_tolerates_null_currency_and_total(monkeypatch):
    _mock_gemini(monkeypatch, {
        "readable": True,
        "items": [{"name": "PAIN", "quantity": "1", "unit_price": 2.1, "line_total": 2.1}],
        "total": None,
        "currency": None,
    })
    sid = _start()
    r = client.post("/api/checkout/ticket/scan", json={"session_id": sid, "image_b64": FAKE_IMG})
    assert r.status_code == 200
    assert r.json()["readable"] is True


def test_qty_helper():
    assert checkout._qty(2) == 2
    assert checkout._qty("2") == 2
    assert checkout._qty(2.7) == 2
    assert checkout._qty(None) == 1
    assert checkout._qty("abc") == 1
    assert checkout._qty(-3) == 1


def test_extract_json_variants():
    assert checkout._extract_json('{"a": 1}') == {"a": 1}
    assert checkout._extract_json('```json\n{"a": 1}\n```') == {"a": 1}
    assert checkout._extract_json('Voici le résultat : {"a": {"b": 2}} merci') == {"a": {"b": 2}}
    assert checkout._extract_json("pas de json ici") is None


def test_spoken_list():
    assert checkout._spoken_list([{"name": "pain", "quantity": 1}]) == "pain"
    assert (
        checkout._spoken_list([
            {"name": "pain", "quantity": 1},
            {"name": "yaourt", "quantity": 2},
        ])
        == "pain et 2 yaourt"
    )
