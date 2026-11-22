
from django.urls import path

from .views import (
    LoginView,
    CurrentUserView,
    RegisterDeviceView,
    CreateInvitationView,
    ActivateInvitationView,
    ShepherdManagementView,
    RevokeShepherdView,
    ChatMessagesView,
    ChatContactsView,
)

urlpatterns = [
    path('login/', LoginView.as_view(), name='login'),
    path('me/', CurrentUserView.as_view(), name='current-user'),

    path(
        'invitations/create/',
        CreateInvitationView.as_view(),
        name='create-invitation'
    ),

    path(
        'invitations/activate/',
        ActivateInvitationView.as_view(),
        name='activate-invitation'
    ),

    path(
        'shepherds/',
        ShepherdManagementView.as_view(),
        name='shepherd-management'
    ),

    path(
        'shepherds/<int:shepherd_id>/revoke/',
        RevokeShepherdView.as_view(),
        name='revoke-shepherd'
    ),
    path('devices/register/', RegisterDeviceView.as_view(), name='register-device'),
    path('chat/messages/', ChatMessagesView.as_view(), name='chat-messages'),
    path(
    'chat/contacts/',
    ChatContactsView.as_view(),
    name='chat-contacts',
),
]
