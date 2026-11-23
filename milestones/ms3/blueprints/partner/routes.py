# Partner routes — Section 3.4 (a–d)
from flask import render_template, session, redirect, url_for
from . import partner_bp


@partner_bp.route('/home')
def home():
    return render_template('home.html')
