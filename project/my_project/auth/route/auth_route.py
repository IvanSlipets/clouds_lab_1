import hmac

from flask import Blueprint, request, jsonify, current_app
from flask_jwt_extended import (
    create_access_token,
    jwt_required,
    get_jwt_identity
)

auth_bp = Blueprint('auth', __name__)


# POST /api/auth/login
@auth_bp.route('/login', methods=['POST'])
def login():
    data = request.get_json(silent=True)

    if not isinstance(data, dict):
        return jsonify({
            'message': 'Invalid JSON body'
        }), 400

    username = data.get('username')
    password = data.get('password')

    if not isinstance(username, str) or not isinstance(password, str):
        return jsonify({
            'message': 'Username and password are required'
        }), 400

    expected_username = current_app.config['API_ADMIN_USERNAME']
    expected_password = current_app.config['API_ADMIN_PASSWORD']

    username_valid = hmac.compare_digest(
        username, expected_username
    )

    password_valid = hmac.compare_digest(
        password, expected_password
    )

    if not (username_valid and password_valid):
        return jsonify({
            'message': 'Invalid username or password'
        }), 401

    access_token = create_access_token(identity=username)

    return jsonify({
        'message': 'Login successful',
        'access_token': access_token,
        'token_type': 'Bearer',
        'expires_in': 1800
    }), 200


# GET /api/auth/me
@auth_bp.route('/me', methods=['GET'])
@jwt_required()
def get_current_user():
    username = get_jwt_identity()

    return jsonify({
        'username': username,
        'authenticated': True
    }), 200