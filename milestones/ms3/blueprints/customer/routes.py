# Customer routes — Sections 3.5 and 3.6
from flask import render_template, session, redirect, url_for
from . import customer_bp


@customer_bp.route('/home')
def home():
    return render_template('home.html')
