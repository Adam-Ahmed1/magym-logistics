from flask import Blueprint

partner_bp = Blueprint('partner', __name__, template_folder='../../templates/partner')

from . import routes
