import os
from dotenv import load_dotenv
import pandas as pd
from sqlalchemy import create_engine, URL, text

load_dotenv()

PGHOST = os.getenv("PGHOST", "localhost")
PGPORT = os.getenv("PGPORT", "5432")
PGDATABASE = os.getenv("PGDATABASE")
PGUSER = os.getenv("PGUSER")
PGPASSWORD = os.getenv("PGPASSWORD")


connection_url = URL.create(
    drivername="postgresql+psycopg2",
    username=PGUSER,
    password=PGPASSWORD,
    host=PGHOST,
    port=int(PGPORT),
    database=PGDATABASE,
)

engine = create_engine(connection_url)


def load_cohort_table(table, columns, schema="snap_2018_12"):
    """Return the rows of one table for every trial in analysis.cohort.

    Starts from the cohort and LEFT JOINs the table, so trials with no rows in
    that table are kept, with NaN in its columns. Tables with several rows per
    trial (facilities, sponsors, ...) come back with several rows per trial.

    Example:
        sponsors = load_cohort_table("sponsors", ["agency_class", "lead_or_collaborator"])

    
    """
    selected = ", ".join(f"t.{col}" for col in columns)
    query = text(f"""
        SELECT c.nct_id, {selected}
        FROM analysis.cohort c
        LEFT JOIN {schema}.{table} t ON c.nct_id = t.nct_id
    """)
    with engine.connect() as conn:
        return pd.read_sql(query, conn)

