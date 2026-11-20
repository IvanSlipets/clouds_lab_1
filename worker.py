import json
import logging
import os
import signal
import time

import boto3

from botocore.exceptions import BotoCoreError, ClientError
from sqlalchemy.exc import IntegrityError, SQLAlchemyError

from app import create_app

from project.my_project.auth.domain.async_job import AsyncJob
from project.my_project.auth.domain.sport import Sport
from project.my_project.utils.db_init import db


logging.basicConfig(level=logging.INFO)

logger = logging.getLogger('sqs-worker')

shutdown_requested = False


def handle_signal(signum, frame):
    global shutdown_requested

    shutdown_requested = True

    logger.info(
        'Signal %s received, finishing current job',
        signum
    )


def process_message(message):
    """
    Returns True if the SQS message may be deleted.
    """

    try:
        envelope = json.loads(message['Body'])
        job_id = envelope['job_id']

    except (KeyError, ValueError, TypeError):
        logger.exception('Invalid SQS message')
        return True

    # Штучна затримка для демонстрації масштабування.
    delay = max(
        0,
        min(
            15,
            float(os.getenv('WORKER_DELAY_SECONDS', '3'))
        )
    )

    time.sleep(delay)

    try:
        # SELECT FOR UPDATE запобігає одночасній обробці одного завдання кількома worker.
        job = (
            db.session.query(AsyncJob)
            .filter_by(job_id=job_id)
            .with_for_update()
            .one_or_none()
        )

        if job is None:
            logger.warning(
                'No job row for ID %s',
                job_id
            )

            db.session.rollback()
            return True

        if job.status in ('completed', 'failed'):
            db.session.rollback()

            logger.info(
                'Job %s already processed',
                job_id
            )

            return True

        if job.job_type != 'create_sport':
            job.status = 'failed'

            job.result = {
                'error': 'Unsupported job type'
            }

            job.finished_at = db.func.current_timestamp()

            db.session.commit()
            return True

        # Створення запису в MySQL.
        sport = Sport(**job.payload)

        db.session.add(sport)
        db.session.flush()

        job.result = {
            'sport_id': sport.sport_id,
            'name': sport.name
        }

        job.status = 'completed'
        job.finished_at = db.func.current_timestamp()

        # Створення Sport та оновлення AsyncJob виконуються в одній транзакції.
        db.session.commit()

        logger.info(
            'Completed job=%s sport_id=%s',
            job_id,
            sport.sport_id
        )

        return True

    except IntegrityError:
        db.session.rollback()

        logger.exception(
            'Invalid or duplicate sport name for %s',
            job_id
        )

        job = db.session.get(AsyncJob, job_id)

        if job is not None:
            job.status = 'failed'

            job.result = {
                'error': (
                    'Sport data violates '
                    'database constraints'
                )
            }

            job.finished_at = db.func.current_timestamp()

            db.session.commit()

        return True

    except SQLAlchemyError:
        db.session.rollback()

        logger.exception(
            'Transient database error for %s',
            job_id
        )

        # False означає: не видаляти повідомлення, щоб SQS могла повторити доставку.
        return False


def main():

    queue_url = os.environ['SQS_QUEUE_URL']

    region = os.environ.get(
        'AWS_REGION',
        'eu-north-1'
    )

    sqs = boto3.client(
        'sqs',
        region_name=region
    )

    app = create_app()

    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)

    logger.info(
        'Worker started. Queue=%s',
        queue_url
    )

    while not shutdown_requested:

        try:
            result = sqs.receive_message(
                QueueUrl=queue_url,
                MaxNumberOfMessages=1,
                WaitTimeSeconds=10,
                VisibilityTimeout=120
            )

            for message in result.get('Messages', []):

                with app.app_context():
                    should_ack = process_message(message)

                if should_ack:
                    sqs.delete_message(
                        QueueUrl=queue_url,
                        ReceiptHandle=message['ReceiptHandle']
                    )

        except (BotoCoreError, ClientError):
            logger.exception('SQS error, retrying')
            time.sleep(3)

        except SQLAlchemyError:
            logger.exception('SQL error, retrying')
            time.sleep(3)

    logger.info('Worker stopped')


if __name__ == '__main__':
    main()
