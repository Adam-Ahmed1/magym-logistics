
import db

try:
    connection = db.get_connection()

    print("SUCCESS! Connected to SQL Server.")

    cursor = connection.cursor()
    cursor.execute("SELECT DB_NAME()")

    database_name = cursor.fetchone()[0]
    print("Connected database:", database_name)

    connection.close()

except Exception as e:
    print("DATABASE CONNECTION FAILED!")
    print("Error:", e)
