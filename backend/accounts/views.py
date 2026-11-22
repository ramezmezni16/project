import hashlib
import secrets
from datetime import timedelta
from django.contrib.auth.models import User
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError
from django.db import transaction
from django.utils import timezone
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework.permissions import AllowAny
from rest_framework import status
from .models import Profile, ChatMessage
from rest_framework_simplejwt.views import TokenObtainPairView
from django.db.models import Q
from .models import Profile, Invitation, DeviceInstallation
from .serializers import UserSerializer
from .push_notifications import send_push_notification






class LoginView(TokenObtainPairView):
    """Returns access and refresh JWT tokens."""


class CurrentUserView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        serializer = UserSerializer(request.user)
        return Response(serializer.data, status=status.HTTP_200_OK)


class RegisterDeviceView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        fcm_token = request.data.get("fcm_token", "").strip()
        platform = request.data.get("platform", "android").strip().lower()

        if not fcm_token:
            return Response(
                {"error": "FCM token is required."},
                status=status.HTTP_400_BAD_REQUEST
            )

        if len(fcm_token) > 512:
            return Response(
                {"error": "FCM token is too long."},
                status=status.HTTP_400_BAD_REQUEST
            )

        if platform not in ["android", "ios", "web"]:
            return Response(
                {"error": "Unsupported platform."},
                status=status.HTTP_400_BAD_REQUEST
            )

        device, created = DeviceInstallation.objects.update_or_create(
            fcm_token=fcm_token,
            defaults={
                "user": request.user,
                "platform": platform,
            }
        )

        return Response(
            {
                "message": "FCM device registered successfully.",
                "created": created,
            },
            status=status.HTTP_200_OK
        )

class CreateInvitationView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):

        if not Profile.objects.filter(
            user=request.user,
            role=Profile.Role.OWNER
        ).exists():
            return Response(
                {"error": "Only farm owners can create invitations."},
                status=status.HTTP_403_FORBIDDEN
            )

        username = request.data.get("username", "").strip()

        if not username:
            return Response(
                {"error": "Username is required."},
                status=status.HTTP_400_BAD_REQUEST
            )

        if User.objects.filter(username=username).exists():
            return Response(
                {"error": "This username is already taken."},
                status=status.HTTP_400_BAD_REQUEST
            )

        if Invitation.objects.filter(username=username).exists():
            return Response(
                {"error": "An invitation already exists for this username."},
                status=status.HTTP_400_BAD_REQUEST
            )

        raw_token = secrets.token_urlsafe(32)
        token_hash = hashlib.sha256(raw_token.encode()).hexdigest()

        invitation = Invitation.objects.create(
            token_hash=token_hash,
            username=username,
            created_by=request.user,
            expires_at=timezone.now() + timedelta(hours=24)
        )

        return Response({
            "message": "Invitation created successfully.",
            "username": invitation.username,
            "token": raw_token,
            "expires_at": invitation.expires_at
        }, status=status.HTTP_201_CREATED)


class ActivateInvitationView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):

        token = request.data.get("token", "")
        password = request.data.get("password", "")

        if not token or not password:
            return Response(
                {"error": "Token and password are required."},
                status=status.HTTP_400_BAD_REQUEST
            )

        token_hash = hashlib.sha256(token.encode()).hexdigest()

        with transaction.atomic():

            try:
                invitation = Invitation.objects.select_for_update().get(
                    token_hash=token_hash
                )
            except Invitation.DoesNotExist:
                return Response(
                    {"error": "Invalid invitation."},
                    status=status.HTTP_400_BAD_REQUEST
                )

            if not invitation.is_valid:
                return Response(
                    {"error": "Invitation has expired, been used, or revoked."},
                    status=status.HTTP_400_BAD_REQUEST
                )

            user = User(username=invitation.username)

            try:
                validate_password(password, user=user)
            except ValidationError as error:
                return Response(
                    {"errors": error.messages},
                    status=status.HTTP_400_BAD_REQUEST
                )

            user.set_password(password)
            user.save()

            Profile.objects.create(
                user=user,
                role=Profile.Role.SHEPHERD,
                owner=invitation.created_by
            )

            invitation.used_at = timezone.now()
            invitation.save(update_fields=["used_at"])

        return Response({
            "message": "Shepherd account activated successfully.",
            "username": user.username,
            "role": Profile.Role.SHEPHERD
        }, status=status.HTTP_201_CREATED)


class ShepherdManagementView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):

        is_owner = Profile.objects.filter(
            user=request.user,
            role=Profile.Role.OWNER
        ).exists()

        if not is_owner:
            return Response(
                {"error": "Only farm owners can view shepherds."},
                status=status.HTTP_403_FORBIDDEN
            )

        profiles = Profile.objects.filter(
            owner=request.user,
            role=Profile.Role.SHEPHERD
        ).select_related("user", "user__latest_shepherd_location")

        shepherds = []

        for profile in profiles:
            user = profile.user
            location = getattr(user, "latest_shepherd_location", None)

            shepherds.append({
                "id": user.id,
                "username": user.username,
                "is_active": user.is_active,
                "created_at": profile.created_at,
                "last_location": {
                    "lat": location.lat,
                    "lon": location.lon,
                    "accuracy": location.accuracy,
                    "speed": location.speed,
                    "recorded_at": location.recorded_at,
                } if location else None
            })

        return Response(shepherds, status=status.HTTP_200_OK)


