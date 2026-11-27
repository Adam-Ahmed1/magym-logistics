# Customer routes — Section 3.6: browsing, favorites, orders and feedback.
#
# Every action calls the Milestone 2 procedure / function / view named under
# "Uses" in the Milestone 3 description:
#   a) Search_Platform, Nearby_Businesses_By_Category, BusinessRatingsSummary
#      (+ h_BusinessDetails, h_BusinessProducts for the business page)
#   b) Toggle_Favorite, My_Favorites, Recommended_Products
#   c) My_Order_History, ZoneDeliveryPerformance, h_OrderSubOrders
#   d) Cancel_Order, Reorder
#   e) Submit_Feedback, Rate_Rider
# Team helpers used here (Team_44.sql): h_ProductCategories, h_MyFavoriteBusinesses
#
# Kept in its own module so it does not clash with Section 3.5 work in routes.py.

import math
from datetime import datetime, timedelta
from decimal import Decimal

from flask import (current_app, flash, redirect, render_template, request,
                   session, url_for)

import db
import error_codes
from auth import login_required, role_required

from . import customer_bp


# ==================================================
# SMALL HELPERS
# ==================================================

# The journey of one part (sub-order) of an order.
PART_STEPS = ['Placed', 'Assigned', 'Picked Up', 'Delivered']

STEP_LABELS = {
    'Placed': 'Order placed',
    'Assigned': 'Rider assigned',
    'Picked Up': 'On the way',
    'Delivered': 'Delivered',
}

# Used when a zone has no finished deliveries yet to learn from.
MIN_PREP_MINUTES = 5


def _cid():
    return session.get('user_id')


def _profile(customer_id):
    rows = db.call_tvf('h_CustomerProfile', [customer_id])
    return rows[0] if rows else None


def _db_now():
    """The database clock, so estimates use the same clock as the stored times."""
    try:
        row = db.query_one("SELECT GETDATE() AS now")
        if row and row.get('now'):
            return row['now']
    except Exception as e:  # pragma: no cover - fallback only
        print(f"Could not read the database clock: {e}")
    return datetime.now()


def _safe_next(default_endpoint, **kwargs):
    """Return to the page the user came from, but only inside this site."""
    target = request.form.get('next') or request.args.get('next') or ''
    if target.startswith('/') and not target.startswith('//'):
        return redirect(target)
    return redirect(url_for(default_endpoint, **kwargs))


def _int(value):
    try:
        return int(str(value).strip())
    except (TypeError, ValueError):
        return None


def _favorite_business_ids(customer_id):
    rows = db.call_tvf('h_MyFavoriteBusinesses', [customer_id])
    return {r['business_id'] for r in rows}


def _favorite_product_ids(customer_id):
    rows = db.call_tvf('My_Favorites', [customer_id])
    return {r['product_id'] for r in rows}


def _business_ids_for(product_ids):
    """Map product_id -> business_id so product cards can link to their business."""
    product_ids = [p for p in product_ids if p is not None]
    if not product_ids:
        return {}
    placeholders = ", ".join(["?"] * len(product_ids))
    rows = db.query_all(
        f"SELECT product_id, business_id FROM dbo.Product WHERE product_id IN ({placeholders})",
        product_ids
    )
    return {r['product_id']: r['business_id'] for r in rows}


def _my_order(customer_id, order_id):
    """The order only if it belongs to the signed-in customer."""
    return db.query_one(
        "SELECT * FROM dbo.My_Order_History(?) WHERE order_id = ?",
        [customer_id, order_id]
    )


def _money(value):
    return Decimal(str(value or 0)).quantize(Decimal('0.01'))


# Jinja helpers available on every page --------------------------------------

@customer_bp.app_context_processor
def _inject_template_helpers():
    def has_endpoint(name):
        return name in current_app.view_functions
    return {'has_endpoint': has_endpoint, 'STEP_LABELS': STEP_LABELS, 'PART_STEPS': PART_STEPS}


@customer_bp.app_template_filter('egp')
def _egp_filter(value):
    try:
        return f"EGP {float(value or 0):,.2f}"
    except (TypeError, ValueError):
        return f"EGP {value}"


@customer_bp.app_template_filter('dt')
def _dt_filter(value, fmt='%d %b %Y, %I:%M %p'):
    if not value:
        return '—'
    if isinstance(value, str):
        return value
    return value.strftime(fmt)


