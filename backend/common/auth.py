"""Token-based authentication and role authorization helpers."""

from functools import wraps
from flask import g, request
from itsdangerous import BadSignature, SignatureExpired, URLSafeTimedSerializer

from common.errors import AppError
from config import db
from config.settings import Settings

_TOKEN_SALT = "podify-auth-token-v1"


def _serializer() -> URLSafeTimedSerializer:
    return URLSafeTimedSerializer(Settings.SECRET_KEY, salt=_TOKEN_SALT)


def create_access_token(user_id: str | int, role: str) -> str:
    """Create a signed, timed Bearer token for an authenticated user."""
    return _serializer().dumps({"user_id": str(user_id), "role": role})


def decode_access_token(token: str) -> dict:
    """Validate and decode a Bearer token."""
    try:
        return _serializer().loads(token, max_age=Settings.TOKEN_EXPIRES_SECONDS)
    except SignatureExpired as exc:
        raise AppError("Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.", status_code=401, code="TOKEN_EXPIRED") from exc
    except BadSignature as exc:
        raise AppError("Token xác thực không hợp lệ.", status_code=401, code="TOKEN_INVALID") from exc


def extract_bearer_token() -> str | None:
    """Extract Bearer token from the Authorization header if present."""
    header = request.headers.get("Authorization", "").strip()
    if not header:
        return None
    parts = header.split(" ", 1)
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise AppError("Header Authorization phải có dạng: Bearer <token>.", status_code=401, code="AUTH_HEADER_INVALID")
    return parts[1].strip()


def load_user_with_creator(user_id: str | int) -> dict | None:
    """Fetch user record along with optional Creator profile."""
    return db.fetch_one(
        """
        SELECT u.ma_nguoi_dung AS user_id,
               u.ten_dang_nhap AS username,
               u.email,
               u.ho_ten AS full_name,
               CASE u.vai_tro
                   WHEN 'nha_sang_tao' THEN 'creator'
                   WHEN 'quan_tri' THEN 'admin'
                   ELSE 'user'
               END AS role,
               u.vai_tro AS vai_tro,
               u.anh_dai_dien AS avatar_url,
               u.ngay_tao AS created_at,
               c.ma_creator AS creator_id,
               c.ten_hien_thi AS creator_display_name,
               c.tieu_su AS creator_bio,
               c.da_xac_minh AS creator_verified
        FROM NguoiDung u
        LEFT JOIN NhaSangTao c ON u.ma_nguoi_dung = c.ma_nguoi_dung
        WHERE u.ma_nguoi_dung = %s
        """,
        (str(user_id),),
    )


def get_optional_user() -> dict | None:
    """Return authenticated user dict if valid Bearer token is provided, else None."""
    if hasattr(g, "current_user"):
        return g.current_user
    token = extract_bearer_token()
    if not token:
        g.current_user = None
        return None
    payload = decode_access_token(token)
    user = load_user_with_creator(str(payload["user_id"]))
    if not user:
        raise AppError("Tài khoản không còn tồn tại.", status_code=401, code="USER_NOT_FOUND")
    g.current_user = user
    return user


def get_current_user() -> dict:
    """Return authenticated user dict or raise 401."""
    user = get_optional_user()
    if not user:
        raise AppError("Vui lòng đăng nhập để thực hiện thao tác này.", status_code=401, code="AUTH_REQUIRED")
    return user


def login_required(fn):
    """Decorator enforcing authenticated user access."""

    @wraps(fn)
    def wrapper(*args, **kwargs):
        get_current_user()
        return fn(*args, **kwargs)

    return wrapper


def roles_required(*allowed_roles: str):
    """Decorator enforcing user role authorization."""

    def decorator(fn):
        @wraps(fn)
        def wrapper(*args, **kwargs):
            user = get_current_user()
            if user["role"] not in allowed_roles:
                raise AppError(
                    f"Chức năng này yêu cầu quyền: {', '.join(allowed_roles)}.",
                    status_code=403,
                    code="FORBIDDEN",
                )
            return fn(*args, **kwargs)

        return wrapper

    return decorator
