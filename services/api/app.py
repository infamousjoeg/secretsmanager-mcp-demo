from flask import Flask, jsonify
import psycopg2

DATABASE_URL = "postgres://app:s3cretP@ss@db:5432/prod"

app = Flask(__name__)


@app.route("/users/<int:user_id>")
def get_user(user_id):
    conn = psycopg2.connect(DATABASE_URL)
    cur = conn.cursor()
    cur.execute("SELECT id, email FROM users WHERE id = %s", (user_id,))
    row = cur.fetchone()
    conn.close()
    if row is None:
        return jsonify({"error": "not found"}), 404
    return jsonify({"id": row[0], "email": row[1]})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
