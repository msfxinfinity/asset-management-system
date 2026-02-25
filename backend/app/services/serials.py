from typing import List

from sqlalchemy.orm import Session

from app.models.tenant import Tenant


def next_serial_numbers(db: Session, tenant_id: int, quantity: int) -> List[str]:
    tenant = (
        db.query(Tenant)
        .filter(Tenant.id == tenant_id)
        .with_for_update()
        .first()
    )
    if not tenant:
        raise ValueError("Tenant not found")

    if quantity <= 0:
        raise ValueError("Quantity must be greater than zero")

    start = tenant.serial_counter + 1
    tenant.serial_counter += quantity
    prefix = tenant.code or f"T{tenant.id}"
    return [f"AMS-{prefix}-{index:06d}" for index in range(start, start + quantity)]
