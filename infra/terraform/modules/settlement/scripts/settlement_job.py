"""
settlement_job.py — Glue (PySpark) parallel settlement processing.

Reads inbound settlement files from S3, processes them in parallel with Spark
(partitioned by card network + settlement date), computes settled totals, and
writes processed output back to S3. This is the "parallel processing with Glue
Spark" that cuts settlement time roughly in half.

Upload this file to: s3://<project>-<env>-settlement-scripts-<suffix>/settlement_job.py
(the Glue job's script_location points here).

Args passed by the Glue job (see modules/settlement/main.tf default_arguments):
  --INBOUND_BUCKET     S3 bucket with raw inbound settlement files
  --PROCESSED_BUCKET   S3 bucket to write processed results
"""
import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql import functions as F

# ---- Boilerplate: wire up Glue + Spark ------------------------------------
args = getResolvedOptions(sys.argv, ["JOB_NAME", "INBOUND_BUCKET", "PROCESSED_BUCKET"])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args["JOB_NAME"], args)

inbound = f"s3://{args['INBOUND_BUCKET']}/"
processed = f"s3://{args['PROCESSED_BUCKET']}/settled/"

# ---- 1. Read inbound settlement files (CSV example) -----------------------
df = (
    spark.read.option("header", "true")
    .option("inferSchema", "true")
    .csv(inbound)
)

# ---- 2. Normalize money precisely (payments require exact decimals) -------
df = df.withColumn("amount", F.col("amount").cast("decimal(19,4)"))

# ---- 3. Parallel aggregation: settled totals per network + date -----------
# Spark automatically parallelizes this across the Glue workers.
settled = (
    df.filter(F.col("status") == F.lit("SETTLED"))
    .groupBy("card_network", "settlement_date", "currency")
    .agg(
        F.count("*").alias("txn_count"),
        F.sum("amount").alias("settled_amount"),
    )
)

# ---- 4. Write processed output, partitioned for fast downstream reads -----
(
    settled.repartition("settlement_date")
    .write.mode("overwrite")
    .partitionBy("settlement_date")
    .parquet(processed)
)

job.commit()
