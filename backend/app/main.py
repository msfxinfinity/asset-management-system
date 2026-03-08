import os
from contextlib import asynccontextmanager

from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import logging

# Initialize environment variables from .env file
load_dotenv()

from app.bootstrap import seed_mvp_data
from app.db import Base, Sessionlocal, engine
from app.models import (  # noqa: F401
    asset,
    asset_event,
    department,
    role_type,
    tenant,
    user,
)
from app.routers import admin, assets, auth, superadmin

# Configure global logging standards for production visibility
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
)
logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Handles application startup and shutdown lifecycle events.
    Verifies critical security configurations before allowing traffic.
    """
    if os.getenv("ENVIRONMENT", "development").lower() == "production":
        # Security Gate: Prevent deployment with default developer keys
        if os.getenv("JWT_SECRET", "ams-dev-secret-key-32-characters-minimum") == "ams-dev-secret-key-32-characters-minimum":
            logger.critical("CRITICAL VULNERABILITY: Default JWT_SECRET detected in production. System halting for safety.")
            raise RuntimeError("Refusing to start in production with default JWT secret.")

    # Automated DB Synchronization (Development/Staging Mode)
    # In full production, this should be handled by Alembic migrations.
    if os.getenv("RUN_MIGRATIONS_ON_STARTUP", "false").lower() in {"1", "true", "yes"}:
        logger.info("Synchronizing database schema and seeding foundational data...")
        Base.metadata.create_all(bind=engine)
        db = Sessionlocal()
        try:
            seed_mvp_data(db)
        finally:
            db.close()
    yield

# Initialize FastAPI with Enterprise Metadata
app = FastAPI(
    title="GoAgile AMS API",
    description="Corporate-grade multi-tenant asset management API.",
    version="1.0.5",
    contact={
        "name": "GoAgile Technologies Support",
        "url": "https://goagile.com",
    },
    lifespan=lifespan
)

@app.exception_handler(Exception)
async def global_exception_handler(request, exc: Exception):
    """
    Catches all unhandled exceptions to prevent server-side info leakage 
    and provide a sanitized response to the client.
    """
    logger.error(f"Sanitized Unhandled Exception on {request.url}: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"detail": "An internal server error occurred. Our engineering team has been notified."},
    )

# Dynamic CORS Configuration
# Ensures the frontend can communicate securely with the API from any organizational domain.
cors_origins_env = os.getenv("CORS_ALLOW_ORIGINS", "")
if cors_origins_env:
    allow_origins = [item.strip() for item in cors_origins_env.split(",") if item.strip()]
else:
    # Default local development origins
    allow_origins = [
        "http://localhost:8080",
        "http://127.0.0.1:8080",
        "http://localhost:8000",
        "http://127.0.0.1:8000",
        "http://0.0.0.0:8080",
        "http://0.0.0.0:8000",
    ]

app.add_middleware(
    CORSMiddleware,
    allow_origins=allow_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Route Orchestration
app.include_router(auth.router)
app.include_router(admin.router)
app.include_router(assets.router)
app.include_router(superadmin.router)


@app.get("/", summary="System Health Check")
def health_check() -> dict:
    """Provides a simple ping for load balancers and uptime monitoring."""
    return {"status": "operational", "version": "1.0.5"}


if __name__ == "__main__":
    import uvicorn
    # In production, run with multiple workers for scalability
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, log_level="info")
