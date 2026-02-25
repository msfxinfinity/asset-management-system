import io
import zipfile
from dataclasses import dataclass
from typing import List

from fastapi import HTTPException, status

@dataclass
class QRLabel:
    serial_number: str
    asset_token: str


def _load_qrcode():
    try:
        import qrcode
    except ImportError as exc:  # pragma: no cover - dependency check
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Missing dependency: qrcode[pil]",
        ) from exc
    return qrcode


def _load_reportlab():
    try:
        from reportlab.lib.pagesizes import A4
        from reportlab.lib.utils import ImageReader
        from reportlab.pdfgen import canvas
    except ImportError as exc:  # pragma: no cover - dependency check
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Missing dependency: reportlab",
        ) from exc
    return A4, ImageReader, canvas


def build_qr_png(token: str) -> bytes:
    qrcode = _load_qrcode()
    image = qrcode.make(token)
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    return buffer.getvalue()


def build_zip(labels: List[QRLabel]) -> bytes:
    output = io.BytesIO()
    with zipfile.ZipFile(output, mode="w", compression=zipfile.ZIP_DEFLATED) as archive:
        for label in labels:
            archive.writestr(f"{label.serial_number}.png", build_qr_png(label.asset_token))
    return output.getvalue()


def build_pdf(labels: List[QRLabel]) -> bytes:
    A4, ImageReader, canvas = _load_reportlab()
    output = io.BytesIO()
    pdf = canvas.Canvas(output, pagesize=A4)
    page_width, page_height = A4

    left = 36
    top = page_height - 36
    card_width = 250
    card_height = 140
    x = left
    y = top - card_height

    for label in labels:
        qr_png = build_qr_png(label.asset_token)
        qr_reader = ImageReader(io.BytesIO(qr_png))

        pdf.roundRect(x, y, card_width, card_height, radius=8, stroke=1, fill=0)
        pdf.drawImage(qr_reader, x + 10, y + 20, width=90, height=90, preserveAspectRatio=True)
        pdf.setFont("Helvetica-Bold", 11)
        pdf.drawString(x + 110, y + 100, label.serial_number)
        pdf.setFont("Helvetica", 10)
        pdf.drawString(x + 110, y + 80, "Token")
        pdf.setFont("Helvetica-Bold", 9)
        pdf.drawString(x + 110, y + 66, label.asset_token)

        x += card_width + 16
        if x + card_width > page_width - 36:
            x = left
            y -= card_height + 16
        if y < 36:
            pdf.showPage()
            x = left
            y = top - card_height

    pdf.save()
    return output.getvalue()


def assert_export_formats(export_formats: List[str]) -> List[str]:
    normalized = [item.lower() for item in export_formats]
    valid = {"pdf", "zip"}
    for item in normalized:
        if item not in valid:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Unsupported export format: {item}",
            )
    if not normalized:
        return ["pdf", "zip"]
    return sorted(set(normalized))
