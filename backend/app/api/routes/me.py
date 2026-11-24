from fastapi import APIRouter, Depends, Request, Response
from sqlalchemy.orm import Session

from app.api.deps import current_user, get_db
from app.api.routes.auth import ERRORS, clear_refresh_cookie, is_web
from app.db.models import User
from app.schemas.accounts import DeleteAccountBody, UserOut
from app.services import accounts

router = APIRouter()


# GET /api/v1/me — данные текущего пользователя
@router.get("/me", response_model=UserOut, responses=ERRORS)
def get_me(user: User = Depends(current_user)) -> UserOut:
    return UserOut.model_validate(user, from_attributes=True)


# DELETE /api/v1/me — удаляет аккаунт и все его данные после подтверждения паролем
@router.delete("/me", status_code=204, responses=ERRORS)
def delete_me(body: DeleteAccountBody, request: Request, user: User = Depends(current_user), db: Session = Depends(get_db)) -> Response:
    accounts.confirm_password(db, user, body.password)
    accounts.delete_account(db, user)
    response = Response(status_code=204)
    if is_web(request):
        clear_refresh_cookie(response)
    return response
