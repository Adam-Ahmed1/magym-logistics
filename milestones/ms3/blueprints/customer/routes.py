# Customer routes — Section 3.5: account, addresses, cards, cart and checkout.
#
# Every action calls the Milestone 2 procedure / function / view named under
# "Uses" in the Milestone 3 description:
#   a) Customer_Register, CustomerLoginValidation (in auth.py) + h_CustomerProfile
#   b) Add_Customer_Address, Update_Delete_Customer_Address, Change_Active_Address
#      (+ h_MyAddresses, h_ZoneList)
#   c) Add_Card (+ h_MyCards)
#   d) Create_Cart, Add_To_Cart, Remove_From_Cart (+ h_MyActiveCart, h_CartItems)
#   e) Calculate_Voucher_Discount, Checkout_Cart, h_CartItems, h_MyCards, h_MyVouchers
#
# Python only collects and checks the input, calls the database and explains
# the result. The business rules stay in the Milestone 2 procedures.
#
# Section 3.6 (browsing, favorites, orders, feedback) lives in browse_routes.py.

from datetime import date
from decimal import Decimal

from flask import (current_app, flash, redirect, render_template, request,
                   session, url_for)

import db
import error_codes
from auth import login_required, role_required

from . import customer_bp


PAYMENT_METHODS = ('Cash', 'Card', 'Wallet')
ZERO = Decimal('0.00')


# ==================================================
# SMALL HELPERS
# ==================================================

def cid():
    """The signed-in customer. Never taken from a form or a URL."""
    return session['user_id']


def _int(value):
    try:
        return int(str(value).strip())
    except (TypeError, ValueError):
        return None


def _text(value):
    """Stripped text, or None when empty (optional fields go to the DB as NULL)."""
    value = (value or '').strip()
    return value or None


def _money(value):
    return Decimal(str(value if value is not None else 0)).quantize(Decimal('0.01'))


def _egp(value):
    return f"EGP {_money(value):,.2f}"


def _has_endpoint(name):
    return name in current_app.view_functions


def _back(default_endpoint):
    """Go back to the page the user came from, but only inside this site."""
    target = request.form.get('next') or ''
    if target.startswith('/') and not target.startswith('//'):
        return redirect(target)
    return redirect(url_for(default_endpoint))


def _profile():
    rows = db.call_tvf('h_CustomerProfile', [cid()])
    return rows[0] if rows else None


def _my_addresses():
    rows = db.call_tvf('h_MyAddresses', [cid()])
    return sorted(rows, key=lambda a: (not a['is_active'], a['description'].lower()))


def _my_address(address_id):
    """The address only if it belongs to the signed-in customer."""
    for a in db.call_tvf('h_MyAddresses', [cid()]):
        if a['address_id'] == address_id:
            return a
    return None


def _zones():
    return db.query_all(
        "SELECT zone_id, zone_name, delivery_fee FROM dbo.h_ZoneList ORDER BY zone_name"
    )


def _zone_fee(zone_id):
    row = db.query_one("SELECT delivery_fee FROM dbo.h_ZoneList WHERE zone_id = ?", [zone_id])
    return _money(row['delivery_fee']) if row else ZERO


def _active_cart_id():
    """The Active cart of my active address (h_MyActiveCart), or None."""
    return db.call_func('h_MyActiveCart', [cid()])


def _product_name(product_id):
    row = db.query_one(
        "SELECT p.name AS product_name, b.name AS business_name "
        "FROM dbo.Product p JOIN dbo.Business b ON b.business_id = p.business_id "
        "WHERE p.product_id = ?",
        [product_id]
    )
    return row or {'product_name': 'This product', 'business_name': 'this business'}


