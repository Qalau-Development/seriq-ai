import copy
import json
import uuid
from datetime import timedelta
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select

from app.db.base import utc_now
from app.db.engine import make_engine, make_session_factory
from app.db.models import AttemptRow, RefreshToken, SessionRow, User
from app.main import create_app
from app.schemas.history import ProgressSummary, SessionList, SessionOut
from app.services import history
from tests.test_accounts import PASSWORD, assert_error, bearer, register

EXAMPLES = Path(__file__).resolve().parents[2] / "docs" / "api-examples"
MEASURES = {"E01": ("lift_height", "hand_lengths"), "E02": ("elbow_angle", "deg"), "E03": ("wrist_lift", "deg"), "E04": ("hand_openness", "percent")}


# client — клиент в режиме mock с включённой базой
@pytest.fixture
def client(accounts_env):
    return TestClient(create_app(), raise_server_exceptions=False)


# db — сессия к той же базе для проверки содержимого таблиц
@pytest.fixture
def db(accounts_env):
    engine = make_engine(accounts_env)
    with make_session_factory(engine)() as session:
        yield session
    engine.dispose()


# user — зарегистрированный пользователь: заголовок авторизации и ответ регистрации
@pytest.fixture
def user(client):
    response = register(client, "anna_k")
    return {**bearer(response), "id": response.json()["user"]["id"]}


# other — второй зарегистрированный пользователь
@pytest.fixture
def other(client):
    response = register(client, "boris_m")
    return {**bearer(response), "id": response.json()["user"]["id"]}


# attempt — попытка для тела PUT; без аргументов это E02 с измерением
def attempt(exercise="E02", label="complete", value=150.0, at="2026-11-25T08:42:10Z", analysis_id=None, series=None, with_measure=True):
    name, unit = MEASURES[exercise]
    body = {
        "analysis_id": analysis_id or str(uuid.uuid4()), "at": at, "source": "model", "model_version": "test-1",
        "verdict": "completed" if label == "complete" else "check_instructions", "label": label, "confidence": 0.8,
    }
    if with_measure:
        body["measure"] = {"name": name, "unit": unit, "value": value, "series": {"fps": 10, "values": series if series is not None else [1.0, None, value]}}
    return body


# session_body — тело PUT занятия
def session_body(attempts, exercise="E02", started_at="2026-11-25T08:41:03Z"):
    return {"exercise": exercise, "started_at": started_at, "attempts": attempts}


# put — PUT занятия от имени пользователя
def put(client, auth, session_id, body):
    return client.put(f"/api/v1/sessions/{session_id}", json=body, headers={"Authorization": auth["Authorization"]})


# new_id — новый UUID строкой
def new_id():
    return str(uuid.uuid4())


# test_put_creates_and_returns_session — первый PUT создаёт занятие и возвращает его как сохранено, попытки по времени
def test_put_creates_and_returns_session(client, user):
    sid = new_id()
    late, early = attempt(at="2026-11-25T09:00:00Z"), attempt(at="2026-11-25T08:00:00+00:00")
    response = put(client, user, sid, session_body([late, early]))
    assert response.status_code == 200
    body = response.json()
    SessionOut.model_validate(body)
    assert body["id"] == sid and body["exercise"] == "E02" and body["started_at"] == "2026-11-25T08:41:03Z"
    assert [a["analysis_id"] for a in body["attempts"]] == [early["analysis_id"], late["analysis_id"]]
    assert body["attempts"][0]["measure"]["series"] == {"fps": 10.0, "values": [1.0, None, 150.0]}


# test_put_offset_time_is_stored_utc — время со смещением хранится и отдаётся в UTC
def test_put_offset_time_is_stored_utc(client, user):
    body = put(client, user, new_id(), session_body([attempt(at="2026-11-25T13:42:10+05:00")], started_at="2026-11-25T13:41:03+05:00")).json()
    assert body["started_at"] == "2026-11-25T08:41:03Z" and body["attempts"][0]["at"] == "2026-11-25T08:42:10Z"


