import pymysql
from getpass import getpass

try:
    con = pymysql.connect(
        host="127.0.0.1",
        user="root",
        password=getpass("Enter MySQL password: "),
        database="cinebook"
    )

    print("MySQL Connected Successfully!")

    cur = con.cursor()
    cur.execute("SELECT * FROM Movies")
    print(cur.fetchall())

    con.close()

except Exception as e:
    print("Connection Error:", e)