def _group_by_business(items):
    """
    Groups the rows of h_CartItems by business. Each business becomes its own
    part (sub-order) at checkout, with its own delivery fee.
    """
    groups = {}
    for item in sorted(items, key=lambda r: (r['business_name'], r['product_name'])):
        g = groups.get(item['business_id'])
        if g is None:
            g = groups[item['business_id']] = {
                'business_id': item['business_id'],
                'business_name': item['business_name'],
                'items': [],
                'subtotal': ZERO,
                'has_unavailable': False,
            }
        g['items'].append(item)
        g['subtotal'] += _money(item['line_total'])
        if not item['is_available']:
            g['has_unavailable'] = True
    return list(groups.values())


def _annotate_businesses(groups):
    """Adds open-now and status from h_BusinessDetails, so problems show before checkout."""
    for g in groups:
        rows = db.call_tvf('h_BusinessDetails', [g['business_id']])
        d = rows[0] if rows else {}
        g['status'] = d.get('status')
        g['is_open_now'] = bool(d.get('is_open_now'))
        g['opening_hour'] = d.get('opening_hour')
        g['closing_hour'] = d.get('closing_hour')
        g['zone_name'] = d.get('zone_name')
    return groups


def _load_cart():
    """Everything the cart and checkout pages need, in one place."""
    profile = _profile()
    cart_id = _active_cart_id() if profile and profile.get('active_address_id') else None
    items = db.call_tvf('h_CartItems', [cart_id]) if cart_id else []
    groups = _annotate_businesses(_group_by_business(items))
    zone_fee = _zone_fee(profile['active_zone_id']) if profile and profile.get('active_zone_id') else ZERO
    return {
        'profile': profile,
        'cart_id': cart_id,
        'items': items,
        'groups': groups,
        'zone_fee': zone_fee,
        'item_count': sum(int(i['quantity']) for i in items),
        'items_subtotal': sum((g['subtotal'] for g in groups), ZERO),
    }


def _cart_problems(cart):
    """Things Checkout_Cart will refuse, explained in the customer's words."""
    problems = []
    my_zone = cart['profile'].get('active_zone') if cart['profile'] else None
    for g in cart['groups']:
        if g['has_unavailable']:
            names = ', '.join(i['product_name'] for i in g['items'] if not i['is_available'])
            problems.append(f"{names} from {g['business_name']} is no longer available. Remove it from your cart.")
        if g.get('status') and g['status'] != 'Active':
            problems.append(f"{g['business_name']} is not taking orders right now. Remove its products from your cart.")
        elif not g.get('is_open_now'):
            opens = g['opening_hour'].strftime('%I:%M %p') if g.get('opening_hour') else 'later'
            problems.append(f"{g['business_name']} is closed now (it opens at {opens}). Order later or remove its products.")
        if my_zone and g.get('zone_name') and g['zone_name'] != my_zone:
            problems.append(f"{g['business_name']} is in {g['zone_name']} and does not deliver to your active "
                            f"address in {my_zone}. Remove its products or change your active address.")
    return problems


# ==================================================
# 3.5.a  HOME PAGE: NAME, ACTIVE ADDRESS, WALLET
# ==================================================

@customer_bp.route('/home')
@login_required
@role_required('customer')
def home():
    profile = None
    cart_count = 0
    cards_count = 0
    vouchers_count = 0

    try:
        profile = _profile()
        if profile and profile.get('active_address_id'):
            cart_id = _active_cart_id()
            if cart_id:
                cart_count = sum(int(i['quantity']) for i in db.call_tvf('h_CartItems', [cart_id]))
        cards_count = len(db.call_tvf('h_MyCards', [cid()]))
        vouchers_count = len(db.call_tvf('h_MyVouchers', [cid()]))
    except Exception as e:
        print(f"Error loading customer home: {e}")
        flash("We could not load your account details right now. Please try again in a moment.", "error")

    return render_template(
        'customer/home.html',
        profile=profile,
        cart_count=cart_count,
        cards_count=cards_count,
        vouchers_count=vouchers_count,
    )


# ==================================================
# 3.5.b  ADDRESSES
# ==================================================