# test_put_is_idempotent — повтор тех же данных не создаёт дублей и не меняет ответ
def test_put_is_idempotent(client, user, db):
    sid, data = new_id(), session_body([attempt(), attempt(label="incomplete")])
    first = put(client, user, sid, data).json()
    second = put(client, user, sid, data).json()
    assert first == second
    assert db.scalar(select(func.count()).select_from(SessionRow)) == 1
    assert db.scalar(select(func.count()).select_from(AttemptRow)) == 2


# test_put_adds_new_attempts_and_keeps_saved — новые попытки добавляются, сохранённые не меняются, exercise и started_at тоже
def test_put_adds_new_attempts_and_keeps_saved(client, user):
    sid, first = new_id(), attempt(label="complete", value=150.0)
    put(client, user, sid, session_body([first]))
    changed = copy.deepcopy(first)
    changed.update(label="incomplete", confidence=0.1, verdict="check_instructions")
    changed["measure"]["value"] = 5.0
    new = attempt(at="2026-11-25T09:30:00Z")
    body = put(client, user, sid, session_body([changed, new], started_at="2030-01-01T00:00:00Z")).json()
    assert [a["analysis_id"] for a in body["attempts"]] == [first["analysis_id"], new["analysis_id"]]
    assert body["attempts"][0]["label"] == "complete" and body["attempts"][0]["measure"]["value"] == 150.0
    assert body["started_at"] == "2026-11-25T08:41:03Z"


# test_put_duplicate_in_one_request — одинаковый analysis_id дважды в теле сохраняется один раз
def test_put_duplicate_in_one_request(client, user):
    a = attempt()
    assert len(put(client, user, new_id(), session_body([a, a])).json()["attempts"]) == 1


# test_put_other_exercise_for_existing_session — другое упражнение для существующего занятия: invalid_request
def test_put_other_exercise_for_existing_session(client, user):
    sid = new_id()
    put(client, user, sid, session_body([attempt()]))
    assert_error(put(client, user, sid, session_body([attempt("E04")], exercise="E04")), 400, "invalid_request")


# test_users_do_not_see_each_other — два пользователя не видят данные друг друга ни в списке, ни по id, ни в сводке
def test_users_do_not_see_each_other(client, user, other):
    sid = new_id()
    put(client, user, sid, session_body([attempt()]))
    assert client.get("/api/v1/sessions", headers={"Authorization": other["Authorization"]}).json() == {"items": [], "next_cursor": None}
    assert_error(client.get(f"/api/v1/sessions/{sid}", headers={"Authorization": other["Authorization"]}), 404, "not_found")
    assert_error(client.delete(f"/api/v1/sessions/{sid}", headers={"Authorization": other["Authorization"]}), 404, "not_found")
    assert client.get("/api/v1/progress/summary", headers={"Authorization": other["Authorization"]}).json()["repetitions"] == 0
    assert client.get(f"/api/v1/sessions/{sid}", headers={"Authorization": user["Authorization"]}).status_code == 200


# test_foreign_ids_conflict — чужой session_id и чужой analysis_id дают id_conflict и ничего не сохраняют
def test_foreign_ids_conflict(client, user, other, db):
    sid, mine = new_id(), attempt()
    put(client, user, sid, session_body([mine]))
    assert_error(put(client, other, sid, session_body([attempt()])), 409, "id_conflict")
    own_session = new_id()
    stolen = put(client, other, own_session, session_body([attempt(at="2026-11-25T10:00:00Z"), copy.deepcopy(mine)]))
    assert_error(stolen, 409, "id_conflict")
    assert db.scalar(select(func.count()).select_from(SessionRow).where(SessionRow.id == own_session)) == 0
    assert db.scalar(select(func.count()).select_from(AttemptRow)) == 1


# test_analysis_id_in_other_session_conflicts — свой analysis_id, уже сохранённый в другом занятии, тоже id_conflict
def test_analysis_id_in_other_session_conflicts(client, user):
    a = attempt()
    put(client, user, new_id(), session_body([a]))
    assert_error(put(client, user, new_id(), session_body([copy.deepcopy(a)])), 409, "id_conflict")


# test_put_is_atomic — ошибка в одной попытке отменяет всё из этого запроса
def test_put_is_atomic(client, user, db):
    sid = new_id()
    put(client, user, sid, session_body([attempt()]))
    bad = attempt(at="2026-11-25T11:00:00Z")
    bad["measure"]["name"] = "wrong_name"
    assert_error(put(client, user, sid, session_body([attempt(at="2026-11-25T10:00:00Z"), bad])), 400, "invalid_request")
    assert db.scalar(select(func.count()).select_from(AttemptRow)) == 1


