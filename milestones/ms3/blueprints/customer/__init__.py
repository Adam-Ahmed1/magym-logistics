from flask import Blueprint

customer_bp = Blueprint('customer', __name__, template_folder='../../templates/customer')

from . import routes
from . import browse_routes  # Section 3.6: browsing, favorites, orders and feedback
