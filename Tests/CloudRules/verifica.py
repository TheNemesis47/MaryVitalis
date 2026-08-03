#!/usr/bin/env python3
"""Verifica end-to-end di regole e modello dati contro il vero progetto Firebase.

Crea tre utenti di prova, esegue il giro completo trainer↔cliente, e li cancella.
Non tocca dati esistenti: usa solo indirizzi @mv-test.invalid.
"""
import json
import plistlib
import sys
import urllib.error
import urllib.request

import os
PLIST = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "MaryVitalis", "GoogleService-Info.plist")
with open(PLIST, "rb") as f:
    cfg = plistlib.load(f)
KEY = cfg["API_KEY"]
PROJECT = cfg["PROJECT_ID"]

AUTH = "https://identitytoolkit.googleapis.com/v1/accounts"
FS = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"

passed = failed = 0


def check(name, ok):
    global passed, failed
    if ok:
        passed += 1
        print(f"  OK   {name}")
    else:
        failed += 1
        print(f"  FAIL {name}")


def post(url, body, token=None):
    data = json.dumps(body).encode()
    req = urllib.request.Request(url, data=data, method="POST")
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    with urllib.request.urlopen(req) as r:
        return json.load(r)


def fs(method, path, token, body=None):
    """Ritorna (status, json). 403 = negato dalle regole, ed è spesso il risultato atteso."""
    url = f"{FS}/{path}"
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req) as r:
            return r.status, json.load(r)
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"{}")


def s(v):
    return {"stringValue": v}


def signup(email, password):
    r = post(f"{AUTH}:signUp?key={KEY}",
             {"email": email, "password": password, "returnSecureToken": True})
    return r["localId"], r["idToken"]


def delete_user(token):
    try:
        post(f"{AUTH}:delete?key={KEY}", {"idToken": token})
    except Exception:
        pass


print(f"progetto: {PROJECT}\n")

trainer_id = client_id = other_id = None
trainer_tok = client_tok = other_tok = None
# Codice diverso a ogni giro: un documento rimasto da una prova precedente
# non è più cancellabile da nessuno, ed è esattamente il comportamento voluto.
import random
ALPHABET = "23456789ABCDEFGHJKMNPQRSTUVWXYZ"
CODE = "".join(random.choice(ALPHABET) for _ in range(6))
CODE2 = "".join(random.choice(ALPHABET) for _ in range(6))

