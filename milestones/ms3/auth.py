
from functools import wraps
from flask import Blueprint, render_template, request, redirect, url_for, session, flash
import db
import error_codes

auth_bp = Blueprint('auth', __name__)

LOGIN_FUNCS = {
    'admin': 'AdminLoginValidation',
    'customer': 'CustomerLoginValidation',
    'partner': 'PartnerLoginValidation',
    'rider': 'RiderLoginValidation'
}

ROLE_LABELS = {
    'admin': 'Admin',
    'customer': 'Customer',
    'partner': 'Partner',
    'rider': 'Rider'
}


# Access control decorators
def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            flash("Please log in to access this page.", "error")
            return redirect(url_for('landing'))

        return f(*args, **kwargs)

    return decorated_function


def role_required(*allowed_roles):
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            if 'user_id' not in session:
                flash("Please log in to access this page.", "error")
                return redirect(url_for('landing'))

            user_role = session.get('role')

            if user_role not in allowed_roles:
                flash("You are not authorized to view this page.", "error")

                if user_role in ROLE_LABELS:
                    return redirect(url_for(f'{user_role}.home'))

                return redirect(url_for('landing'))

            return f(*args, **kwargs)

        return decorated_function

    return decorator


@auth_bp.route('/login/<role>', methods=['GET', 'POST'])
def login(role):
    role = role.lower()

    if role not in LOGIN_FUNCS:
        flash("Invalid user role specified.", "error")
        return redirect(url_for('landing'))

    role_label = ROLE_LABELS.get(role, role.capitalize())

    if request.method == 'POST':
        username = request.form.get('username', '').strip()

        # Do not strip passwords; spaces may be part of the password.
        password = request.form.get('password', '')

        if not username or not password:
            flash("Please provide both username and password.", "error")
            return render_template(
                'login.html',
                role=role,
                role_label=role_label
            )

        login_func = LOGIN_FUNCS[role]
        is_valid = db.call_func(login_func, [username, password])

        if is_valid == 1:
            user_id = db.call_func("h_GetUserId", [username])

            if user_id is None:
                user_record = db.query_one(
                    "SELECT user_id FROM dbo.Users WHERE username = ?",
                    [username]
                )
                user_id = user_record['user_id'] if user_record else None

            if user_id is None:
                flash("Unable to retrieve your account information.", "error")
                return render_template(
                    'login.html',
                    role=role,
                    role_label=role_label
                )

            user_info = db.query_one(
                """
                SELECT first_name, last_name, email
                FROM dbo.Users
                WHERE user_id = ?
                """,
                [user_id]
            )

            if not user_info:
                flash("Unable to retrieve your account information.", "error")
                return render_template(
                    'login.html',
                    role=role,
                    role_label=role_label
                )

            session.clear()
            session['user_id'] = user_id
            session['username'] = username
            session['role'] = role
            session['first_name'] = user_info['first_name']
            session['last_name'] = user_info['last_name']

            if role == 'admin':
                admin_info = db.query_one(
                    """
                    SELECT
                        a.role AS admin_role,
                        a.zone_id,
                        z.zone_name
                    FROM dbo.Admin a
                    LEFT JOIN dbo.Zone z
                        ON a.zone_id = z.zone_id
                    WHERE a.admin_id = ?
                    """,
                    [user_id]
                )

                if not admin_info:
                    session.clear()
                    flash("Admin account information could not be found.", "error")
                    return render_template(
                        'login.html',
                        role=role,
                        role_label=role_label
                    )

                session['admin_role'] = admin_info['admin_role']
                session['admin_zone_id'] = admin_info['zone_id']
                session['admin_zone_name'] = admin_info['zone_name']

            flash("Signed in successfully.", "success")
            return redirect(url_for(f'{role}.home'))

        flash("Wrong username or password.", "error")

    return render_template(
        'login.html',
        role=role,
        role_label=role_label
    )


@auth_bp.route('/register/<role>', methods=['GET', 'POST'])
def register(role):
    role = role.lower()

    if role not in ['customer', 'partner', 'rider']:
        flash("Registration is not available for this role.", "error")
        return redirect(url_for('landing'))

    role_label = ROLE_LABELS.get(role, role.capitalize())

    zones = []

    if role == 'rider':
        zones = db.query_all(
            "SELECT zone_id, zone_name FROM dbo.Zone ORDER BY zone_name"
        )

    if request.method == 'POST':
        first_name = request.form.get('first_name', '').strip()
        middle_name = request.form.get('middle_name', '').strip() or None
        last_name = request.form.get('last_name', '').strip()
        username = request.form.get('username', '').strip()
        email = request.form.get('email', '').strip()

        # Do not strip passwords; spaces may be part of the password.
        password = request.form.get('password', '')

        phone = request.form.get('phone', '').strip()
        dob = request.form.get('dob', '').strip() or None

        rc = -1

        if role == 'customer':
            rc = db.call_proc("Customer_Register", [
                first_name,
                middle_name,
                last_name,
                username,
                password,
                email,
                phone,
                dob
            ])

        elif role == 'partner':
            rc = db.call_proc("Partner_Register", [
                first_name,
                middle_name,
                last_name,
                username,
                password,
                email,
                phone,
                dob
            ])

        elif role == 'rider':
            vehicle_type = request.form.get(
                'vehicle_type', 'Motorcycle'
            ).strip()

            plate_no = (
                request.form.get('plate_no', '').strip()
                or request.form.get('plate_number', '').strip()
            )

            license_no = (
                request.form.get('license_no', '').strip()
                or f"LIC-{username}"
            )

            zone_id = request.form.get('zone_id')

            try:
                zone_id = int(zone_id) if zone_id else None
            except ValueError:
                zone_id = None

            rc = db.call_proc("Rider_Register", [
                first_name,
                middle_name,
                last_name,
                username,
                password,
                email,
                phone,
                dob,
                vehicle_type,
                plate_no,
                license_no,
                zone_id
            ])

        if rc == 0:
            flash(
                "Account registered successfully. Please log in.",
                "success"
            )
            return redirect(url_for('auth.login', role=role))

        flash(error_codes.get_message(rc, {
            -1: "Some details are missing or invalid. Fill in first name, last name, username, "
                "password and email, use an 11-digit phone number and a birth date in the past.",
            -2: "This username or email is already taken. Choose another one, or log in instead."
                if role != 'rider' else
                "This username, email, plate number or license number is already registered. "
                "Check them and try again.",
        }), "error")

    return render_template(
        'register.html',
        role=role,
        role_label=role_label,
        zones=zones
    )


@auth_bp.route('/logout')
def logout():
    session.clear()
    flash("You have been logged out.", "info")
    return redirect(url_for('landing'))
