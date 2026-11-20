import json
import os
import uuid

import boto3
from botocore.exceptions import BotoCoreError, ClientError

from flask import Blueprint, jsonify, request
from marshmallow import ValidationError

from project.my_project.auth.domain.async_job import AsyncJob
from project.my_project.auth.domain.sport_dto import SportDTO
from project.my_project.utils.db_init import db
from project.my_project.utils.idempotency import idempotent


jobs_bp = Blueprint('jobs', __name__)

sport_dto = SportDTO()


@jobs_bp.route('/sports', methods=['POST'])
@idempotent
def queue_sport_creation():

    data = request.get_json(silent=True)

    if not isinstance(data, dict):
        return jsonify({
            'message': 'A JSON object is required'
        }), 400

    try:
        payload = sport_dto.load(data)

    except ValidationError as exc:
        return jsonify({
            'message': 'Invalid sport data',
            'errors': exc.messages
        }), 400

    queue_url = os.getenv('SQS_QUEUE_URL', '')

    if not queue_url:
        return jsonify({
            'message': 'Async queue is not configured'
        }), 503

    job_id = str(uuid.uuid4())

    job = AsyncJob(
        job_id=job_id,
        job_type='create_sport',
        status='queued',
        payload=payload,
    )

    db.session.add(job)
    db.session.commit()

    try:
        sqs = boto3.client(
            'sqs',
            region_name=os.environ.get(
                'AWS_REGION', 'eu-north-1'
            )
        )

        sqs.send_message(
            QueueUrl=queue_url,
            MessageBody=json.dumps({
                'job_id': job_id,
                'type': 'create_sport'
            }),
        )

    except (BotoCoreError, ClientError):
        db.session.delete(job)
        db.session.commit()

        return jsonify({
            'message': 'Unable to enqueue the job'
        }), 503

    location = f'/api/jobs/{job_id}'

    return jsonify({
        'job_id': job_id,
        'status': 'queued',
        'status_url': location,
    }), 202, {'Location': location}


@jobs_bp.route('/<string:job_id>', methods=['GET'])
def get_job(job_id):

    job = db.session.get(AsyncJob, job_id)

    if job is None:
        return jsonify({
            'message': 'Job not found'
        }), 404

    return jsonify({
        'job_id': job.job_id,
        'status': job.status,
        'result': job.result,

        'created_at': (
            job.created_at.isoformat()
            if job.created_at else None
        ),

        'finished_at': (
            job.finished_at.isoformat()
            if job.finished_at else None
        ),

    }), 200
