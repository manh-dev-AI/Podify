"""Entry point for the Podify Flask backend."""

import os

from dotenv import load_dotenv
from flask import Flask, jsonify
from flask_cors import CORS

load_dotenv()


def create_app() -> Flask:
    """Create and configure the Flask application."""
    app = Flask(__name__)
    app.config["SECRET_KEY"] = os.getenv("SECRET_KEY", "dev-secret-key")
    CORS(app)

    @app.get("/api/health")
    def health_check():
        return jsonify({"status": "ok", "service": "podify-backend"}), 200

    # TODO: Register module blueprints here once implemented:
    # from modules.content import content_bp
    # from modules.listening import listening_bp
    # from modules.analytics import analytics_bp

    return app


app = create_app()

if __name__ == "__main__":
    host = os.getenv("FLASK_HOST", "127.0.0.1")
    port = int(os.getenv("FLASK_PORT", "5000"))
    debug = os.getenv("FLASK_DEBUG", "True").lower() == "true"
    app.run(host=host, port=port, debug=debug)