# bad_variants — тела, которые должны давать invalid_request
def bad_variants():
    base = session_body([attempt()])
    variants = {}
    for key, value in {
        "exercise": "E05", "started_at": "2026-11-25T08:41:03", "attempts": [],
    }.items():
        variants[f"top {key}"] = {**base, key: value}
    for key, value in {
        "label": "great", "verdict": "ok", "source": "other", "confidence": 1.5, "at": "yesterday", "analysis_id": "not-a-uuid",
        "model_version": "v" * 65,
    }.items():
        variants[f"attempt {key}"] = session_body([{**attempt(), key: value}])
    variants["attempt negative confidence"] = session_body([{**attempt(), "confidence": -0.1}])
    variants["attempt naive at"] = session_body([{**attempt(), "at": "2026-11-25T08:42:10"}])
    for key, value in {"name": "elbow_angle", "unit": "deg"}.items():
        one = attempt("E04")
        one["measure"][key] = value
        variants[f"E04 measure {key}"] = session_body([one], exercise="E04")
    one = attempt()
    one["measure"]["series"]["fps"] = 0
    variants["fps zero"] = session_body([one])
    one = attempt()
    one["measure"]["series"]["values"] = ["x"]
    variants["series text"] = session_body([one])
    return variants


# test_put_validation — неверные значения дают 400 invalid_request, ничего не сохраняется
@pytest.mark.parametrize("name", list(bad_variants()))
def test_put_validation(client, user, db, name):
    assert_error(put(client, user, new_id(), bad_variants()[name]), 400, "invalid_request")
    assert db.scalar(select(func.count()).select_from(SessionRow)) == 0


# test_put_bad_session_id — session_id в пути не UUID: invalid_request
def test_put_bad_session_id(client, user):
    assert_error(put(client, user, "not-a-uuid", session_body([attempt()])), 400, "invalid_request")
    assert_error(client.get("/api/v1/sessions/not-a-uuid", headers={"Authorization": user["Authorization"]}), 400, "invalid_request")


# test_put_limits — до 200 попыток и до 1000 значений в ряду; больше: 413 payload_too_large
def test_put_limits(client, user, db):
    ok = session_body([attempt(analysis_id=new_id(), series=[1.0] * 1000, with_measure=True) for _ in range(200)])
    assert put(client, user, new_id(), ok).status_code == 200
    assert_error(put(client, user, new_id(), session_body([attempt() for _ in range(201)])), 413, "payload_too_large")
    assert_error(put(client, user, new_id(), session_body([attempt(series=[1.0] * 1001)])), 413, "payload_too_large")
    assert db.scalar(select(func.count()).select_from(SessionRow)) == 1


# test_put_body_too_large — тело больше 4 МиБ: 413
def test_put_body_too_large(client, user):
    body = session_body([attempt()])
    body["attempts"][0]["measure"]["unit"] = "x" * (5 * 1024 * 1024)
    assert_error(put(client, user, new_id(), body), 413, "payload_too_large")


# test_history_needs_token — без токена все маршруты истории дают 401
def test_history_needs_token(client):
    sid = new_id()
    for method, path in (("PUT", f"/api/v1/sessions/{sid}"), ("GET", "/api/v1/sessions"), ("GET", f"/api/v1/sessions/{sid}"), ("DELETE", f"/api/v1/sessions/{sid}"), ("DELETE", "/api/v1/sessions"), ("GET", "/api/v1/progress/summary")):
        kwargs = {"json": session_body([attempt()])} if method == "PUT" else {}
        assert_error(client.request(method, path, **kwargs), 401, "invalid_token")