@customer_bp.app_template_filter('hm')
def _hm_filter(value):
    """Format a TIME / datetime as 09:30 AM."""
    if value is None:
        return '—'
    if hasattr(value, 'strftime'):
        return value.strftime('%I:%M %p')
    return str(value)[:5]


# ==================================================
# DELIVERY ESTIMATE (3.6.c)
# ==================================================

def _zone_performance():
    """zone_name -> {delivery_count, avg_tracking_time} from ZoneDeliveryPerformance."""
    rows = db.query_all(
        "SELECT zone_id, zone_name, delivery_count, avg_tracking_time FROM dbo.ZoneDeliveryPerformance"
    )
    return {r['zone_name']: r for r in rows}


def _annotate_part(part, order, zone_row, now):
    """
    Adds progress and an estimated arrival to one part (sub-order).

    How the estimate works, using only data the database already has:
      * expected_delivery_time — what the business promises from order to door.
      * avg_tracking_time      — how long riders in the order's zone really take
                                 from pickup to door (ZoneDeliveryPerformance).
    Before pickup: arrival = assigned time + max(promise, zone ride + short prep).
    After pickup:  arrival = pickup time + zone ride (or the rest of the promise
                   when the zone has no finished deliveries yet).
    """
    p = dict(part)
    status = p.get('status')
    business = p.get('business_name') or 'the business'
    zone_name = order.get('zone_name')
    expected = int(p.get('expected_delivery_time') or 30)

    ride = None
    ride_count = 0
    if zone_row and zone_row.get('avg_tracking_time') is not None and (zone_row.get('delivery_count') or 0) > 0:
        ride = float(zone_row['avg_tracking_time'])
        ride_count = int(zone_row['delivery_count'])

    p['step_index'] = PART_STEPS.index(status) if status in PART_STEPS else -1
    p['is_cancelled'] = status == 'Cancelled'
    p['is_active'] = status in ('Placed', 'Assigned', 'Picked Up')
    p['eta'] = None
    p['eta_minutes'] = None
    p['eta_basis'] = None
    p['actual_minutes'] = None

    start = p.get('assigned_at') or order.get('order_date')

    if status in ('Placed', 'Assigned') and start:
        if ride is not None:
            total = max(expected, ride + MIN_PREP_MINUTES)
            p['eta_basis'] = (
                f"{business} promises about {expected} min, and riders in {zone_name} "
                f"take {ride:.0f} min on average from pickup to your door "
                f"({ride_count} past deliver{'y' if ride_count == 1 else 'ies'})."
            )
        else:
            total = expected
            p['eta_basis'] = (
                f"Based on {business}'s expected delivery time of {expected} min "
                f"(no finished deliveries in {zone_name} yet to compare with)."
            )
        p['eta'] = start + timedelta(minutes=total)

    elif status == 'Picked Up':
        picked = p.get('picked_up_at') or start
        if ride is not None and picked:
            p['eta'] = picked + timedelta(minutes=ride)
            p['eta_basis'] = (
                f"Your rider picked it up at {picked.strftime('%I:%M %p')}; riders in {zone_name} "
                f"take {ride:.0f} min on average from pickup to door."
            )
        elif start:
            p['eta'] = max(start + timedelta(minutes=expected),
                           (picked or start) + timedelta(minutes=MIN_PREP_MINUTES))
            p['eta_basis'] = f"Based on {business}'s expected delivery time of {expected} min."

    elif status == 'Delivered' and p.get('delivered_at') and start:
        p['actual_minutes'] = max(0, round((p['delivered_at'] - start).total_seconds() / 60))

    if p['eta'] is not None:
        p['eta_minutes'] = math.ceil((p['eta'] - now).total_seconds() / 60)

    return p


def _load_parts(order, zone_perf, now):
    parts = db.call_tvf('h_OrderSubOrders', [order['order_id']])
    parts = sorted(parts, key=lambda r: r['suborder_id'])
    zone_row = zone_perf.get(order.get('zone_name'))
    return [_annotate_part(p, order, zone_row, now) for p in parts]


