"""Entry point for the Podify Flask backend and static frontend server."""

import os
from flask import Flask, jsonify, request
from flask_cors import CORS

from common.errors import register_error_handlers
from config import db
from config.settings import Settings
from modules import analytics_bp, content_bp, listening_bp

BACKEND_DIR = os.path.dirname(os.path.abspath(__file__))
FRONTEND_DIR = os.path.abspath(os.path.join(BACKEND_DIR, "..", "frontend"))


def create_app() -> Flask:
    """Create and configure the Flask application."""
    app = Flask(
        __name__,
        static_folder=FRONTEND_DIR,
        static_url_path="",
    )
    app.config["SECRET_KEY"] = Settings.SECRET_KEY
    CORS(app)
    register_error_handlers(app)

    @app.get("/")
    def serve_index():
        return app.send_static_file("index.html")

    @app.get("/api/health")
    def health_check():
        payload = {"status": "ok", "service": "podify-backend"}
        if request.args.get("db") == "1":
            payload["database"] = db.check_health()
        return jsonify(payload), 200

    app.register_blueprint(content_bp)
    app.register_blueprint(listening_bp)
    app.register_blueprint(analytics_bp)

    return app


app = create_app()

if __name__ == "__main__":
    app.run(
        host=Settings.FLASK_HOST,
        port=Settings.FLASK_PORT,
        debug=Settings.FLASK_DEBUG,
    )