class RevokeShepherdView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, shepherd_id):

        is_owner = Profile.objects.filter(
            user=request.user,
            role=Profile.Role.OWNER
        ).exists()

        if not is_owner:
            return Response(
                {"error": "Only farm owners can revoke shepherd access."},
                status=status.HTTP_403_FORBIDDEN
            )

        try:
            shepherd_profile = Profile.objects.select_related("user").get(
                user_id=shepherd_id,
                owner=request.user,
                role=Profile.Role.SHEPHERD
            )
        except Profile.DoesNotExist:
            return Response(
                {"error": "Shepherd not found."},
                status=status.HTTP_404_NOT_FOUND
            )

        shepherd = shepherd_profile.user

        if not shepherd.is_active:
            return Response(
                {"message": "Shepherd account is already disabled."},
                status=status.HTTP_200_OK
            )

        shepherd.is_active = False
        shepherd.save(update_fields=["is_active"])

        return Response({
            "message": "Shepherd access revoked successfully.",
            "username": shepherd.username
        }, status=status.HTTP_200_OK)

class ChatMessagesView(APIView):
    permission_classes = [IsAuthenticated]

    def get_profiles(self, user, partner_username):
        current_profile = Profile.objects.filter(user=user).first()
        partner_profile = Profile.objects.filter(
            user__username=partner_username
        ).first()

        if not current_profile or not partner_profile:
            return None, None

        # Owner can only chat with their own Shepherds.
        owner_to_shepherd = (
            current_profile.role == Profile.Role.OWNER
            and partner_profile.role == Profile.Role.SHEPHERD
            and partner_profile.owner_id == user.id
        )

        # Shepherd can only chat with their assigned Owner.
        shepherd_to_owner = (
            current_profile.role == Profile.Role.SHEPHERD
            and partner_profile.role == Profile.Role.OWNER
            and current_profile.owner_id == partner_profile.user_id
        )

        if not (owner_to_shepherd or shepherd_to_owner):
            return None, None

        return current_profile, partner_profile

    def get(self, request):
        partner_username = request.query_params.get('with_user')

        if not partner_username:
            return Response(
                {'error': 'with_user is required.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        current_profile, partner_profile = self.get_profiles(
            request.user, partner_username
        )

        if not partner_profile:
            return Response(
                {'error': 'You cannot access this conversation.'},
                status=status.HTTP_403_FORBIDDEN
            )

        messages = ChatMessage.objects.filter(
            Q(sender=request.user, recipient=partner_profile.user) |
            Q(sender=partner_profile.user, recipient=request.user)
        ).select_related('sender', 'recipient').order_by('created_at')

        # Mark incoming messages as read.
        ChatMessage.objects.filter(
            sender=partner_profile.user,
            recipient=request.user,
            is_read=False
        ).update(is_read=True)

        result = [
            {
                'id': message.id,
                'sender': message.sender.username,
                'recipient': message.recipient.username,
                'message': message.message,
                'created_at': message.created_at,
                'is_read': message.is_read,
            }
            for message in messages
        ]

        return Response(result)

    def post(self, request):
        partner_username = request.data.get('recipient')
        message_text = request.data.get('message', '')

        if not partner_username or not isinstance(message_text, str):
            return Response(
                {'error': 'recipient and message are required.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        message_text = message_text.strip()

        if not message_text:
            return Response(
                {'error': 'Message cannot be empty.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        if len(message_text) > 5000:
            return Response(
                {'error': 'Message cannot exceed 5000 characters.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        current_profile, partner_profile = self.get_profiles(
            request.user, partner_username
        )

        if not partner_profile:
            return Response(
                {'error': 'You cannot message this user.'},
                status=status.HTTP_403_FORBIDDEN
            )

        chat_message = ChatMessage.objects.create(
            sender=request.user,
            recipient=partner_profile.user,
            message=message_text
        )
        try:
            send_push_notification(
                user=partner_profile.user,
                title=f"New message from {request.user.username}",
                body=message_text[:120],
                data={
                    "type": "chat_message",
                    "sender": request.user.username,
                },
            )
        except Exception:
            import logging
            logging.getLogger(__name__).exception(
                "Failed to send chat notification."
            )

        return Response(
            {
                'id': chat_message.id,
                'sender': request.user.username,
                'recipient': partner_profile.user.username,
                'message': chat_message.message,
                'created_at': chat_message.created_at,
                'is_read': False,
            },
            status=status.HTTP_201_CREATED
        )


class ChatContactsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        profile = Profile.objects.select_related(
            'owner', 'user'
        ).filter(user=request.user).first()

        if not profile:
            return Response(
                {'error': 'Profile not found.'},
                status=status.HTTP_404_NOT_FOUND
            )

        if profile.role == Profile.Role.OWNER:
            shepherd_profiles = Profile.objects.filter(
                role=Profile.Role.SHEPHERD,
                owner=request.user,
                user__is_active=True,
            ).select_related('user')

            contacts = [
                {
                    'username': item.user.username,
                    'role': 'SHEPHERD',
                }
                for item in shepherd_profiles
            ]

        elif profile.role == Profile.Role.SHEPHERD:
            if not profile.owner:
                return Response([])

            contacts = [{
                'username': profile.owner.username,
                'role': 'OWNER',
            }]

        else:
            contacts = []

        return Response(contacts)