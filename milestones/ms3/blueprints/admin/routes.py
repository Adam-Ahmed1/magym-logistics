# Admin routes — Sections 3.2 and 3.3
from flask import render_template, session, redirect, url_for
from . import admin_bp


@admin_bp.route('/home')
def home():
    return render_template('home.html')
