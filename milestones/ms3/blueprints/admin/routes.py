
from datetime import datetime
from decimal import Decimal, InvalidOperation

from flask import render_template, session, redirect, url_for, flash, request
from . import admin_bp
from auth import login_required, role_required
import db


# --------------------------------------------------
# HELPER: CHECK SUPER ADMIN
# --------------------------------------------------

def is_super_admin():
    return session.get('admin_role') == 'Super Admin'


# --------------------------------------------------
# ADMIN HOME
# --------------------------------------------------

@admin_bp.route('/home')
@login_required
@role_required('admin')
def home():
    return render_template('home.html')


# --------------------------------------------------
# BUSINESS APPROVALS
# --------------------------------------------------

@admin_bp.route('/business-approvals')
@login_required
@role_required('admin')
def business_approvals():
    pending_businesses = []

    try:
        pending_businesses = db.query_all(
            "SELECT * FROM dbo.PendingBusinessApprovals"
        )
    except Exception as e:
        print(f"Error loading pending businesses: {e}")
        flash(
            "Could not load pending businesses. Please check the database connection.",
            "error"
        )

    return render_template(
        'business_approvals.html',
        businesses=pending_businesses
    )


@admin_bp.route('/approve-business/<int:business_id>', methods=['POST'])
@login_required
@role_required('admin')
def approve_business(business_id):
    admin_id = session.get('user_id')

    try:
        result = db.call_proc(
            'Approve_Business',
            [business_id, admin_id]
        )

        if result == 0:
            flash("Business approved successfully!", "success")
        else:
            flash(
                "Could not approve this business. Check its status and your permissions.",
                "error"
            )

    except Exception as e:
        print(f"Error approving business: {e}")
        flash("An error occurred while approving the business.", "error")

    return redirect(url_for('admin.business_approvals'))


@admin_bp.route('/reject-business/<int:business_id>', methods=['POST'])
@login_required
@role_required('admin')
def reject_business(business_id):
    admin_id = session.get('user_id')

    try:
        result = db.call_proc(
            'Reject_Business',
            [business_id, admin_id]
        )

        if result == 0:
            flash("Business rejected successfully!", "success")
        else:
            flash(
                "Could not reject this business. Check its status and your permissions.",
                "error"
            )

    except Exception as e:
        print(f"Error rejecting business: {e}")
        flash("An error occurred while rejecting the business.", "error")

    return redirect(url_for('admin.business_approvals'))


# --------------------------------------------------
# BUSINESS MANAGEMENT
# --------------------------------------------------

@admin_bp.route('/business-management')
@login_required
@role_required('admin')
def business_management():
    businesses = []

    try:
        businesses = db.query_all(
            "SELECT * FROM dbo.allBusinessProfiles"
        )
    except Exception as e:
        print(f"Error loading businesses: {e}")
        flash(
            "Could not load businesses. Please check the database connection.",
            "error"
        )

    return render_template(
        'business_management.html',
        businesses=businesses
    )


# --------------------------------------------------
# SUSPEND BUSINESS - SUPER ADMIN ONLY
# --------------------------------------------------

@admin_bp.route('/suspend-business/<int:business_id>', methods=['POST'])
@login_required
@role_required('admin')
def suspend_business(business_id):

    if not is_super_admin():
        flash("Only Super Admins can suspend businesses.", "error")
        return redirect(url_for('admin.business_management'))

    admin_id = session.get('user_id')
    reason = request.form.get('reason', '').strip()

    if not reason:
        flash("Please provide a reason for suspension.", "error")
        return redirect(url_for('admin.business_management'))

    if len(reason) > 255:
        flash("The suspension reason cannot exceed 255 characters.", "error")
        return redirect(url_for('admin.business_management'))

    try:
        result = db.call_proc(
            'Suspend_Business',
            [business_id, admin_id, reason]
        )

        if result == 0:
            flash("Business suspended successfully.", "success")
        else:
            flash(
                "Could not suspend this business. Check its status and permissions.",
                "error"
            )

    except Exception as e:
        print(f"Error suspending business: {e}")
        flash("An error occurred while suspending the business.", "error")

    return redirect(url_for('admin.business_management'))


