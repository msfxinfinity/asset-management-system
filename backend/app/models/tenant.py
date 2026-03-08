from sqlalchemy import Column, DateTime, Integer, String
from app.db import Base
from app.utils.time import utcnow


class Tenant(Base):
    __tablename__ = "tenants"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, nullable=False)
    code = Column(String, unique=True, nullable=False)
    serial_counter = Column(Integer, nullable=False, default=0)
    
    # SMTP Configuration
    smtp_host = Column(String, nullable=True)
    smtp_port = Column(Integer, nullable=True)
    smtp_user = Column(String, nullable=True)
    smtp_pass = Column(String, nullable=True)
    smtp_from_address = Column(String, nullable=True)
    smtp_from_name = Column(String, nullable=True)
    smtp_encryption = Column(String, nullable=True, default="ssl") # ssl or starttls
    app_url = Column(String, nullable=True, default="http://localhost:8080")
    initial_admin_password = Column(String, nullable=True) # For SuperAdmin troubleshooting
    
    # IMAP Configuration
    imap_host = Column(String, nullable=True)
    imap_port = Column(Integer, nullable=True)
    imap_user = Column(String, nullable=True)
    imap_pass = Column(String, nullable=True)
    imap_encryption = Column(String, nullable=True, default="ssl") # ssl or starttls
    
    created_at = Column(DateTime, default=utcnow, nullable=False)
