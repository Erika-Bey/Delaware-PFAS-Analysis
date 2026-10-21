
# Loads EPA text files into an existing PostgreSQL database

# Run python load_data.py in the terminal
# Afterwards, run SQL files 01-04

from pathlib import Path
from getpass import getpass
import pandas as pd
from sqlalchemy import create_engine, URL, Text, Numeric, Date, text


# 1. Choose the database and data folder
DB_USER = ""
DB_NAME = "pfas_analysis"
DB_HOST = "localhost"
DB_PORT = 5432
DATA_DIR = Path(__file__).resolve().parent/"data"/"raw"

# 2. Read and clean the two files
# (Read as text first to preserve leading zeros and literal identifiers like "NA")
ucmr5_raw = pd.read_csv(DATA_DIR / "UCMR5_All.txt", sep="\t", encoding="latin1", dtype="string", keep_default_na=False)
ucmr5_raw.columns = ucmr5_raw.columns.str.strip().str.lower()

for column in ucmr5_raw.columns:
    ucmr5_raw[column] = ucmr5_raw[column].str.strip()
ucmr5_raw = ucmr5_raw.replace("", pd.NA)


# Convert dates and concentrations to useful data types
ucmr5_raw["analyticalresultvalue"] = pd.to_numeric(ucmr5_raw["analyticalresultvalue"])
ucmr5_raw["mrl"] = pd.to_numeric(ucmr5_raw["mrl"])
ucmr5_raw["collectiondate"] = pd.to_datetime(ucmr5_raw["collectiondate"], format="%m/%d/%Y").dt.date

zipcodes = pd.read_csv(DATA_DIR / "UCMR5_ZIPCodes.txt", sep="\t", encoding="latin1", dtype="string", keep_default_na=False)
zipcodes.columns = zipcodes.columns.str.strip().str.lower()

zipcodes = zipcodes[["pwsid", "zipcode"]].copy()
for column in zipcodes.columns:
    zipcodes[column] = zipcodes[column].str.strip()
zipcodes = zipcodes.replace("", pd.NA).dropna()
zipcodes["zipcode"] = zipcodes["zipcode"].str.replace(r"\.0$", "", regex=True).str.zfill(5)
zipcodes = zipcodes.drop_duplicates()


# 3. Connect to the database
connection_details = URL.create(
    "postgresql+psycopg", username=DB_USER,
    password=getpass("PostgreSQL password: "),
    host=DB_HOST, port=DB_PORT, database=DB_NAME
)
engine = create_engine(connection_details)


# 4. Save the tables
column_types = {column: Text() for column in ucmr5_raw.columns}
column_types.update(analyticalresultvalue=Numeric(), mrl=Numeric(), collectiondate=Date())


# Commits both tables together or roll back if a database step fails
with engine.begin() as conn:
    # head(0) creates an empty table if there are none existing
    ucmr5_raw.head(0).to_sql(
        "ucmr5_raw", conn, schema="public", if_exists="append",
        index=False, dtype=column_types
    )
    zipcodes.head(0).to_sql(
        "zipcodes", conn, schema="public", if_exists="append",
        index=False, dtype={"pwsid": Text(), "zipcode": Text()}
    )

    # Empty the tables without dropping them, so dependent views stay valid
    conn.execute(text("TRUNCATE TABLE public.ucmr5_raw, public.zipcodes"))
    ucmr5_raw.to_sql(
        "ucmr5_raw", conn, schema="public", if_exists="append",
        index=False, chunksize=2000, dtype=column_types
    )
    zipcodes.to_sql(
        "zipcodes", conn, schema="public", if_exists="append",
        index=False, chunksize=2000
    )

    # 5. Check how many rows were saved
    print("ucmr5_raw rows:", conn.execute(text("SELECT COUNT(*) FROM public.ucmr5_raw")).scalar_one())
    print("zipcodes rows:", conn.execute(text("SELECT COUNT(*) FROM public.zipcodes")).scalar_one())

engine.dispose()
print("Load committed.")