@customer_bp.route('/addresses')
@login_required
@role_required('customer')
def addresses():
    my_addresses, zones = [], []
    try:
        my_addresses = _my_addresses()
        zones = _zones()
    except Exception as e:
        print(f"Error loading addresses: {e}")
        flash("We could not load your addresses right now. Please try again.", "error")

    return render_template('customer/addresses.html', addresses=my_addresses, zones=zones)


def _read_address_form():
    """Returns (description, zone_id, error message or None)."""
    description = (request.form.get('description') or '').strip()
    zone_id = _int(request.form.get('zone_id'))
    if not description:
        return description, zone_id, "Describe the address, for example \"Home, 12 Street 9, Maadi\"."
    if len(description) > 150:
        return description, zone_id, "The address description can have at most 150 characters. Shorten it."
    if zone_id is None:
        return description, zone_id, "Pick the zone the address is in from the list."
    return description, zone_id, None


@customer_bp.route('/addresses/add', methods=['POST'])
@login_required
@role_required('customer')
def add_address():
    description, zone_id, error = _read_address_form()
    if error:
        flash(error, "error")
        return redirect(url_for('customer.addresses'))

    rc = db.call_proc('Add_Customer_Address', [cid(), description, zone_id])

    if rc == 0:
        flash(f"\"{description}\" was added and is now your active address. Your cart and the "
              f"businesses you can order from now follow this address.", "success")
    else:
        flash(error_codes.get_message(rc, {
            -1: "Write a description and pick a zone from the list, then try again.",
            -3: "Only customer accounts can add delivery addresses.",
        }), "error")
    return redirect(url_for('customer.addresses'))


@customer_bp.route('/addresses/<int:address_id>/edit', methods=['GET', 'POST'])
@login_required
@role_required('customer')
def edit_address(address_id):
    address = _my_address(address_id)
    if not address:
        flash("We could not find that address in your account.", "error")
        return redirect(url_for('customer.addresses'))

    if request.method == 'GET':
        return render_template('customer/address_edit.html', address=address, zones=_zones())

    description, zone_id, error = _read_address_form()
    if error:
        flash(error, "error")
        return redirect(url_for('customer.edit_address', address_id=address_id))

    rc = db.call_proc('Update_Delete_Customer_Address',
                      [cid(), address_id, description, zone_id, 'Update'])

    if rc == 0:
        flash(f"Your address \"{description}\" was updated.", "success")
        return redirect(url_for('customer.addresses'))

    flash(error_codes.get_message(rc, {
        -1: "Write a description and pick a zone from the list, then save again.",
        -3: "That address is not in your account.",
        -4: f"You can't change \"{address['description']}\" while an order to it is still on its way. "
            f"Try again after it is delivered.",
    }), "error")
    return redirect(url_for('customer.edit_address', address_id=address_id))


@customer_bp.route('/addresses/<int:address_id>/delete', methods=['POST'])
@login_required
@role_required('customer')
def delete_address(address_id):
    address = _my_address(address_id)
    if not address:
        flash("We could not find that address in your account.", "error")
        return redirect(url_for('customer.addresses'))

    rc = db.call_proc('Update_Delete_Customer_Address',
                      [cid(), address_id, None, None, 'Delete'])

    if rc == 0:
        msg = f"\"{address['description']}\" was deleted."
        if address['is_active']:
            new_active = next((a for a in _my_addresses() if a['is_active']), None)
            if new_active:
                msg += f" \"{new_active['description']}\" is now your active address."
            else:
                msg += " Add a new address before you order again."
        flash(msg, "success")
    else:
        flash(error_codes.get_message(rc, {
            -1: "We could not find that address. Refresh the page and try again.",
            -3: "That address is not in your account.",
            -4: f"\"{address['description']}\" has carts or orders linked to it, so it can't be deleted. "
                f"You can edit it instead.",
        }), "error")
    return redirect(url_for('customer.addresses'))


