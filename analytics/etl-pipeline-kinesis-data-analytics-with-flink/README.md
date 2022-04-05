# Set up streaming ETL pipelines

[Link](https://aws.amazon.com/getting-started/hands-on/set-up-streaming-etl-pipelines-apache-flink-and-amazon-kinesis-data-analytics/)

In this tutorial, you will learn how to create an Amazon Kinesis Data Analytics for Apache Flink application with Amazon Kinesis Data Streams as a source and a Amazon S3 bucket as a sink.

Random data is ingested using Amazon Kinesis Data Generator. The Apache Flink application code performs a word count on the streaming random data using a tumbling window of 5 minutes. The generated word count is then stored in the specified Amazon S3 bucket. Amazon Athena is used to query data generated in the Amazon S3 bucket to validate the end results.
In this tutorial you will learn how to:

* Create an Amazon Kinesis Data Stream
* Set up an Amazon Kinesis Data Generator
* Send sample data to a Kinesis Data Stream
* Create an Amazon S3 bucket
* Download code for a Kinesis Data Analytics application
* Modify application code
* Compile application code
* Upload Apache Flink Streaming Java code to S3
* Create, configure, and launch a Kinesis Data Analytics application
* Verify results
* Clean up resources