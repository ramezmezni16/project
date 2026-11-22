
import logging
import os

import firebase_admin
from firebase_admin import credentials, messaging

logger = logging.getLogger(__name__)


def get_firebase_app():
    try:
        return firebase_admin.get_app()
    except ValueError:
        credentials_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")

        if not credentials_path or not os.path.isfile(credentials_path):
            logger.error("Firebase service-account file is missing.")
            return None

        try:
            credential = credentials.Certificate(credentials_path)
            return firebase_admin.initialize_app(credential)
        except Exception:
            logger.exception("Firebase initialization failed.")
            return None


def send_push_notification(user, title, body, data=None):
    app = get_firebase_app()

    if app is None:
        return 0

    tokens = list(
        user.device_installations
        .exclude(fcm_token__isnull=True)
        .exclude(fcm_token="")
        .values_list("fcm_token", flat=True)
    )

    if not tokens:
        return 0

    message = messaging.MulticastMessage(
        notification=messaging.Notification(
            title=title,
            body=body,
        ),
        data={
            str(key): str(value)
            for key, value in (data or {}).items()
        },
        tokens=tokens,
        android=messaging.AndroidConfig(
            priority="high",
        ),
    )

    try:
        response = messaging.send_each_for_multicast(
            message,
            app=app,
        )

        logger.info(
            "Push notification sent to %s devices; %s succeeded.",
            len(tokens),
            response.success_count,
        )

        # Remove tokens that Firebase confirms are no longer registered.
        for token, result in zip(tokens, response.responses):
            if not result.success:
                error = result.exception
                if isinstance(
                    error,
                    messaging.UnregisteredError,
                ):
                    user.device_installations.filter(
                        fcm_token=token
                    ).delete()

        return response.success_count

    except Exception:
        logger.exception("Failed to send push notification.")
        return 0