@customer_bp.route('/addresses/<int:address_id>/activate', methods=['POST'])
@login_required
@role_required('customer')
def activate_address(address_id):
    address = _my_address(address_id)
    if not address:
        flash("We could not find that address in your account.", "error")
        return redirect(url_for('customer.addresses'))

    rc = db.call_proc('Change_Active_Address', [cid(), address_id])

    if rc == 0:
        flash(f"\"{address['description']}\" ({address['zone_name']}) is now your active address. "
              f"Your cart and the businesses you can order from now follow this address.", "success")
    else:
        flash(error_codes.get_message(rc, {
            -3: "That address is not in your account.",
        }), "error")
    return _back('customer.addresses')


# ==================================================
# 3.5.c  CARDS
# ==================================================

@customer_bp.route('/cards')
@login_required
@role_required('customer')
def cards():
    my_cards = []
    try:
        my_cards = db.call_tvf('h_MyCards', [cid()])  # last 4 digits only
    except Exception as e:
        print(f"Error loading cards: {e}")
        flash("We could not load your cards right now. Please try again.", "error")

    return render_template('customer/cards.html', cards=my_cards, today=date.today().isoformat())


@customer_bp.route('/cards/add', methods=['POST'])
@login_required
@role_required('customer')
def add_card():
    card_no = ''.join(ch for ch in (request.form.get('card_no') or '') if ch not in ' -')
    holder = (request.form.get('card_holder_name') or '').strip()
    expiry_raw = (request.form.get('expiration_date') or '').strip()

    if len(card_no) != 16 or not card_no.isdigit():
        flash("The card number must be exactly 16 digits.", "error")
        return redirect(url_for('customer.cards'))
    if not holder:
        flash("Write the name printed on the card.", "error")
        return redirect(url_for('customer.cards'))
    if len(holder) > 100:
        flash("The card holder's name can have at most 100 characters.", "error")
        return redirect(url_for('customer.cards'))
    try:
        expiry = date.fromisoformat(expiry_raw)
    except ValueError:
        flash("Pick the card's expiry date.", "error")
        return redirect(url_for('customer.cards'))
    if expiry < date.today():
        flash("This card has already expired. Use a card with a later expiry date.", "error")
        return redirect(url_for('customer.cards'))

    rc = db.call_proc('Add_Card', [cid(), card_no, holder, expiry])
    last4 = card_no[-4:]

    if rc == 0:
        flash(f"Your card ending in {last4} was saved.", "success")
    else:
        flash(error_codes.get_message(rc, {
            -1: "Check the card: 16 digits, the holder's name, and an expiry date that hasn't passed.",
            -2: f"The card ending in {last4} is already saved on your account.",
            -3: "Only customer accounts can save cards.",
        }), "error")
    return redirect(url_for('customer.cards'))


# ==================================================
# 3.5.d  CART
# ==================================================

@customer_bp.route('/cart')
@login_required
@role_required('customer')
def cart():
    data = None
    try:
        data = _load_cart()
    except Exception as e:
        print(f"Error loading cart: {e}")
        flash("We could not load your cart right now. Please try again.", "error")
        return redirect(url_for('customer.home'))

    return render_template(
        'customer/cart.html',
        problems=_cart_problems(data) if data['items'] else [],
        **data,
    )


@customer_bp.route('/cart/create', methods=['POST'])
@login_required
@role_required('customer')
def create_cart():
    rc = db.call_proc('Create_Cart', [cid()])

    if rc == 0:
        profile = _profile()
        where = profile['active_address'] if profile else 'your active address'
        flash(f"Your cart for \"{where}\" is ready. Browse businesses and add products.", "success")
    elif rc == -2:
        flash("You already have a cart for your active address. Here it is.", "info")
    else:
        flash(error_codes.get_message(rc, {
            -1: "Add a delivery address and make it active first, then start a cart.",
            -3: "Your account can't place orders right now. Contact support.",
        }), "error")
    return redirect(url_for('customer.cart'))


