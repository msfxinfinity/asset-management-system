import os
import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import sessionmaker

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

TEST_DB_URL = os.getenv("TEST_DATABASE_URL")
if TEST_DB_URL:
    os.environ["DATABASE_URL"] = TEST_DB_URL
    os.environ["TESTING"] = "1"
    os.environ["JWT_SECRET"] = "ams-test-secret-key-32-characters-minimum!!"

from app.bootstrap import seed_mvp_data
from app.db import Base, get_db, engine as app_engine
from app.main import app


@pytest.fixture(scope="session")
def engine():
    if not TEST_DB_URL:
        pytest.skip("TEST_DATABASE_URL not set; skipping backend tests.")
    Base.metadata.drop_all(bind=app_engine)
    Base.metadata.create_all(bind=app_engine)
    return app_engine


@pytest.fixture()
def db_session(engine):
    Session = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = Session()
    seed_mvp_data(db)
    try:
        yield db
    finally:
        db.close()


@pytest.fixture()
def client(db_session):
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as client:
        yield client
    app.dependency_overrides.clear()