def _summarise_order(order, parts):
    o = dict(order)
    o['parts'] = parts
    active = [p for p in parts if p['is_active'] and p['eta'] is not None]
    o['eta'] = max((p['eta'] for p in active), default=None)
    o['eta_minutes'] = max((p['eta_minutes'] for p in active), default=None)
    o['can_cancel'] = (
        o.get('status') != 'Cancelled'
        and not any(p['status'] in ('Picked Up', 'Delivered') for p in parts)
        and any(p['status'] in ('Placed', 'Assigned') for p in parts)
    )
    o['refund_if_cancelled'] = _money(o.get('total_amount')) - _money(o.get('refunded_amount'))
    o['is_on_the_way'] = o.get('status') in ('Placed', 'In Progress')
    o['needs_feedback'] = any(
        p['status'] == 'Delivered' and (not p.get('has_feedback') or
                                        (p.get('delivery_id') and p.get('rider_rating') is None))
        for p in parts
    )
    return o


# ==================================================
# 3.6.a  SEARCH / BROWSE BUSINESSES
# ==================================================

@customer_bp.route('/browse')
@login_required
@role_required('customer')
def browse():
    customer_id = _cid()
    keyword = request.args.get('q', '').strip()
    category = request.args.get('category', '').strip()

    profile = None
    categories = []
    results = []
    mode = None
    favorite_ids = set()

    try:
        profile = _profile(customer_id)
        categories = db.query_all(
            "SELECT category, business_count FROM dbo.h_ProductCategories ORDER BY category"
        )
        favorite_ids = _favorite_business_ids(customer_id)
    except Exception as e:
        print(f"Error loading browse page: {e}")
        flash("We could not load the businesses right now. Please try again in a moment.", "error")

    has_address = bool(profile and profile.get('active_address_id'))

    if keyword or category:
        if not has_address:
            flash("Add a delivery address and make it active first, so we can show the "
                  "businesses that deliver to you.", "error")
        elif keyword:
            mode = 'search'
            if len(keyword) > 100:
                flash("Your search is too long. Use at most 100 characters.", "error")
            else:
                try:
                    results = db.query_all(
                        """
                        SELECT s.business_id, s.business_name, s.priority,
                               r.avg_rating, r.ratings_count,
                               d.description, d.zone_name, d.is_open_now,
                               d.opening_hour, d.closing_hour, d.expected_delivery_time,
                               CAST(1 AS BIT) AS same_zone
                        FROM dbo.Search_Platform(?, ?) s
                        LEFT JOIN dbo.BusinessRatingsSummary r ON r.business_id = s.business_id
                        CROSS APPLY dbo.h_BusinessDetails(s.business_id) d
                        ORDER BY s.priority, s.business_id
                        """,
                        [customer_id, keyword]
                    )
                except Exception as e:
                    print(f"Error in Search_Platform: {e}")
                    flash("The search could not be completed. Please try again.", "error")
        else:
            mode = 'category'
            known = {c['category'] for c in categories}
            if category not in known:
                flash("Choose a category from the list.", "error")
            else:
                try:
                    results = db.query_all(
                        """
                        SELECT n.business_id, n.business_name, n.zone_name, n.same_zone,
                               n.zone_avg_delivery_time,
                               r.avg_rating, r.ratings_count,
                               d.description, d.is_open_now, d.opening_hour, d.closing_hour,
                               d.expected_delivery_time
                        FROM dbo.Nearby_Businesses_By_Category(?, ?) n
                        LEFT JOIN dbo.BusinessRatingsSummary r ON r.business_id = n.business_id
                        CROSS APPLY dbo.h_BusinessDetails(n.business_id) d
                        ORDER BY n.same_zone DESC,
                                 CASE WHEN n.zone_avg_delivery_time IS NULL THEN 1 ELSE 0 END,
                                 n.zone_avg_delivery_time,
                                 n.business_id
                        """,
                        [profile['active_address_id'], category]
                    )
                except Exception as e:
                    print(f"Error in Nearby_Businesses_By_Category: {e}")
                    flash("We could not load that category. Please try again.", "error")

    return render_template(
        'customer/browse.html',
        profile=profile,
        has_address=has_address,
        categories=categories,
        keyword=keyword,
        category=category,
        mode=mode,
        results=results,
        favorite_ids=favorite_ids,
    )