@customer_bp.route('/cart/add', methods=['POST'])
@login_required
@role_required('customer')
def add_to_cart():
    product_id = _int(request.form.get('product_id'))
    quantity = _int(request.form.get('quantity'))
    notes = _text(request.form.get('notes'))

    if product_id is None:
        flash("Choose a product to add.", "error")
        return _back('customer.cart')
    if quantity is None or quantity < 1:
        flash("Choose a quantity of at least 1.", "error")
        return _back('customer.cart')
    if quantity > 10:
        flash("You can order at most 10 of one product. Lower the quantity.", "error")
        return _back('customer.cart')
    if notes and len(notes) > 255:
        flash("The note can have at most 255 characters. Shorten it.", "error")
        return _back('customer.cart')

    profile = _profile()
    if not profile or not profile.get('active_address_id'):
        flash("Add a delivery address and make it active before you add products.", "error")
        return redirect(url_for('customer.addresses'))

    # The cart always comes from the database, never from the form.
    cart_id = _active_cart_id()
    if cart_id is None:
        rc = db.call_proc('Create_Cart', [cid()])
        if rc != 0:
            flash(error_codes.get_message(rc, {
                -1: "Add a delivery address and make it active first, then start a cart.",
                -3: "Your account can't place orders right now. Contact support.",
            }), "error")
            return _back('customer.cart')
        cart_id = _active_cart_id()

    names = _product_name(product_id)
    product = names['product_name']

    rc = db.call_proc('Add_To_Cart', [cart_id, product_id, quantity, notes])

    if rc == 0:
        now_in_cart = next((i['quantity'] for i in db.call_tvf('h_CartItems', [cart_id])
                            if i['product_id'] == product_id), quantity)
        flash(f"Added {quantity} × {product} to your cart (you now have {now_in_cart}).", "success")
    elif rc == -6:
        already = next((i['quantity'] for i in db.call_tvf('h_CartItems', [cart_id])
                        if i['product_id'] == product_id), 0)
        if already:
            flash(f"You can have at most 10 of one product. You already have {already} × {product} "
                  f"in your cart, so you can add up to {10 - already} more.", "error")
        else:
            flash("You can order at most 10 of one product. Lower the quantity.", "error")
    else:
        flash(error_codes.get_message(rc, {
            -1: f"Choose a quantity of at least 1 for {product}.",
            -4: f"{product} can't be ordered right now (it is unavailable or {names['business_name']} "
                f"is not taking orders). Pick something else.",
            -5: f"{names['business_name']} does not deliver to your active address "
                f"in {profile['active_zone']}. Change your active address or choose another business.",
        }), "error")
    return _back('customer.cart')


@customer_bp.route('/cart/remove/<int:product_id>', methods=['POST'])
@login_required
@role_required('customer')
def remove_from_cart(product_id):
    cart_id = _active_cart_id()
    if cart_id is None:
        flash("You don't have an open cart for your active address.", "error")
        return redirect(url_for('customer.cart'))

    product = _product_name(product_id)['product_name']
    rc = db.call_proc('Remove_From_Cart', [cart_id, product_id])

    if rc == 0:
        flash(f"{product} was removed from your cart.", "success")
    else:
        flash(error_codes.get_message(rc, {
            -1: f"{product} is no longer in your cart. Refresh the page.",
            -4: "This cart can't be changed anymore. Refresh the page to see your current cart.",
        }), "error")
    return redirect(url_for('customer.cart'))


# ==================================================
# 3.5.e  CHECKOUT: WHAT EXACTLY WILL I PAY, AND WHY?
# ==================================================

def _voucher_label(v):
    if v['is_percentage']:
        off = f"{_money(v['amount']).normalize():f}% off"
    else:
        off = f"{_egp(v['amount'])} off"
    return f"{v['promo_code']} — {off} · expires {v['expiry_date'].strftime('%d %b %Y')}"


def _checkout_options():
    my_cards = db.call_tvf('h_MyCards', [cid()])
    vouchers = db.call_tvf('h_MyVouchers', [cid()])
    for v in vouchers:
        v['label'] = _voucher_label(v)
    return my_cards, vouchers


