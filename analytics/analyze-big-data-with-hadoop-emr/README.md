# Analyze Big Data with Hadoop

[Link](https://aws.amazon.com/getting-started/hands-on/analyze-big-data/?trk=gs_card)

Create a Hadoop cluster and run a Hive script to process log data

Amazon EMR is a managed service that makes it fast, easy, and cost-effective to run Apache Hadoop and Spark to process vast amounts of data. Amazon EMR also supports powerful and proven Hadoop tools such as Presto, Hive, Pig, HBase, and more. In this project, you will deploy a fully functional Hadoop cluster, ready to analyze log data in just a few minutes. You will start by launching an Amazon EMR cluster and then use a HiveQL script to process sample log data stored in an Amazon S3 bucket. HiveQL, is a SQL-like scripting language for data warehousing and analysis. You can then use a similar setup to analyze your own log files.

## Resources Created

* EMR Cluster
* S3 Bucket
* IAM roles

## Pre Requisites

* Terraform

### Terraform Variables

It's necessary create tfvars file with the following variables

* subnet_id