# --------------------------------------------------
# REINSTATE BUSINESS - SUPER ADMIN ONLY
# --------------------------------------------------

@admin_bp.route('/reinstate-business/<int:business_id>', methods=['POST'])
@login_required
@role_required('admin')
def reinstate_business(business_id):

    if not is_super_admin():
        flash("Only Super Admins can reinstate businesses.", "error")
        return redirect(url_for('admin.business_management'))

    super_admin_id = session.get('user_id')

    try:
        result = db.call_proc(
            'Reinstate_Business',
            [business_id, super_admin_id]
        )

        if result == 0:
            flash("Business reinstated successfully.", "success")
        else:
            flash(
                "Could not reinstate this business. Check its status and permissions.",
                "error"
            )

    except Exception as e:
        print(f"Error reinstating business: {e}")
        flash("An error occurred while reinstating the business.", "error")

    return redirect(url_for('admin.business_management'))


# --------------------------------------------------
# ADMIN MANAGEMENT PAGE - SUPER ADMIN ONLY
# --------------------------------------------------

@admin_bp.route('/admin-management')
@login_required
@role_required('admin')
def admin_management():

    if not is_super_admin():
        flash("Only Super Admins can access Admin Management.", "error")
        return redirect(url_for('admin.home'))

    zones = []
    zone_admins = []

    try:
        zones = db.query_all(
            """
            SELECT zone_id, zone_name
            FROM dbo.Zone
            ORDER BY zone_name
            """
        )

        zone_admins = db.query_all(
            """
            SELECT
                a.admin_id,
                u.first_name,
                u.last_name,
                u.username,
                a.zone_id,
                z.zone_name
            FROM dbo.Admin a
            INNER JOIN dbo.Users u
                ON a.admin_id = u.user_id
            LEFT JOIN dbo.Zone z
                ON a.zone_id = z.zone_id
            WHERE a.role = 'Zone Admin'
            ORDER BY u.first_name, u.last_name
            """
        )

    except Exception as e:
        print(f"Error loading admin management data: {e}")
        flash(
            "Could not load zones or administrators. Please check the database connection.",
            "error"
        )

    return render_template(
        'admin_management.html',
        zones=zones,
        zone_admins=zone_admins
    )


# --------------------------------------------------
# CREATE ADMIN - SUPER ADMIN ONLY
# --------------------------------------------------

