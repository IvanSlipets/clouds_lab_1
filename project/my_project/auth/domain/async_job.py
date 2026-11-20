from project.my_project.utils.db_init import db


class AsyncJob(db.Model):
    __tablename__ = 'async_jobs'

    job_id = db.Column(
        db.String(36),
        primary_key=True
    )

    job_type = db.Column(
        db.String(40),
        nullable=False
    )

    status = db.Column(
        db.String(20),
        nullable=False,
        default='queued'
    )

    payload = db.Column(
        db.JSON,
        nullable=False
    )

    result = db.Column(
        db.JSON,
        nullable=True
    )

    created_at = db.Column(
        db.DateTime,
        server_default=db.func.current_timestamp(),
        nullable=False
    )

    finished_at = db.Column(
        db.DateTime,
        nullable=True
    )