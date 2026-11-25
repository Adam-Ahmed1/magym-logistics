
import os


class Config:
    SECRET_KEY = os.environ.get(
        'SECRET_KEY',
        'magym-team44-dev-secret-key-2026'
    )

    # Database settings
    DB_DRIVER = os.environ.get(
        'DB_DRIVER',
        'ODBC Driver 18 for SQL Server'
    )

    DB_SERVER = os.environ.get(
        'DB_SERVER',
        r'localhost\SQLEXPRESS'
    )

    DB_NAME = os.environ.get(
        'DB_NAME',
        'LocalDeliveryMarketplace_Team_44'
    )

    @classmethod
    def get_connection_string(cls) -> str:
        return (
            f"DRIVER={{{cls.DB_DRIVER}}};"
            f"SERVER={cls.DB_SERVER};"
            f"DATABASE={cls.DB_NAME};"
            "Trusted_Connection=yes;"
            "Encrypt=no;"
            "TrustServerCertificate=yes;"
        )