@admin_bp.route('/create-admin', methods=['POST'])
@login_required
@role_required('admin')
def create_admin():

    if not is_super_admin():
        flash("Only Super Admins can create administrators.", "error")
        return redirect(url_for('admin.home'))

    first_name = request.form.get('first_name', '').strip()
    middle_name = request.form.get('middle_name', '').strip() or None
    last_name = request.form.get('last_name', '').strip()
    username = request.form.get('username', '').strip()
    password = request.form.get('password', '')
    email = request.form.get('email', '').strip()
    phone = request.form.get('phone', '').strip()
    dob_input = request.form.get('dob', '').strip()
    role = request.form.get('role', '').strip()
    zone_input = request.form.get('zone_id', '').strip()

    if not first_name or not last_name or not username or not password:
        flash("Please fill in all required name and login fields.", "error")
        return redirect(url_for('admin.admin_management'))

    if not email or not phone or not role:
        flash("Please fill in all required fields.", "error")
        return redirect(url_for('admin.admin_management'))

    if len(phone) != 11 or not phone.isdigit():
        flash("Phone number must contain exactly 11 digits.", "error")
        return redirect(url_for('admin.admin_management'))

    if role not in ('Super Admin', 'Zone Admin'):
        flash("Please select a valid admin role.", "error")
        return redirect(url_for('admin.admin_management'))

    if role == 'Zone Admin' and not zone_input:
        flash("Please select a zone for the Zone Admin.", "error")
        return redirect(url_for('admin.admin_management'))

    if role == 'Super Admin' and zone_input:
        flash("A Super Admin cannot be assigned to a zone.", "error")
        return redirect(url_for('admin.admin_management'))

    try:
        dob = datetime.strptime(dob_input, '%Y-%m-%d').date() if dob_input else None
        zone_id = int(zone_input) if zone_input else None

        result = db.call_proc(
            'Create_Admin',
            [
                first_name,
                middle_name,
                last_name,
                username,
                password,
                email,
                phone,
                dob,
                role,
                zone_id,
                session.get('user_id')
            ]
        )

        if result == 0:
            flash("New admin created successfully!", "success")
        elif result == -2:
            flash("This username or email is already registered.", "error")
        elif result == -3:
            flash("You are not authorized to create administrators.", "error")
        else:
            flash("Could not create admin. Please check the entered information.", "error")

    except ValueError:
        flash("Please enter a valid date of birth or zone.", "error")
    except Exception as e:
        print(f"Error creating admin: {e}")
        flash("An error occurred while creating the admin.", "error")

    return redirect(url_for('admin.admin_management'))


# --------------------------------------------------
# ASSIGN / MOVE ZONE ADMIN - SUPER ADMIN ONLY
# --------------------------------------------------

@admin_bp.route('/assign-admin-zone', methods=['POST'])
@login_required
@role_required('admin')
def assign_admin_zone():

    if not is_super_admin():
        flash("Only Super Admins can assign administrator zones.", "error")
        return redirect(url_for('admin.home'))

    admin_input = request.form.get('admin_id', '').strip()
    zone_input = request.form.get('zone_id', '').strip()

    try:
        admin_id = int(admin_input)
        zone_id = int(zone_input)

        result = db.call_proc(
            'Assign_Admin_Zone',
            [
                admin_id,
                zone_id,
                session.get('user_id')
            ]
        )

        if result == 0:
            flash("Zone Admin's assigned zone updated successfully!", "success")
        elif result == -3:
            flash("You are not authorized to assign administrator zones.", "error")
        else:
            flash(
                "Could not assign this zone. Check the selected administrator and zone.",
                "error"
            )

    except ValueError:
        flash("Please select a valid administrator and zone.", "error")
    except Exception as e:
        print(f"Error assigning admin zone: {e}")
        flash("An error occurred while assigning the zone.", "error")

    return redirect(url_for('admin.admin_management'))


# --------------------------------------------------
# VOUCHER MANAGEMENT PAGE - ALL ADMINS
# --------------------------------------------------

@admin_bp.route('/voucher-management')
@login_required
@role_required('admin')
def voucher_management():

    customers = []
    vouchers = []

    try:
        customers = db.query_all(
            """
            SELECT
                c.customer_id,
                u.first_name,
                u.last_name
            FROM dbo.Customer c
            INNER JOIN dbo.Users u
                ON c.customer_id = u.user_id
            WHERE u.account_status = 'Active'
            ORDER BY u.first_name, u.last_name
            """
        )

        vouchers = db.query_all(
            """
            SELECT *
            FROM dbo.ActiveVouchers
            ORDER BY expiry_date
            """
        )

    except Exception as e:
        print(f"Error loading voucher management data: {e}")
        flash(
            "Could not load customers or vouchers. Please check the database connection.",
            "error"
        )

    return render_template(
        'voucher_management.html',
        customers=customers,
        vouchers=vouchers
    )


# --------------------------------------------------
# ISSUE VOUCHER - ALL ADMINS
# --------------------------------------------------

