import os
import sys

from datetime import timedelta
from flask import Flask, request, jsonify
from flask_jwt_extended import JWTManager, verify_jwt_in_request
from ruamel.yaml import YAML
from sqlalchemy.engine import URL


project_root = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    'project'
)

if project_root not in sys.path:
    sys.path.append(project_root)


from project.my_project.auth.route.athlete_route import athlete_bp
from project.my_project.auth.route.sport_route import sport_bp
from project.my_project.auth.route.competition_route import competition_bp
from project.my_project.auth.route.procedure_route import procedure_bp
from project.my_project.auth.route.auth_route import auth_bp

from project.my_project.utils.db_init import db


def create_app():

    app = Flask(__name__)

    yaml = YAML()

    config_path = os.path.join(
        app.root_path,
        'project',
        'config',
        'app.yml'
    )

    with open(config_path, 'r') as f:
        config = yaml.load(f)

    app.config['SECRET_KEY'] = os.environ['FLASK_SECRET_KEY']
    app.config['DEBUG'] = False

    app.config['JWT_SECRET_KEY'] = os.environ['JWT_SECRET_KEY']
    app.config['JWT_ACCESS_TOKEN_EXPIRES'] = timedelta(minutes=30)
    app.config['JWT_TOKEN_LOCATION'] = ['headers']
    app.config['JWT_ALGORITHM'] = 'HS256'
    app.config['JWT_ERROR_MESSAGE_KEY'] = 'message'

    app.config['API_ADMIN_USERNAME'] = os.environ['API_ADMIN_USERNAME']
    app.config['API_ADMIN_PASSWORD'] = os.environ['API_ADMIN_PASSWORD']

    jwt = JWTManager(app)

    @jwt.invalid_token_loader
    def invalid_token_callback(reason):
        return jsonify({
            'message': 'Invalid JWT token'
        }), 401

    # Підключення MySQL
    db_config = config['database']

    db_url = URL.create(
        drivername='mysql+pymysql',
        username=os.getenv('DB_USER', db_config['user']),
        password=os.environ['DB_PASSWORD'],
        host=os.getenv('DB_HOST', db_config['host']),
        port=int(os.getenv('DB_PORT', db_config['port'])),
        database=os.getenv('DB_NAME', db_config['database_name'])
    )

    app.config['SQLALCHEMY_DATABASE_URI'] = db_url
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

    db.init_app(app)

    app.register_blueprint(
        athlete_bp, url_prefix='/api/athletes'
    )

    app.register_blueprint(
        sport_bp, url_prefix='/api/sports'
    )

    app.register_blueprint(
        competition_bp, url_prefix='/api/competitions'
    )

    app.register_blueprint(
        procedure_bp, url_prefix='/api/procedures'
    )

    app.register_blueprint(
        auth_bp, url_prefix='/api/auth'
    )

    # Захист усіх запитів, які змінюють дані
    @app.before_request
    def protect_api_writes():

        # Login повинен працювати без JWT
        if request.endpoint == 'auth.login':
            return

        protected_methods = {
            'POST',
            'PUT',
            'PATCH',
            'DELETE'
        }

        if (
            request.path.startswith('/api/')
            and request.method in protected_methods
        ):
            verify_jwt_in_request()

    # Ініціалізація таблиць у RDS
    if os.getenv('INIT_DB_SCHEMA', 'false').lower() == 'true':
        with app.app_context():
            db.create_all()

    # Health check
    @app.route('/health', methods=['GET'])
    def health_check():
        return {'status': 'ok'}, 200

    @app.route('/', methods=['GET'])
    def index():
        return {
            "name": "Sports Nutrition API",
            "status": "running",
            "environment": "AWS ECS Fargate",
            "endpoints": {
                "health": "/health",
                "sports": "/api/sports/",
                "athletes": "/api/athletes/",
                "competitions": "/api/competitions/",
                "auth": "/api/auth/login"
                }
                }, 200
    
    return app


if __name__ == '__main__':
    app = create_app()
    app.run(host='0.0.0.0', port=5000)