def _read_checkout_form(my_cards, vouchers):
    """Returns (method, card, voucher, error message or None). card / voucher are rows or None."""
    method = (request.form.get('payment_method') or '').strip()
    card_id = _int(request.form.get('card_id'))
    voucher_id = _int(request.form.get('voucher_id'))

    if method not in PAYMENT_METHODS:
        return method, None, None, "Choose how you want to pay: Cash, Card or Wallet."

    card = None
    if method == 'Card':
        card = next((c for c in my_cards if c['card_id'] == card_id), None)
        if card is None:
            if not my_cards:
                return method, None, None, "You have no saved card. Save one first, or pay with Cash or Wallet."
            return method, None, None, "Choose one of your saved cards to pay with."

    voucher = None
    if request.form.get('voucher_id'):
        voucher = next((v for v in vouchers if v['voucher_id'] == voucher_id), None)
        if voucher is None:
            return method, card, None, "That voucher can't be used anymore. Pick another one or check out without a voucher."

    return method, card, voucher, None


def _breakdown(cart, voucher):
    """
    The total exactly as Checkout_Cart computes it:
      items (per business) + one zone delivery fee per business - voucher discount.
    The discount comes from Calculate_Voucher_Discount, on the items subtotal only.
    """
    items_subtotal = cart['items_subtotal']
    business_count = len(cart['groups'])
    fees = cart['zone_fee'] * business_count
    discount = ZERO
    if voucher:
        discount = _money(db.call_func('Calculate_Voucher_Discount',
                                       [voucher['voucher_id'], items_subtotal]))
        if discount < 0:
            discount = ZERO
    return {
        'items_subtotal': items_subtotal,
        'business_count': business_count,
        'zone_fee': cart['zone_fee'],
        'fees': fees,
        'discount': discount,
        'capped': bool(voucher and not voucher['is_percentage'] and discount < _money(voucher['amount'])),
        'total': items_subtotal + fees - discount,
    }


def _checkout_guard(cart):
    """Redirect for a cart that can't go to checkout at all, else None."""
    if not cart['profile'] or not cart['profile'].get('active_address_id'):
        flash("Add a delivery address and make it active before checking out.", "error")
        return redirect(url_for('customer.addresses'))
    if not cart['cart_id'] or not cart['items']:
        flash("Your cart is empty. Add products before checking out.", "error")
        return redirect(url_for('customer.cart'))
    return None


@customer_bp.route('/checkout', methods=['GET'])
@login_required
@role_required('customer')
def checkout():
    try:
        cart = _load_cart()
        guard = _checkout_guard(cart)
        if guard:
            return guard
        my_cards, vouchers = _checkout_options()
    except Exception as e:
        print(f"Error loading checkout: {e}")
        flash("We could not open checkout right now. Please try again.", "error")
        return redirect(url_for('customer.cart'))

    # Keep the customer's choices when they come back from the preview with "Change".
    chosen = {
        'payment_method': request.args.get('payment_method', ''),
        'card_id': _int(request.args.get('card_id')),
        'voucher_id': _int(request.args.get('voucher_id')),
    }

    return render_template(
        'customer/checkout.html',
        cards=my_cards,
        vouchers=vouchers,
        chosen=chosen,
        problems=_cart_problems(cart),
        **cart,
    )


@customer_bp.route('/checkout/preview', methods=['POST'])
@login_required
@role_required('customer')
def checkout_preview():
    cart = _load_cart()
    guard = _checkout_guard(cart)
    if guard:
        return guard

    my_cards, vouchers = _checkout_options()
    method, card, voucher, error = _read_checkout_form(my_cards, vouchers)
    if error:
        flash(error, "error")
        return redirect(url_for('customer.checkout', payment_method=method,
                                card_id=request.form.get('card_id', ''),
                                voucher_id=request.form.get('voucher_id', '')))

    bd = _breakdown(cart, voucher)
    wallet = _money(cart['profile']['wallet_balance'])

    return render_template(
        'customer/checkout_preview.html',
        method=method,
        card=card,
        voucher=voucher,
        bd=bd,
        wallet=wallet,
        wallet_short=(method == 'Wallet' and wallet < bd['total']),
        problems=_cart_problems(cart),
        **cart,
    )