try:
    print("[creazione utenti di prova]")
    trainer_id, trainer_tok = signup("trainer@mv-test.invalid", "provaprova1")
    client_id, client_tok = signup("cliente@mv-test.invalid", "provaprova1")
    other_id, other_tok = signup("estraneo@mv-test.invalid", "provaprova1")
    check("tre utenti creati", all([trainer_id, client_id, other_id]))

    print("\n[profili]")
    st, _ = fs("PATCH", f"users/{trainer_id}", trainer_tok,
               {"fields": {"displayName": s("Coach"), "role": s("trainer"),
                           "accentHex": s("#f59e0b"), "symbolName": s("figure.strengthtraining.traditional"),
                           "inviteCode": s("AAAAAA")}})
    check("il trainer scrive il proprio profilo", st == 200)

    st, _ = fs("PATCH", f"users/{client_id}", client_tok,
               {"fields": {"displayName": s("Pasquale"), "role": s("member"),
                           "accentHex": s("#38bdf8"), "symbolName": s("person.crop.circle.fill"),
                           "inviteCode": s(CODE)}})
    check("il cliente scrive il proprio profilo", st == 200)

    st, _ = fs("PATCH", f"users/{client_id}", trainer_tok,
               {"fields": {"displayName": s("Manomesso")}})
    check("il trainer NON può scrivere il profilo del cliente", st == 403)

    st, _ = fs("GET", f"users/{client_id}", trainer_tok)
    check("senza legame il trainer NON legge il profilo del cliente", st == 403)

    print("\n[codice invito]")
    st, _ = fs("PATCH", f"inviteCodes/{CODE}", client_tok,
               {"fields": {"userId": s(client_id)}})
    check("il cliente pubblica il proprio codice", st == 200)

    st, body = fs("GET", f"inviteCodes/{CODE}", trainer_tok)
    found = body.get("fields", {}).get("userId", {}).get("stringValue")
    check("il trainer risolve il codice", st == 200 and found == client_id)

    st, _ = fs("PATCH", f"inviteCodes/{CODE}", other_tok,
               {"fields": {"userId": s(other_id)}})
    check("un estraneo NON puo dirottare il codice altrui", st == 403)

    st, _ = fs("DELETE", f"inviteCodes/{CODE}", other_tok)
    check("un estraneo NON puo liberare il codice altrui", st == 403)

    # Rigenerazione: si libera il vecchio e si prende il nuovo.
    st, _ = fs("PATCH", f"inviteCodes/{CODE2}", client_tok,
               {"fields": {"userId": s(client_id)}})
    check("il cliente puo prendere un codice nuovo", st == 200)
    st, _ = fs("DELETE", f"inviteCodes/{CODE2}", client_tok)
    check("il cliente puo liberare il proprio codice", st == 200)

    print("\n[richiesta di collegamento]")
    link = f"{trainer_id}_{client_id}"
    st, _ = fs("PATCH", f"trainerLinks/{link}", trainer_tok,
               {"fields": {"trainerId": s(trainer_id), "clientId": s(client_id),
                           "status": s("accepted")}})
    check("il trainer NON può auto-accettarsi", st == 403)

    st, _ = fs("PATCH", f"trainerLinks/{link}", trainer_tok,
               {"fields": {"trainerId": s(trainer_id), "clientId": s(client_id),
                           "status": s("pending")}})
    check("il trainer crea la richiesta in sospeso", st == 200)

    st, _ = fs("GET", f"users/{client_id}", trainer_tok)
    check("in sospeso il trainer ancora NON legge il profilo", st == 403)

    # Il verso opposto invece deve funzionare subito: chi riceve una richiesta
    # ha il diritto di sapere da chi arriva, altrimenti non puo decidere.
    st, body = fs("GET", f"users/{trainer_id}", client_tok)
    name = body.get("fields", {}).get("displayName", {}).get("stringValue")
    check("il cliente vede chi lo ha invitato", st == 200 and name == "Coach")

    st, _ = fs("GET", f"users/{trainer_id}", other_tok)
    check("un estraneo NON vede il profilo del trainer", st == 403)

    st, _ = fs("GET", f"trainerLinks/{link}", other_tok)
    check("un estraneo NON legge il legame altrui", st == 403)

    print("\n[consenso del cliente]")
    st, _ = fs("PATCH", f"trainerLinks/{link}", client_tok,
               {"fields": {"trainerId": s(trainer_id), "clientId": s(client_id),
                           "status": s("accepted")}})
    check("il cliente accetta", st == 200)

    st, body = fs("GET", f"users/{client_id}", trainer_tok)
    name = body.get("fields", {}).get("displayName", {}).get("stringValue")
    check("ora il trainer legge il profilo del cliente", st == 200 and name == "Pasquale")

    print("\n[la scheda scritta dal trainer]")
    routine = "11111111-2222-3333-4444-555555555555"
    item = {"mapValue": {"fields": {
        "id": s("bbbbbbbb-0000-0000-0000-000000000001"),
        "exerciseQuery": s("lever chest press"),
        "exerciseName": s("Chest press"),
        "sets": {"integerValue": "4"},
        "repsText": s("12"),
        "sortIndex": {"integerValue": "0"},
    }}}
    day = {"mapValue": {"fields": {
        "id": s("aaaaaaaa-0000-0000-0000-000000000001"),
        "name": s("Giorno 1"),
        "sortIndex": {"integerValue": "0"},
        "items": {"arrayValue": {"values": [item]}},
    }}}
    payload = {"fields": {
        "id": s(routine),
        "ownerId": s(client_id),
        "name": s("Scheda di Pasquale"),
        "emoji": s("\U0001F525"),
        "accentHex": s("#38bdf8"),
        "goal": s("Massa"),
        "summary": s("Scritta dal trainer"),
        "isTemplate": {"booleanValue": False},
        "sortIndex": {"integerValue": "0"},
        "updatedAt": {"timestampValue": "2026-08-02T14:00:00Z"},
        "days": {"arrayValue": {"values": [day]}},
    }}

    st, _ = fs("PATCH", f"routines/{routine}", trainer_tok, payload)
    check("il trainer scrive la scheda del cliente", st == 200)

    st, body = fs("GET", f"routines/{routine}", client_tok)
    got = body.get("fields", {}).get("name", {}).get("stringValue")
    check("il cliente la ritrova", st == 200 and got == "Scheda di Pasquale")

    days = body.get("fields", {}).get("days", {}).get("arrayValue", {}).get("values", [])
    items = days[0]["mapValue"]["fields"]["items"]["arrayValue"]["values"] if days else []
    check("giorni ed esercizi annidati arrivano interi", len(days) == 1 and len(items) == 1)

    st, _ = fs("GET", f"routines/{routine}", other_tok)
    check("un estraneo NON legge la scheda", st == 403)

    st, _ = fs("PATCH", f"routines/{routine}", other_tok,
               {"fields": {"ownerId": s(client_id), "name": s("Manomessa")}})
    check("un estraneo NON scrive la scheda", st == 403)

    st, _ = fs("DELETE", f"routines/{routine}", other_tok)
    check("un estraneo NON cancella la scheda", st == 403)

    # Il trainer sì: può già riscriverne il contenuto, vietargli la
    # cancellazione lasciava solo schede sbagliate che nessuno poteva togliere.
    st, _ = fs("DELETE", f"routines/{routine}", trainer_tok)
    check("il trainer può cancellare la scheda che ha scritto", st == 200)

    # Rimessa: serve alle prove che vengono dopo.
    st, _ = fs("PATCH", f"routines/{routine}", trainer_tok, payload)
    check("e può riscriverla", st == 200)

    print("\n[palestre condivise]")
    gym_private = "aaaa1111-0000-0000-0000-000000000001"
    gym_shared  = "bbbb2222-0000-0000-0000-000000000002"
    gym_code = "".join(random.choice(ALPHABET) for _ in range(6))

    equip = {"mapValue": {"fields": {
        "name": s("Leg press"), "category": s("Macchine isotoniche"),
        "gridRow": {"integerValue": "0"}, "gridColumn": {"integerValue": "1"},
        "uncertain": {"booleanValue": False}}}}

    def gym_payload(owner, shared, code, name):
        return {"fields": {
            "id": s(gym_shared if shared else gym_private),
            "ownerId": s(owner), "brand": s("FitActive"), "name": s(name),
            "city": s("Napoli"), "columns": {"integerValue": "4"},
            "isShared": {"booleanValue": shared}, "shareCode": s(code),
            "updatedAt": {"timestampValue": "2026-08-02T14:00:00Z"},
            "equipment": {"arrayValue": {"values": [equip]}}}}

    st, _ = fs("PATCH", f"gyms/{gym_private}", client_tok,
               gym_payload(client_id, False, "", "Sala privata"))
    check("il cliente crea una sede privata", st == 200)

    st, _ = fs("GET", f"gyms/{gym_private}", other_tok)
    check("un estraneo NON legge una sede privata", st == 403)

    st, _ = fs("PATCH", f"gyms/{gym_shared}", trainer_tok,
               gym_payload(trainer_id, True, gym_code, "Sala condivisa"))
    check("il trainer pubblica la propria sede", st == 200)

    st, _ = fs("PATCH", f"gymCodes/{gym_code}", trainer_tok,
               {"fields": {"gymId": s(gym_shared), "ownerId": s(trainer_id)}})
    check("il codice della sede viene registrato", st == 200)

    st, body = fs("GET", f"gymCodes/{gym_code}", other_tok)
    check("chiunque risolve il codice", st == 200
          and body.get("fields", {}).get("gymId", {}).get("stringValue") == gym_shared)

    st, body = fs("GET", f"gyms/{gym_shared}", other_tok)
    count = len(body.get("fields", {}).get("equipment", {}).get("arrayValue", {}).get("values", []))
    check("una sede pubblicata la legge chiunque", st == 200 and count == 1)

    st, _ = fs("PATCH", f"gyms/{gym_shared}", other_tok,
               gym_payload(trainer_id, True, gym_code, "Manomessa"))
    check("chi la importa NON puo modificare l'originale", st == 403)

    st, _ = fs("PATCH", f"gymCodes/{gym_code}", other_tok,
               {"fields": {"gymId": s(gym_private), "ownerId": s(other_id)}})
    check("un estraneo NON dirotta il codice della sede", st == 403)

    # Il trainer assegna una sede al cliente: la scrive nel profilo di lui.
    gym_assigned = "cccc3333-0000-0000-0000-000000000003"
    payload = gym_payload(client_id, False, "", "Assegnata dal trainer")
    payload["fields"]["id"] = s(gym_assigned)
    st, _ = fs("PATCH", f"gyms/{gym_assigned}", trainer_tok, payload)
    check("il trainer assegna una sede al cliente", st == 200)

    st, body = fs("GET", f"gyms/{gym_assigned}", client_tok)
    got = body.get("fields", {}).get("name", {}).get("stringValue")
    check("il cliente la ritrova", st == 200 and got == "Assegnata dal trainer")

    st, _ = fs("DELETE", f"gyms/{gym_assigned}", trainer_tok)
    check("il trainer NON puo cancellare la sede del cliente", st == 403)

    print("\n[storico]")
    session = "99999999-0000-0000-0000-000000000001"
    st, _ = fs("PATCH", f"sessions/{session}", client_tok,
               {"fields": {"ownerId": s(client_id), "routineId": s(routine),
                           "dateKey": s("2026-08-02"), "setsDone": {"integerValue": "12"}}})
    check("il cliente registra l'allenamento", st == 200)

    st, _ = fs("GET", f"sessions/{session}", trainer_tok)
    check("il trainer lo legge", st == 200)

    st, _ = fs("PATCH", f"sessions/{session}", trainer_tok,
               {"fields": {"ownerId": s(client_id), "setsDone": {"integerValue": "99"}}})
    check("il trainer NON può falsificarlo", st == 403)

    print("\n[revoca]")
    st, _ = fs("PATCH", f"trainerLinks/{link}", trainer_tok,
               {"fields": {"trainerId": s(trainer_id), "clientId": s(client_id),
                           "status": s("revoked")}})
    check("il trainer può revocare", st == 200)

    st, _ = fs("GET", f"routines/{routine}", trainer_tok)
    check("dopo la revoca il trainer NON legge più la scheda", st == 403)

    print("\n[ricollegarsi dopo una revoca]")
    # Il caso che non funzionava: il legame esiste già, quindi la richiesta non
    # è una create ma una update, e le regole la rifiutavano in silenzio.
    st, _ = fs("PATCH", f"trainerLinks/{link}", trainer_tok,
               {"fields": {"trainerId": s(trainer_id), "clientId": s(client_id),
                           "status": s("pending")}})
    check("il trainer può richiedere di nuovo", st == 200)

    # Rimandare una richiesta ancora in sospeso: capita quando il cliente non
    # l'ha vista o ha cambiato codice. Prima rispondeva 403.
    st, _ = fs("PATCH", f"trainerLinks/{link}", trainer_tok,
               {"fields": {"trainerId": s(trainer_id), "clientId": s(client_id),
                           "status": s("pending")}})
    check("il trainer può rimandare una richiesta in sospeso", st == 200)

    st, _ = fs("PATCH", f"trainerLinks/{link}", trainer_tok,
               {"fields": {"trainerId": s(trainer_id), "clientId": s(client_id),
                           "status": s("accepted")}})
    check("ma continua a NON potersi auto-accettare", st == 403)

    st, _ = fs("GET", f"routines/{routine}", trainer_tok)
    check("in sospeso NON rilegge la scheda", st == 403)

    st, _ = fs("PATCH", f"trainerLinks/{link}", client_tok,
               {"fields": {"trainerId": s(trainer_id), "clientId": s(client_id),
                           "status": s("accepted")}})
    check("il cliente riaccetta", st == 200)

    print("\n[pulizia]")
    for gid, tok in ((gym_private, client_tok), (gym_shared, trainer_tok),
                     (gym_assigned, client_tok)):
        fs("DELETE", f"gyms/{gid}", tok)
    fs("DELETE", f"gymCodes/{gym_code}", trainer_tok)
    fs("DELETE", f"routines/{routine}", client_tok)
    fs("DELETE", f"sessions/{session}", client_tok)
    fs("DELETE", f"trainerLinks/{link}", client_tok)
    fs("DELETE", f"inviteCodes/{CODE}", client_tok)
    fs("DELETE", f"users/{client_id}", client_tok)
    fs("DELETE", f"users/{trainer_id}", trainer_tok)
    print("  documenti di prova rimossi")

finally:
    for tok in (trainer_tok, client_tok, other_tok):
        if tok:
            delete_user(tok)
    print("  utenti di prova rimossi")

print(f"\n=== {passed} passati, {failed} falliti ===")
sys.exit(1 if failed else 0)
