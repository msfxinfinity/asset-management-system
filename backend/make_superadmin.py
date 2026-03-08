from app.db import Sessionlocal
from app.models.user import User

def make_admin_super():
    db = Sessionlocal()
    try:
        user = db.query(User).filter(User.username == "admin@goagile.com").first()
        if user:
            user.is_superadmin = True
            db.commit()
            print(f"Successfully made {user.username} a Superadmin.")
        else:
            print("Admin user not found.")
    finally:
        db.close()

if __name__ == "__main__":
    make_admin_super()