@admin_bp.route('/issue-voucher', methods=['POST'])
@login_required
@role_required('admin')
def issue_voucher():

    customer_input = request.form.get('customer_id', '').strip()
    promo_code = request.form.get('promo_code', '').strip()
    percentage_input = request.form.get('is_percentage', '').strip()
    amount_input = request.form.get('amount', '').strip()
    expiry_input = request.form.get('expiry_date', '').strip()

    if not customer_input or not promo_code or not percentage_input:
        flash("Please fill in all required voucher fields.", "error")
        return redirect(url_for('admin.voucher_management'))

    if percentage_input not in ('0', '1'):
        flash("Please select a valid discount type.", "error")
        return redirect(url_for('admin.voucher_management'))

    if len(promo_code) > 30:
        flash("Promo code cannot exceed 30 characters.", "error")
        return redirect(url_for('admin.voucher_management'))

    try:
        customer_id = int(customer_input)
        is_percentage = int(percentage_input)
        amount = Decimal(amount_input)
        expiry_date = datetime.strptime(expiry_input, '%Y-%m-%d').date()

        if amount <= 0:
            flash("Discount amount must be greater than zero.", "error")
            return redirect(url_for('admin.voucher_management'))

        if is_percentage == 1 and (amount < 1 or amount > 100):
            flash("Percentage discount must be between 1 and 100.", "error")
            return redirect(url_for('admin.voucher_management'))

        if expiry_date < datetime.today().date():
            flash("Expiry date cannot be in the past.", "error")
            return redirect(url_for('admin.voucher_management'))

        result = db.call_proc(
            'Issue_Voucher',
            [
                customer_id,
                promo_code,
                is_percentage,
                amount,
                expiry_date,
                session.get('user_id')
            ]
        )

        if result == 0:
            flash("Voucher issued successfully!", "success")
        elif result == -2:
            flash("This promo code already exists. Please choose another.", "error")
        elif result == -3:
            flash(
                "The selected customer is invalid, blacklisted, or your admin account is invalid.",
                "error"
            )
        else:
            flash("Could not issue voucher. Please check the entered information.", "error")

    except (ValueError, InvalidOperation):
        flash("Please enter valid customer, amount and expiry date values.", "error")
    except Exception as e:
        print(f"Error issuing voucher: {e}")
        flash("An error occurred while issuing the voucher.", "error")

    return redirect(url_for('admin.voucher_management'))


# --------------------------------------------------
# CUSTOMER BLACKLIST PAGE - ALL ADMINS
# --------------------------------------------------

@admin_bp.route('/customer-blacklist')
@login_required
@role_required('admin')
def customer_blacklist():

    customers = []
    blacklisted_customers = []

    try:

        if is_super_admin():

            customers = db.query_all(
                """
                SELECT
                    c.customer_id,
                    u.first_name,
                    u.last_name
                FROM dbo.Customer c
                INNER JOIN dbo.Users u
                    ON c.customer_id = u.user_id
                WHERE u.account_status = 'Active'
                ORDER BY u.first_name, u.last_name
                """
            )

            blacklisted_customers = db.query_all(
                """
                SELECT
                    c.customer_id,
                    u.first_name,
                    u.last_name,
                    u.username,
                    u.account_status,
                    b.admin_id,
                    b.reason
                FROM dbo.Blacklist b
                INNER JOIN dbo.Customer c
                    ON b.customer_id = c.customer_id
                INNER JOIN dbo.Users u
                    ON c.customer_id = u.user_id
                ORDER BY u.first_name, u.last_name
                """
            )

        else:

            zone_id = session.get('admin_zone_id')

            if zone_id is None:
                flash(
                    "Your account does not have an assigned zone. Please contact a Super Admin.",
                    "error"
                )

            else:

                customers = db.query_all(
                    """
                    SELECT
                        c.customer_id,
                        u.first_name,
                        u.last_name
                    FROM dbo.Customer c
                    INNER JOIN dbo.Users u
                        ON c.customer_id = u.user_id
                    WHERE u.account_status = 'Active'
                      AND EXISTS (
                          SELECT 1
                          FROM dbo.Address a
                          WHERE a.customer_id = c.customer_id
                            AND a.zone_id = ?
                      )
                    ORDER BY u.first_name, u.last_name
                    """,
                    [zone_id]
                )

                blacklisted_customers = db.query_all(
                    """
                    SELECT
                        c.customer_id,
                        u.first_name,
                        u.last_name,
                        u.username,
                        u.account_status,
                        b.admin_id,
                        b.reason
                    FROM dbo.Blacklist b
                    INNER JOIN dbo.Customer c
                        ON b.customer_id = c.customer_id
                    INNER JOIN dbo.Users u
                        ON c.customer_id = u.user_id
                    WHERE EXISTS (
                        SELECT 1
                        FROM dbo.Address a
                        WHERE a.customer_id = c.customer_id
                          AND a.zone_id = ?
                    )
                    ORDER BY u.first_name, u.last_name
                    """,
                    [zone_id]
                )

    except Exception as e:
        print(f"Error loading customer blacklist data: {e}")
        flash(
            "Could not load customer blacklist data. Please check the database connection.",
            "error"
        )

    return render_template(
        'customer_blacklist.html',
        customers=customers,
        blacklisted_customers=blacklisted_customers
    )