@customer_bp.route('/business/<int:business_id>')
@login_required
@role_required('customer')
def business_page(business_id):
    customer_id = _cid()

    try:
        details_rows = db.call_tvf('h_BusinessDetails', [business_id])
        if not details_rows:
            flash("We could not find that business. It may have been removed.", "error")
            return redirect(url_for('customer.browse'))
        details = details_rows[0]

        rating = db.query_one(
            "SELECT avg_rating, ratings_count FROM dbo.BusinessRatingsSummary WHERE business_id = ?",
            [business_id]
        ) or {'avg_rating': None, 'ratings_count': 0}

        products = db.call_tvf('h_BusinessProducts', [business_id])
        profile = _profile(customer_id)
        favorite_business = business_id in _favorite_business_ids(customer_id)
        favorite_products = _favorite_product_ids(customer_id)
    except Exception as e:
        print(f"Error loading business page: {e}")
        flash("We could not open this business right now. Please try again.", "error")
        return redirect(url_for('customer.browse'))

    # Group the products by category for an easy-to-scan menu.
    grouped = {}
    for p in sorted(products, key=lambda r: (r['category'], r['product_name'])):
        grouped.setdefault(p['category'], []).append(p)

    delivers_to_me = bool(profile and profile.get('active_zone') == details.get('zone_name'))

    return render_template(
        'customer/business.html',
        b=details,
        rating=rating,
        grouped=grouped,
        product_count=len(products),
        profile=profile,
        delivers_to_me=delivers_to_me,
        favorite_business=favorite_business,
        favorite_products=favorite_products,
    )


# ==================================================
# 3.6.b  FAVORITES AND RECOMMENDATIONS
# ==================================================

@customer_bp.route('/favorites')
@login_required
@role_required('customer')
def favorites():
    customer_id = _cid()
    fav_products, fav_businesses, recommended = [], [], []

    try:
        fav_products = db.call_tvf('My_Favorites', [customer_id])
        fav_businesses = db.call_tvf('h_MyFavoriteBusinesses', [customer_id])
        recommended = db.call_tvf('Recommended_Products', [customer_id])

        owners = _business_ids_for(
            [r['product_id'] for r in fav_products] + [r['product_id'] for r in recommended]
        )
        for row in fav_products + recommended:
            row['business_id'] = owners.get(row['product_id'])

        fav_products.sort(key=lambda r: (not r['is_orderable'], r['business_name'], r['product_name']))
        fav_businesses.sort(key=lambda r: (not r['is_orderable'], r['business_name']))
    except Exception as e:
        print(f"Error loading favorites: {e}")
        flash("We could not load your favorites right now. Please try again.", "error")

    favorite_product_ids = {r['product_id'] for r in fav_products}

    return render_template(
        'customer/favorites.html',
        fav_products=fav_products,
        fav_businesses=fav_businesses,
        recommended=recommended,
        favorite_product_ids=favorite_product_ids,
    )


@customer_bp.route('/favorites/toggle', methods=['POST'])
@login_required
@role_required('customer')
def toggle_favorite():
    customer_id = _cid()
    item_type = request.form.get('item_type', '').strip()
    item_id = _int(request.form.get('item_id'))
    item_name = (request.form.get('item_name') or '').strip()[:100] or 'This item'

    if item_type not in ('Business', 'Product') or item_id is None:
        flash("Choose a business or a product to add to your favorites.", "error")
        return _safe_next('customer.favorites')

    try:
        if item_type == 'Business':
            was_favorite = item_id in _favorite_business_ids(customer_id)
        else:
            was_favorite = item_id in _favorite_product_ids(customer_id)

        rc = db.call_proc('Toggle_Favorite', [customer_id, item_id, item_type])
    except Exception as e:
        print(f"Error in Toggle_Favorite: {e}")
        rc = None

    if rc == 0:
        if was_favorite:
            flash(f"{item_name} was removed from your favorites.", "success")
        else:
            flash(f"{item_name} was added to your favorites.", "success")
    else:
        flash(error_codes.get_message(rc, {
            -1: f"We could not find this {item_type.lower()}. It may have been removed. Refresh the page and try again.",
            -3: "Only signed-in customers can keep favorites. Log in again and retry.",
        }) if rc is not None else "Your favorites could not be updated. Please try again.", "error")

    return _safe_next('customer.favorites')


# ==================================================
# 3.6.c  MY ORDERS — WHERE IS IT AND WHEN WILL IT ARRIVE?
# ==================================================

@customer_bp.route('/orders')
@login_required
@role_required('customer')
def orders():
    customer_id = _cid()
    on_the_way, past = [], []
    now = _db_now()

    try:
        history = db.query_all(
            "SELECT * FROM dbo.My_Order_History(?) ORDER BY order_date DESC, order_id DESC",
            [customer_id]
        )
        zone_perf = _zone_performance()
        for order in history:
            summary = _summarise_order(order, _load_parts(order, zone_perf, now))
            (on_the_way if summary['is_on_the_way'] else past).append(summary)
    except Exception as e:
        print(f"Error loading order history: {e}")
        flash("We could not load your orders right now. Please try again.", "error")

    return render_template(
        'customer/orders.html',
        on_the_way=on_the_way,
        past=past,
        now=now,
    )


