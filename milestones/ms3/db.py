import pyodbc
from config import Config

def get_connection():
    connection = pyodbc.connect(Config.get_connection_string())
    connection.autocommit = True
    return connection

def query_all(sql: str, params: list = None) -> list[dict]:
    connection = get_connection()
    try:
        cursor = connection.cursor()
        cursor = cursor.execute(sql, params or [])
        if not cursor.description:
            return []
        columns = [column[0] for column in cursor.description]
        results = []
        for row in cursor.fetchall():
            results.append(dict(zip(columns, row)))
        return results
    finally:
        connection.close()

def query_one(sql: str, params: list = None) -> dict | None:
    results = query_all(sql, params)
    return results[0] if results else None

def call_proc(proc_name: str, params: list = None) -> int:
    params = params or []
    
    proc_name = proc_name.strip()
    if not proc_name[0:4] == "dbo.":
        proc_name = "dbo." + proc_name
    
    inputs = ", ".join(["?"] * len(params))

    proc_caller = proc_name + " " + inputs

    sql = f"""
    SET NOCOUNT ON;
    DECLARE @rc INT;
    EXEC @rc = {proc_caller};
    SELECT @rc AS return_code;
    """

    connection = get_connection()
    try:
        cursor = connection.cursor()
        cursor = cursor.execute(sql, params or [])

        ret_val = None
        while True:
            if cursor.description:
                row = cursor.fetchone()
                if row is not None:
                    ret_val = row[0]
            if not cursor.nextset():
                break
        return ret_val
    except pyodbc.Error as e:
        print(f"Database error in {proc_name}: {e}")
        return -1
    finally:
        connection.close()

def call_func(func_name: str, params: list = None):
    params = params or []

    func_name = func_name.strip()
    if not func_name.startswith("dbo."):
        func_name = "dbo." + func_name

    placeholders = ", ".join(["?"] * len(params))
    sql = f"SELECT {func_name}({placeholders}) AS result"

    row = query_one(sql, params)
    return row['result'] if row else None

def call_tvf(func_name: str, params: list = None) -> list[dict]:
    params = params or []

    func_name = func_name.strip()
    if not func_name.startswith("dbo."):
        func_name = "dbo." + func_name

    placeholders = ", ".join(["?"] * len(params))
    sql = f"SELECT * FROM {func_name}({placeholders})"

    return query_all(sql, params)
