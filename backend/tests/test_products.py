"""
Tests du module products (identification par code-barres Open Food Facts).

Les appels Gemini et Open Food Facts sont mockés.
"""

import json

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app import products

client = TestClient(app)

FAKE_IMG = "data:image/jpeg;base64,/9j/fake"

# Produit OFF type : Nutella
OFF_NUTELLA = {
    "product_name_fr": "Nutella",
    "brands": "Ferrero",
    "quantity": "400 g",
    "nutriscore_grade": "e",
    "allergens_tags": ["en:milk", "en:nuts", "en:soybeans"],
    "ingredients_text_fr": "Sucre, huile de palme, noisettes 13%, lait écrémé en poudre...",
}


def _mock_off(monkeypatch, product):
    async def fake(barcode):
        return product
    monkeypatch.setattr(products, "_fetch_off", fake)


def _mock_gemini(monkeypatch, response):
    async def fake(parts, timeout=30):
        return json.dumps(response) if isinstance(response, dict) else response
    monkeypatch.setattr(products, "_call_gemini", fake)


# ============================================================================
# /lookup : recherche directe par code-barres
# ============================================================================

def test_lookup_found_with_allergen_alert(monkeypatch):
    _mock_off(monkeypatch, OFF_NUTELLA)
    r = client.post("/api/products/lookup", json={
        "barcode": "3017620422003",
        "allergies": ["lait", "arachide"],
    })
    assert r.status_code == 200
    data = r.json()
    assert data["found"] is True
    assert data["name"] == "Nutella"
    assert data["brand"] == "Ferrero"
    assert data["nutriscore"] == "E"
    assert "lait" in data["allergens"]
    assert "fruits à coque" in data["allergens"]
    # L'allergie "lait" du profil doit déclencher l'alerte
    assert data["profile_allergen_alerts"] == ["lait"]
    assert "Attention" in data["voice_message"]
    assert "déconseillé" in data["voice_message"]


def test_lookup_found_no_profile_alert(monkeypatch):
    _mock_off(monkeypatch, OFF_NUTELLA)
    r = client.post("/api/products/lookup", json={
        "barcode": "3017620422003",
        "allergies": ["gluten"],
    })
    data = r.json()
    assert data["profile_allergen_alerts"] == []
    assert "Attention" not in data["voice_message"]
    assert "Contient" in data["voice_message"]


def test_lookup_not_found(monkeypatch):
    _mock_off(monkeypatch, None)
    r = client.post("/api/products/lookup", json={"barcode": "00000000"})
    data = r.json()
    assert data["found"] is False
    assert "introuvable" in data["voice_message"]


def test_lookup_invalid_barcode():
    r = client.post("/api/products/lookup", json={"barcode": "12"})
    assert r.status_code == 422


def test_lookup_strips_non_digits(monkeypatch):
    captured = {}

    async def fake(barcode):
        captured["barcode"] = barcode
        return OFF_NUTELLA
    monkeypatch.setattr(products, "_fetch_off", fake)

    r = client.post("/api/products/lookup", json={"barcode": "3017 6204 2200 3"})
    assert r.status_code == 200
    assert captured["barcode"] == "3017620422003"


# ============================================================================
# /identify : lecture du code-barres par Gemini puis lookup OFF
# ============================================================================

def test_identify_success(monkeypatch):
    _mock_gemini(monkeypatch, {"barcode": "3017620422003"})
    _mock_off(monkeypatch, OFF_NUTELLA)
    r = client.post("/api/products/identify", json={
        "image_b64": FAKE_IMG,
        "allergies": ["arachide"],
    })
    data = r.json()
    assert data["found"] is True
    assert data["barcode"] == "3017620422003"
    assert data["name"] == "Nutella"


def test_identify_no_barcode_readable(monkeypatch):
    _mock_gemini(monkeypatch, {"barcode": None})
    r = client.post("/api/products/identify", json={"image_b64": FAKE_IMG})
    data = r.json()
    assert data["found"] is False
    assert data["barcode"] is None
    assert "Rapprochez" in data["voice_message"]


def test_identify_barcode_unknown_product(monkeypatch):
    _mock_gemini(monkeypatch, {"barcode": "12345678"})
    _mock_off(monkeypatch, None)
    r = client.post("/api/products/identify", json={"image_b64": FAKE_IMG})
    data = r.json()
    assert data["found"] is False
    assert data["barcode"] == "12345678"
    assert "introuvable" in data["voice_message"]


def test_identify_gemini_returns_garbage(monkeypatch):
    _mock_gemini(monkeypatch, "désolé je ne vois pas de code-barres")
    r = client.post("/api/products/identify", json={"image_b64": FAKE_IMG})
    data = r.json()
    assert data["found"] is False


# ============================================================================
# Normalisation
# ============================================================================

def test_normalize_minimal_product():
    # Produit OFF avec presque aucun champ rempli : ne doit pas planter
    result = products._normalize_product("123", {}, [])
    assert result["name"] == "Produit sans nom"
    assert result["allergens"] == []
    assert result["voice_message"]


def test_normalize_unknown_allergen_tag():
    product = {"product_name": "Test", "allergens_tags": ["en:something-new"]}
    result = products._normalize_product("123", product, [])
    assert result["allergens"] == ["something-new"]