# test_list_order_and_pages — новые первыми, страницы по курсору, фильтр по упражнению, сводка по меткам
def test_list_order_and_pages(client, user):
    ids = []
    for i in range(5):
        sid = new_id()
        ids.append(sid)
        labels = ["complete", "incomplete", "uncertain"][: (i % 3) + 1]
        put(client, user, sid, session_body([attempt(label=label, at=f"2026-11-2{i}T08:00:0{n}Z") for n, label in enumerate(labels)], started_at=f"2026-11-2{i}T07:00:00Z"))
    put(client, user, new_id(), session_body([attempt("E04", value=60.0)], exercise="E04", started_at="2026-11-24T12:00:00Z"))
    headers = {"Authorization": user["Authorization"]}
    page1 = client.get("/api/v1/sessions?exercise=E02&limit=2", headers=headers).json()
    SessionList.model_validate(page1)
    assert [i["id"] for i in page1["items"]] == [ids[4], ids[3]] and page1["next_cursor"]
    assert page1["items"][0]["summary"] == {"total": 2, "complete": 1, "incomplete": 1, "uncertain": 0}
    assert "attempts" not in page1["items"][0]
    page2 = client.get(f"/api/v1/sessions?exercise=E02&limit=2&cursor={page1['next_cursor']}", headers=headers).json()
    assert [i["id"] for i in page2["items"]] == [ids[2], ids[1]]
    page3 = client.get(f"/api/v1/sessions?exercise=E02&limit=2&cursor={page2['next_cursor']}", headers=headers).json()
    assert [i["id"] for i in page3["items"]] == [ids[0]] and page3["next_cursor"] is None
    everything = client.get("/api/v1/sessions", headers=headers).json()
    assert len(everything["items"]) == 6 and everything["items"][0]["exercise"] == "E04"
    assert [i["exercise"] for i in client.get("/api/v1/sessions?exercise=E04", headers=headers).json()["items"]] == ["E04"]


# test_list_bad_params — неверные limit, cursor и exercise: invalid_request
@pytest.mark.parametrize("query", ["limit=0", "limit=101", "limit=x", "cursor=%%%", "cursor=YWJj", "exercise=E05"])
def test_list_bad_params(client, user, query):
    assert_error(client.get(f"/api/v1/sessions?{query}", headers={"Authorization": user["Authorization"]}), 400, "invalid_request")


# test_get_session_detail — занятие целиком с рядами
def test_get_session_detail(client, user):
    sid = new_id()
    saved = put(client, user, sid, session_body([attempt()])).json()
    assert client.get(f"/api/v1/sessions/{sid.upper()}", headers={"Authorization": user["Authorization"]}).json() == saved
    assert_error(client.get(f"/api/v1/sessions/{new_id()}", headers={"Authorization": user["Authorization"]}), 404, "not_found")


# test_delete_session_and_reuse_ids — удаление занятия стирает попытки, и те же id можно сохранить заново
def test_delete_session_and_reuse_ids(client, user, db):
    sid, a = new_id(), attempt()
    other_sid = new_id()
    put(client, user, sid, session_body([a]))
    put(client, user, other_sid, session_body([attempt()]))
    headers = {"Authorization": user["Authorization"]}
    assert client.delete(f"/api/v1/sessions/{sid}", headers=headers).status_code == 204
    assert_error(client.delete(f"/api/v1/sessions/{sid}", headers=headers), 404, "not_found")
    assert_error(client.get(f"/api/v1/sessions/{sid}", headers=headers), 404, "not_found")
    assert db.scalar(select(func.count()).select_from(AttemptRow)) == 1
    assert put(client, user, new_id(), session_body([copy.deepcopy(a)])).status_code == 200


# test_delete_all_sessions — удаляет всю историю пользователя, историю другого не трогает, аккаунт остаётся
def test_delete_all_sessions(client, user, other, db):
    for _ in range(3):
        put(client, user, new_id(), session_body([attempt()]))
    put(client, other, new_id(), session_body([attempt()]))
    assert client.delete("/api/v1/sessions", headers={"Authorization": user["Authorization"]}).status_code == 204
    assert client.delete("/api/v1/sessions", headers={"Authorization": user["Authorization"]}).status_code == 204
    assert client.get("/api/v1/sessions", headers={"Authorization": user["Authorization"]}).json()["items"] == []
    assert len(client.get("/api/v1/sessions", headers={"Authorization": other["Authorization"]}).json()["items"]) == 1
    assert client.get("/api/v1/me", headers={"Authorization": user["Authorization"]}).status_code == 200
    assert db.scalar(select(func.count()).select_from(AttemptRow)) == 1


