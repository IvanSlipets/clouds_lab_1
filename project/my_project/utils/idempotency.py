import hashlib
import json
import re
from functools import wraps

from flask import current_app, jsonify, make_response, request
from flask_jwt_extended import get_jwt_identity
from redis import Redis, RedisError


_IDEMPOTENCY_KEY_PATTERN = re.compile(r'^[A-Za-z0-9._:-]{8,128}$')
_TTL_SECONDS = 24 * 60 * 60


def _fingerprint(body):
    canonical = json.dumps(
        body,
        sort_keys=True,
        ensure_ascii=False,
        separators=(',', ':')
    )
    return hashlib.sha256(canonical.encode('utf-8')).hexdigest()


def _client():
    client = current_app.extensions.get('idempotency_redis')

    if client is None:
        client = Redis.from_url(
            current_app.config['IDEMPOTENCY_REDIS_URL'],
            decode_responses=True,
            socket_connect_timeout=2,
            socket_timeout=2,
            retry_on_timeout=False,
        )
        current_app.extensions['idempotency_redis'] = client

    return client


def idempotent(func):
    @wraps(func)
    def wrapped(*args, **kwargs):
        request_key = request.headers.get('Idempotency-Key')

        if request_key is None:
            return func(*args, **kwargs)

        if not _IDEMPOTENCY_KEY_PATTERN.fullmatch(request_key):
            return jsonify({
                'message': (
                    'Idempotency-Key must contain 8-128 '
                    'ASCII letters, digits or . _ : -'
                )
            }), 400

        identity = str(get_jwt_identity())

        scope = (
            f'{identity}:{request.method}:'
            f'{request.path}:{request_key}'
        )

        redis_key = (
            'idempotency:v1:'
            + hashlib.sha256(scope.encode()).hexdigest()
        )

        fingerprint = _fingerprint(
            request.get_json(silent=True)
        )

        pending = json.dumps({
            'fingerprint': fingerprint,
            'state': 'processing'
        })

        try:
            client = _client()

            claimed = client.set(
                redis_key,
                pending,
                ex=_TTL_SECONDS,
                nx=True
            )

            if not claimed:
                previous_raw = client.get(redis_key)

                if previous_raw is None:
                    return jsonify({
                        'message': 'Retry this request'
                    }), 409

                previous = json.loads(previous_raw)

                if previous.get('fingerprint') != fingerprint:
                    return jsonify({
                        'message': (
                            'Idempotency-Key reused '
                            'with different request data'
                        )
                    }), 409

                if previous.get('state') == 'completed':
                    replay = make_response(
                        jsonify(previous['body']),
                        previous['status']
                    )

                    if previous.get('location'):
                        replay.headers['Location'] = (
                            previous['location']
                        )

                    replay.headers['Idempotency-Replayed'] = 'true'
                    return replay

                response = jsonify({
                    'message': 'This request is still processing'
                })
                response.status_code = 409
                response.headers['Retry-After'] = '1'
                return response

        except (RedisError, ValueError, KeyError):
            current_app.logger.exception(
                'Redis idempotency claim failed'
            )
            return jsonify({
                'message': 'Idempotency storage unavailable'
            }), 503

        try:
            response = make_response(
                func(*args, **kwargs)
            )

        except Exception:
            try:
                client.delete(redis_key)
            except RedisError:
                current_app.logger.exception(
                    'Could not delete idempotency claim'
                )
            raise

        if not 200 <= response.status_code < 300:
            try:
                client.delete(redis_key)
            except RedisError:
                current_app.logger.exception(
                    'Could not delete failed idempotency claim'
                )
            return response

        record = {
            'fingerprint': fingerprint,
            'state': 'completed',
            'status': response.status_code,
            'body': response.get_json(silent=True),
            'location': response.headers.get('Location'),
        }

        try:
            client.set(
                redis_key,
                json.dumps(record),
                ex=_TTL_SECONDS,
                xx=True
            )

        except RedisError:
            current_app.logger.exception(
                'Cannot save idempotency replay result'
            )
            return jsonify({
                'message': (
                    'Write completed, '
                    'but replay storage failed'
                )
            }), 503

        response.headers['Idempotency-Replayed'] = 'false'
        return response

    return wrapped