# --------------------------------------------------
# BLACKLIST CUSTOMER - ALL ADMINS
# --------------------------------------------------

@admin_bp.route('/blacklist-customer', methods=['POST'])
@login_required
@role_required('admin')
def blacklist_customer():

    customer_input = request.form.get('customer_id', '').strip()
    reason = request.form.get('reason', '').strip()

    if not customer_input or not reason:
        flash("Please select a customer and provide a reason.", "error")
        return redirect(url_for('admin.customer_blacklist'))

    if len(reason) > 255:
        flash("The reason cannot exceed 255 characters.", "error")
        return redirect(url_for('admin.customer_blacklist'))

    try:
        customer_id = int(customer_input)

        result = db.call_proc(
            'Blacklist_Customer',
            [
                customer_id,
                session.get('user_id'),
                reason
            ]
        )

        if result == 0:
            flash("Customer blacklisted successfully.", "success")
        elif result == -3:
            flash(
                "You are not authorized to blacklist this customer, or the customer does not exist.",
                "error"
            )
        elif result == -4:
            flash("This customer is already blacklisted.", "error")
        else:
            flash("Could not blacklist this customer. Please check the entered information.", "error")

    except ValueError:
        flash("Please select a valid customer.", "error")
    except Exception as e:
        print(f"Error blacklisting customer: {e}")
        flash("An error occurred while blacklisting the customer.", "error")

    return redirect(url_for('admin.customer_blacklist'))


# --------------------------------------------------
# LIFT CUSTOMER BLACKLIST - ORIGINAL ADMIN ONLY
# --------------------------------------------------

@admin_bp.route(
    '/lift-customer-blacklist/<int:customer_id>',
    methods=['POST']
)
@login_required
@role_required('admin')
def lift_customer_blacklist(customer_id):

    try:
        result = db.call_proc(
            'Lift_Customer_Blacklist',
            [
                customer_id,
                session.get('user_id')
            ]
        )

        if result == 0:
            flash("Customer blacklist lifted successfully. Account restored.", "success")
        elif result == -4:
            flash("This customer is not currently blacklisted.", "error")
        elif result == -3:
            flash(
                "Only the admin who originally blacklisted this customer can lift the blacklist.",
                "error"
            )
        else:
            flash("Could not lift this customer's blacklist.", "error")

    except Exception as e:
        print(f"Error lifting customer blacklist: {e}")
        flash("An error occurred while restoring the customer account.", "error")

    return redirect(url_for('admin.customer_blacklist'))