# test_account_deletion_erases_history — удаление аккаунта стирает занятия и попытки, у другого пользователя всё остаётся
def test_account_deletion_erases_history(client, user, other, db):
    put(client, user, new_id(), session_body([attempt(), attempt()]))
    keep = new_id()
    put(client, other, keep, session_body([attempt()]))
    response = client.request("DELETE", "/api/v1/me", json={"password": PASSWORD}, headers={"Authorization": user["Authorization"]})
    assert response.status_code == 204
    db.expire_all()
    assert [s.id for s in db.scalars(select(SessionRow))] == [keep]
    assert db.scalar(select(func.count()).select_from(AttemptRow)) == 1
    assert db.scalar(select(func.count()).select_from(User)) == 1
    assert db.scalar(select(func.count()).select_from(RefreshToken).where(RefreshToken.user_id == user["id"])) == 0


# test_progress_summary — счётчики, доли, активность по дням со смещением и ряд значений
def test_progress_summary(client, user):
    now = utc_now().replace(microsecond=0)
    day = lambda d, h: (now - timedelta(days=d)).replace(hour=h, minute=0, second=0).strftime("%Y-%m-%dT%H:%M:%SZ")  # noqa: E731
    put(client, user, new_id(), session_body([attempt(label="complete", value=150.0, at=day(2, 10)), attempt(label="incomplete", value=100.0, at=day(2, 11))], started_at=day(2, 9)))
    put(client, user, new_id(), session_body([attempt(label="uncertain", value=120.0, at=day(0, 12))], started_at=day(0, 11)))
    put(client, user, new_id(), session_body([attempt("E04", label="complete", value=70.0, at=day(1, 12), with_measure=True)], exercise="E04", started_at=day(1, 11)))
    headers = {"Authorization": user["Authorization"]}
    summary = client.get("/api/v1/progress/summary?exercise=E02", headers=headers).json()
    ProgressSummary.model_validate(summary)
    assert summary["exercise"] == "E02" and summary["sessions"] == 2 and summary["repetitions"] == 3
    assert summary["labels"] == {"complete": 1, "incomplete": 1, "uncertain": 1}
    assert summary["shares"] == {"complete": 0.3333, "incomplete": 0.3333, "uncertain": 0.3333}
    assert [(a["sessions"], a["repetitions"]) for a in summary["activity"]] == [(1, 2), (1, 1)]
    assert summary["measure"] == {"name": "elbow_angle", "unit": "deg"}
    assert [(p["value"], p["label"]) for p in summary["points"]] == [(150.0, "complete"), (100.0, "incomplete"), (120.0, "uncertain")]
    everything = client.get("/api/v1/progress/summary", headers=headers).json()
    assert everything["exercise"] is None and everything["sessions"] == 3 and everything["repetitions"] == 4
    assert everything["measure"] is None and everything["points"] is None
    shifted = client.get("/api/v1/progress/summary?exercise=E02&utc_offset_minutes=840", headers=headers).json()
    assert shifted["activity"][-1]["date"] != summary["activity"][-1]["date"]
    assert_error(client.get("/api/v1/progress/summary?utc_offset_minutes=900", headers=headers), 400, "invalid_request")


# test_progress_empty — без данных нули и shares null
def test_progress_empty(client, user):
    body = client.get("/api/v1/progress/summary?exercise=E01", headers={"Authorization": user["Authorization"]}).json()
    assert body == {
        "exercise": "E01", "sessions": 0, "repetitions": 0, "labels": {"complete": 0, "incomplete": 0, "uncertain": 0},
        "shares": None, "activity": [], "measure": {"name": "lift_height", "unit": "hand_lengths"}, "points": [],
    }


# test_progress_limits — активность за последние 90 дней и не больше 100 точек
def test_progress_limits(client, user):
    now = utc_now().replace(microsecond=0)
    old = (now - timedelta(days=120)).strftime("%Y-%m-%dT%H:%M:%SZ")
    attempts = [attempt(at=(now - timedelta(minutes=i)).strftime("%Y-%m-%dT%H:%M:%SZ"), value=float(i)) for i in range(120)]
    put(client, user, new_id(), session_body(attempts + [attempt(at=old)], started_at=old))
    body = client.get("/api/v1/progress/summary?exercise=E02", headers={"Authorization": user["Authorization"]}).json()
    assert body["repetitions"] == 121 and len(body["points"]) == 100
    assert sum(a["repetitions"] for a in body["activity"]) == 120


