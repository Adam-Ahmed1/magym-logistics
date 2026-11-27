from flask import render_template, session, redirect, url_for, request, flash
from . import customer_bp
from auth import login_required, role_required
import db
import error_codes

def cid():
    return session['user_id']

@customer_bp.route('/home')
@login_required
@role_required('customer')
def home():
    return render_template('customer/home.html')