@customer_bp.route('/orders/<int:order_id>')
@login_required
@role_required('customer')
def order_detail(order_id):
    customer_id = _cid()
    now = _db_now()

    try:
        order = _my_order(customer_id, order_id)
        if not order:
            flash("We could not find that order in your account.", "error")
            return redirect(url_for('customer.orders'))

        summary = _summarise_order(order, _load_parts(order, _zone_performance(), now))
        addresses = db.call_tvf('h_MyAddresses', [customer_id])
    except Exception as e:
        print(f"Error loading order {order_id}: {e}")
        flash("We could not open this order right now. Please try again.", "error")
        return redirect(url_for('customer.orders'))

    same_zone_addresses = [a for a in addresses if a['zone_name'] == order['zone_name']]
    same_zone_addresses.sort(key=lambda a: (not a['is_active'], a['description']))

    return render_template(
        'customer/order_detail.html',
        o=summary,
        now=now,
        reorder_addresses=same_zone_addresses,
        other_zone_count=len(addresses) - len(same_zone_addresses),
    )


# ==================================================
# 3.6.d  CANCEL AND REORDER
# ==================================================

@customer_bp.route('/orders/<int:order_id>/cancel', methods=['POST'])
@login_required
@role_required('customer')
def cancel_order(order_id):
    customer_id = _cid()

    order = _my_order(customer_id, order_id)
    if not order:
        flash("We could not find that order in your account.", "error")
        return redirect(url_for('customer.orders'))

    refunded_before = _money(order.get('refunded_amount'))

    try:
        rc = db.call_proc('Cancel_Order', [order_id])
    except Exception as e:
        print(f"Error in Cancel_Order: {e}")
        rc = None

    if rc == 0:
        after = _my_order(customer_id, order_id) or order
        refunded_now = _money(after.get('refunded_amount')) - refunded_before
        if after.get('payment_method') == 'Cash':
            flash(f"Order #{order_id} was cancelled. You chose cash on delivery, so you will not "
                  f"pay the {_egp_filter(refunded_now)}.", "success")
        elif refunded_now > 0:
            flash(f"Order #{order_id} was cancelled and {_egp_filter(refunded_now)} was refunded "
                  f"to your wallet.", "success")
        else:
            flash(f"Order #{order_id} was cancelled.", "success")
    elif rc == -4:
        if order.get('status') == 'Cancelled':
            flash(f"Order #{order_id} is already cancelled.", "error")
        else:
            flash(f"Order #{order_id} cannot be cancelled because a part of it was already picked up "
                  f"or delivered. You can still leave feedback once it arrives.", "error")
    elif rc is None:
        flash("The order could not be cancelled right now. Please try again.", "error")
    else:
        flash(error_codes.get_message(rc, {
            -1: "We could not find that order. Refresh the page and try again.",
        }), "error")

    return redirect(url_for('customer.order_detail', order_id=order_id))


@customer_bp.route('/orders/<int:order_id>/reorder', methods=['POST'])
@login_required
@role_required('customer')
def reorder(order_id):
    customer_id = _cid()

    order = _my_order(customer_id, order_id)
    if not order:
        flash("We could not find that order in your account.", "error")
        return redirect(url_for('customer.orders'))

    address_id = _int(request.form.get('address_id'))
    if address_id is None:
        flash("Choose the address to deliver the new order to.", "error")
        return redirect(url_for('customer.order_detail', order_id=order_id))

    addresses = {a['address_id']: a for a in db.call_tvf('h_MyAddresses', [customer_id])}
    address = addresses.get(address_id)
    if not address:
        flash("Choose one of your own addresses from the list.", "error")
        return redirect(url_for('customer.order_detail', order_id=order_id))

    try:
        rc = db.call_proc('Reorder', [order_id, address_id])
    except Exception as e:
        print(f"Error in Reorder: {e}")
        rc = None

    if rc == 0:
        flash(f"The available products of order #{order_id} are now in a new cart for "
              f"\"{address['description']}\", which is now your active address. "
              f"Review the cart and check out.", "success")
        if 'customer.cart' in current_app.view_functions:
            return redirect(url_for('customer.cart'))
        return redirect(url_for('customer.order_detail', order_id=order_id))

    flash(error_codes.get_message(rc, {
        -1: "We could not find that order. Refresh the page and try again.",
        -2: f"You already have an open cart for \"{address['description']}\". Check out that cart "
            f"first, or reorder to another address in {order['zone_name']}.",
        -3: "Your account is blacklisted, so you cannot place new orders. Contact support.",
        -5: f"This order was delivered in {order['zone_name']}, but \"{address['description']}\" is in "
            f"{address['zone_name']}. Choose an address in {order['zone_name']}.",
        -9: "None of the products from this order can be ordered right now (they are unavailable "
            "or the business is not taking orders). Browse for something else instead.",
    }) if rc is not None else "The order could not be repeated right now. Please try again.", "error")

    return redirect(url_for('customer.order_detail', order_id=order_id))