def _explain_wrong_status(cart, voucher):
    """Checkout_Cart returns -4 for several reasons; find the one that applies."""
    if not cart['cart_id']:
        return ("This cart was already checked out or belongs to another address. "
                "Open your cart to see what's in it now.")
    problems = _cart_problems(cart)
    if problems:
        return problems[0]
    if voucher and not any(v['voucher_id'] == voucher['voucher_id']
                           for v in db.call_tvf('h_MyVouchers', [cid()])):
        return f"The voucher {voucher['promo_code']} was already used. Check out without it or pick another."
    return "This cart can't be checked out right now. Refresh your cart and try again."


@customer_bp.route('/checkout/confirm', methods=['POST'])
@login_required
@role_required('customer')
def checkout_confirm():
    cart = _load_cart()
    my_cards, vouchers = _checkout_options()
    method, card, voucher, error = _read_checkout_form(my_cards, vouchers)

    if error:
        flash(error, "error")
        return redirect(url_for('customer.checkout'))
    if not cart['cart_id']:
        flash("You don't have an open cart for your active address. It may already be checked out.", "error")
        return redirect(url_for('customer.cart'))

    expected = _breakdown(cart, voucher)['total'] if cart['items'] else ZERO

    rc = db.call_proc('Checkout_Cart', [
        cart['cart_id'],
        voucher['voucher_id'] if voucher else None,
        method,
        card['card_id'] if card else None,
    ])

    if rc == 0:
        paid_with = {
            'Cash': 'in cash on delivery',
            'Card': f"with your card ending in {card['last_four_digits']}" if card else 'by card',
            'Wallet': 'from your wallet',
        }[method]
        order = db.query_one(
            "SELECT TOP 1 order_id, total_amount FROM dbo.My_Order_History(?) ORDER BY order_id DESC",
            [cid()]
        )
        total = order['total_amount'] if order else expected
        flash(f"Order placed! You pay {_egp(total)} {paid_with}. Riders are on their way to the "
              f"business{'es' if len(cart['groups']) > 1 else ''}.", "success")
        if order and _has_endpoint('customer.order_detail'):
            return redirect(url_for('customer.order_detail', order_id=order['order_id']))
        if _has_endpoint('customer.orders'):
            return redirect(url_for('customer.orders'))
        return redirect(url_for('customer.home'))

    back_to_checkout = redirect(url_for('customer.checkout', payment_method=method,
                                        card_id=card['card_id'] if card else '',
                                        voucher_id=voucher['voucher_id'] if voucher else ''))

    if rc == -4:
        flash(_explain_wrong_status(cart, voucher), "error")
        return redirect(url_for('customer.cart'))

    if rc == -7:
        if method == 'Wallet':
            wallet = _money(cart['profile']['wallet_balance'])
            flash(f"Your wallet has {_egp(wallet)}, which is not enough for {_egp(expected)}. "
                  f"Choose Cash or Card.", "error")
        else:
            flash("This card can't be used: it may have expired. Choose another saved card, "
                  "or pay with Cash or Wallet.", "error")
        return back_to_checkout

    flash(error_codes.get_message(rc, {
        -1: "That voucher can't be used anymore (it may have expired). Pick another one or "
            "check out without a voucher.",
        -3: "Your account is blacklisted, so you cannot check out. Contact support.",
        -5: "Some products come from a business that does not deliver to your active address. "
            "Remove them or change your active address.",
        -8: "No rider is available in your area right now. Try again in a few minutes.",
        -9: "Your cart is empty. Add products before checking out.",
    }), "error")

    if rc in (-5, -9):
        return redirect(url_for('customer.cart'))
    return back_to_checkout
