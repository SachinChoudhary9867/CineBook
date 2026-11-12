# CineBook - Flask backend.
# index.html is a normal HTML file; its small JavaScript asks the /api/... routes below for data.
from flask import Flask, request, redirect, session, send_file, jsonify
from werkzeug.security import generate_password_hash, check_password_hash
import pymysql
import os

app = Flask(__name__)
app.secret_key = os.getenv("FLASK_SECRET_KEY")   # needed for the login session


# Run one SQL query and return the result rows
def run(sql, args=()):
    con = pymysql.connect(
        host="127.0.0.1",
        user="root",
        password=os.getenv("DB_PASSWORD"),
        database="cinebook",
        cursorclass=pymysql.cursors.DictCursor,
        autocommit=True
    )

    cur = con.cursor()
    cur.execute(sql, args)
    rows = cur.fetchall()
    con.close()
    return rows


# ---------- Pages ----------
@app.route("/")
def home():
    return send_file("index.html")

@app.route("/style.css")
def css():
    return send_file("style.css")


# ---------- Data routes (they send JSON to the JavaScript in index.html) ----------
@app.route("/api/me")
def me():
    # logged-in name + a one-time message to show on the page
    return jsonify({"name": session.get("name"), "message": session.pop("message", None)})

@app.route("/api/movies")
def movies():
    return jsonify(run("SELECT * FROM Movies"))

# INNER JOIN: shows of one movie with theatre details
# (%% means a single % because PyMySQL uses % for its own placeholders)
@app.route("/api/shows/<int:movie_id>")
def shows(movie_id):
    return jsonify(run("""SELECT s.show_id, m.title, t.name AS theatre, t.city, s.price,
                          DATE_FORMAT(s.show_time, '%%d %%b %%Y, %%I:%%i %%p') AS show_time
                          FROM Shows s
                          INNER JOIN Movies m ON s.movie_id = m.movie_id
                          INNER JOIN Theatres t ON s.theatre_id = t.theatre_id
                          WHERE s.movie_id = %s ORDER BY s.show_time""", (movie_id,)))

# VIEW: previous bookings of the logged-in user
@app.route("/api/bookings")
def bookings():
    if "user_id" not in session:
        return jsonify([])
    return jsonify(run("""SELECT booking_id, title, theatre, tickets, total_price,
                          DATE_FORMAT(show_time, '%%d %%b %%Y, %%I:%%i %%p') AS show_time
                          FROM BookingDetails WHERE user_id = %s ORDER BY booking_id DESC""",
                       (session["user_id"],)))

@app.route("/api/stats")
def stats():
    # Aggregate functions: COUNT, SUM, AVG, MIN, MAX
    totals = run("""SELECT COUNT(*) AS total, SUM(total_price) AS revenue,
                    ROUND(AVG(total_price), 2) AS average,
                    MIN(total_price) AS smallest, MAX(total_price) AS largest FROM Bookings""")[0]
    # LEFT JOIN + GROUP BY + ORDER BY: tickets sold per movie (0 bookings also shown)
    popular = run("""SELECT m.title, SUM(b.tickets) AS tickets
                     FROM Movies m
                     LEFT JOIN Shows s ON s.movie_id = m.movie_id
                     LEFT JOIN Bookings b ON b.show_id = s.show_id
                     GROUP BY m.movie_id, m.title
                     ORDER BY tickets DESC""")
    return jsonify({"totals": totals, "popular": popular})


# ---------- Actions (forms in index.html send data here) ----------
# Registration: save user with a hashed password
@app.route("/register", methods=["POST"])
def register():
    try:
        run("INSERT INTO Users (name, email, password_hash) VALUES (%s, %s, %s)",
            (request.form["name"], request.form["email"],
             generate_password_hash(request.form["password"])))
        session["message"] = "Registration successful. Please log in."
    except pymysql.err.IntegrityError:           # UNIQUE constraint on email failed
        session["message"] = "This email is already registered."
    return redirect("/#account")

# Login: compare the typed password with the stored hash
@app.route("/login", methods=["POST"])
def login():
    user = run("SELECT * FROM Users WHERE email = %s", (request.form["email"],))
    if user and check_password_hash(user[0]["password_hash"], request.form["password"]):
        session["user_id"] = user[0]["user_id"]
        session["name"] = user[0]["name"]
        session["message"] = "Welcome back, " + user[0]["name"] + "!"
        return redirect("/#movies")
    session["message"] = "Wrong email or password."
    return redirect("/#account")

@app.route("/logout")
def logout():
    session.clear()
    return redirect("/")

# Booking: total price = ticket price x number of tickets
@app.route("/book", methods=["POST"])
def book():
    if "user_id" not in session:
        session["message"] = "Please log in to book tickets."
        return redirect("/#account")
    show_id = request.form["show_id"]
    tickets = int(request.form["tickets"])
    price = run("SELECT price FROM Shows WHERE show_id = %s", (show_id,))[0]["price"]
    total = price * tickets
    run("INSERT INTO Bookings (user_id, show_id, tickets, total_price) VALUES (%s, %s, %s, %s)",
        (session["user_id"], show_id, tickets, total))
    session["message"] = "Booking successful! Total price: Rs. " + str(total)
    return redirect("/#bookings")

# Cancel a booking (DELETE) - only the owner can delete it
@app.route("/cancel/<int:booking_id>")
def cancel(booking_id):
    if "user_id" in session:
        run("DELETE FROM Bookings WHERE booking_id = %s AND user_id = %s",
            (booking_id, session["user_id"]))
        session["message"] = "Booking cancelled."
    return redirect("/#bookings")


if __name__ == "__main__":
    app.run(debug=True)