# ==================================================
# 3.6.e  FEEDBACK AND RIDER RATING
# ==================================================

def _my_part(customer_id, order_id, suborder_id):
    if not _my_order(customer_id, order_id):
        return None
    for part in db.call_tvf('h_OrderSubOrders', [order_id]):
        if part['suborder_id'] == suborder_id:
            return part
    return None


@customer_bp.route('/orders/<int:order_id>/parts/<int:suborder_id>/feedback', methods=['POST'])
@login_required
@role_required('customer')
def submit_feedback(order_id, suborder_id):
    customer_id = _cid()
    back = redirect(url_for('customer.order_detail', order_id=order_id) + f"#part-{suborder_id}")

    part = _my_part(customer_id, order_id, suborder_id)
    if not part:
        flash("We could not find that part of your order.", "error")
        return redirect(url_for('customer.orders'))

    headline = request.form.get('headline', '').strip()
    description = request.form.get('description', '').strip() or None
    rating = _int(request.form.get('rating'))

    if not headline:
        flash("Write a short headline for your review.", "error")
        return back
    if len(headline) > 100:
        flash("The headline can have at most 100 characters. Shorten it and try again.", "error")
        return back
    if description and len(description) > 500:
        flash("The review can have at most 500 characters. Shorten it and try again.", "error")
        return back
    if rating is None or not 1 <= rating <= 5:
        flash("Pick a rating from 1 to 5 stars.", "error")
        return back

    try:
        rc = db.call_proc('Submit_Feedback', [suborder_id, headline, description, rating])
    except Exception as e:
        print(f"Error in Submit_Feedback: {e}")
        rc = None

    if rc == 0:
        flash(f"Thank you! Your {rating}-star review of {part['business_name']} was posted.", "success")
    else:
        flash(error_codes.get_message(rc, {
            -1: "Your review is missing a headline or a rating. Fill them in and try again.",
            -2: f"You already reviewed the {part['business_name']} part of this order.",
            -4: f"You can review {part['business_name']} once this part of the order is delivered.",
        }) if rc is not None else "Your review could not be saved right now. Please try again.", "error")

    return back


@customer_bp.route('/orders/<int:order_id>/parts/<int:suborder_id>/rate-rider', methods=['POST'])
@login_required
@role_required('customer')
def rate_rider(order_id, suborder_id):
    customer_id = _cid()
    back = redirect(url_for('customer.order_detail', order_id=order_id) + f"#part-{suborder_id}")

    part = _my_part(customer_id, order_id, suborder_id)
    if not part:
        flash("We could not find that part of your order.", "error")
        return redirect(url_for('customer.orders'))

    rating = _int(request.form.get('rider_rating'))
    if rating is None or not 1 <= rating <= 5:
        flash("Pick a rider rating from 1 to 5 stars.", "error")
        return back

    try:
        rc = db.call_proc('Rate_Rider', [suborder_id, rating])
    except Exception as e:
        print(f"Error in Rate_Rider: {e}")
        rc = None

    rider = part.get('rider_name') or 'your rider'
    if rc == 0:
        flash(f"Thanks! You rated {rider} {rating} out of 5.", "success")
    else:
        flash(error_codes.get_message(rc, {
            -1: "Pick a rider rating from 1 to 5 stars.",
            -2: f"You already rated {rider} for this delivery.",
            -4: "You can rate the rider once this part of the order is delivered.",
        }) if rc is not None else "Your rating could not be saved right now. Please try again.", "error")

    return back
