
from rest_framework import serializers
from django.contrib.auth.models import User


class UserSerializer(serializers.ModelSerializer):

    role = serializers.SerializerMethodField()

    def get_role(self, obj):
        try:
            return obj.profile.role
        except User.profile.RelatedObjectDoesNotExist:
            return None

    class Meta:
        model = User
        fields = [
            'id',
            'username',
            'email',
            'role',
        ]
