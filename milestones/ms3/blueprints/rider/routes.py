# Rider routes — Section 3.4 (e–g)
from flask import render_template, session, redirect, url_for
from . import rider_bp


@rider_bp.route('/home')
def home():
    return render_template('home.html')
