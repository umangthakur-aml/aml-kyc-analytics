import os 
from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL
load_dotenv()
print("Port read from .env:", os.getenv("DB_PORT"))
url = URL.create(
    drivername="postgresql+psycopg2",
    username=os.getenv("DB_USER"),
    password=os.getenv("DB_PASSWORD"),
    host=os.getenv("DB_HOST"),
    port=int(os.getenv("DB_PORT")),
    database=os.getenv("DB_NAME")
)
engine = create_engine(url)
with engine.connect() as conn:
    version = conn.execute(text("SELECT version();")).scalar()
    print("connected successfully")
    print (version)
