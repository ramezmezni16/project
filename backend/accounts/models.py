import uuid
import hashlib

from django.conf import settings
from django.db import models
from django.utils import timezone


class Profile(models.Model):

    class Role(models.TextChoices):
        OWNER = 'OWNER', 'Farm Owner'
        SHEPHERD = 'SHEPHERD', 'Shepherd'

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='profile'
    )

    role = models.CharField(
        max_length=10,
        choices=Role.choices
    )

    owner = models.ForeignKey(
    settings.AUTH_USER_MODEL,
    on_delete=models.CASCADE,
    null=True,
    blank=True,
    related_name='shepherd_profiles'
    )

    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.username} - {self.role}"


class Invitation(models.Model):

    token_hash = models.CharField(max_length=64, unique=True)

    username = models.CharField(max_length=150, unique=True)

    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='created_invitations'
    )

    created_at = models.DateTimeField(auto_now_add=True)

    expires_at = models.DateTimeField()

    used_at = models.DateTimeField(null=True, blank=True)

    revoked = models.BooleanField(default=False)

    @property
    def is_valid(self):
        return (
            not self.revoked
            and self.used_at is None
            and timezone.now() < self.expires_at
        )

    def __str__(self):
        return f"Invitation for {self.username}"

class DeviceInstallation(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='device_installations'
    )

    # Keep old records compatible.
    installation_id = models.CharField(
        max_length=255,
        unique=True,
        null=True,
        blank=True
    )

    # Actual Firebase Cloud Messaging token.
    fcm_token = models.CharField(
        max_length=512,
        unique=True,
        null=True,
        blank=True,
        db_index=True
    )

    platform = models.CharField(max_length=20, default='android')

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.user.username} - {self.platform}"

class ChatMessage(models.Model):
    sender = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='sent_chat_messages'
    )

    recipient = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='received_chat_messages'
    )

    message = models.TextField()

    created_at = models.DateTimeField(auto_now_add=True)

    is_read = models.BooleanField(default=False)

    class Meta:
        ordering = ['created_at']
        indexes = [
            models.Index(fields=['sender', 'recipient', 'created_at']),
            models.Index(fields=['recipient', 'is_read']),
        ]

    def __str__(self):
        return f'{self.sender} -> {self.recipient}: {self.message[:40]}'