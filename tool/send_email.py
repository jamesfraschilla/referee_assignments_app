import os
import smtplib
from email.message import EmailMessage
from pathlib import Path

smtp_host = os.environ.get("SMTP_HOST", "")
smtp_port = int(os.environ.get("SMTP_PORT", "0"))
smtp_user = os.environ.get("SMTP_USER", "")
smtp_pass = os.environ.get("SMTP_PASS", "")
recipients = os.environ.get("RECIPIENTS", "")
subject = os.environ.get("EMAIL_SUBJECT", "Referee Assignments")
body = os.environ.get("EMAIL_BODY", "Attached is the referee assignments image.")
attachment_path = os.environ.get("ATTACHMENT", "")

if not smtp_host or not smtp_port or not smtp_user or not smtp_pass:
    raise SystemExit("Missing SMTP credentials.")

recipient_list = [r.strip() for r in recipients.split(",") if r.strip()]
if not recipient_list:
    raise SystemExit("No recipients provided.")

msg = EmailMessage()
msg["Subject"] = subject
msg["From"] = smtp_user
msg["To"] = ", ".join(recipient_list)
msg.set_content(body)

if attachment_path:
    path = Path(attachment_path)
    if not path.exists():
        raise SystemExit(f"Attachment not found: {attachment_path}")
    data = path.read_bytes()
    msg.add_attachment(data, maintype="image", subtype="png", filename=path.name)

if smtp_port == 465:
    server = smtplib.SMTP_SSL(smtp_host, smtp_port)
else:
    server = smtplib.SMTP(smtp_host, smtp_port)
    server.starttls()

try:
    server.login(smtp_user, smtp_pass)
    server.send_message(msg)
finally:
    server.quit()
