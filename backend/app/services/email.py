import os
import smtplib
import ssl
import logging
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from typing import List, Optional
from email_validator import validate_email, EmailNotValidError

from dataclasses import dataclass

logger = logging.getLogger(__name__)

@dataclass
class SmtpConfig:
    host: str
    port: int
    user: str
    password: str
    from_address: str
    from_name: str
    encryption: str = "ssl"

    @property
    def is_active(self) -> bool:
        return bool(self.host and self.port and self.user and self.password)

def verify_email_valid(email: str) -> bool:
    """
    Performs verification of the email address:
    1. Check syntax
    2. Check deliverability (optional, defaults to False for reliability)
    """
    try:
        # Syntax check only by default for high reliability in production
        validate_email(email, check_deliverability=False)
        return True
    except EmailNotValidError as e:
        logger.error(f"[EMAIL VALIDATION ERROR] {str(e)}")
        return False

def send_email(subject: str, recipients: List[str], html_content: str, config: SmtpConfig):
    """
    Sends an email using the provided tenant's SMTP configuration.
    Raises an Exception if the email cannot be sent.
    """
    if not recipients:
        return False
        
    # If SMTP is not configured for this tenant, we silently skip
    if not config.is_active:
        logger.warning(f"[EMAIL SKIP] SMTP not configured for tenant. Subject: {subject}")
        return False

    # Pre-verify the email and domain
    if not verify_email_valid(recipients[0]):
        raise Exception(f"The email address {recipients[0]} is invalid. Please double-check.")

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = f"{config.from_name} <{config.from_address}>"
    msg["To"] = ", ".join(recipients)

    part = MIMEText(html_content, "html")
    msg.attach(part)

    context = ssl.create_default_context()
    
    try:
        logger.info(f"[EMAIL] Attempting to connect to {config.host}:{config.port} via {config.encryption}...")
        
        if config.encryption == "ssl":
            with smtplib.SMTP_SSL(config.host, config.port, context=context, timeout=10) as server:
                server.login(config.user, config.password)
                logger.info(f"[EMAIL] Logged in as {config.user}. Sending...")
                server.send_email = server.send_message
                server.send_message(msg)
            logger.info(f"[EMAIL] Successfully sent to {recipients}")
            return True
        else:
            # STARTTLS support if needed (port 587)
            with smtplib.SMTP(config.host, config.port, timeout=10) as server:
                server.starttls(context=context)
                server.login(config.user, config.password)
                logger.info(f"[EMAIL] Logged in as {config.user} via STARTTLS. Sending...")
                server.send_message(msg)
            logger.info(f"[EMAIL] Successfully sent via STARTTLS to {recipients}")
            return True

    except Exception as e:
        logger.error(f"[EMAIL ERROR] {str(e)}")
        raise Exception(f"Email delivery failed: {str(e)}")


def get_welcome_email_html(full_name: str, username: str, password: str, app_url: str) -> str:
    # Ensure app_url doesn't end with slash for consistent joining
    base = app_url.rstrip("/")
    return f"""
    <html>
    <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
        <div style="max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e1e1e1; border-radius: 10px;">
            <h2 style="color: #1E293B;">Welcome to GoAgile AMS!</h2>
            <p>Hello {full_name},</p>
            <p>Your account has been created successfully. You can now log in using the following details:</p>
            <div style="background-color: #f8fafc; padding: 15px; border-radius: 5px; margin: 20px 0;">
                <p style="margin: 5px 0;"><strong>Username:</strong> {username}</p>
                <p style="margin: 5px 0;"><strong>Temporary Password:</strong> {password}</p>
                <p style="margin: 15px 0 5px 0;"><strong>Dashboard:</strong> <a href="{base}">Click here to Login</a></p>
            </div>
            <p style="color: #666; font-size: 0.9em;">Please change your password after logging in for the first time.</p>
            <hr style="border: 0; border-top: 1px solid #eee; margin: 20px 0;">
            <p style="font-size: 12px; color: #777;">&copy; 2026 GoAgile Solutions. All rights reserved.</p>
        </div>
    </body>
    </html>
    """

def get_reset_email_html(full_name: str, reset_url: str) -> str:
    return f"""
    <html>
    <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
        <div style="max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e1e1e1; border-radius: 10px;">
            <h2 style="color: #1E293B;">Reset Your Password</h2>
            <p>Hello {full_name},</p>
            <p>You requested to reset your password. Please click the button below to set a new one:</p>
            <div style="text-align: center; margin: 30px 0;">
                <a href="{reset_url}" style="background-color: #1E293B; color: white; padding: 12px 25px; text-decoration: none; border-radius: 5px; font-weight: bold;">Reset Password</a>
            </div>
            <p>This link will expire in 15 minutes. If you did not request this, please ignore this email.</p>
            <hr style="border: 0; border-top: 1px solid #eee; margin: 20px 0;">
            <p style="font-size: 12px; color: #777;">&copy; 2026 GoAgile Solutions. All rights reserved.</p>
        </div>
    </body>
    </html>
    """
