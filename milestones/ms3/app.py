from flask import Flask, render_template
from config import Config

from auth import auth_bp
from blueprints.admin import admin_bp
from blueprints.partner import partner_bp
from blueprints.rider import rider_bp
from blueprints.customer import customer_bp


def create_app():
    app = Flask(__name__)
    app.config.from_object(Config)

    # Register authentication blueprint at root level (/login, /register, /logout)
    app.register_blueprint(auth_bp)

    # Register role-specific blueprints with their respective URL prefixes
    app.register_blueprint(admin_bp, url_prefix='/admin')
    app.register_blueprint(partner_bp, url_prefix='/partner')
    app.register_blueprint(rider_bp, url_prefix='/rider')
    app.register_blueprint(customer_bp, url_prefix='/customer')

    @app.route('/')
    def landing():
        return render_template('landing.html')

    @app.errorhandler(404)
    def page_not_found(e):
        return render_template('landing.html'), 404

    return app


app = create_app()

if __name__ == '__main__':
    app.run(debug=True, port=5000)