# test_examples_in_docs — примеры из docs/api-examples принимаются и соответствуют ответам
def test_examples_in_docs(client, user):
    request = json.loads((EXAMPLES / "session-put-request.json").read_text())
    expected = json.loads((EXAMPLES / "session.json").read_text())
    response = put(client, user, expected["id"], request)
    assert response.status_code == 200
    actual = response.json()
    for body in (actual, expected):
        body.pop("created_at")
    assert actual == expected
    SessionList.model_validate(json.loads((EXAMPLES / "sessions-list.json").read_text()))
    ProgressSummary.model_validate(json.loads((EXAMPLES / "progress-summary.json").read_text()))
    assert history.MAX_ATTEMPTS == 200 and history.MAX_VALUES == 1000


# test_quota_sessions — на аккаунт не больше MAX_USER_SESSIONS занятий; повтор сохранённого занятия квоту не тратит, удаление освобождает
def test_quota_sessions(client, user, monkeypatch, db):
    monkeypatch.setattr(history, "MAX_USER_SESSIONS", 3)
    sessions = [new_id() for _ in range(3)]
    bodies = [session_body([attempt()]) for _ in sessions]
    for sid, body in zip(sessions, bodies):
        assert put(client, user, sid, body).status_code == 200
    for sid, body in zip(sessions, bodies):
        assert put(client, user, sid, body).status_code == 200
    rejected = put(client, user, new_id(), session_body([attempt()]))
    assert_error(rejected, 413, "quota_exceeded")
    assert db.scalar(select(func.count()).select_from(SessionRow)) == 3
    assert client.delete(f"/api/v1/sessions/{sessions[0]}", headers={"Authorization": user["Authorization"]}).status_code == 204
    assert put(client, user, new_id(), session_body([attempt()])).status_code == 200


# test_quota_attempts — на аккаунт не больше MAX_USER_ATTEMPTS попыток; новые попытки в сохранённом занятии тоже считаются, ничего не сохраняется частично
def test_quota_attempts(client, user, monkeypatch, db):
    monkeypatch.setattr(history, "MAX_USER_ATTEMPTS", 4)
    sid = new_id()
    saved = [attempt(), attempt()]
    assert put(client, user, sid, session_body(saved)).status_code == 200
    assert put(client, user, sid, session_body(saved)).status_code == 200
    assert put(client, user, sid, session_body(saved + [attempt()])).status_code == 200
    over = put(client, user, sid, session_body(saved + [attempt(), attempt()]))
    assert_error(over, 413, "quota_exceeded")
    assert db.scalar(select(func.count()).select_from(AttemptRow)) == 3
    assert put(client, user, sid, session_body(saved + [attempt()])).status_code == 200
    assert_error(put(client, user, new_id(), session_body([attempt(), attempt()])), 413, "quota_exceeded")
    assert db.scalar(select(func.count()).select_from(SessionRow)) == 1


# test_quota_is_per_account — квота считается на аккаунт, у другого пользователя своя
def test_quota_is_per_account(client, user, other, monkeypatch):
    monkeypatch.setattr(history, "MAX_USER_SESSIONS", 1)
    assert put(client, user, new_id(), session_body([attempt()])).status_code == 200
    assert_error(put(client, user, new_id(), session_body([attempt()])), 413, "quota_exceeded")
    assert put(client, other, new_id(), session_body([attempt()])).status_code == 200


# test_quota_not_spent_by_resend_at_limit — аккаунт на пределе может повторять уже сохранённое занятие без ошибки
def test_quota_not_spent_by_resend_at_limit(client, user, monkeypatch):
    sid, body = new_id(), session_body([attempt(), attempt()])
    assert put(client, user, sid, body).status_code == 200
    monkeypatch.setattr(history, "MAX_USER_SESSIONS", 1)
    monkeypatch.setattr(history, "MAX_USER_ATTEMPTS", 2)
    assert put(client, user, sid, body).status_code == 200


# test_quota_defaults — предельные числа по умолчанию
def test_quota_defaults():
    assert (history.MAX_USER_SESSIONS, history.MAX_USER_ATTEMPTS) == (1000, 10000)
